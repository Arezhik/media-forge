# scripts

Shared Linux checks for the monorepo. Run them from the repo root.

## verify-linux.sh

```bash
./scripts/verify-linux.sh            # all (the default)
./scripts/verify-linux.sh all        # MediaForge, the root umbrella, then mkvforge, mp4subrip, and pgs2srt
./scripts/verify-linux.sh package    # MediaForge and the root umbrella only
./scripts/verify-linux.sh mkvforge   # one app: mkvforge, mp4subrip, or pgs2srt
```

`all` and `package` use the same strict flags as CI:

```bash
swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

The first two test and build the canonical `Packages/MediaForge` package. The last one checks the thin root umbrella. A root `swift test` does not run the MediaForge package tests.

An app run works from that app's directory. It regenerates the Xcode project with XcodeGen when `App/project.yml` exists and a binary is available (`XCODEGEN`, then `xcodegen` on `PATH`, then a known Linux fallback). Missing `xcodegen` is not a failure. It then runs `Apps/MKVForge/scripts/check-project.sh` for MKV Forge, and `scripts/bump-version.sh <app> --check` for every app, then `swift test` and `swift build` with the same strict flags.

If `swift` is not installed, the package portion prints that the GitHub Actions Linux (`swift:6.2.4`) and macOS jobs will run those commands and does not fail. An app portion still runs XcodeGen and the non-Swift checks, prints the app `swift` commands, and does not fail. Do not install Swift on the Linux agent VM.

`Apps/<App>/scripts/verify-linux.sh` execs this script with that app's name.

## bump-version.sh

```bash
./scripts/bump-version.sh <app> patch|minor|major [--dry-run]
./scripts/bump-version.sh <app> --check
./scripts/bump-version.sh <app> --current
./scripts/bump-version.sh <app> --check-against <ref>
./scripts/bump-version.sh <app> --rebase <ref> patch|minor|major [--dry-run]
```

`<app>` is exactly one of `mkvforge`, `mp4subrip`, or `pgs2srt`.

SemVer: `patch` for a bug fix or small tweak, `minor` for a new feature, `major` for a major enhancement or breaking change. A new phase is usually `minor`. Every bump also adds 1 to the build number. Docs-only and CI-only PRs don't bump. Release tags are `<app>-vX.Y.Z` (`mkvforge-vX.Y.Z`, `mp4subrip-vX.Y.Z`, `pgs2srt-vX.Y.Z`), never a bare `vX.Y.Z`.

`--check` requires `App/*.xcodeproj/project.pbxproj` and `App/project.yml` to agree. MKV Forge and MP4SubRip also require a `CHANGELOG.md` section for that version. PGS2SRT has no `CHANGELOG.md`. `--check` still requires the two project files to agree, and a bump does not create a changelog.

`--check-against <ref>` passes when the version and build are unchanged, or when the build is higher than `<ref>`'s. It fails when the build goes down, or when the version changes without a new build.

`--rebase <ref> <rule>` sets the version to `<ref>`'s version plus the rule and the build to `<ref>`'s build + 1. Use it when another PR merged a bump first.

`Apps/<App>/scripts/bump-version.sh` execs this script with that app's name and forwards every argument. `Apps/MKVForge/scripts/check-project.sh` stays an app script.

The script works with macOS bash 3.2 and BSD `sed`/`awk`, and with GNU tools. The only `project.pbxproj` edits it makes are the version lines.
