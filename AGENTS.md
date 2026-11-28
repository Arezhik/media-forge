# media-forge

Monorepo for Arezhik's macOS media apps and the shared MediaForge package.
Read this before the first change.

## Layout

- `Packages/MediaForge` — canonical Swift package. Products: `MediaCore` (UITestingEnvironment, RollingLogStore, DebugLog with one category set, ProgressThrottle, ExternalTool locator, ToolCommand runner), `MediaUI`, and `MediaTesting` (UITestFixtureBuilder).
- `Apps/MKVForge` — MKV Forge (macOS 15), with its own package, version, and tags `mkvforge-vX.Y.Z`. Workflow: `.github/workflows/mkvforge.yml`.
- `Apps/MP4SubRip` — MP4SubRip (macOS 15), with its own package, version, and tags `mp4subrip-vX.Y.Z`. Workflow: `.github/workflows/mp4subrip.yml`.
- `Apps/PGS2SRT` — PGS2SRT (macOS 15), with its own package, version, and tags `pgs2srt-vX.Y.Z`. Workflow: `.github/workflows/pgs2srt.yml`.
- `Apps/MediaForgeCatalog` — MediaForgeCatalog (macOS 15). Internal developer catalog for MediaUI and MediaTesting. Not shipped and not released. Version 0.1.0 (build 1). Workflow: `.github/workflows/mediaforgecatalog.yml`.
- `scripts/` — shared local checks. `scripts/bump-version.sh <app>` checks or bumps one app (`mkvforge`, `mp4subrip`, `pgs2srt`, or `mediaforgecatalog`) and tags `<app>-vX.Y.Z`. The catalog is not released. `scripts/verify-linux.sh` runs MediaForge and the root umbrella, then the apps, when given `all` or no arguments. `package` is MediaForge and the umbrella only. An app name runs that app. `Apps/<App>/scripts/bump-version.sh` and `verify-linux.sh` forward to these. `Apps/MKVForge/scripts/check-project.sh` stays an app script.
- `.github/workflows/ci.yml` — Linux and macOS `swift test` / `swift build` for MediaForge and the umbrella.
- `.github/workflows/mkvforge.yml` — MKVForge Linux tests, macOS tests, and the universal app.
- `.github/workflows/mp4subrip.yml` — MP4SubRip Linux tests, macOS tests, and the universal app.
- `.github/workflows/pgs2srt.yml` — PGS2SRT Linux tests, macOS tests, and the universal app.
- `.github/workflows/mediaforgecatalog.yml` — MediaForgeCatalog Linux tests, macOS tests, and the universal app. Not a release.

`Package.swift` at the repo root is a thin umbrella. It depends on
`.package(path: "Packages/MediaForge")` so the root is a valid Swift package.
Sources live only in `Packages/MediaForge`. Do not duplicate them in the root manifest.

`swift test` at the repo root does not run tests from a path dependency. Test
the canonical package with the command below. CI also runs a thin root
`swift test` so the umbrella manifest stays valid. That run does not replace
the canonical tests. `Apps/MKVForge/Package.swift`, `Apps/MP4SubRip/Package.swift`,
`Apps/PGS2SRT/Package.swift`, and `Apps/MediaForgeCatalog/Package.swift` are separate packages and are not root dependencies,
so `.github/workflows/ci.yml` keeps testing MediaForge and the umbrella.

## Locked rules

- MediaForge floor is macOS 15.
- All apps and MediaForge target macOS 15+. Newer UI APIs are availability-gated or stay in the app.
- Swift 6 strict concurrency and warnings-as-errors. Pass `-Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` on every `swift test` and `swift build`.
- Never hand-edit `project.pbxproj`. Edit `project.yml` and regenerate with XcodeGen.
- Shared features go into `Packages/MediaForge` first. App-specific engines stay in the apps: PGS OCR/review, MP4 caption engines, MKV scan/remux matching, `ConversionQueue` / `BatchRunner`, and track pickers.
- Releases use per-app tags `<app>-vX.Y.Z` (for example `mkvforge-v0.8.5`) via `.github/workflows/release.yml` on push to `main`. Not a single monorepo `vX.Y.Z`. There is one shared Releases page. Each app keeps its own semver and build number: MKV Forge is 1.2.0 (build 17), MP4SubRip is 1.0.0 (build 16), and PGS2SRT is 1.0.0 (build 12).
- MediaForgeCatalog is an internal developer catalog. It is not shipped. Do not add it to `release.yml`.
- One PR per phase. Green CI is required. Arezhik tests on a Mac before merge.
- `MediaCore` and `MediaTesting` stay Linux-buildable: no AppKit, SwiftUI, or Vision imports. `MediaUI` may import SwiftUI only inside `#if canImport(SwiftUI)`, with a Linux-safe type outside that guard, so Linux `swift test` still passes.
- CI pins Swift 6.2.4 (`container: image: swift:6.2.4` on the Linux job), matching mkv-forge, pgs2srt, and mp4-sub-rip. Change that pin only together with this file.

## Tests

```bash
swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

When `swift` is on PATH, `./scripts/verify-linux.sh` (or `./scripts/verify-linux.sh all`) runs the MediaForge `swift test` and `swift build` commands above, then the root umbrella `swift test`, with the same strict flags, then each app (XcodeGen when a binary is available, that app's non-Swift checks, then `swift test` and `swift build` from the app directory). `./scripts/verify-linux.sh package` stops after MediaForge and the umbrella. `./scripts/verify-linux.sh mkvforge` (or `mp4subrip`, `pgs2srt`, or `mediaforgecatalog`) runs only that app. On a Linux machine with no Swift toolchain, the package portion prints that GitHub Actions will run those commands and does not fail; each app portion still runs its non-Swift checks, prints the app `swift` commands, and does not fail. Missing `xcodegen` is not a failure.

## Where you run

You work on Linux. Do not install or upgrade Swift here. Do not hand-edit `project.pbxproj`. Versions change with `scripts/bump-version.sh <app>` from the repo root (`mkvforge`, `mp4subrip`, `pgs2srt`, or `mediaforgecatalog`). The copy in each `Apps/<App>/scripts/` forwards to that command. Every bump also adds 1 to the build number. Docs-only and CI-only PRs don't bump. MKV Forge is 1.2.0 (build 17), tagged `mkvforge-vX.Y.Z`. MP4SubRip is 1.0.0 (build 16), tagged `mp4subrip-vX.Y.Z`. PGS2SRT is 1.0.0 (build 12), tagged `pgs2srt-vX.Y.Z`. PGS2SRT has no `CHANGELOG.md`; `--check` still requires `project.pbxproj` and `App/project.yml` to agree, and the script does not create a changelog. `--check-against` allows an unchanged version and build. The build must rise when the version changes, and the build must not go down.
