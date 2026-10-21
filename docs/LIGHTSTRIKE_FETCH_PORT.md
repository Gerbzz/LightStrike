# Downloader cancellation/deadline source port

This narrow source port adapts [LightCraft commit
`2c60d2ab276151d6adf4f272fe4b5dcba90f050b`](https://github.com/storytold/lightcraft/commit/2c60d2ab276151d6adf4f272fe4b5dcba90f050b)
(upstream PR #1778 / issue #1532) onto LightStrike main
`3d805ddf1524b091f7937be0d1e4f69987e72b0f`. The original LightCraft licensing and credit remain in place.

System name resolution runs on a helper thread. The waiting downloader checks cancellation every 250 ms or less and
gives up at the connect deadline. DNS and all subsequent TCP addresses share that deadline. An abandoned system
resolver thread can finish later; the operating system lookup itself is not interrupted. As upstream, a TCP connect
already in progress can block for the remaining connect budget; this does not promise 250 ms cancellation during TCP
connection establishment. TLS handshake and body stall behavior remain unchanged.

The only production adaptation from the upstream HTTP fix is an internal connector callback. Normal requests pass
`TcpStream::connect_timeout`; tests inject local connectors to verify shrinking budgets and deadline exhaustion without
using non-routable external addresses. Resolver mocks cover cancellation before and during lookup and lookup timeout.
A loopback socket covers successful address fallback. Existing downloader tests cover generated payloads, mirrors,
redirects, resumable partials, hashes, caps, stalled bodies, cancellation and URL/token safeguards. No AI model is needed.

No dependencies, workspace features, model catalogs, branding, attribution assets or downloader file-handling logic
change. The complete inherited desktop, CLI and web source remains in the workspace.

## Verification status

Local Rust compilation and execution remain deferred while another suite app owns the build slot, as required by
`AGENTS.md`. The focused GitHub workflow checks the exact PR head on standard Ubuntu and Windows runners: formatting,
test compilation and the synthetic/local fetch suite are separate steps. Ubuntu also checks that synchronous DNS and
per-address timeout mutations cause the relevant behavioral tests to fail, restores the candidate source and reruns
the full fetch suite. Its Unix run includes the existing partial-file symlink regression. Consult the exact-head CI
results for executed outcomes; source checks alone are not runtime acceptance. Hosted results do not establish Room
or full-application/platform acceptance. This source port establishes no release or installer readiness.
