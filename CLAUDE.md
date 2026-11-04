# Theater & AV AppleScripts

A library of AppleScripts for theater/AV production, mostly QLab. Published to GitHub.

## Conventions

- **Every script is self-contained.** One file does one complete job and can be copied
  on its own into a QLab Script cue or Script Editor. Never make a script depend on another
  file, a shared handler library, or `load script`. Duplicating a handler across scripts
  is fine and expected.
- Store scripts as plain-text `.applescript` (UTF-8, LF), never compiled `.scpt`.
- Start each script with the header from `tools/template.applescript`. Put anything a
  user might change for their show (cue numbers, names, volumes, paths) in the
  "Settings" block at the top.
- Folders: QLab scripts are sorted by type:
  - `QLab/Bulk/`: bigger tools that change many cues at once (usually with menus/dialogs)
  - `QLab/Hotkeys/`: small quick fixes meant to run from a hotkey, often mid-tech
  - `QLab/Show-Specific/`: written for one production; kept as examples. Name the show
    in the header's Notes line.
  Other apps get their own top-level folder (e.g. `Companion/`). File names are
  lowercase-hyphenated and describe the job, e.g. `QLab/Hotkeys/fade-selected-cues.applescript`.
- When adding or renaming a script, update the matching script index table in `README.md`.
- Hotkey scripts may run during a live run: don't leave the selection or playhead moved,
  and don't pop up dialogs except for errors.
- QLab terms: check the official QLab 5 AppleScript dictionary rather than guessing:
  https://qlab.app/docs/v5/scripting/applescript-dictionary-v5/
  The installed app's own dictionary is more complete than that page (it has `custom string`,
  `output channel`, etc.): `sdef "/Applications/Audio Apps/QLab5.app"`. Check that scripts
  compile with `osacompile -o "$TMPDIR/t.scpt" <file>`.
- Inside a `tell` QLab block, don't name variables after QLab terms (e.g. `playCount`, `time`),
  and call handlers with `my`. Records QLab reads (like slice markers) must be built inside the tell.

## Comment style

Scripts get edited on site mid-tech, so comment heavily. Follow
`QLab/Bulk/snap-cues-to-slice-markers.applescript` as the reference example:

- Comments use `--` with no space before the text, lowercase start: `--stop if nothing is selected`
- Number the main steps with a divider block (`-- ----` / `-- 1. Step name` / `-- ----`).
- Put a short comment above each meaningful block saying what it does and why.
- **Every block closer gets a comment naming what's ending:** `end if --if the group is empty`,
  `end repeat --each cue in the group`, `end tell --QLab`. For `if/else if` chains, describe
  the whole decision: `end if --what type of cue is selected`.
- Every setting in the Settings block gets a comment saying what it does and what values it accepts.

## Working with the author

The author is a self-taught AppleScript writer. When improving a script, keep it
recognizable, explain each change in plain language (what was wrong or fragile, and why
the new version is better), and don't add complexity a one-job script doesn't need.
