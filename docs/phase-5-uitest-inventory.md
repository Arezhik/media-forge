# Phase 5 UI-test inventory

Shared XCUITest helpers live in `Packages/MediaForge/Sources/MediaTesting/UITest`. They compile only for `#if canImport(XCTest) && os(macOS)`, so Linux `swift test` does not see them. Each app keeps the pages, components, copy, and assertions that belong to that app. The tables below are the map. Tests still check what they checked before the move.

Launch stays `--uitesting` only. Do not pass `-ApplePersistenceIgnoreState YES`. Tests subclass the app's `BaseUITest`, seed files in `prepareFixtures()`, and do not call `app.launch()`.

## Shared in MediaTesting

`import MediaTesting` in any app file that uses these types. App classes subclass them. Do not copy the shared file into an app.

| Shared type | Path | What the app still supplies |
| --- | --- | --- |
| `BaseUITest` | `UITest/Base/BaseUITest.swift` | `launchEnvironment(for:)`. MKVForge uses `UITestFixtures.mkvForgeEnvironment`. MP4SubRip and PGS2SRT use `UITestFixtures.inputOutputEnvironment`. |
| `BasePage` | `UITest/Base/BasePage.swift` | Nothing. Screens subclass it. |
| `MainWindowPage` | `UITest/Pages/MainWindowPage.swift` | Folder fields, mode, queue, and toolbar actions. PGS2SRT overrides `root` with `queueWindow`. |
| `SettingsPage` | `UITest/Pages/SettingsPage.swift` | `menuTitle`, and the controls inside the window. |
| `UITestFixtures`, `UITestTimeout`, `UITestQuery`, `UITestWait`, `UITestPoll` | `UITest/Helpers/UITestFixtures.swift` | Which `UITEST_*` keys the app reads. |
| `XCUIElement` helpers | `UITest/Helpers/XCUIElement+UITest.swift` | Which helper matches that app's text (`uiText`, `uiMenuText`, or `uiLabelAndValue`). |
| `QueueRowComponent` | `UITest/Components/QueueRowComponent.swift` | Badge sentences. MKVForge also adds Include, Choose Match, and Unmatch. |
| `ModePickerComponent` | `UITest/Components/ModePickerComponent.swift` | Picker id, titles, and the menu-style click. MKVForge and MP4SubRip only. |
| `IntakeBannerComponent` | `UITest/Components/IntakeBannerComponent.swift` | The sentence. MP4SubRip uses the shared type. PGS2SRT subclasses it and reads `uiLabelAndValue`. |
| `UITestFixtureBuilder` | `UITestFixtureBuilder.swift` | Nothing. Call it from `prepareFixtures()`. |

App-specific, left in the app:

- MKVForge: `ToolBannerComponent`, `FolderFieldComponent`, `BottomBarComponent`, `SplitPage`, `RemuxPage`, mode titles (Split / Remux), queue badge copy, Settings sections.
- MP4SubRip: `SaveToComponent`, mode titles (One at a Time / Parallel), intake and queue copy.
- PGS2SRT: `queueWindow` (`pgs2srt.queue`, then the drop screen or the footer), `FooterSummaryComponent`, settings pane lookup (`pgs2srt.settings`), banner and queue copy.

## How to add a test

From the app directory, run `./scripts/scaffold-xcuitest.sh <FlowName>`. When `Tests/` and `Base/BaseUITest.swift` exist, it writes `Tests/<Flow>UITests.swift` as a subclass of that app's `BaseUITest`.

The new test overrides `prepareFixtures() async throws` and does not override `setUp` or call `app.launch()`. Put locators on a page or component in the app target. Subclass the MediaTesting page or component when the screen shares that chrome. Keep the assertion in the app test. Keep edge cases in the app's core tests (`MKVForgeCoreTests`, `MP4SubRipCoreTests`, or `PGSCoreTests`).

## Base, helpers, pages, components

