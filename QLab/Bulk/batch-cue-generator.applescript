-- Name:        QLab Batch Cue Generator
-- Description: Makes cues in bulk from the QLab Batch Cue Generator Google Sheet. Export a
--              tab of the sheet as TSV (or CSV) and run this script. It recognizes which
--              tab you exported and builds those cues.
-- Works with:  QLab 5, and version 3 of the QLab Batch Cue Generator sheet:
--              https://docs.google.com/spreadsheets/d/1Z--2UYToCa054WpF5W9hxfIapoohNZ2vGqBo5gIEh_A/template/preview
--              Instructions: https://www.taylorglad.com/post/qlab-5-batch-cue-generator-tsv-csv
-- How to use:  1. Fill out a tab of the sheet and download it (File > Download > .tsv).
--              2. In QLab, select where the new cues should go. For Slices, Load-to-Time,
--                 and Prompt, select the audio/video cue they're for.
--              3. Run this script and choose one or more exported files. You don't need
--                 Excel or any other spreadsheet app open.
-- Notes:       - If the script crashes, make sure you are using version 3 of the sheet.
--              - TSV is safer than CSV: in a CSV, a cell with a comma in it splits in two.
--              - Feedback is welcome in the comments or through the Contact Me page on
--                taylorglad.com.
-- Author:      Taylor Glad. Version 3.2, updated October 29, 2026 (3.1: March 31, 2024)

-- ============================================================
-- HOW THE SHEET IS LAID OUT
-- ============================================================
-- Column A holds the settings for the whole tab, one per row:
--   Row 1:  title (used for the header memo, and as the song title on the Prompt tab)
--   Row 2:  which tab this is, e.g. "Text Cues". This is how the script knows what to make.
--   Row 4:  where the new cues go: New Group, New Cue List, Cue List, or Cue List with Header
--   Row 6:  the name of that group or cue list
--   Row 8+: settings for that tab (patch, MIDI command, timecode format, and so on)
-- Columns B and up hold the cues, one cue per row, starting at row 3.
--   Column B is always the cue number, and column C is always the cue name.
-- Tab names and settings can be typed in any capitalization.

-- ============================================================
-- SETTINGS (change these when the sheet changes)
-- ============================================================

--shown with every error, since most errors come from using an older version of the sheet
set sheetVersionMessage to "Make sure you are using version 3 of the QLab Batch Cue Generator sheet. See https://www.taylorglad.com/post/qlab-5-batch-cue-generator-tsv-csv"

--every tab this version of the script knows how to handle (row 2 of the sheet)
set knownTabs to {"group cues", "slices", "text cues", "osc qlab cues", "osc parameters", "osc custom", "osc split", ¬
	"midi voice", "midi show control", "midi sysex", "timecode", "start cues", "load-to-time", "memo cues", ¬
	"audio targets", "video targets", "prompt"}

-- ============================================================
-- SHARED VALUES
-- "global" means these can be used by the main script and by every handler below.
-- (A handler is a named, reusable chunk of script, like "on newCue(...)". It runs
-- when another part of the script calls it by name.)
-- ============================================================

