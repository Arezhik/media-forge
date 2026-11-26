# media-forge

Monorepo for a shared Swift package and three native macOS media apps.

- **MediaForge** (`Packages/MediaForge`) — libraries `MediaCore`, `MediaUI`, and `MediaTesting`. The package floor is macOS 13. `MediaCore` and `MediaTesting` build on Linux. `MediaUI` uses SwiftUI only where that framework is available.
- **Apps**
  - `Apps/MKVForge` — MKV Forge (macOS 15). Own package, XcodeGen project, and version (0.8.1, build 10). CI: `.github/workflows/mkvforge.yml` (workflow name MKVForge CI). Release tags: `mkvforge-vX.Y.Z`.
  - `Apps/MP4SubRip` — MP4SubRip (macOS 14). Own package, XcodeGen project, and version (0.8.0, build 10). CI: `.github/workflows/mp4subrip.yml` (workflow name MP4SubRip CI). Release tags: `mp4subrip-vX.Y.Z`.
  - `Apps/PGS2SRT` — PGS2SRT (macOS 13). Own package, XcodeGen project, and version (0.3.0, build 7). CI: `.github/workflows/pgs2srt.yml` (workflow name PGS2SRT CI). Release tags: `pgs2srt-vX.Y.Z`.

Each app keeps its own deployment target, semver, build number, and tag (`mkvforge-vX.Y.Z` for MKV Forge, `mp4subrip-vX.Y.Z` for MP4SubRip, `pgs2srt-vX.Y.Z` for PGS2SRT).

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

MKV Forge checks, from `Apps/MKVForge`:

```bash
./scripts/verify-linux.sh
bash scripts/bump-version.sh --check
bash scripts/check-project.sh
```

MP4SubRip checks, from `Apps/MP4SubRip`:

```bash
./scripts/verify-linux.sh
bash scripts/bump-version.sh --check
```

PGS2SRT checks, from `Apps/PGS2SRT`:

```bash
./scripts/verify-linux.sh
```

On Linux without Swift installed, the root `./scripts/verify-linux.sh` prints the GitHub Actions commands and exits 0. GitHub Actions runs the package tests on Linux (`swift:6.2.4`) and on macOS. MKVForge's workflow is `.github/workflows/mkvforge.yml`. MP4SubRip's workflow is `.github/workflows/mp4subrip.yml`. PGS2SRT's workflow is `.github/workflows/pgs2srt.yml`.

Agents: read `AGENTS.md` before changing the repo.