| Piece | MKVForge | MP4SubRip | PGS2SRT | Phase 5 |
| --- | --- | --- | --- | --- |
| `BaseUITest` | yes | yes | yes | Shared. Launch, fixture root, `prepareFixtures()`, teardown. |
| `BasePage` | yes | yes | yes | Shared. Holds `XCUIApplication` and the screen root. |
| `XCUIElement+UITest` | yes | yes | yes | Shared. `mainWindow`, `matchingLabelOrValue`, waits, switch values. |
| `UITestFixtures` | yes | yes | yes | Shared wrapper. Keys differ: MKVForge sets source, output, video, and audio. MP4SubRip and PGS2SRT set `UITEST_INPUT_DIR` and `UITEST_OUTPUT_DIR`. |
| `UITestFixtureBuilder` | MediaTesting | MediaTesting | MediaTesting | Already shared. Do not copy the file builders into an app. |
| `MainWindowPage` | yes | yes | yes | Shared chrome only (window, toolbar). Folder fields and mode stay app-specific. |
| `SettingsPage` | yes | yes | yes | Shared open-from-the-app-menu and window lookup. Sections stay app-specific. |
| `QueueRowComponent` | yes | yes | yes | Shared row lookup by identifier plus label or value. Badge copy stays app-specific. |
| `IntakeBannerComponent` | no | yes | yes | Shared for MP4 and PGS intake notices. MKVForge uses `ToolBannerComponent` instead. |
| `ToolBannerComponent` | yes | no | no | App-specific. MKVToolNix-missing banner. PGS has no gate banner. MP4 reports ffmpeg in Settings. |
| `ModePickerComponent` | yes | yes | no | Shared click-a-segment helper. Titles differ (Split/Remux vs One at a Time/Parallel). |
| `FolderFieldComponent` | yes | no | no | App-specific until another app grows folder fields. |
| `BottomBarComponent` | yes | no | no | App-specific. MP4 uses `SaveToComponent`. PGS uses `FooterSummaryComponent`. |
| `SaveToComponent` | no | yes | no | App-specific. |
| `FooterSummaryComponent` | no | no | yes | App-specific. |
| `SplitPage` / `RemuxPage` | yes | no | no | App-specific. |

## Test scenarios

| Scenario | MKVForge | MP4SubRip | PGS2SRT | Phase 5 |
| --- | --- | --- | --- | --- |
| Main window and seeded folders | `MainWindowSmokeUITests` | `MainWindowSmokeUITests` | `MainWindowSmokeUITests` | Shared smoke shape. Assertions stay per app. |
| Settings essentials | `SettingsEssentialsUITests` | `SettingsEssentialsUITests` | `SettingsEssentialsUITests` | Shared open-Settings steps. Controls differ. |
| Tool missing | `ToolMissingBannerUITests` | ffmpeg row in `SettingsEssentialsUITests` (`Not found` or a path) | no banner; bad `.mkv` covers the fallback | Keep the MKV banner. Do not invent one for PGS or MP4. |
| Empty or unsupported input | `SplitEmptyFileUITests` | `UnsupportedFileUITests` plus the empty-folder banner in the smoke | `UnsupportedFileUITests` plus the empty-folder banner in the smoke | Shared banner helper. Copy differs. |
| Primary action enabled or disabled | Split / Remux toolbar | `primaryAction` (Extract Subtitles) in `DummyMP4QueueUITests` | no Convert button; Clear Finished and Cancel All in `EmptySUPFailureUITests` | App-specific. |
| Mode switch | Remux match tests call `switchToRemux()` | `ExtractionModeUITests` | none | Shared picker helper where a mode exists. |
| Existing output | `SplitExistingOutputUITests`, `RemuxExistingOutputUITests` | Settings picker only (Skip / Overwrite / Add a number). A real skip row needs an extract. | Settings picker only (Overwrite / Add a number / Skip). A real skip row needs OCR. | App-specific until the flows can run without a full transcode. |
| Queue failure that must not start real work | empty file, still changing, missing chapters | `DummyMP4QueueUITests` (0-byte `.mp4`, probe may fail, Extract is not clicked) | `EmptySUPFailureUITests` (`The PGS file is empty.`), `EmptyMKVFailureUITests` | Shared "dummy file, do not run the engine" rule. |
| Happy-path run | `RemuxRunUITests`, `SplitReadyUITests`, `ShowReadySplitUITests`, `ShowReadyRemuxUITests` | not a smoke (ffmpeg) | not a smoke (OCR) | Stays in the app that can finish without a long engine. |

