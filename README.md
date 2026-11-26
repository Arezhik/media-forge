# media-forge

Monorepo for a shared Swift package and three native macOS media apps.

- **MediaForge** (`Packages/MediaForge`) — libraries `MediaCore`, `MediaUI`, and `MediaTesting`. The package floor is macOS 15. `MediaCore` and `MediaTesting` build on Linux. `MediaUI` uses SwiftUI only where that framework is available. `MediaCore` holds `UITestingEnvironment`, `RollingLogStore`, `DebugLog` (one category set for every app), and `ProgressThrottle`. `MediaTesting` holds `UITestFixtureBuilder`.
- **Apps**
  - `Apps/MKVForge` — MKV Forge (macOS 15). Own package, XcodeGen project, and version (0.8.2, build 11). CI: `.github/workflows/mkvforge.yml` (workflow name MKVForge CI). Release tags: `mkvforge-vX.Y.Z`.
  - `Apps/MP4SubRip` — MP4SubRip (macOS 15). Own package, XcodeGen project, and version (0.8.1, build 11). CI: `.github/workflows/mp4subrip.yml` (workflow name MP4SubRip CI). Release tags: `mp4subrip-vX.Y.Z`.
  - `Apps/PGS2SRT` — PGS2SRT (macOS 15). Own package, XcodeGen project, and version (0.3.1, build 8). CI: `.github/workflows/pgs2srt.yml` (workflow name PGS2SRT CI). Release tags: `pgs2srt-vX.Y.Z`.

Every app targets macOS 15. Each app keeps its own semver, build number, and tag (`mkvforge-vX.Y.Z` for MKV Forge, `mp4subrip-vX.Y.Z` for MP4SubRip, `pgs2srt-vX.Y.Z` for PGS2SRT).

The root `Package.swift` is a thin umbrella over `Packages/MediaForge`. It does not contain the library sources. The canonical package, and the one root CI (`.github/workflows/ci.yml`) tests, is `Packages/MediaForge`. `Apps/MKVForge/Package.swift`, `Apps/MP4SubRip/Package.swift`, and `Apps/PGS2SRT/Package.swift` are separate packages. MKVForge tests run in `.github/workflows/mkvforge.yml`. MP4SubRip tests run in `.github/workflows/mp4subrip.yml`. PGS2SRT tests run in `.github/workflows/pgs2srt.yml`.

## Clone

```bash
git clone https://github.com/Arezhik/media-forge.git
cd media-forge
```

## Tests

Use Swift 6.2.4, with strict concurrency and warnings as errors:

```bash
swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

To check that the root umbrella still links the three products:

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

A root `swift test` does not run the MediaForge package tests. Run the `--package-path` command for those. `Apps/MKVForge/Package.swift`, `Apps/MP4SubRip/Package.swift`, and `Apps/PGS2SRT/Package.swift` are separate packages, so the root commands stay on the umbrella.

Shared checks, from the repo root:

```bash
./scripts/verify-linux.sh                  # MediaForge, the umbrella, then all three apps
./scripts/verify-linux.sh package          # MediaForge and the umbrella only
./scripts/verify-linux.sh mkvforge         # one of: mkvforge, mp4subrip, pgs2srt
./scripts/bump-version.sh mkvforge --check
./scripts/bump-version.sh mp4subrip --current
./scripts/bump-version.sh pgs2srt --check-against origin/main
```

`<app>` is exactly `mkvforge`, `mp4subrip`, or `pgs2srt`. A bump is `./scripts/bump-version.sh <app> patch|minor|major`. Every bump also adds 1 to the build number. Docs-only and CI-only PRs don't bump. Tags stay per app (`mkvforge-vX.Y.Z`, `mp4subrip-vX.Y.Z`, `pgs2srt-vX.Y.Z`), never a bare `vX.Y.Z`. PGS2SRT has no `CHANGELOG.md`. `--check` still requires `project.pbxproj` and `App/project.yml` to agree, and the script does not create a changelog. `--check-against` allows an unchanged version and build. The build must rise when the version changes, and the build must not go down.

The same commands work from an app directory. `Apps/<App>/scripts/verify-linux.sh` and `bump-version.sh` forward to the root scripts. `Apps/MKVForge/scripts/check-project.sh` stays there.

```bash
# from Apps/MKVForge
./scripts/verify-linux.sh
bash scripts/bump-version.sh --check
bash scripts/check-project.sh

# from Apps/MP4SubRip or Apps/PGS2SRT
./scripts/verify-linux.sh
bash scripts/bump-version.sh --check
```

When `swift` is on PATH, `./scripts/verify-linux.sh all` runs the MediaForge and umbrella commands above, then each app. On Linux without Swift installed, the package portion prints the GitHub Actions commands and does not fail. Each app run regenerates that app's Xcode project with XcodeGen when a binary is available (a missing `xcodegen` is not a failure), runs the app's non-Swift checks, and runs `swift test` and `swift build` from the app directory when `swift` is on PATH. Without `swift`, it prints those commands and does not fail. GitHub Actions runs the package tests on Linux (`swift:6.2.4`) and on macOS. MKVForge's workflow is `.github/workflows/mkvforge.yml`. MP4SubRip's workflow is `.github/workflows/mp4subrip.yml`. PGS2SRT's workflow is `.github/workflows/pgs2srt.yml`. Those workflows also run when `scripts/**` changes.

Agents: read `AGENTS.md` before changing the repo.
