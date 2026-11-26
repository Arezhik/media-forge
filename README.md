# media-forge

Monorepo for a shared Swift package and three native macOS media apps.

- **MediaForge** (`Packages/MediaForge`) — libraries `MediaCore`, `MediaUI`, and `MediaTesting`. The package floor is macOS 13. `MediaCore` and `MediaTesting` build on Linux. `MediaUI` uses SwiftUI only where that framework is available.
- **Apps**
  - `Apps/MKVForge` — MKV Forge (macOS 15). Own package, XcodeGen project, and version (0.8.1, build 10). CI: `.github/workflows/mkvforge.yml` (workflow name MKVForge CI). Release tags: `mkvforge-vX.Y.Z`.
  - `Apps/pgs2srt` — PGS2SRT (macOS 13). Not imported yet.
  - `Apps/mp4subrip` — MP4SubRip (macOS 14). Not imported yet.

Each app keeps its own deployment target, semver, build number, and tag (`mkvforge-vX.Y.Z` for MKV Forge).

The root `Package.swift` is a thin umbrella over `Packages/MediaForge`. It does not contain the library sources. The canonical package, and the one root CI (`.github/workflows/ci.yml`) tests, is `Packages/MediaForge`. `Apps/MKVForge/Package.swift` is a separate package. MKVForge tests run in `.github/workflows/mkvforge.yml`.

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

A root `swift test` does not run the MediaForge package tests. Run the `--package-path` command for those. `Apps/MKVForge/Package.swift` is a separate package, so the root commands stay on the umbrella.

MKV Forge checks, from `Apps/MKVForge`:

```bash
./scripts/verify-linux.sh
bash scripts/bump-version.sh --check
bash scripts/check-project.sh
```

On Linux without Swift installed, the root `./scripts/verify-linux.sh` prints the GitHub Actions commands and exits 0. GitHub Actions runs the package tests on Linux (`swift:6.2.4`) and on macOS. MKVForge's workflow is `.github/workflows/mkvforge.yml`.

Agents: read `AGENTS.md` before changing the repo.