global sheetTable --every row of the exported file, each one split into a list of cells
global currentRow --the row being worked on, so an error message can say where it happened
global newCueGroupType --row 4: where the new cues go
global newCueGroup --the group made for "New Group" (missing value if there isn't one)
global addHeader --true for "Cue List with Header"
global patchWarningShown --so the "patch not found" warning only shows once per file
global failedCues, flaggedCues --for Audio/Video Targets: cues that couldn't be relinked

-- ============================================================
-- MAIN SCRIPT
-- ============================================================

set originalDelimiters to AppleScript's text item delimiters
set theFiles to choose file of type {"tsv", "csv"} with prompt "Select tsv or csv files:" with multiple selections allowed

--bring QLab to the front, so any messages the script shows don't end up hidden behind other windows
tell application id "com.figure53.QLab.5" to activate

repeat with fileNumber from 1 to (count of theFiles)
	set theFile to item fileNumber of theFiles
	set currentRow to 0

	try
		-- ------------------------------------------------------------
		-- 1. Read the file, and start fresh for this file
		-- ------------------------------------------------------------

		set fileName to readSheet(theFile)
		set tabType to cell(2, 1)
		set newCueGroupType to cell(4, 1)
		set newCueGroup to missing value
		set addHeader to false
		set patchWarningShown to false

		--remember what was selected before any cues get made
		--(Slices, Load-to-Time, and Prompt use it to know which audio/video cue they're for)
		tell application id "com.figure53.QLab.5" to tell front workspace
			set startingSelection to (selected as list)
		end tell --QLab

		-- ------------------------------------------------------------
		-- 2. Run the section for this tab
		-- ------------------------------------------------------------

		if tabType is not in knownTabs then
			display dialog ("Invalid tsv/csv file: " & fileName & return & return & sheetVersionMessage) with icon 2 buttons {"OK"} default button "OK"

		else if tabType is "prompt" then
			makePromptCues(startingSelection)

		else if tabType is "slices" then
			makeSlices(startingSelection, 6, 2)

		else
			--every other tab: first make (or find) the group or cue list the new cues go in
			setUpDestination(6)

			if tabType is "group cues" then
				makeGroupCues()
			else if tabType is "text cues" then
				makeTextCues()
			else if tabType is "osc qlab cues" then
				makeOscQLabCues()
			else if tabType is "osc parameters" then
				makeOscParameterCues()
			else if tabType is "osc custom" then
				makeOscCustomCues()
			else if tabType is "osc split" then
				makeOscSplitCues()
			else if tabType is "midi voice" then
				makeMidiVoiceCues()
			else if tabType is "midi show control" then
				makeMscCues()
			else if tabType is "midi sysex" then
				makeSysexCues()
			else if tabType is "timecode" then
				makeTimecodeCues()
			else if tabType is "start cues" then
				makeStartOrMemoCues("start")
			else if tabType is "load-to-time" then
				makeLoadCues(startingSelection)
			else if tabType is "memo cues" then
				makeStartOrMemoCues("memo")
			else if tabType is "audio targets" then
				relinkMediaCues("audio")
			else if tabType is "video targets" then
				relinkMediaCues("video")
			end if --which tab
		end if --known tab, Prompt, Slices, or everything else

	on error errorMessage number errorNumber
		-- ------------------------------------------------------------
		-- If anything went wrong: say where, say what, and remind about the sheet version
		-- ------------------------------------------------------------

		--error -128 means Cancel was pressed (or the script was told to stop), so stop quietly
		if errorNumber is -128 then exit repeat

		if currentRow > 0 then
			set whereItHappened to "on row " & currentRow & " of " & fileName
		else
			set whereItHappened to "in " & fileName
		end if --if we know which row
		set AppleScript's text item delimiters to originalDelimiters
		display dialog ("This script encountered an error " & whereItHappened & ":" & return & errorMessage & return & return & sheetVersionMessage) with icon 2 buttons {"OK"} default button "OK"
	end try --processing this file

end repeat --each file

set AppleScript's text item delimiters to originalDelimiters


-- ============================================================
-- HANDLERS: READING THE SHEET
-- ============================================================

--reads the file into sheetTable, and returns the file's name
on readSheet(theFile)
	--read as UTF-8 so accented letters and symbols come through correctly
	--(if the file isn't UTF-8, read it the old way)
	try
		set fileContents to read theFile as «class utf8»
	on error
		set fileContents to read theFile
	end try --reading the file

	tell application "System Events"
		set fileName to name of disk item (POSIX path of theFile)
		set fileType to name extension of disk item (POSIX path of theFile)
	end tell --System Events

	--CSV cells are split by commas, TSV cells by tabs
	if fileType is "csv" then
		set AppleScript's text item delimiters to ","
	else
		set AppleScript's text item delimiters to tab
	end if --CSV or TSV

	--split every row into its cells once, up front
	set sheetTable to {}
	repeat with eachLine in (paragraphs of fileContents)
		set end of sheetTable to text items of (contents of eachLine)
	end repeat --each line of the file

	return fileName
end readSheet


--returns one cell of the sheet, e.g. cell(4, 1) is row 4, column A
--returns "" for cells that don't exist (blank lines, short rows), instead of crashing
on cell(rowNumber, columnNumber)
	if rowNumber > (count of sheetTable) then return ""
	set rowCells to item rowNumber of sheetTable
	if columnNumber > (count of rowCells) then return ""
	return item columnNumber of rowCells
end cell


--true if every cell from firstColumn to lastColumn in this row is empty
on rowIsBlank(rowNumber, firstColumn, lastColumn)
	repeat with columnNumber from firstColumn to lastColumn
		if cell(rowNumber, columnNumber) is not "" then return false
	end repeat --each column
	return true
end rowIsBlank


-- ============================================================
-- HANDLERS: SHARED STEPS FOR MAKING CUES
-- (inside a "tell QLab" block, handlers have to be called with "my", e.g. "my cell(4, 1)")
-- ============================================================

--makes (or finds) the group or cue list the new cues go in, based on row 4,
--and adds a header memo if needed
--groupNameRow is the row with the name: row 6 for most tabs (Prompt also uses rows 8 and 10)
on setUpDestination(groupNameRow)
	set groupName to cell(groupNameRow, 1)
	set headerName to cell(1, 1)

	tell application id "com.figure53.QLab.5" to tell front workspace

		if newCueGroupType is "New Group" then
			--if an earlier section already made a group, select it so this group goes after it, not inside it
			if newCueGroup is not missing value then set selected to {newCueGroup}
			make type "group"
			set newCueGroup to last item of (selected as list)
			set mode of newCueGroup to start_first_and_enter
			set q name of newCueGroup to groupName
			set q number of newCueGroup to ""
			collapse newCueGroup

		else if newCueGroupType is in {"New Cue List", "Cue List", "Cue List with Header"} then
			set needNewCueList to true

			--"Cue List" uses an existing cue list with this name, if there is one
			if newCueGroupType is not "New Cue List" then
				try
					set current cue list to (last cue list whose q name is groupName)
					set needNewCueList to false
				end try --looking for an existing cue list
			end if --if an existing cue list can be used

			if needNewCueList then
				make type "cue list"
				set q name of last cue list to groupName
				set current cue list to (last cue list whose q name is groupName)
			end if --if a new cue list is needed

			if newCueGroupType is "Cue List with Header" then set addHeader to true
		end if --where the new cues go

		if addHeader then
			make type "memo"
			set headerMemo to last item of (selected as list)
			set q name of headerMemo to headerName
			--no number, so it doesn't take the number meant for the first new cue
			set q number of headerMemo to ""
		end if --if a header memo is needed

	end tell --QLab
end setUpDestination


--makes a cue of this type for the current row, and fills in its number (column B) and name (column C)
on newCue(cueType)
	set cueNumber to cell(currentRow, 2)
	set cueName to cell(currentRow, 3)

	tell application id "com.figure53.QLab.5" to tell front workspace
		--QLab makes the new cue below the selected cue and selects it, so grab it from the selection
		make type cueType
		set theCue to last item of (selected as list)
		if cueNumber is not "" then set q number of theCue to cueNumber
		if cueName is not "" then set q name of theCue to cueName
	end tell --QLab

	return theCue
end newCue


--the last step for every cue: set its pre-wait from this column (0 = no pre-wait column),
--then move it into the new group if there is one
on finishCue(theCue, preWaitColumn)
	set preWait to ""
	if preWaitColumn > 0 then set preWait to cell(currentRow, preWaitColumn)

	tell application id "com.figure53.QLab.5" to tell front workspace
		if preWait is not "" then set pre wait of theCue to preWait
		if newCueGroupType is "New Group" then
			move cue id (uniqueID of theCue) of parent of theCue to end of newCueGroup
		end if --if there's a new group
	end tell --QLab
end finishCue


--patches a cue using rows 8 and 10 of the sheet
--  row 8:  "Patch Name" or "Patch Number"
--  row 10: the patch name or number
--patchKind is "network", "midi", or "audio output"
--Network cues can't be built without their patch, so a missing network patch stops the script.
--MIDI and audio output patches can be fixed later, so those just warn once and keep going.
on patchCue(theCue, patchKind)
	set useName to (cell(8, 1) is "Patch Name")
	set patchValue to cell(10, 1)

	tell application id "com.figure53.QLab.5" to tell front workspace

		--set the patch, then read it back to see if QLab found it
		--(numbers are compared as text, since QLab gives back a number but the sheet gives text)
		if patchKind is "network" then
			if useName then
				set network patch name of theCue to patchValue
				set patchWorked to ((network patch name of theCue) is patchValue)
			else
				set network patch number of theCue to patchValue
				set patchWorked to (((network patch number of theCue) as text) is patchValue)
			end if --name or number

		else if patchKind is "midi" then
			if useName then
				set midi patch name of theCue to patchValue
				set patchWorked to ((midi patch name of theCue) is patchValue)
			else
				set midi patch number of theCue to patchValue
				set patchWorked to (((midi patch number of theCue) as text) is patchValue)
			end if --name or number

		else if patchKind is "audio output" then
			if useName then
				set audio output patch name of theCue to patchValue
				set patchWorked to ((audio output patch name of theCue) is patchValue)
			else
				set audio output patch number of theCue to patchValue
				set patchWorked to (((audio output patch number of theCue) as text) is patchValue)
			end if --name or number
		end if --which kind of patch

		if not patchWorked then
			if patchKind is "network" then
				if useName then
					display dialog ("Please create a network patch for QLab 5 and name it: " & patchValue) with title "QLab Batch Cue Generator" with icon 1 buttons {"OK"} default button "OK"
				else
					display dialog ("Please create a network patch for QLab 5 ordered number " & patchValue & " in the network patch list.") with title "QLab Batch Cue Generator" with icon 1 buttons {"OK"} default button "OK"
				end if --name or number
				error number -128 --stop the script

			else if not patchWarningShown then
				if patchKind is "midi" then
					set patchLabel to "A MIDI patch"
				else
					set patchLabel to "An audio output patch"
				end if --which kind of patch
				if useName then
					set patchLabel to patchLabel & " named "
				else
					set patchLabel to patchLabel & " numbered "
				end if --name or number
				--pressing Cancel here stops the script
				display dialog (patchLabel & patchValue & " was not found. Press OK to continue creating cues.") with title "QLab Batch Cue Generator" with icon 1
				set patchWarningShown to true
			end if --network, or the first MIDI/audio warning
		end if --if the patch wasn't found

	end tell --QLab
end patchCue


-- ============================================================
-- HANDLERS: ONE FOR EACH TAB OF THE SHEET
-- Every tab works the same way: go through each row from row 3 down, skip blank rows,
-- make a cue, fill it in from that row's cells, then finish it.
-- ============================================================

-- ------------------------------------------------------------
-- Group Cues
--   Row 8 (column A): group mode for every new group
--   B: number   C: name   G: pre-wait
-- ------------------------------------------------------------
on makeGroupCues()
	set groupMode to cell(8, 1)

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 7) then
			set theCue to newCue("group")

			tell application id "com.figure53.QLab.5" to tell front workspace
				if groupMode is "Cue List" then
					set mode of theCue to cue_list
				else if groupMode is "Timeline" then
					set mode of theCue to timeline
				else if groupMode is "Playlist" then
					set mode of theCue to playlist
				else if groupMode is "Start first and enter" then
					set mode of theCue to start_first_and_enter
				else if groupMode is "Start first" then
					set mode of theCue to start_first
				else if groupMode is "Start random" then
					set mode of theCue to start_random
				end if --group mode
			end tell --QLab

			finishCue(theCue, 7)
		end if --if the row isn't blank
	end repeat --each row
end makeGroupCues


-- ------------------------------------------------------------
-- Start Cues and Memo Cues (these two tabs are laid out the same)
--   B: number   C: name   G: pre-wait
-- ------------------------------------------------------------
on makeStartOrMemoCues(cueType)
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 7) then
			set theCue to newCue(cueType)
			finishCue(theCue, 7)
		end if --if the row isn't blank
	end repeat --each row
end makeStartOrMemoCues


-- ------------------------------------------------------------
-- Load-to-Time
--   Every Load cue targets the first cue that was selected before the script ran.
--   B: number   C: name   G: load time
-- ------------------------------------------------------------
on makeLoadCues(startingSelection)
	if startingSelection is {} then
		display dialog "Please select the cue for the Load cues to target, then run the script again." with title "Select a Cue" with icon 2 buttons {"OK"} default button "OK"
		error number -128 --stop the script
	end if --if nothing was selected
	set targetCue to item 1 of startingSelection

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 7) then
			set theCue to newCue("load")
			set loadTime to cell(currentRow, 7)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set cue target of theCue to targetCue
				if loadTime is not "" then set load time of theCue to loadTime
			end tell --QLab

			finishCue(theCue, 0)
		end if --if the row isn't blank
	end repeat --each row
