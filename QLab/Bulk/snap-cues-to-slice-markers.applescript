-- Name:        Snap Cues to Slice Markers
-- Description: Lines up cues inside a Timeline group with the slice markers of an
--              audio or video cue, by setting each cue's pre-wait.
-- Works with:  QLab 5
-- How to use:  Select one of these, then run the script:
--                - an audio or video cue inside a Timeline group, or
--                - a Timeline group whose first (top) cue is an audio or video cue.
--              Choose an option from the menu. Going top to bottom, each matching cue
--              in the group gets snapped to the next slice marker.
-- Notes:       - Skips cues that aren't armed.
--              - Skips slice markers before the cue's start time or after its end time.
--              - Accounts for the audio/video cue's own pre-wait, start time, and rate,
--                so everything lines up in timeline view.
--              - Assumes each slice plays once. Looping slices (play count above 1, or an
--                infinite loop) will make the later cues fire too early.
-- Author:      Taylor Glad, 12/26/2023

-- ============================================================
-- SETTINGS (change these to fit your show)
-- ============================================================

--the type of cue the script looks for in the group and snaps to slice markers
--use the type name the way QLab shows it, e.g. "Start", "Stop", "Fade", "Light", "Network", "MIDI"
set cueTypeToSnap to "Start"

--the choices in the menu (changing the wording here updates it everywhere in the script)
set optionSlicesOnly to "Just the slice markers"
set optionStart to "Start of timeline and slice markers"
set optionEnd to "End of timeline and slice markers"
set optionBoth to "Start and end of timeline, and slice markers"

-- ============================================================
-- SCRIPT
-- ============================================================

