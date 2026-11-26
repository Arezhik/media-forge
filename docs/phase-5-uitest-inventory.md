# Phase 5 UI-test inventory

Each app still owns its page objects. This list is the input for issue #7: move the shared pieces into `Packages/MediaForge` (`MediaTesting`) without changing what the tests check.

Launch stays `--uitesting` only. Do not pass `-ApplePersistenceIgnoreState YES`. Tests subclass `BaseUITest`, seed files in `prepareFixtures()`, and do not call `app.launch()`.

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

- One shared fixture builder. `UITestFixtureBuilder` already creates `input/`, `output/`, `video/`, and `audio/` and can write a dummy file, a valid container, a valid `.srt`, or a minimal `.sup`. Unit tests that still hand-roll those bytes should call the builder, or a sibling that does not import XCTest.
- Names match the behavior (`FileIntakeTests`, `OutputReservationTests`), the way UI tests match the workflow (`EmptySUPFailureUITests`).
- A test sets up data, then calls one function. It does not also launch a process unless the test is about that process.
- Skip when a tool is missing (`XCTSkip` / the builder's missing-ffmpeg handler) instead of failing the machine that does not have ffmpeg.

Phase 5 should move `BaseUITest`, `BasePage`, `XCUIElement+UITest`, and the intake-banner and settings-window helpers into `MediaTesting`. Leave queue copy, mode titles, and tool banners in the apps until a second caller needs them.