end makeLoadCues


-- ------------------------------------------------------------
-- Slices (also used by the Prompt tab)
--   Adds slice markers to every selected audio/video cue. Replaces any slices already there.
--   timeColumn: the column with slice times (F on the Slices tab, G on the Prompt tab)
--   playCountColumn: the column with play counts (B on the Slices tab), or 0 to play each slice once
--   Times that are blank or 0 are skipped.
-- ------------------------------------------------------------
on makeSlices(targetCues, timeColumn, playCountColumn)
	if targetCues is {} then
		display dialog "Please select an audio or video cue before creating slices." with title "Select Audio or Video Cue" with icon 2 buttons {"OK"} default button "OK"
		error number -128 --stop the script
	end if --if nothing was selected

	tell application id "com.figure53.QLab.5" to tell front workspace
		repeat with theCue in targetCues

			if q type of theCue is in {"Audio", "Video"} then
				set cueEndTime to end time of theCue
				set theMarkers to {}

				repeat with rowNumber from 3 to (count of sheetTable)
					set currentRow to rowNumber
					set sliceTime to my cell(currentRow, timeColumn)

					if sliceTime is not in {"", "0"} then

						--stop if a slice is past the end of the cue
						if (sliceTime as real) > cueEndTime then
							display dialog ("The slice on row " & currentRow & " is past the end time of your selected cue.") with title "Incompatible Slice" with icon 2 buttons {"OK"} default button "OK"
							error number -128 --stop the script
						end if --if the slice is past the end

						--play count: blank or 0 plays once, "inf" loops forever (-1 in QLab)
						--(the variable can't be named "playCount", because inside "tell QLab" that word belongs to QLab)
						set slicePlayCount to 1
						if playCountColumn > 0 then
							set playCountText to my cell(currentRow, playCountColumn)
							if playCountText is "inf" then
								set slicePlayCount to -1
							else if playCountText is not in {"", "0"} then
								set slicePlayCount to playCountText as integer
							end if --which play count
						end if --if this tab has play counts

						--(this record has to be built inside "tell QLab" so QLab understands "time" and "playCount")
						set end of theMarkers to {time:sliceTime, playCount:slicePlayCount}
					end if --if the row has a slice time
				end repeat --each row

				set slice markers of theCue to theMarkers

			else
				display dialog "Please select an audio or video cue before creating slices." with title "Select Audio or Video Cue" with icon 2 buttons {"OK"} default button "OK"
			end if --if it's an audio or video cue

		end repeat --each selected cue
	end tell --QLab
end makeSlices


-- ------------------------------------------------------------
-- Text Cues
--   B: number   C: name   D: text   E: layer ("top", "bottom", or a number)
--   F: stage ID   J: pre-wait
-- ------------------------------------------------------------
on makeTextCues()
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 10) then
			set theCue to newCue("text")
			set cueText to cell(currentRow, 4)
			set layerText to cell(currentRow, 5)
			set stageID to cell(currentRow, 6)

			tell application id "com.figure53.QLab.5" to tell front workspace
				if cueText is not "" then set text of theCue to cueText

				--layer: QLab's top layer is 1000 and its bottom layer is 0
				if layerText is "top" then
					set layer of theCue to 1000
				else if layerText is "bottom" then
					set layer of theCue to 0
				else if layerText is not "" then
					set layer of theCue to layerText
				end if --which layer

				if stageID is not "" then set stage id of theCue to stageID
			end tell --QLab

			finishCue(theCue, 10)
		end if --if the row isn't blank
	end repeat --each row
