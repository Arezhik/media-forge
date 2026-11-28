# MKVForge v1 layout contract — Force Cancel (2026-11-28)

**Status: Approved for issue #57.** Arezhik's answers are recorded below and are not reopened. This note adds one Settings switch and a live Option override on Cancel. Every v2 through v2.5 rule stays as approved. If this note and an earlier contract seem to disagree, the earlier text wins, except for the Cancel behavior described here.

**Repo:** `docs/design/v1-layout-contract_force-cancel.md`, next to the earlier contract files. No mockup PNGs. `docs/design/README.md` lists this file.

## Settings · Cancel

### Placement and strings

- **New section `Cancel`** in v2 §8's single grouped Form, **after `Remux` and `Scanning`, and before "When a batch finishes".** It is not a row inside Remux or Scanning.
- One row, the same pattern as the other Settings switches:
  - Label: `Cancel stops the current file immediately`
  - Help line 1: `Off: finish the current file, then stop. On: stop at once and delete the unfinished file. Files that haven’t started go back to Ready either way.`
  - Help line 2: `Hold Option to use the other behavior for one click.`
  - Control: a trailing **mini switch**, `Toggle(isOn:)` with `.toggleStyle(.switch).controlSize(.mini)`.
- **Default: off.** A missing stored value stays off, including a fresh install and `--uitesting`. The key is `cancelStopsImmediately`. It is in `AppSettings.Key.all` and the debug summary.
- The switch **stays enabled** during a scan or a batch. Changing it mid-batch does not clear the queue and does not change a cancel already in progress. The next Cancel reads the new value.

### What the switch does

- **Off (default):** Cancel finishes the current file, then stops. That is today's Cancel.
- **On:** Cancel stops at once. That is the same hard stop as the Quit alert's **Quit** button (kill the current mkvmerge, delete the temp and the partial output, keep finished files), without quitting.
- The file that was stopped goes back to **Ready**. It is not Cancelled. Files that had not started go back to Ready either way. There is no confirmation dialog.

## Toolbar and shortcuts

While a batch is running, the primary button is Cancel. Holding Option relabels it live (a `flagsChanged` monitor). The tooltip matches the behavior that click will use. Releasing Option restores the unheld title. While a cancel is already in progress, the title stays `Cancelling…`.

| Setting | Option | Title | Click, ⌥ when held |
| --- | --- | --- | --- |
| Off | up | Cancel | Finish the current file, then stop |
| Off | held | Force Cancel | Stop immediately |
| On | up | Cancel | Stop immediately |
| On | held | Finish Current | Finish the current file, then stop |

- Plain **⌘.** and plain **Esc** use the unheld row (today's Cancel when the switch is off).
- **⌥⌘.** and **⌥Esc** use the held row.
- Option does not change the stored setting. It applies to that one click.
- Idle titles stay `Split` and `Remux`. Option does not relabel them.

## Quit during an immediate stop

**⌘Q while an immediate stop is in progress shows the usual quit alert (QuitFlow G1).** It does not use a wait-then-quit path. The alert's Quit button is safe if the hard stop is already underway: stopping twice does not crash, and it does not kill the work a second time in a way that loses finished files.

### Accessibility

- The switch's accessibility label is `Cancel stops the current file immediately`. The two help lines are the hint.
- Identifier `cancelStopsImmediatelyToggle`.
- The toolbar button's accessibility label is its visible title (`Cancel`, `Force Cancel`, `Finish Current`, or `Cancelling…`).
- Tab and Space work with Full Keyboard Access, the same as the other switches.

### Window

Settings stays 540 pt wide, not resizable, and fitted to its content. Do not hard-code the height.
