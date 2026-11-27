# XCUITest layout

Playwright-style page objects for `MP4SubRipUITests`. Tests stay thin. Screens and regions own the locators.

Every UI test lives in `Tests/` and subclasses this app's `BaseUITest`. `UITestFixtureBuilder` lives in MediaTesting. Tests call it through `UITestFixtures` / `fixtures`.

```
App/MP4UITests/
├── README.md
├── Tests/
├── Pages/
├── Components/
└── Base/
```

## Shared in MediaTesting

`import MediaTesting`. Shared types compile only on macOS with XCTest. This app's `BaseUITest` subclasses `MediaTesting.BaseUITest` and returns `UITestFixtures.inputOutputEnvironment` (`UITEST_INPUT_DIR` and `UITEST_OUTPUT_DIR`). Do not copy the shared files into the app.

Shared: `BaseUITest`, `BasePage`, `MainWindowPage` (window and toolbar), `SettingsPage` (application menu, then the settings window), `UITestFixtures`, waits and text helpers, `QueueRowComponent` (row lookup), `ModePickerComponent` (click a segment), and `IntakeBannerComponent` (`intakeBanner`). MP4SubRip uses the shared intake banner. It does not keep a local copy.

Kept here: `SaveToComponent`, mode titles (One at a Time / Parallel) and `extractionModePicker` (menu-style picker, half-width click), and the intake and queue sentences.

## Adding a test

From `Apps/MP4SubRip`, run `./scripts/scaffold-xcuitest.sh <FlowName>`. The new file subclasses this `BaseUITest`, overrides `prepareFixtures() async throws`, and does not override `setUp` or call `app.launch()`. Put locators on a page or component in this target. Subclass the MediaTesting type when the screen shares that chrome. Keep assertions in the test. Keep edge cases in `MP4SubRipCoreTests`. Do not click Extract Subtitles in a smoke. A real extract needs ffmpeg and stays in the core tests.

## Launch

`BaseUITest` launches with `--uitesting` only. Do not add `-ApplePersistenceIgnoreState YES`. Combined with `--uitesting` it suppresses the SwiftUI main window.

Only `BaseUITest` overrides `setUp`. A test overrides `prepareFixtures() async throws`. Do not call `app.launch()` in a test.

| Variable | Folder |
| --- | --- |
| `UITEST_INPUT_DIR` | `fixtures.input` |
| `UITEST_OUTPUT_DIR` | `fixtures.output` |

An empty input folder shows `No .mp4 files were found in input.` A queued file does not extract until Extract Subtitles. These tests do not click Extract Subtitles.

`createDummyFile` writes a 0-byte `.mp4`. Probe may fail that file. That is the error state. A real extract needs `createValidMediaFile` and is left to core tests.

## Accessibility identifiers

| Identifier | What |
| --- | --- |
| `emptyDrop` | The drop screen |
| `intakeBanner` | One intake notice |
| `queueFileName` | The file name in a row |
| `queueStatus` | The status cell |
| `primaryAction` | Extract Subtitles, or Stop while a run is active |
| `saveToMenu` | Save to. The title is the output folder |
| `extractionModePicker` | One at a Time or Parallel |
| `existingFilePicker` | If the output file already exists |
| `ffmpegSection` | The ffmpeg settings heading |

There is no blocking tool banner. ffmpeg reports a path or `Not found` in Settings.

## Tests

`MainWindowSmokeUITests` checks the drop screen, the empty-folder banner, and a disabled Extract button.

`UnsupportedFileUITests` seeds `notes.txt` in the input folder. A folder drop ignores that file. The banner says no `.mp4` files were found in `input`. There is no per-file skip banner and no queue row.

`DummyMP4QueueUITests` seeds `sample.mp4`, checks Save to, and checks that Extract is enabled only while the row is Pending.

`ExtractionModeUITests` switches Parallel and One at a Time. This replaces `Phase3ModeAndFeedbackUITests`.

`SettingsEssentialsUITests` checks the output folder, Skip / Overwrite, and a settled ffmpeg row.

Edge cases stay in `MP4SubRipCoreTests`.