tell application id "com.figure53.QLab.5" to tell front workspace

	-- ------------------------------------------------------------
	-- 1. Check the selection, and find the group and the slice cue
	--    groupCue = the Timeline group
	--    sliceCue = the audio/video cue whose slice markers we use
	-- ------------------------------------------------------------

	--stop if nothing is selected
	set selectedCues to (selected as list)
	if (count of selectedCues) is 0 then
		display dialog "Nothing is selected. Please select a Timeline group with an audio/video cue at the top, or an audio/video cue inside a Timeline group." with icon 2
		return
	end if --if nothing is selected

	set selectedCue to first item of selectedCues
	set cueType to q type of selectedCue

	if cueType is in {"Audio", "Video"} then
		--an audio/video cue is selected: use its slices, and use the group it's in
		set sliceCue to selectedCue
		set groupCue to parent of selectedCue

	else if cueType is "Group" then
		--a group is selected: use the slices of the first (top) cue in the group
		set groupCue to selectedCue
		set groupChildren to cues of groupCue

		--stop if the group is empty
		if (count of groupChildren) is 0 then
			display dialog "This group is empty. Please select a Timeline group with an audio or video cue at the top." with icon 2
			return
		end if --if the group is empty

		--stop if the first cue in the group isn't audio or video
		set sliceCue to first item of groupChildren
		if q type of sliceCue is not in {"Audio", "Video"} then
			display dialog "The first cue in this group isn't an audio or video cue. Please select a Timeline group with an audio or video cue at the top." with icon 2
			return
		end if --if the first cue isn't audio/video

	else
		--something else is selected
		display dialog "Please select a Timeline group with an audio/video cue at the top, or an audio/video cue inside a Timeline group." with icon 2
		return
	end if --what type of cue is selected

	--stop if the group isn't in Timeline mode
	--(this also catches an audio/video cue that isn't in a group at all, since its "parent" is the cue list)
	if mode of groupCue is not timeline then
		display dialog "This script is only for groups in Timeline mode." with icon 2
		return
	end if --if the group isn't in Timeline mode

	-- ------------------------------------------------------------
	-- 2. Make a list of the cues to snap
	--    (only cues of type cueTypeToSnap that are armed, in order top to bottom)
	-- ------------------------------------------------------------

	set cuesToSnap to {}
	repeat with eachCue in (cues of groupCue)
		--the uniqueID check skips the slice cue itself, in case cueTypeToSnap is "Audio" or "Video"
		if (q type of eachCue is cueTypeToSnap) and (armed of eachCue is true) and (uniqueID of eachCue is not uniqueID of sliceCue) then
			set end of cuesToSnap to contents of eachCue
		end if --if it's the right type, armed, and not the slice cue
	end repeat --each cue in the group

	--stop if there's nothing to snap
	if (count of cuesToSnap) is 0 then
		display dialog ("There are no armed " & cueTypeToSnap & " cues in this group to snap.") with icon 2
		return
	end if --if there are no cues to snap

	-- ------------------------------------------------------------
	-- 3. Make a list of the slice marker times to snap to
	--    (only the slices between the cue's start time and end time, since the rest never play)
	-- ------------------------------------------------------------

	set sliceCueStart to start time of sliceCue
	set sliceCueEnd to end time of sliceCue

	set sliceTimes to {}
	repeat with eachSlice in (slice markers of sliceCue)
		set thisSliceTime to time of eachSlice
		if thisSliceTime > sliceCueStart and thisSliceTime < sliceCueEnd then
			set end of sliceTimes to thisSliceTime
		end if --if the slice is between the start and end time
	end repeat --each slice marker

	-- ------------------------------------------------------------
	-- 4. Ask what to snap to
	-- ------------------------------------------------------------

	--the prompt says where the slices are coming from, depending on what was selected
	if cueType is "Group" then
		set slicesComeFrom to "the first audio/video cue in the group"
	else
		set slicesComeFrom to "the selected audio/video cue"
	end if --if a group or an audio/video cue was selected

	set userChoice to choose from list {optionSlicesOnly, optionStart, optionEnd, optionBoth} ¬
		with title ("Snap " & cueTypeToSnap & " Cues to Slice Markers") ¬
		with prompt ("This script will use the slices in " & slicesComeFrom & ". Snap " & cueTypeToSnap & " cues to:") ¬
		default items {optionSlicesOnly}

	--stop without changing anything if Cancel was pressed
	if userChoice is false then return
	set userChoice to item 1 of userChoice

	--add the start and/or end of the audio/video cue as extra snap points, depending on the choice
	if userChoice is in {optionStart, optionBoth} then
		set beginning of sliceTimes to sliceCueStart
	end if --if the start was chosen
	if userChoice is in {optionEnd, optionBoth} then
		set end of sliceTimes to sliceCueEnd
	end if --if the end was chosen

	-- ------------------------------------------------------------
	-- 5. Snap the cues
	--    A slice at time X in the file shows up on the timeline at:
	--      (slice cue's pre-wait) + (X - slice cue's start time) / (slice cue's rate)
	--    so that's what each cue's pre-wait gets set to.
	-- ------------------------------------------------------------

	set sliceCuePreWait to pre wait of sliceCue
	set sliceCueRate to rate of sliceCue

	--only go as far as the shorter list, so we don't run out of cues or slices
	if (count of sliceTimes) < (count of cuesToSnap) then
		set snapLimit to count of sliceTimes
	else
		set snapLimit to count of cuesToSnap
	end if --which list is shorter

	repeat with i from 1 to snapLimit
		set newPreWait to sliceCuePreWait + ((item i of sliceTimes) - sliceCueStart) / sliceCueRate
		set pre wait of (item i of cuesToSnap) to newPreWait
	end repeat --each cue to snap

	-- ------------------------------------------------------------
	-- 6. Report any extra cues or extra slice markers
	--    positive = more cues than slices, negative = more slices than cues
	-- ------------------------------------------------------------

	set leftoverCues to (count of cuesToSnap) - (count of sliceTimes)
	if leftoverCues > 1 then
		display dialog ("" & leftoverCues & " " & cueTypeToSnap & " cues were left without a time to snap them to.") with icon 1
	else if leftoverCues is 1 then
		display dialog ("1 " & cueTypeToSnap & " cue was left without a time to snap to.") with icon 1
	else if leftoverCues is -1 then
		display dialog ("You have 1 fewer " & cueTypeToSnap & " cue than slice markers.") with icon 1
	else if leftoverCues < -1 then
		display dialog ("You have " & -leftoverCues & " fewer " & cueTypeToSnap & " cues than slice markers.") with icon 1
	end if --how many cues or slices are left over

end tell --QLab
