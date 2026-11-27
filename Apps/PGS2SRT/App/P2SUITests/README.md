# XCUITest layout

Playwright-style page objects for `PGS2SRTUITests`. Tests stay thin. Screens and regions own the locators.

Every UI test lives in `Tests/` and subclasses this app's `BaseUITest`. `UITestFixtureBuilder` lives in MediaTesting. Tests call it through `UITestFixtures` / `fixtures`.

```
App/P2SUITests/
├── README.md
├── Tests/
├── Pages/
├── Components/
└── Base/
```

## Shared in MediaTesting

`import MediaTesting`. Shared types compile only on macOS with XCTest. This app's `BaseUITest` subclasses `MediaTesting.BaseUITest` and returns `UITestFixtures.inputOutputEnvironment` (`UITEST_INPUT_DIR` and `UITEST_OUTPUT_DIR`). Do not copy the shared files into the app.

Shared: `BaseUITest`, `BasePage`, `MainWindowPage` (window and toolbar), `SettingsPage` (application menu, then the settings window), `UITestFixtures`, waits and text helpers (`uiLabelAndValue` for PGS text), `QueueRowComponent` (row lookup), and `IntakeBannerComponent` (`intakeBanner`). There is no mode picker in this app.

Kept here: `queueWindow` (`pgs2srt.queue`, then the drop screen or the footer), because Settings titles the selected pane, `FooterSummaryComponent`, the settings pane lookup (`pgs2srt.settings`), the intake-banner subclass that joins label and value, and the banner and queue sentences.

## Adding a test

From `Apps/PGS2SRT`, run `./scripts/scaffold-xcuitest.sh <FlowName>`. The new file subclasses this `BaseUITest`, overrides `prepareFixtures() async throws`, and does not override `setUp` or call `app.launch()`. Put locators on a page or component in this target. Subclass the MediaTesting type when the screen shares that chrome. Keep assertions in the test. Keep edge cases in `PGSCoreTests`. Do not seed `createValidPGSFile` as input. A real `.sup` starts OCR.

## Launch

`BaseUITest` launches with `--uitesting` only. Do not add `-ApplePersistenceIgnoreState YES`. Combined with `--uitesting` it suppresses the SwiftUI main window.

Only `BaseUITest` overrides `setUp`. A test overrides `prepareFixtures() async throws` to seed files before launch. Do not call `app.launch()` or construct `XCUIApplication` in a test.

`UITestFixtures.launchEnvironment` sets:

| Variable | Folder |
| --- | --- |
| `UITEST_INPUT_DIR` | `fixtures.input` |
| `UITEST_OUTPUT_DIR` | `fixtures.output` |

PGS2SRT does not read MKVForge's `UITEST_SOURCE_DIR`, `UITEST_VIDEO_DIR`, or `UITEST_AUDIO_DIR`.

An empty input folder is ingested like a drop and shows `No .sup or .mkv files were found in input.` The output folder is applied as "In a folder I choose". The footer `settingsSummary` includes that path and `4 pictures at a time`.

Do not seed `createValidPGSFile` as input. A real `.sup` starts conversion, including OCR. `createDummyFile` writes a 0-byte file. An empty `.sup` fails with `The PGS file is empty.` and does not run OCR.

## Window queries

Do not look up the window with `app.windows["PGS2SRT"]`. Use `app.mainWindow` (accessibility identifier `pgs2srt.queue`). The Settings window is `pgs2srt.settings`; its title bar names the selected pane. Do not walk `descendants(matching: .any)`.

SwiftUI `Text` exposes its string as `value`. Use `matchingLabelOrValue`. Never use raw `containing`.

## Accessibility identifiers

| Identifier | What |
| --- | --- |
| `emptyDrop` | The drop screen shown when the queue is empty |
| `intakeBanner` | One intake notice. The sentence is the text value |
| `settingsSummary` | Footer line: language, output place, pictures at a time |
| `batchLine` | Footer after a batch, such as `1 failed in 0s` |
| `queueRow` | One queued file. The file name is a static text inside it |
| `existingFilePicker` | Settings "If the .srt already exists" |
| `languagePicker` | Settings "Subtitle language" |
| `concurrencyStepper` | Settings "Pictures to read at once" |
| `italicsToggle` | Settings "Detect italics" |
| `chooseMKVTrackToggle` | Settings "Choose subtitle tracks for each MKV" |
| `batchNotificationPicker` | Settings "Send a notification" |

Toolbar titles are `Open…` (ellipsis), `Cancel All`, and `Clear Finished`. There is no tool-missing banner. MKVToolNix is a fallback, not a gate.

## Tests

`MainWindowSmokeUITests` checks the window, the drop screen, the empty-folder banner, and the seeded output summary. It dismisses the banner.

`UnsupportedFileUITests` seeds `notes.txt` in the input folder. A folder drop ignores that file. The banner says no `.sup` or `.mkv` files were found in `input`. There is no per-file skip banner and no queue row.

`EmptySUPFailureUITests` seeds `sample.sup`. The row fails with `The PGS file is empty.` The footer contains `1 failed`. Clear Finished brings the drop screen back.

`EmptyMKVFailureUITests` seeds `sample.mkv`. The row settles. The footer contains `failed` or `skipped`. The exact sentence depends on whether MKVToolNix is installed.

`SettingsEssentialsUITests` opens Settings from the PGS2SRT menu. It checks the output folder, the existing-file picker, the MKV track switch, the language picker, italics, the pictures stepper, and the notification picker. It does not click Choose… or Open System Settings.

Edge cases stay in `PGSCoreTests`.
