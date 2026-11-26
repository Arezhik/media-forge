# media-forge

Monorepo for a shared Swift package and three native macOS media apps.

- **MediaForge** (`Packages/MediaForge`) — libraries `MediaCore`, `MediaUI`, and `MediaTesting`. The package floor is macOS 13. `MediaCore` and `MediaTesting` build on Linux. `MediaUI` uses SwiftUI only where that framework is available.
- **Apps** — PGS2SRT, MP4SubRip, and MKV Forge will live in `Apps/pgs2srt`, `Apps/mp4subrip`, and `Apps/mkvforge`. That folder is a placeholder until Phase 1. Each app keeps its own deployment target (macOS 13, 14, and 15) and its own version.

The root `Package.swift` is a thin umbrella over `Packages/MediaForge`. It does not contain the library sources. The canonical package, and the one CI tests, is `Packages/MediaForge`.

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

A root `swift test` does not run the MediaForge package tests. Run the `--package-path` command for those.

On Linux without Swift installed, `./scripts/verify-linux.sh` skips the commands and exits 0. GitHub Actions runs them on Linux (`swift:6.2.4`) and on macOS.

Agents: read `AGENTS.md` before changing the repo.