end makeTextCues


-- ------------------------------------------------------------
-- OSC QLab Cues (Network cues that control QLab)
--   Rows 8 and 10: network patch (see patchCue)
--   Row 12: "Active Workspace", or else the workspace in row 14 is used
--   Row 14: workspace name/ID
--   B: number   C: name   D, E, F: parameter values   J: pre-wait
-- ------------------------------------------------------------
on makeOscQLabCues()
	set useActiveWorkspace to (cell(12, 1) is "Active Workspace")
	set workspaceID to cell(14, 1)

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 10) then
			set theCue to newCue("network")
			patchCue(theCue, "network")
			set valueD to cell(currentRow, 4)
			set valueE to cell(currentRow, 5)
			set valueF to cell(currentRow, 6)

			tell application id "com.figure53.QLab.5" to tell front workspace
				--the parameters are in a different order for the active workspace vs. a specific workspace
				--(a specific workspace has one extra value: its name/ID)
				if useActiveWorkspace then
					set parameter values of theCue to {"Cues", "useActive", valueD, valueE, valueF}
				else
					set parameter values of theCue to {"Cues", "useID", workspaceID, valueD, valueE, valueF}
				end if --active workspace or a specific one
			end tell --QLab

			finishCue(theCue, 10)
		end if --if the row isn't blank
	end repeat --each row
