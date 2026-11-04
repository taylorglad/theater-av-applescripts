-- Name:        Select Cues with Same File Type
-- Description: Selects every cue in the current cue list whose target file has the same file type as
--              the last selected cue (all the WAVs, all the movies…), so they can be edited together.
-- Works with:  QLab 5
-- How to use:  Select one audio or video cue and run. The selection becomes every cue in the current
--              list whose target has a matching file type.
-- Notes:       A cue with no file target makes the script stop with an error, so run it in a list where
--              the cues have targets. It changes the selection on purpose, so it isn't a mid-run hotkey.
-- Author:      Taylor Glad, written 2023–2024 (filed here 2026-11-03)

-- ============================================================
-- SCRIPT
-- ============================================================

tell application id "com.figure53.QLab.5" to tell front workspace
	-- get the type identifier of the file target for the last selected cue
	set selectedCue to last item of (selected as list)
	set targetTypeIdentifier to my getTypeIdentifier(selectedCue)
	
	set selectedCues to {}
	repeat with thisCue in (every cue of current cue list)
		if my getTypeIdentifier(thisCue) is targetTypeIdentifier then
			log my (getTypeIdentifier(thisCue))
			log (targetTypeIdentifier)
			set end of selectedCues to thisCue
		end if
	end repeat
	set selected to selectedCues
end tell


on getTypeIdentifier(aCue)
	tell application id "com.figure53.QLab.5" to tell front workspace
		set targetPath to file target of aCue
	end tell
	tell application "System Events" to return (type identifier of (targetPath as alias) as text)
end getTypeIdentifier
