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
- Hosted verification workflow: pending.

## Verification

The inherited source pin, licence texts, app-icon licence, and separate brand terms were reviewed directly. No local Rust compilation was run because the shared C: drive and build slot are reserved for another app. Hosted build, synthetic import/develop/save/reopen/export, and UI captures are pending and must be attached here with exact run and commit before any release claim.

## Remaining

- Confirm hosted Linux desktop and CLI builds, a native or headless branded UI capture, and synthetic end-to-end image workflow.
- Validate Windows and macOS behavior and package identity before a downloadable release.
- Address camera colour, raw variants, lens database, rendering fidelity, AI model terms, and large-library stability using measured fixtures; see upstream ROADMAP.md and docs/gaps.md for source-project details.
- Replace the temporary, openly licensed upstream app icon with approved LightStrike artwork when one exists. Do not create a new logo from the restricted ArtCraft marks.
