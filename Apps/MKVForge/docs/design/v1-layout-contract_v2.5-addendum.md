# MKVForge v1 layout contract — v2.5 addendum (2026-11-27)

**Status: Approved for issue #19, child-folder scanning.** This addendum adds one Settings switch. Every v2, v2.1, v2.2, v2.3 and v2.4 rule stays as approved. If this addendum and an earlier contract seem to disagree, the earlier text wins, except for the scan scope described here.

**Repo:** `docs/design/v1-layout-contract_v2.5-addendum.md`, next to the earlier contract files. No mockup PNGs. `docs/design/README.md` lists this file.

## Settings · Scan child folders

### Placement and strings

- **New section `Scanning`** in v2 §8's single grouped Form, **after `Remux` and before "When a batch finishes".** It is not a row inside Remux. The switch applies to Split and Remux.
- One row, the same pattern as the other Settings switches:
  - Label: `Scan child folders`
  - Caption: `Look in subfolders of the Source, Video, and Audio folders.`
  - Second line: `Changing this clears the queue. Scan again afterward.`
  - Control: a trailing **mini switch**, `Toggle(isOn:)` with `.toggleStyle(.switch).controlSize(.mini)`.
- **Default: off.** A missing stored value stays off, including a fresh install and `--uitesting`. The key is `scanChildFolders`.
- **Off** is the v1 scan: top level of the chosen folder only.
- **On** lists files at any depth. Hidden folders (a dot-prefixed name, including `._`) and package or bundle directories are not opened. The Output folder is not walked for layout. Finished files stay flat in Output: `Season 1/Episode.mkv` writes `<Output>/Episode.mka`. Two files with the same base name are one row, flagged `Duplicate name in <Role> folder`, and are not read. Remux matching, including Match on MKA Name, uses the whole tree.

### What changing it does

- **Right away, in both modes:** the Split queue and the Remux queue, any Remux picks, the Remux match undo actions, and the last summary are dropped. Folders stay.
- Each mode goes back to the not-scanned state (`Not scanned yet`, `Ready to scan`). There is no extra caption. The user clicks Scan again. The app does not start that scan itself.
- VoiceOver posts `Queue cleared. Scan again.`
- **The switch is disabled while a scan or a batch is in progress**, in either mode. Its hint becomes `Available when a scan or batch isn't running.`

### Accessibility

- The switch's accessibility label is `Scan child folders`. The caption and the second line are the hint. When the switch is disabled, the disabled line is the hint.
- Identifier `scanChildFolders`.
- Tab and Space work with Full Keyboard Access, the same as the other switches.

### Window

Settings stays 540 pt wide, not resizable, and fitted to its content. Do not hard-code the height.
