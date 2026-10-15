# LightStrike foundation and verification

## Provenance

- Official counterpart: [LightCraft](https://getartcraft.com/apps/lightcraft), whose [source link](https://github.com/storytold/lightcraft) resolves to the upstream Rust workspace.
- Exact source pin: `0da998f24dfc03069d49867f8877af2bf7c51f94` (2026-10-15). The public root is a new snapshot so restricted upstream `docs/brand/` artwork is absent from its history.
- Source licence: MIT OR Apache-2.0. The `crates/segment` SAM 3 code is Apache-2.0 only; its optional weights have separate terms and are not bundled. See NOTICE and assets/ATTRIBUTION.md.
- The lynx app icon has its own explicit MIT OR Apache-2.0 notice. The approved PWDS mark is separately licensed and copied unchanged.

## Why this foundation

LightCraft already has the application structure LightStrike needs: an egui desktop editor, a web host, a headless CLI and MCP surface, image import and catalog, non-destructive settings, CPU/GPU development, raw decoders, and export. Its own roadmap calls it alpha and identifies quality and camera-coverage gaps. A few image crates or a repainted shell would not provide a comparable workflow.

Darktable and RawTherapee are mature alternatives for photo development, but their application cores and copyleft licences do not match the Rust/permissive-source direction of this suite. A new Rust UI over them would require a substantial compatibility and licence plan. LightCraft is the strongest directly compatible full-app starting point found; this is a foundation choice, not a parity claim.

## Implemented here

- Full source snapshot and required upstream notices, without the restricted ArtCraft artwork.
- Independent LightStrike desktop identity and approved PWDS mark on the initial loading screen and About panel.
- Independent repository/help/issue links in the visible app UI; original project credited in About and documentation.
- Hosted verification workflow passed at code revision `fe68809`; exact headless, native-window, and export captures are preserved in `docs/images/` with attribution.

## Verification

The inherited source pin, licence texts, app-icon licence, and separate brand terms were reviewed directly. No local Rust compilation was run because the shared C: drive and build slot are reserved for another app. Local `cargo fmt --all --check`, offline locked metadata resolution, Python syntax, and changed-file whitespace checks passed.

[Hosted run 38721570167](https://github.com/Gerbzz/LightStrike/actions/runs/38721570167) passed at code commit `f8682b23d2e74a4fec8b5277fc757d17ff26fe39` on public Ubuntu 24.04 with Rust 1.95.0. It built the complete desktop and CLI binaries in an unoptimized `smoke` profile with optional default denoise disabled. The script generated a 96×64 PNG; imported it into a real persistent library; set exposure to 0.75; exported a 60×40 PNG; reopened the library in another process and confirmed the saved edit; and verified the imported original's SHA-256 was unchanged. It rendered 1280×800 startup and About screens through the CPU headless egui host. The exact [startup](images/lightstrike-startup-headless.png), [About](images/lightstrike-about-headless.png), and [export](images/lightstrike-synthetic-export.png) images were downloaded, compared by hash with their run artifacts, and visually inspected. The initial [run 38721423352](https://github.com/Gerbzz/LightStrike/actions/runs/38721423352) stopped before compilation because the new UI image dependency lacked a lockfile entry; commit `f8682b2` corrected it.

The later [hosted run 38723828993](https://github.com/Gerbzz/LightStrike/actions/runs/38723828993) passed at code commit `fe68809510fa0b948fca1500a723a74463e56967`. It again built the desktop and CLI binaries and ran the PNG workflow, then generated a synthetic JPEG, imported it into another persistent library, edited exposure, and exported a 48x32 PNG. It launched the actual native desktop app on Ubuntu 24.04 under Xvfb/Glow. The capture script queried the running application's `ui.inspect` state until its active loupe reported `source: render`, `pending: false`, and `failed: null`; only then did it capture the [1280x800 native editor](images/lightstrike-native-home-ubuntu24.png). That image visibly shows the rendered procedural photo, histogram, filmstrip, and develop controls. Some background thumbnails were still queued in this unoptimized CPU run. The exact [JPEG-derived export](images/lightstrike-jpeg-import-export.png) and native image were downloaded, hash-checked against the run artifacts, visually inspected, and indexed with adjacent attribution sidecars.

These results establish a synthetic Linux source baseline with one settled native editor image. The screenshot additions after `fe68809` change documentation/assets only; they do not change application code.

## Remaining

- Validate native behavior with real images, Windows/macOS behavior, and package identity before a downloadable release.
- Add representative licensed camera JPEG and raw fixtures, colour/mask checks, and visual comparison against independent reference cases.
- Address camera colour, raw variants, lens database, rendering fidelity, AI model terms, and large-library stability using measured fixtures; see upstream ROADMAP.md and docs/gaps.md for source-project details.
- Replace the temporary, openly licensed upstream app icon with approved LightStrike artwork when one exists. Do not create a new logo from the restricted ArtCraft marks.