MKVForge also has `HelloWorldUITests`, `RemuxChooseMatchUITests`, `RemuxMatchOnMKANameUITests`, `RemuxMatchToggleUITests`, `RemuxVideoOnlyNoteUITests`, `SplitAudioOnlyUITests`, and `SplitMissingChaptersUITests`. Those stay MKV-specific.

## What happened to the old MP4 and PGS tests

| File | Fate |
| --- | --- |
| `Apps/PGS2SRT/App/P2SUITests/HelloWorldUITests.swift` | Deleted. It overrode `setUpWithError`, launched with `-ApplePersistenceIgnoreState YES`, and used `descendants(matching: .any)`. Replaced by the five PGS tests above. |
| `Apps/MP4SubRip/App/MP4UITests/HelloWorldUITests.swift` | Deleted. Same launch-flag bug and inline locators. |
| `Apps/MP4SubRip/App/MP4UITests/Phase3ModeAndFeedbackUITests.swift` | Deleted and rewritten as `Tests/ExtractionModeUITests.swift`. The scenario (seeded row, Extract Subtitles present, Mode segments) stayed. The old file built `XCUIApplication` in the test and walked `descendants(matching: .any)`. |

## Core and unit tests

`PGSCoreTests` and `MP4SubRipCoreTests` can follow the same shape without becoming UI tests.

- One shared fixture builder. `UITestFixtureBuilder` already creates `input/`, `output/`, `video/`, and `audio/` and can write a dummy file, a valid container, a valid `.srt`, or a minimal `.sup`. A review of the app unit tests found no helper that hand-rolls those same bytes. `SyntheticSUP` builds specific segments (palette, objects, crops, bad lengths). Scan and engine tests write path-specific contents (`"abc"`, a partial `.srt`, a shell script). Those stay local. App `FileIntakeTests` only lock each app's extensions and wording; the walk already lives in MediaCore.
- Names match the behavior (`FileIntakeTests`, `OutputReservationTests`), the way UI tests match the workflow (`EmptySUPFailureUITests`).
- A test sets up data, then calls one function. It does not also launch a process unless the test is about that process.
- Skip when a tool is missing (`XCTSkip` / the builder's missing-ffmpeg handler) instead of failing the machine that does not have ffmpeg.

## Duplicates reviewed

Moved: the identical ETA sentence (`About N seconds left` and the minute and hour forms) from MKVForge and MP4SubRip `RunETA` into `MediaCore.ETAWording`. Each app still computes the seconds. `RunETA.sentence` forwards to it, so the existing wording tests stay.

Left, because they are not exact copies:

- `RunETA` sample types and remaining-time math. MKVForge uses one file's percent. MP4SubRip uses parallel slots and unmeasured c608 files. PGS2SRT has no ETA sentence.
- `AppIdentity`, `QueueItem`, and `BatchSummary`. Names, extensions, and fields differ.
- `DebugLogSupport`, `UITestingLaunch`, `WindowEvents`, and the open-file inbox. Some methods match, and the files do not (suite names, tool facts, delegate forwarding, diagnostics).
- `QueueWindowClaim`. PGS2SRT also writes an accessibility identifier and a diagnostic log. MP4SubRip only sets the window identifier.

`BaseUITest`, `BasePage`, `XCUIElement+UITest`, and the intake-banner and settings-window helpers now live in `MediaTesting`. Queue copy, mode titles, and tool banners stay in the apps.

## Releases

`.github/workflows/release.yml` publishes to this repo's single Releases page. It runs on a push to `main` when `Apps/<app>/**`, `Packages/MediaForge/**`, or the workflow file changes, and from Actions → Run workflow (`app`: `all`, `mkvforge`, `mp4subrip`, or `pgs2srt`). It does not run on pull requests.

For each affected app it reads the version with `bash scripts/bump-version.sh <app> --current`. It skips the app when the tag `<app>-v<version>` already exists (`mkvforge-v0.8.5`, `mp4subrip-v0.9.2`, `pgs2srt-v0.4.1`). Otherwise a `macos-latest` job builds the unsigned universal Release app, zips `<App>-<version>-universal.zip`, and creates that tag with `gh release create`. The title is `<App> <version>`. The notes are that version's CHANGELOG section. PGS2SRT has no CHANGELOG, so the note is the app name and version. A version bump that lands on `main` is what cuts a new release. Docs-only and CI-only changes do not bump, so they do not create a new tag.