end makeOscQLabCues


-- ------------------------------------------------------------
-- OSC Parameters (Network cues with up to 8 parameter values)
--   Rows 8 and 10: network patch (see patchCue)
--   B: number   C: name   D-K: parameter values (a "*" means that parameter fades)
--   L: fade from   M: fade to   N: fade duration   R: pre-wait
-- ------------------------------------------------------------
on makeOscParameterCues()
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 18) then
			set theCue to newCue("network")
			patchCue(theCue, "network")

			--collect the 8 parameter values (columns D-K), and which ones fade
			set parameterList to {}
			set fadeList to {}
			repeat with columnNumber from 4 to 11
				set parameterValue to cell(currentRow, columnNumber)
				set end of parameterList to parameterValue
				set end of fadeList to (parameterValue is "*")
			end repeat --each parameter column

			set fadeFrom to cell(currentRow, 12)
			set fadeTo to cell(currentRow, 13)
			set fadeDuration to cell(currentRow, 14)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set parameter values of theCue to parameterList

				--only set up the fade if at least one parameter fades
				if fadeList contains true then
					set parameter fades enabled of theCue to fadeList
					if fadeFrom is not "" then set fade from of theCue to fadeFrom
					if fadeTo is not "" then set fade to of theCue to fadeTo
					if fadeDuration is not "" then set duration of theCue to fadeDuration
				end if --if anything fades
			end tell --QLab

			finishCue(theCue, 18)
		end if --if the row isn't blank
	end repeat --each row
end makeOscParameterCues


-- ------------------------------------------------------------
-- OSC Custom (Network cues with a custom OSC message)
--   Rows 8 and 10: network patch (see patchCue)
--   B: number   C: name   D: OSC message   H: pre-wait
-- ------------------------------------------------------------
on makeOscCustomCues()
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 8) then
			set theCue to newCue("network")
			patchCue(theCue, "network")
			set oscMessage to cell(currentRow, 4)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set custom string of theCue to oscMessage
			end tell --QLab

			finishCue(theCue, 8)
		end if --if the row isn't blank
	end repeat --each row
end makeOscCustomCues


-- ------------------------------------------------------------
-- OSC Split (Network cues with a custom OSC message built from pieces)
--   Rows 8 and 10: network patch (see patchCue)
--   B: number   C: name   D-H: pieces of the OSC address, joined together
--   I: value added after a space (optional)   M: pre-wait
-- ------------------------------------------------------------
on makeOscSplitCues()
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 13) then
			set theCue to newCue("network")
			patchCue(theCue, "network")

			--join columns D-H together, then add column I after a space if there is one
			set oscMessage to ""
			repeat with columnNumber from 4 to 8
				set oscMessage to oscMessage & cell(currentRow, columnNumber)
			end repeat --each piece of the address
			if cell(currentRow, 9) is not "" then set oscMessage to oscMessage & " " & cell(currentRow, 9)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set custom string of theCue to oscMessage
			end tell --QLab

			finishCue(theCue, 13)
		end if --if the row isn't blank
	end repeat --each row
end makeOscSplitCues


