# scripts

`verify-linux.sh` is the local Linux check for Phase 0.

From the repo root:

```bash
./scripts/verify-linux.sh
```

If `swift` is on `PATH`, it runs the same commands as CI:

```bash
swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

The first two test and build the canonical `Packages/MediaForge` package. The last one checks the thin root umbrella. A root `swift test` does not run the MediaForge package tests. This script does not run `Apps/MKVForge`, `Apps/MP4SubRip`, or `Apps/PGS2SRT`; each app has its own `scripts/verify-linux.sh`.

If `swift` is not installed, the script prints that the GitHub Actions Linux (`swift:6.2.4`) and macOS jobs will run those commands, then exits 0. Do not install Swift on the Linux agent VM.
