# Theater & AV AppleScripts

A collection of AppleScripts for theater and live AV production. Most are for
[QLab](https://qlab.app), and the rest are general production utilities.

## What's here

| Folder | What's in it |
| --- | --- |
| [`QLab/Bulk/`](QLab/Bulk/) | Bigger tools that change many cues at once |
| [`QLab/Hotkeys/`](QLab/Hotkeys/) | Small quick fixes, made to run from a hotkey |
| [`QLab/Show-Specific/`](QLab/Show-Specific/) | Scripts written for one production, kept as examples to adapt |
| [`Companion/`](Companion/) | Scripts for Bitfocus Companion |
| [`tools/`](tools/) | Helpers for maintaining this repo |

### Script index

**QLab: Bulk**

| Script | What it does |
| --- | --- |
| [QLab Batch Cue Generator](QLab/Bulk/batch-cue-generator.applescript) | Builds cues in bulk (text, network, MIDI, timecode, start, load, memo, slices, relinking) from the [Batch Cue Generator sheet](https://www.taylorglad.com/post/qlab-5-batch-cue-generator-tsv-csv) |
| [Snap Cues to Slice Markers](QLab/Bulk/snap-cues-to-slice-markers.applescript) | Sets pre-waits in a Timeline group so cues line up with an audio/video cue's slice markers |
| [Select Cues with Same File Type](QLab/Bulk/select-cues-with-same-file-type.applescript) | Selects every cue in the current list whose target file is the same type as the selected cue (all WAVs, all movies…) |
| [Rivage Cues from I/O Sheet](QLab/Bulk/rivage-cues-from-io-sheet.applescript) | Builds a group of Network cues that name, colour, icon and DCA-assign Yamaha Rivage channels/mixes/matrices from a TSV I/O sheet |
| [Retarget Cues to Other Extension](QLab/Bulk/retarget-cues-to-other-extension.applescript) | _Draft, not working yet._ Meant to re-point audio/video cues at a same-named file with a preferred extension (WAV → MP3) |
| [Rivage Cues from I/O Sheet](QLab/Bulk/rivage-cues-from-io-sheet.applescript) | Builds a group of Network cues that program a Yamaha Rivage (channel/mix/matrix names, colours, icons, DCA assignments) from a TSV export of the show's I/O sheet |
| [Select Cues with Same File Type](QLab/Bulk/select-cues-with-same-file-type.applescript) | Selects every cue in the current list whose target file has the same type as the selected cue (all WAVs, all movies…) for batch editing |
| [Retarget Cues to Other Extension](QLab/Bulk/retarget-cues-to-other-extension.applescript) | **Draft, does not run yet** — meant to re-point every audio/video cue at a same-named file with a preferred extension (WAV → MP3) |

**QLab: Hotkeys**

| Script | What it does |
| --- | --- |
| [Drop Memo in Running Timeline](QLab/Hotkeys/drop-memo-in-running-timeline.applescript) | Adds a named Memo to a playing Timeline group at the current moment, for marking spots on the fly |

**QLab: Show-Specific**

| Script | Show | What it does |
| --- | --- | --- |
| _None yet_ | | |

**Companion**

| Script | What it does |
| --- | --- |
| [Companion Pages from Spreadsheet](Companion/companion-pages-from-spreadsheet.applescript) | Makes a batch of Companion pages from one template page and a CSV/TSV, one page per row |

## Using a script

**In QLab:** open the `.applescript` file, copy everything, and paste it into a
Script cue (or into Workspace Settings → Scripts for a hotkey). Read the header
at the top of each script for the QLab version it was written for and any
settings to change.

**On its own:** double-click the `.applescript` file to open it in Script
Editor and press Run, or run it from Terminal:

```sh
osascript QLab/some-script.applescript
```

The first time a script controls another app, macOS will ask for Automation
permission. Allow it in System Settings → Privacy & Security → Automation.

## Adding a script

1. Save it as plain text (`.applescript`), not compiled `.scpt`. GitHub can
   show plain text and track every change; compiled scripts are opaque binaries.
   To convert existing `.scpt` files:
   ```sh
   tools/convert-scpt.sh path/to/script.scpt   # or a whole folder
   ```
2. Keep it self-contained: each script does one complete job and works when
   copied on its own, with no dependencies on other files in this repo.
3. Start it with the header from [`tools/template.applescript`](tools/template.applescript).
4. Put it in the right folder and add it to the script index above.

## License

[MIT](LICENSE). Use and adapt these freely for your own shows.