-- ------------------------------------------------------------
-- MIDI Voice
--   Rows 8 and 10: MIDI patch (see patchCue)
--   Row 12: command: "Note On", "Note Off", or "Program Change"
--   B: number   C: name   D: channel   E: byte one   F: byte two (not used for Program Change)
--   J: pre-wait
-- ------------------------------------------------------------
on makeMidiVoiceCues()
	set midiCommand to cell(12, 1)

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 10) then
			set theCue to newCue("midi")
			patchCue(theCue, "midi")
			set midiChannel to cell(currentRow, 4)
			set byteOne to cell(currentRow, 5)
			set byteTwo to cell(currentRow, 6)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set message type of theCue to voice
				if midiCommand is "Note On" then
					set command of theCue to note_on
				else if midiCommand is "Note Off" then
					set command of theCue to note_off
				else if midiCommand is "Program Change" then
					set command of theCue to program_change
				end if --which MIDI command

				if midiChannel is not "" then set channel of theCue to midiChannel
				if byteOne is not "" then set byte one of theCue to byteOne
				if midiCommand is not "Program Change" and byteTwo is not "" then set byte two of theCue to byteTwo
			end tell --QLab

			finishCue(theCue, 10)
		end if --if the row isn't blank
	end repeat --each row
end makeMidiVoiceCues


-- ------------------------------------------------------------
-- MIDI Show Control
--   Rows 8 and 10: MIDI patch (see patchCue)
--   B: number   C: name   D: command format   E: command
--   F: device ID   G: Q number   H: Q list   I: Q path   M: pre-wait
--   The command format and command are typed as names in the sheet. QLab wants the
--   official MSC code number for each one, so the lists below pair each name with its code.
--   (The codes are usually written in hex, e.g. Sound (General) is 0x10 = 16. The hex is in the comments.)
-- ------------------------------------------------------------
on makeMscCues()
	set commandFormats to {¬
		{"All Types", 127}, ¬
		{"Lighting (General)", 1}, {"Moving Lights", 2}, {"Color Changers", 3}, {"Strobes", 4}, {"Lasers", 5}, {"Chasers", 6}, ¬
		{"Sound (General)", 16}, {"Music", 17}, {"CD Players", 18}, {"EPROM Playback", 19}, {"Audio Tape Machines", 20}, ¬
		{"Intercoms", 21}, {"Amplifiers", 22}, {"Audio Effects Devices", 23}, {"Equalizers", 24}, ¬
		{"Machinery (General)", 32}, {"Rigging", 33}, {"Flys", 34}, {"Lifts", 35}, {"Turntables", 36}, {"Trusses", 37}, ¬
		{"Robots", 38}, {"Animation", 39}, {"Floats", 40}, {"Breakaways", 41}, {"Barges", 42}, ¬
		{"Video (General)", 48}, {"Video Tape Machines", 49}, {"Video Cassette Machines", 50}, {"Video Disc Players", 51}, ¬
		{"Video Switchers", 52}, {"Video Effects", 53}, {"Video Character Generators", 54}, {"Video Still Stores", 55}, ¬
		{"Video Monitors", 56}, ¬
		{"Projection (General)", 64}, {"Film Projectors", 65}, {"Slide Projectors", 66}, {"Video Projectors", 67}, ¬
		{"Dissolvers", 68}, {"Shutter Controls", 69}, ¬
		{"Process Control (General)", 80}, {"Hydraulic Oil", 81}, {"H2O", 82}, {"H20", 82}, {"CO2", 83}, ¬
		{"Compressed Air", 84}, {"Natural Gas", 85}, {"Fog", 86}, {"Smoke", 87}, {"Cracked Haze", 88}, ¬
		{"Pyrotechnics (General)", 96}, {"Fireworks", 97}, {"Explosions", 98}, {"Flame", 99}, {"Smoke Pots", 100}}
	--hex: All Types 0x7F; Lighting 0x01-0x06; Sound 0x10-0x18; Machinery 0x20-0x2A; Video 0x30-0x38;
	--Projection 0x40-0x45; Process Control 0x50-0x58; Pyro 0x60-0x64
	--("H20" with a zero is how the sheet spells it, so both spellings work)
	
	set commandNames to {¬
		{"GO", 1}, {"STOP", 2}, {"RESUME", 3}, {"TIMED_GO", 4}, {"LOAD", 5}, {"SET", 6}, {"FIRE", 7}, {"ALL_OFF", 8}, ¬
		{"RESTORE", 9}, {"RESET", 10}, {"GO_OFF", 11}, ¬
		{"GO/JAM_CLOCK", 16}, {"STANDBY_+", 17}, {"STANDBY_-", 18}, {"SEQUENCE_+", 19}, {"SEQUENCE_-", 20}, ¬
		{"START_CLOCK", 21}, {"STOP_CLOCK", 22}, {"ZERO_CLOCK", 23}, {"SET_CLOCK", 24}, {"MTC_CHASE_ON", 25}, ¬
		{"MTC_CHASE_OFF", 26}, {"OPEN_CUE_LIST", 27}, {"CLOSE_CUE_LIST", 28}, {"OPEN_CUE_PATH", 29}, {"CLOSE_CUE_PATH", 30}}
	--hex: GO-GO_OFF 0x01-0x0B; GO/JAM_CLOCK-CLOSE_CUE_PATH 0x10-0x1E (0x0C-0x0F aren't used)
	
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 13) then
			set theCue to newCue("midi")
			patchCue(theCue, "midi")
			set formatName to cell(currentRow, 4)
			set commandName to cell(currentRow, 5)
			set deviceNumber to cell(currentRow, 6)
			set mscQNumber to cell(currentRow, 7)
			set mscQList to cell(currentRow, 8)
			set mscQPath to cell(currentRow, 9)
			
			--look up the command format's code
			set formatNumber to missing value
			repeat with eachFormat in commandFormats
				if item 1 of eachFormat is formatName then set formatNumber to item 2 of eachFormat
			end repeat --each command format
			if formatNumber is missing value then error "Unknown MSC command format: \"" & formatName & "\""
			
			--look up the command's code
			set commandNumber to missing value
			repeat with eachCommand in commandNames
				if item 1 of eachCommand is commandName then set commandNumber to item 2 of eachCommand
			end repeat --each command
			if commandNumber is missing value then error "Unknown MSC command: \"" & commandName & "\""

			tell application id "com.figure53.QLab.5" to tell front workspace
				set message type of theCue to msc
				set command format of theCue to formatNumber
				set command number of theCue to commandNumber
				if deviceNumber is not "" then set deviceID of theCue to deviceNumber
				if mscQNumber is not "" then set q_number of theCue to mscQNumber
				if mscQList is not "" then set q_list of theCue to mscQList
				if mscQPath is not "" then set q_path of theCue to mscQPath
			end tell --QLab

			finishCue(theCue, 13)
		end if --if the row isn't blank
	end repeat --each row
