-- Name:        Retarget Cues to Other Extension (DRAFT — does not run yet)
-- Description: Meant to re-point every audio and video cue at a same-named file next to its current
--              target that has a preferred extension (swap every WAV for its MP3, for example), asking
--              for the preferred audio and video extensions in two dialogs.
-- Works with:  QLab 5
-- How to use:  Not yet — see Notes.
-- Notes:       DRAFT. It compiles but fails when run: `songTitle` is never defined (used in the first
--              dialog's title), that first "choose from list" result is never used, and the file-name
--              maths reads "q number of targetPath" (a cue property) from a path string. Kept for the
--              idea; finish it before relying on it.
-- Author:      Taylor Glad, written 2023–2024 (filed here 2026-11-03)

-- ============================================================
-- SCRIPT
-- ============================================================

tell application id "com.figure53.QLab.5" to tell front workspace
	-- Get a list of all audio and video cues in the workspace
	set allAudioCues to every audio cue
	set allVideoCues to every video cue
	
	-- Prompt user for preferred file extensions for audio cues
	set userChoice to choose from list {"aiff", "wav", "mp4", "mp3"} with title ("QLab Batch Cue Generator - " & songTitle) with prompt "Convert tsv/csv to:" default items "Slices"
	set audioExtensionList to text returned of (display dialog "Enter preferred file extension for audio cues:" default answer "mp3, m4a, wav, aiff")
	set AppleScript's text item delimiters to {", ", ","}
	set audioTargetExtensions to text items of audioExtensionList
	
	-- Prompt user for preferred file extensions for video cues
	set videoExtensionList to text returned of (display dialog "Enter preferred file extension for video cues:" default answer "mov, mp4, m4v")
	set videoTargetExtensions to text items of videoExtensionList
	
	-- Loop through each audio cue and check its target file
	repeat with theAudioCue in allAudioCues
		set cueTarget to target of theAudioCue
		if cueTarget is not missing value then
			set targetPath to POSIX path of cueTarget
			
			-- Check for files with the same name but different extension
			set targetFolder to POSIX file (POSIX path of targetPath & "..")
			set targetName to text 1 thru -((length of (q number of targetPath)) + 2) of (q number of targetPath)
			set foundMatch to false
			repeat with ext in audioTargetExtensions
				set possibleTarget to targetFolder & targetName & ext
				if (possibleTarget as POSIX file) exists then
					set target of theAudioCue to (possibleTarget as text)
					set foundMatch to true
					exit repeat
				end if
			end repeat -- end repeat with ext in audioTargetExtensions
			
			if not foundMatch then
				display dialog "No alternative file found for cue " & (number of theAudioCue as text) & "."
			end if
		end if
	end repeat -- end repeat with theAudioCue in allAudioCues
	
	-- Loop through each video cue and check its target file
	repeat with theVideoCue in allVideoCues
		set cueTarget to target of theVideoCue
		if cueTarget is not missing value then
			set targetPath to POSIX path of cueTarget
			
			-- Check for files with the same name but different extension
			set targetFolder to POSIX file (POSIX path of targetPath & "..")
			set targetName to text 1 thru -((length of (q number of targetPath)) + 2) of (q number of targetPath)
			set foundMatch to false
			repeat with ext in videoTargetExtensions
				set possibleTarget to targetFolder & targetName & ext
				if (possibleTarget as POSIX file) exists then
					set target of theVideoCue to (possibleTarget as text)
					set foundMatch to true
					exit repeat
				end if
			end repeat -- end repeat with ext in videoTargetExtensions
			
			if not foundMatch then
				display dialog "No alternative file found for cue " & (number of theVideoCue as text) & "."
			end if
		end if
	end repeat -- end repeat with theVideoCue in allVideoCues
end tell
