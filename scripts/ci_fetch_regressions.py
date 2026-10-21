"""Behavioral mutation checks for the local-only fetch regressions. No model or external HTTP requests."""

import os
from pathlib import Path
import re
import subprocess


SOURCE = Path("crates/fetch/src/http.rs")
CARGO = ["cargo", "+1.95.0", "test", "--locked", "--profile", "smoke", "-p", "lightcraft-fetch", "--lib"]


def expect_behavioral_failure(test):
    command = CARGO + [f"http::tests_connect::{test}", "--", "--exact", "--nocapture", "--test-threads=1"]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    print(result.stdout, flush=True)
    if result.returncode == 0 or not re.search(r"test result: FAILED\. 0 passed; 1 failed;", result.stdout):
        raise RuntimeError(f"{test} did not produce exactly one behavioral test failure (exit {result.returncode})")
    print(f"EXPECTED BEHAVIORAL FAILURE: {test}", flush=True)


def main():
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if head != os.environ["FETCH_EXPECTED_HEAD"]:
        raise RuntimeError("mutation checks must run against the exact requested head")
    original = SOURCE.read_bytes()
    source = original.decode("utf-8")
    start = source.index("fn lookup(")
    end = source.index("/// Connect to the first of", start)
    synchronous = """fn lookup(
    host: &str,
    resolve: impl FnOnce() -> std::io::Result<Vec<SocketAddr>> + Send + 'static,
    _deadline: Instant,
    limits: &Limits,
) -> Result<Vec<SocketAddr>, HttpError> {
    if limits.cancel.load(Ordering::Relaxed) {
        return Err(HttpError::Cancelled);
    }
    resolve().map_err(|e| HttpError::Connect(format!("{host}: {e}")))
}

"""
    try:
        SOURCE.write_text(source[:start] + synchronous + source[end:], encoding="utf-8")
        expect_behavioral_failure("a_blocked_lookup_times_out_before_the_resolver_finishes")
        expect_behavioral_failure("cancel_stops_an_inflight_lookup_before_the_resolver_finishes")
        connect_start = source.index("fn connect_any(")
        before, connection = source[:connect_start], source[connect_start:]
        budget = "let left = deadline.saturating_duration_since(Instant::now());"
        if connection.count(budget) != 1:
            raise RuntimeError("expected exactly one address budget calculation")
        SOURCE.write_text(before + connection.replace(budget, "let left = limits.connect;", 1), encoding="utf-8")
        expect_behavioral_failure("lookup_and_each_address_consume_the_same_connect_budget")
    finally:
        SOURCE.write_bytes(original)
    if SOURCE.read_bytes() != original:
        raise RuntimeError("candidate source was not restored")
    print(f"PASS: all three behavioral mutations rejected; source restored at {head}", flush=True)


if __name__ == "__main__":
    main()