end makeMscCues


-- ------------------------------------------------------------
-- MIDI SysEx
--   Rows 8 and 10: MIDI patch (see patchCue)
--   B: number   C: name   D: SysEx message   H: pre-wait
-- ------------------------------------------------------------
on makeSysexCues()
	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 8) then
			set theCue to newCue("midi")
			patchCue(theCue, "midi")
			set sysexText to cell(currentRow, 4)

			tell application id "com.figure53.QLab.5" to tell front workspace
				set message type of theCue to sysex
				if sysexText is not "" then set sysex message of theCue to sysexText
			end tell --QLab

			finishCue(theCue, 8)
		end if --if the row isn't blank
	end repeat --each row
end makeSysexCues


-- ------------------------------------------------------------
-- Timecode
--   Rows 8 and 10: patch (audio output patch for LTC, MIDI patch for MTC; see patchCue)
--   Row 12: "Linear Timecode (LTC)" or "MIDI Timecode (MTC)"
--   Row 14: output channel (LTC only)
--   Row 16: frame rate: "24 fps", "25 fps", "30 fps non-drop", or "30 fps drop"
--   B: number   C: name   G: start time offset   K: pre-wait
-- ------------------------------------------------------------
on makeTimecodeCues()
	set timecodeType to cell(12, 1)
	set outputChannel to cell(14, 1)
	set frameRate to cell(16, 1)

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 11) then
			set theCue to newCue("timecode")
			set startOffset to cell(currentRow, 7)

			--LTC goes out an audio output, MTC goes out a MIDI port
			if timecodeType is "Linear Timecode (LTC)" then
				tell application id "com.figure53.QLab.5" to tell front workspace
					set type of theCue to ltc
				end tell --QLab
				patchCue(theCue, "audio output")
				tell application id "com.figure53.QLab.5" to tell front workspace
					set output channel of theCue to outputChannel
				end tell --QLab

			else if timecodeType is "MIDI Timecode (MTC)" then
				tell application id "com.figure53.QLab.5" to tell front workspace
					set type of theCue to mtc
				end tell --QLab
				patchCue(theCue, "midi")
			end if --LTC or MTC

			tell application id "com.figure53.QLab.5" to tell front workspace
				if frameRate is "24 fps" then
					set smpte format of theCue to fps_24
				else if frameRate is "25 fps" then
					set smpte format of theCue to fps_25
				else if frameRate is "30 fps non-drop" then
					set smpte format of theCue to fps_30_non_drop
				else if frameRate is "30 fps drop" then
					set smpte format of theCue to fps_30_drop
				end if --which frame rate

				if startOffset is not "" then set start time offset of theCue to startOffset
			end tell --QLab

			finishCue(theCue, 11)
		end if --if the row isn't blank
	end repeat --each row
end makeTimecodeCues


