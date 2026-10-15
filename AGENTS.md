# LightStrike workspace

This is the full LightCraft Rust application source pinned and credited in README.md.
Keep the upstream MIT OR Apache-2.0 notices and per-asset attribution intact.
Do not restore `docs/brand/` ArtCraft marks or imply ArtCraft endorses LightStrike.
The PWDS mark is separately licensed in `assets/branding/LICENSE-brand.txt`; use
the existing file unchanged.

Keep internal crate names until a deliberate, tested migration. Prefer changes
that retain the desktop, CLI, web, import, develop, library, and export paths.
Before claiming a workflow works, run an end-to-end check with generated or
licence-safe input and record the environment and exact commit. Treat upstream
ROADMAP.md and docs/gaps.md as source-project assessments, not LightStrike
acceptance results.

This workspace is sharing a Windows host with other Strike builds. Preserve the
20 GiB free-space floor on C: and do not compile locally while another suite app
owns the build slot. Use only bounded, free public hosted checks when authorized.
