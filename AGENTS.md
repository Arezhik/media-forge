# media-forge

Monorepo for Arezhik's macOS media apps and the shared MediaForge package.
Read this before the first change.

## Layout

- `Packages/MediaForge` — canonical Swift package. Products: `MediaCore`, `MediaUI`, `MediaTesting`.
- `Apps/MKVForge` — MKV Forge (macOS 15), with its own package, version, and tags `mkvforge-vX.Y.Z`. Workflow: `.github/workflows/mkvforge.yml`.
- `Apps/pgs2srt` and `Apps/mp4subrip` — not imported yet. They keep macOS 13 and macOS 14 when they land.
- `scripts/` — local checks. `scripts/verify-linux.sh` is the Linux gate for MediaForge and the root umbrella.
- `.github/workflows/ci.yml` — Linux and macOS `swift test` / `swift build` for MediaForge and the umbrella.
- `.github/workflows/mkvforge.yml` — MKVForge Linux tests, macOS tests, and the universal app.

`Package.swift` at the repo root is a thin umbrella. It depends on
`.package(path: "Packages/MediaForge")` so the root is a valid Swift package.
Sources live only in `Packages/MediaForge`. Do not duplicate them in the root manifest.

`swift test` at the repo root does not run tests from a path dependency. Test
the canonical package with the command below. CI also runs a thin root
`swift test` so the umbrella manifest stays valid. That run does not replace
the canonical tests. `Apps/MKVForge/Package.swift` is a separate package and
is not a root dependency, so `.github/workflows/ci.yml` keeps testing
MediaForge and the umbrella.

## Locked rules

- MediaForge floor is macOS 13.
- Apps keep their own deployment targets: PGS 13, MP4 14, MKV 15. Newer UI APIs are availability-gated or stay in the app.
- Swift 6 strict concurrency and warnings-as-errors. Pass `-Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` on every `swift test` and `swift build`.
- Never hand-edit `project.pbxproj`. Edit `project.yml` and regenerate with XcodeGen.
- App engines stay in the apps: PGS OCR/review, MP4 caption engines, MKV scan/remux matching, `ConversionQueue` / `BatchRunner`, and track pickers.
- Each app keeps its own semver and build number, and per-app tags `mkvforge-vX.Y.Z` (MKV Forge is 0.8.1, build 10). There is no single monorepo `vX.Y.Z`.
- One PR per phase. Green CI is required. Arezhik tests on a Mac before merge.
- `MediaCore` and `MediaTesting` stay Linux-buildable: no AppKit, SwiftUI, or Vision imports. `MediaUI` may import SwiftUI only inside `#if canImport(SwiftUI)`, with a Linux-safe type outside that guard, so Linux `swift test` still passes.
- CI pins Swift 6.2.4 (`container: image: swift:6.2.4` on the Linux job), matching mkv-forge, pgs2srt, and mp4-sub-rip. Change that pin only together with this file.

## Tests

```bash
swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

On a Linux machine with no Swift toolchain, `./scripts/verify-linux.sh` prints that GitHub Actions will run those commands and exits 0.

## Where you run

You work on Linux. Do not install or upgrade Swift here. Do not hand-edit `project.pbxproj`. MKV Forge versions change with `Apps/MKVForge/scripts/bump-version.sh`. Its releases are tagged `mkvforge-vX.Y.Z`. PGS2SRT and MP4SubRip are not imported yet; each will keep its own version and tag.