-- ------------------------------------------------------------
-- Audio Targets and Video Targets
--   Relinks existing cues to files in a folder you choose, or makes new cues for
--   cue numbers that don't exist yet. Cues that can't be relinked get flagged.
--   B: cue number   C: name   D: file name (in the chosen folder)   H: pre-wait
--   mediaType is "audio" or "video"
-- ------------------------------------------------------------
on relinkMediaCues(mediaType)
	set theFolder to choose folder with prompt ("Select the folder containing your " & mediaType & " files")
	set folderPath to POSIX path of theFolder
	set relinkedCount to 0
	set failedCues to {}
	set flaggedCues to {}

	repeat with rowNumber from 3 to (count of sheetTable)
		set currentRow to rowNumber
		if not rowIsBlank(currentRow, 2, 8) then
			set cueNumber to cell(currentRow, 2)
			set cueName to cell(currentRow, 3)
			set mediaFileName to cell(currentRow, 4)

			--use the cue with this number if it already exists, or else make a new one
			set theCue to missing value
			if cueNumber is not "" then
				tell application id "com.figure53.QLab.5" to tell front workspace
					try
						set theCue to cue cueNumber
					end try --looking for an existing cue
				end tell --QLab
			end if --if the row has a cue number

			if theCue is missing value then
				set theCue to newCue(mediaType)
			else if cueName is not "" then
				tell application id "com.figure53.QLab.5" to tell front workspace
					set q name of theCue to cueName
				end tell --QLab
			end if --new cue or existing cue

			tell application id "com.figure53.QLab.5" to tell front workspace
				set cueType to q type of theCue
			end tell --QLab

			if cueType is not mediaType then
				--an existing cue with this number is the wrong type, so leave it alone and flag it
				noteFailedCue(theCue)

			else
				--check that the file is in the folder
				set fileFound to false
				if mediaFileName is not "" then
					tell application "System Events"
						set fileFound to (exists file (folderPath & mediaFileName))
					end tell --System Events
				end if --if the row has a file name

				if fileFound then
					set mediaFile to POSIX file (folderPath & mediaFileName)
					tell application id "com.figure53.QLab.5" to tell front workspace
						set file target of theCue to mediaFile
						--if QLab took the file, the cue's default name is now the file name
						set relinkWorked to ((q default name of theCue) is mediaFileName)
					end tell --QLab
					if relinkWorked then
						set relinkedCount to relinkedCount + 1
					else
						noteFailedCue(theCue)
					end if --if QLab took the file
				else
					noteFailedCue(theCue)
				end if --if the file was found

				finishCue(theCue, 8)
			end if --if it's the right type of cue
		end if --if the row isn't blank
	end repeat --each row

	--report what happened
	if failedCues is not {} then
		set AppleScript's text item delimiters to ", "
		set failedList to failedCues as text
		tell application id "com.figure53.QLab.5"
			display dialog ("The following cues failed to update " & mediaType & " targets, and have been flagged:" & return & failedList & return & return & relinkedCount & " cues were successfully relinked.") with icon 2 with title "Target Updates Failed" buttons {"Unflag", "Accept"} default button "Accept"
			if button returned of result is "Unflag" then
				tell front workspace
					repeat with eachCue in flaggedCues
						set flagged of eachCue to false
					end repeat --each flagged cue
				end tell --front workspace
			end if --if Unflag was clicked
		end tell --QLab
	else if relinkedCount > 0 then
		tell application id "com.figure53.QLab.5"
			display dialog ((relinkedCount as text) & " cues were successfully relinked.") buttons {"OK"} default button "OK"
		end tell --QLab
	end if --what to report
end relinkMediaCues


--adds a cue to the list of cues that couldn't be relinked, and flags it
--(cues that were already flagged stay flagged even if "Unflag" is clicked later)
on noteFailedCue(theCue)
	tell application id "com.figure53.QLab.5" to tell front workspace
		set cueLabel to q number of theCue
		if cueLabel is "" then set cueLabel to "row " & currentRow
		set end of failedCues to cueLabel
		if flagged of theCue is not true then
			set flagged of theCue to true
			set end of flaggedCues to theCue
		end if --if it wasn't already flagged
	end tell --QLab
end noteFailedCue


-- ------------------------------------------------------------
-- Prompt
--   Turns one list of moments in a song into any mix of Start cues, Load cues, Memo cues,
--   and slices, using the audio/video cue that was selected.
--   Row 1: song title   Rows 6, 8, 10: group/cue list names for Start, Load, and Memo cues
--   B: number   C: name   G: time (pre-wait for Starts and Memos, load time for Loads,
--   slice time for Slices)
-- ------------------------------------------------------------
on makePromptCues(startingSelection)
	set songTitle to cell(1, 1)

	tell application id "com.figure53.QLab.5"
		set userChoice to choose from list {"Slices", "Start Cues", "Load-to-Time Cues", "Memo Cues", ¬
			"Start Cues and Slices", "Load-to-Time Cues and Slices", "Memo Cues and Slices", "Loads, Memos, and Slices", ¬
			"Starts, Loads, and Slices", "Starts, Loads, and Memos", "All"} ¬
			with title ("QLab Batch Cue Generator - " & songTitle) with prompt "Convert tsv/csv to:" default items {"Slices"}
	end tell --QLab

	--stop if Cancel was pressed
	if userChoice is false then return
	set userChoice to item 1 of userChoice
	set makeAll to (userChoice is "All")

	if makeAll or userChoice contains "Start" then
		setUpDestination(6)
		makeStartOrMemoCues("start")
	end if --Start cues

	if makeAll or userChoice contains "Load" then
		setUpDestination(8)
		makeLoadCues(startingSelection)
	end if --Load cues

	if makeAll or userChoice contains "Memo" then
		setUpDestination(10)
		makeStartOrMemoCues("memo")
	end if --Memo cues

	if makeAll or userChoice contains "Slices" then
		makeSlices(startingSelection, 7, 0)
	end if --Slices
end makePromptCues
