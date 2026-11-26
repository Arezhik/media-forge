# Rules for this repo (macOS app; from PGS2SRT lessons)
- Native Swift/SwiftUI macOS app, universal (arm64 + x86_64), unsigned, not sandboxed. Minimum macOS 14.0.
- You run on Linux and can't run Xcode, the app, or AVFoundation. Put logic in the Swift package (no AppKit, SwiftUI, AVFoundation, or Vision) and cover it with `swift test`. The macOS jobs in `.github/workflows/mp4subrip.yml` are the real app build check. Probe helpers and parsers that don't need AVFoundation stay in the package so Linux can still test them.
- The Linux gate is the "MP4SubRip Linux tests" job in `.github/workflows/mp4subrip.yml` (repo root; working directory `Apps/MP4SubRip`): `bash scripts/bump-version.sh --check`, then `swift test` and `swift build`, both with `-Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`. Run them before you open the PR.
- Don't rename the package to the app's name, and don't move the `.xcodeproj` out of `App/`. The Swift package `MP4SubRipKit` lives in `Apps/MP4SubRip`. The thin SwiftUI app is `Apps/MP4SubRip/App/MP4SubRip.xcodeproj`. Never hand-edit `App/MP4SubRip.xcodeproj/project.pbxproj`. To add, rename, or remove an app file, update `App/project.yml` and run `./scripts/verify-linux.sh` from `Apps/MP4SubRip`, then commit both. Open `Apps/MP4SubRip/App/MP4SubRip.xcodeproj`, never `Package.swift`, for the windowed app. Regenerate from `Apps/MP4SubRip` (the local package's folder reference takes that directory's name, `MP4SubRip`).
- Don't set `ARCHS` for Debug. Debug follows the run destination (`ONLY_ACTIVE_ARCH=YES`). Release stays universal.
- Fix only the issue you were given. Note other problems in the PR description instead of fixing them. Don't pull later-phase work into the current PR; keep it as open issues.
- Build with `-strict-concurrency=complete -warnings-as-errors`. Keep the core Sendable-clean.
- Every long loop checks `Task.checkCancellation()`, including reading and decoding. Cancel deletes partial output.
- Never write `@Published` or observed state during a view update. Controls keep local `@State` and write the model on the next run-loop turn (`DispatchQueue.main.async` or `Task { @MainActor in }`).
- Throttle progress to about 10 updates a second (`AppModel.report`). Menu commands read only `CommandFlags`, which publish only when they change (stops menu flicker while a file runs).
- Extract Subtitles / Stop: adding files only queues them. Extract runs the serial loop and becomes Stop while a file is extracting. Stop/Cancel send the in-flight row back to Pending and delete a half-written `.srt`. Extract must enable again only after Stop's cleanup finishes (not while the cancelled task is still tearing down).
- Don't replace a window's delegate. Observe `NSWindow` notifications. If you must replace it, use a `SafeWindowDelegateProxy`-style ObjC forwarder and list every method you implement (see PGS2SRT's `ReviewWindowDelegateProxy`).
- Don't set window properties from `layout()`.
- Every toolbar item is also in the menu bar. Settings opens with `SettingsLink` or `openSettings`.
- Dock drops and Open With reuse the one open window. Folders walk subfolders. Adding a path that is already queued highlights that row; don't add a duplicate.
- Clear Processed (⇧⌘K) removes done, skipped, no-subtitles, and image-only rows and keeps Failed. Option-click or Clear All Finished also removes Failed. The row ✕ removes any row that is not extracting, including Pending during a run. Never delete files on disk. An empty queue shows the drop screen. No confirmation.
- Existing output: Skip (default), Overwrite, or Add a number, from Settings. No per-file prompt and no Apply-to-all sheet. The engine applies that choice.
- Subtitle pipelines: tx3g / mov_text via AVFoundation (`AVAssetReader`, nil output settings) in the app layer behind `SubtitleMediaReading`. Discrete EIA-608 (`c608`) via ffmpeg (`-map 0:s:N -c:s srt`). CEA-708, captions only inside the video, bitmap, WebVTT-in-MP4, DRM, and other codecs are typed skip/fail reasons — don't extract them. Don't add CCExtractor or lavfi `subcc` unless a tracked issue asks for it.
- ffmpeg SRT cleanup (c608 only): strip the first `{\anN}` in a cue; a later one in the same cue becomes a line break; remove `<font>` / `</font>` and `\h`; keep real `<i>`. Flatten overlapping cues onto one timeline; lengthen a last cue under one second. No punctuation-based glue fallback.
- External tools: search `/opt/homebrew/bin`, `/usr/local/bin`, `/Applications/<Tool>*.app/Contents/MacOS`, then `PATH`. Log the command, exit code, and stderr (cut at 2,000 characters). Settings can find ffmpeg automatically or use a copy the user chooses. A chosen path is used alone — if it is missing, do not fall back to automatic; skip the closed-caption file and say so. Launch log and debug-log header must say whether the copy was automatic or chosen.
- Log through `DebugLog.shared.record(...)`: launch, settings, each file's start, finish, and error, window events, Saves, and Reveal. No user content. Home becomes `~`.
- Reveal in Finder checks the file exists first, uses `NSWorkspace.selectFile(_:inFileViewerRootedAtPath:)`, and logs the call.
- Add a test with every bug fix. Use small generated fixtures and keep real media out of git. Arezhik's local samples (for example `~/Desktop/Test MP4s`) are for Mac test steps only.
- In the PR description, list the test steps for Arezhik to run on his Mac (use `docs/PR_TEST_CHECKLIST.md`). He tests and approves every merge. CI alone is not approval. App CI is `.github/workflows/mp4subrip.yml` at the media-forge repo root.
- Versioning (SemVer): in the same PR, run `scripts/bump-version.sh patch` for a bug fix or small tweak, `minor` for a new feature, or `major` for a major enhancement or new phase. Docs-only and CI-only PRs don't bump. `scripts/bump-version.sh --check` must pass (CI runs it). Releases of this app are tagged `mp4subrip-vX.Y.Z` (for example `mp4subrip-v0.8.1`).
- The build number goes up by 1 with every bump and is never reused. Don't edit the version by hand. The script keeps project.pbxproj and project.yml in sync. CI compares the build number against `Apps/MP4SubRip` on the base branch, and skips that check when the base has no `Apps/MP4SubRip` yet. Otherwise it fails a PR whose build number isn't above the base's.
- Fill in the CHANGELOG.md entry. Put `Version bump: old to new (rule)` in the PR description. Arezhik confirms it at merge.

### Local Linux VM (no Swift installed)
- Apply these rules only when `command -v swift` finds nothing (or when xcodegen exists at `/workspace/macos-dev-test/projects/mkv-forge/icon/tools/XcodeGen-2.48.0/.build/x86_64-unknown-linux-gnu/release/xcodegen`). Everywhere else the rules above apply unchanged.
- Edit source files directly in the working tree. Don't generate `apply_changes.py` or `verify.diff`.
- Run `./scripts/verify-linux.sh` from `Apps/MP4SubRip`. It regenerates the Xcode project with XcodeGen whenever `App/project.yml` exists and an xcodegen binary is available, whether or not Swift is on PATH (the local package folder reference is named `MP4SubRip`), then runs `scripts/bump-version.sh --check`. When `swift` is on PATH it also runs `swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` and `swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` from `Apps/MP4SubRip`. When `swift` is not on PATH it prints that the "MP4SubRip Linux tests" job in `.github/workflows/mp4subrip.yml` will run those commands (working directory `Apps/MP4SubRip`) and does not fail. A second run must change nothing. Inspect `git diff` so only intended changes are staged. Don't run `xcodebuild` here; it runs in GitHub CI on a Mac.
- To add a new Core type and its test, run `./scripts/scaffold-swift.sh <Name> [Subfolder]` first instead of creating the files by hand.
- To add a new UI flow test, run `./scripts/scaffold-xcuitest.sh <FlowName>` first instead of creating the file by hand.
- Push to a feature branch `grok/<slug>`, then open a PR with `gh pr create --fill` (or `--draft` for work in progress) because CI runs on pull requests. Check CI with `gh pr checks` or `gh run list` only if `gh auth status` succeeds. No version bump, no CHANGELOG change.

## This project
- Repo `Arezhik/media-forge`, app path `Apps/MP4SubRip`. App MP4SubRip, bundle ID `com.arezhik.MP4SubRip`, macOS 14.0+. Tags `mp4subrip-vX.Y.Z`. Workflow `.github/workflows/mp4subrip.yml`.
- Package `MP4SubRipKit` (module `MP4SubRipCore`, tests `MP4SubRipCoreTests`). Xcode project `Apps/MP4SubRip/App/MP4SubRip.xcodeproj`, scheme `MP4SubRip`.
- Version: `scripts/bump-version.sh --current` (started at 0.1.0, build 1). History: CHANGELOG.md. Decision log: notes.md.
- Scope: SPEC.md. Test sheet template: docs/PR_TEST_CHECKLIST.md. Tester guide: TESTERS.md. CI artifact: `MP4SubRip-universal.zip`.

## GitHub Issue & Comment Format (Token-Efficient Spec)
When creating, rewriting, or commenting on GitHub issues (including triage, design notes, or research), **never post conversational prose**. Preserve the original human description at the top if editing an existing issue, and append or post strictly in this compact schema:

### For Issue Rewrites / Specs (`## Agent Spec`)
```markdown
## Agent Spec
### Goal
<1–2 sentences: exact behavioral change>

### Rules & Logic
- <Deterministic rule or edge-case behavior>

### UI / UX
- <Control type, exact label, default state, placement — or "None">

### Test Cases (Input -> Expected)
- `<Input>` -> `<Expected result / output>`

### Constraints
- <What must NOT change>
```

### For Research / Triage / Design Comments
Keep comments under 15 lines using only:
- **Relevant Files:** `<path/to/File.swift>` (`SymbolName`)
- **Findings / Edge Cases:** <1–3 terse bullets>
- **Proposed Approach:** <2–4 terse bullets>
- **Open Questions:** <Bullet list, or "None">
