//! Local resolver/connector mocks for upstream issue #1532. No external network or model downloads.

use super::*;
use std::net::TcpListener;
use std::sync::mpsc;

fn limits(cancel: &AtomicBool) -> Limits<'_> {
    Limits { connect: Duration::from_millis(500), stall: Duration::from_secs(1), cancel }
}

fn addresses() -> Vec<SocketAddr> {
    vec!["127.0.0.1:1".parse().unwrap(), "127.0.0.1:2".parse().unwrap()]
}

#[test]
fn a_pre_cancelled_lookup_never_starts_the_resolver() {
    let cancel = AtomicBool::new(true);
    let start = Instant::now();
    let result = lookup("local", || panic!("cancelled lookup must not resolve"), start + Duration::from_secs(3), &limits(&cancel));
    assert_eq!(result, Err(HttpError::Cancelled));
    assert!(start.elapsed() < Duration::from_secs(1));
}

#[test]
fn a_blocked_lookup_times_out_before_the_resolver_finishes() {
    let cancel = AtomicBool::new(false);
    let (release, wait) = mpsc::channel();
    let (finished, done) = mpsc::channel();
    let start = Instant::now();
    let result = lookup(
        "local",
        move || {
            let _ = wait.recv_timeout(Duration::from_secs(3));
            let _ = finished.send(());
            Ok(Vec::new())
        },
        start + Duration::from_millis(100),
        &limits(&cancel),
    );
    let elapsed = start.elapsed();
    let still_running = matches!(done.try_recv(), Err(mpsc::TryRecvError::Empty));
    let _ = release.send(());
    if still_running {
        done.recv_timeout(Duration::from_secs(1)).unwrap();
    }
    assert!(matches!(result, Err(HttpError::Connect(ref message)) if message.contains("local") && message.contains("timed out")), "{result:?}");
    assert!(still_running, "lookup must return while the system resolver is still blocked");
    assert!(elapsed < Duration::from_secs(1), "{elapsed:?}");
}

#[test]
fn cancel_stops_an_inflight_lookup_before_the_resolver_finishes() {
    let cancel = Arc::new(AtomicBool::new(false));
    let (started, ready) = mpsc::channel();
    let (release, wait) = mpsc::channel();
    let (finished, done) = mpsc::channel();
    let flag = cancel.clone();
    let canceller = std::thread::spawn(move || {
        ready.recv_timeout(Duration::from_secs(3)).unwrap();
        flag.store(true, Ordering::Relaxed);
    });
    let start = Instant::now();
    let result = lookup(
        "local",
        move || {
            started.send(()).unwrap();
            let _ = wait.recv_timeout(Duration::from_secs(3));
            let _ = finished.send(());
            Ok(Vec::new())
        },
        start + Duration::from_secs(3),
        &limits(&cancel),
    );
    let elapsed = start.elapsed();
    let still_running = matches!(done.try_recv(), Err(mpsc::TryRecvError::Empty));
    let _ = release.send(());
    if still_running {
        done.recv_timeout(Duration::from_secs(1)).unwrap();
    }
    canceller.join().unwrap();
    assert_eq!(result, Err(HttpError::Cancelled));
    assert!(still_running, "cancel must not wait for the system resolver to return");
    assert!(elapsed < Duration::from_secs(1), "{elapsed:?}");
}

#[test]
fn lookup_preserves_addresses_empty_answers_and_errors() {
    let cancel = AtomicBool::new(false);
    let deadline = Instant::now() + Duration::from_secs(3);
    let expected = addresses();
    let answer = expected.clone();
    assert_eq!(lookup("local", move || Ok(answer), deadline, &limits(&cancel)).unwrap(), expected);
    assert!(lookup("local", || Ok(Vec::new()), deadline, &limits(&cancel)).unwrap().is_empty());
    let result = lookup("local", || Err(std::io::Error::other("mock resolution failure")), deadline, &limits(&cancel));
    assert!(
        matches!(result, Err(HttpError::Connect(ref message)) if message.contains("local") && message.contains("mock resolution failure")),
        "{result:?}"
    );
}

#[test]
fn lookup_and_each_address_consume_the_same_connect_budget() {
    let cancel = AtomicBool::new(false);
    let deadline = Instant::now() + Duration::from_millis(500);
    let addrs = lookup(
        "local",
        || {
            std::thread::sleep(Duration::from_millis(100));
            Ok(addresses())
        },
        deadline,
        &limits(&cancel),
    )
    .unwrap();
    let mut budgets = Vec::new();
    let result = connect_any("local", &addrs, deadline, &limits(&cancel), |_, left| {
        budgets.push(left);
        std::thread::sleep(Duration::from_millis(100));
        Err(std::io::Error::new(ErrorKind::ConnectionRefused, "mock refusal"))
    });
    assert!(matches!(result, Err(HttpError::Connect(ref message)) if message.contains("mock refusal")), "{result:?}");
    assert_eq!(budgets.len(), 2);
    assert!(budgets[0] <= Duration::from_millis(400), "DNS must consume the connect budget: {budgets:?}");
    assert!(budgets[1] <= budgets[0].saturating_sub(Duration::from_millis(100)), "attempts must share the remaining budget: {budgets:?}");
}

#[test]
fn an_attempt_exhausting_the_deadline_prevents_later_attempts() {
    let cancel = AtomicBool::new(false);
    let start = Instant::now();
    let mut calls = 0;
    let result = connect_any("local", &addresses(), start + Duration::from_millis(100), &limits(&cancel), |_, left| {
        calls += 1;
        std::thread::sleep(left);
        Err(std::io::Error::new(ErrorKind::TimedOut, "mock timeout"))
    });
    assert!(matches!(result, Err(HttpError::Connect(ref message)) if message.contains("connecting timed out")), "{result:?}");
    assert_eq!(calls, 1, "later addresses must not receive a fresh timeout");
    assert!(start.elapsed() < Duration::from_secs(1));
}

#[test]
fn cancelled_expired_and_empty_connections_do_not_call_the_connector() {
    let cancel = AtomicBool::new(true);
    assert!(matches!(
        connect_any("local", &addresses(), Instant::now() + Duration::from_secs(3), &limits(&cancel), |_, _| panic!("cancelled")),
        Err(HttpError::Cancelled)
    ));
    cancel.store(false, Ordering::Relaxed);
    assert!(matches!(
        connect_any("local", &addresses(), Instant::now(), &limits(&cancel), |_, _| panic!("expired")),
        Err(HttpError::Connect(message)) if message.contains("timed out")
    ));
    assert!(matches!(
        connect_any("local", &[], Instant::now() + Duration::from_secs(3), &limits(&cancel), |_, _| panic!("empty")),
        Err(HttpError::Connect(message)) if message == "local: no address"
    ));
}

#[test]
fn connection_fallback_keeps_address_order_and_uses_the_successful_socket() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addrs = [addresses()[0], listener.local_addr().unwrap()];
    let cancel = AtomicBool::new(false);
    let mut attempted = Vec::new();
    let socket = connect_any("local", &addrs, Instant::now() + Duration::from_secs(3), &limits(&cancel), |address, left| {
        attempted.push(*address);
        if attempted.len() == 1 {
            Err(std::io::Error::new(ErrorKind::ConnectionRefused, "mock first-address failure"))
        } else {
            TcpStream::connect_timeout(address, left)
        }
    })
    .unwrap();
    assert_eq!(attempted, addrs);
    assert_eq!(socket.peer_addr().unwrap(), addrs[1]);
}
