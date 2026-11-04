-- Name:        Drop Memo in Running Timeline
-- Description: While a Timeline group is playing, adds a Memo cue inside it at the exact
--              moment you run the script. Handy for marking spots on the fly (camera
--              shots, cues to build later) while you listen through a track.
-- Works with:  QLab 5
-- How to use:  Put this in a Script cue with a hotkey (or in Workspace Settings > Scripts).
--              Start a Timeline group, and press the hotkey wherever you want a marker.
-- Notes:       - The memo's pre-wait is set to the group's elapsed time, so it shows up
--                at that spot in timeline view.
--              - If more than one Timeline group is running, it uses the first one QLab lists.
--              - Your selection and playhead are put back afterward, so the next GO is
--                still the cue you expect.
-- Author:      Taylor Glad

-- ============================================================
-- SETTINGS (change these to fit your show)
-- ============================================================

--the name given to each new memo cue
set memoName to "IMAG"

-- ============================================================
-- SCRIPT
-- ============================================================

tell application id "com.figure53.QLab.5" to tell front workspace

	-- ------------------------------------------------------------
	-- 1. Find the running Timeline group and grab its time
	--    (look through everything that's playing, since the list also includes
	--    the cues inside the group, and this script itself if it's a Script cue)
	-- ------------------------------------------------------------

	set groupCue to missing value
	repeat with eachCue in (active cues as list)
		if q type of eachCue is "Group" and mode of eachCue is timeline then
			set groupCue to contents of eachCue
			exit repeat
		end if --if it's a Timeline group
	end repeat --each playing cue

	--stop if no Timeline group is playing
	if groupCue is missing value then
		display dialog "No Timeline group is playing. Start one, then run this script to drop a memo into it." with icon 2
		return
	end if --if no Timeline group is playing

	--grab the time right away, so the memo lands where the hotkey was pressed
	set elapsedTime to action elapsed of groupCue

	-- ------------------------------------------------------------
	-- 2. Remember the selection and playhead
	--    (making a new cue selects it, which can move the playhead mid-show)
	-- ------------------------------------------------------------

	set theCueList to current cue list
	set savedSelection to (selected as list)
	set savedPlayhead to playhead of theCueList

	-- ------------------------------------------------------------
	-- 3. Make the memo and move it into the group
	-- ------------------------------------------------------------

	--QLab makes the new cue below the selected cue and selects it, so grab it from the selection
	make type "Memo"
	set newCue to last item of (selected as list)
	set q name of newCue to memoName
	set pre wait of newCue to elapsedTime

	--move it to the end of the running group
	move cue id (uniqueID of newCue) of parent of newCue to end of groupCue

	-- ------------------------------------------------------------
	-- 4. Put the selection and playhead back
	--    (in a "try" so nothing breaks if there was no playhead to put back)
	-- ------------------------------------------------------------

	set selected to savedSelection
	try
		set playhead of theCueList to savedPlayhead
	end try --putting the playhead back

end tell --QLab
