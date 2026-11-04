-- Name:        Rivage Cues from I/O Sheet
-- Description: Reads a TSV exported from a show's I/O sheet and builds a collapsed group of Network cues
--              that program a Yamaha Rivage (channel / mix / matrix names, colours, icons and DCA
--              assignments) through QLab's "Yamaha Rivage" network patch, then starts the group.
-- Works with:  QLab 5 (Network cue with a patch of type "Yamaha Rivage")
-- How to use:  Make a Network patch of type "Yamaha Rivage" and name it as in Settings. Export the I/O
--              sheet as TSV: inputs have "Source" in column 2 of the header row (with Rivage Channel,
--              DCA, Chan Color, Icon columns), mixes have "Mix Name" (with a Mix column), matrices have
--              "Matrix Name" (with a Matrix column). Run the script and pick the file.
-- Notes:       Names are cut to 8 characters. An input whose Icon cell is blank gets an icon guessed
--              from its source name ("HH" → Hi-Hat, "BGV" → Choir, "Podium" → Speech Mic…). A DCA
--              assignment sends all 24 DCAs off, then the one on (25 cues per channel). Written before
--              the Console Programming Assistant app did this job directly over the Rivage's network
--              protocol; kept as the reference for that workflow.
-- Author:      Taylor Glad, written 2023–2024 (filed here 2026-11-03)

-- ============================================================
-- SETTINGS (change these to fit your show)
-- ============================================================

set networkPatchName to "Rivage" --put the name (case sensitive) of your network patch with type set to "Yamaha Rivage". If there are multiple network patches with the same name, the first result (highest on the list) will be used.

-- ============================================================
-- SCRIPT
-- ============================================================

set TheFile to choose file of type "tsv" with prompt "Please select your exported TSV I/O sheet"
set theFileContents to read TheFile
set thetids to AppleScript's text item delimiters
set AppleScript's text item delimiters to tab
set thenumberofrows to count of paragraphs of theFileContents
set thenumberofcolumns to count of text items in paragraph 1 of theFileContents
set cueCount to 0
tell application id "com.figure53.QLab.5" to tell front workspace
	if text item 2 of paragraph 1 of theFileContents is "Source" then --If the csv file comes straight from the I/O sheet for inputs
		--make type "cue list"
		-- or make a group cue instead of a cue list. You'll have to "un-comment" 2 lines below as well
		--set q name of last cue list to "New Light Cues"
		--set current cue list to last cue list whose q name is "New Light Cues"
		make type "group"
		set GroupQ to last item of (selected as list)
		set the mode of GroupQ to start_first_and_enter
		set the q name of GroupQ to "Rivage Cues"
		set the q number of GroupQ to ""
		collapse GroupQ
		
		
		set SourceColumn to false
		set RivageChannelColumn to false
		set DCAColumn to false
		set ChanColorColumn to false
		set IconColumn to false
		
		
		--Determine which column headers there are
		repeat with eachColumn from 1 to thenumberofcolumns
			if text item eachColumn of paragraph 1 of theFileContents is "Source" then
				set SourceColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Rivage Channel" then
				set RivageChannelColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "DCA" then
				set DCAColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Chan Color" then
				set ChanColorColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Icon" then
				set IconColumn to eachColumn
			end if
		end repeat
		
		
		
		if RivageChannelColumn is false then
			return
		end if
		
		repeat with makeCues from 2 to (thenumberofrows)
			set theRow to (paragraph makeCues) of theFileContents
			--if the row has a Rivage Channel Number
			if text item SourceColumn of theRow is not "" then --skip blank rows
				
				--Make OSC cue for Channel Name
				make type "network"
				set theCue to last item of (selected as list)
				set the network patch name of theCue to networkPatchName
				if the network patch name of theCue is not networkPatchName then
					display dialog ("Please create a network patch for Yamaha Rivage and name it: " & networkPatchName) with title "Rivage Cues" with icon 1
					return
				end if
				set SourceName to text item SourceColumn of theRow as string
				if (count of SourceName) > 8 then
					set truncatedName to text 1 thru 8 of SourceName
				else
					set truncatedName to SourceName
				end if
				set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "Label", "Name", "\"" & truncatedName & "\""}
				
				set the pre wait of theCue to 0.01
				set the continue mode of theCue to auto_follow
				set the q number of theCue to ""
				set newQID to uniqueID of theCue
				move cue id newQID of parent of theCue to end of GroupQ
				
				if DCAColumn is not false and text item DCAColumn of theRow is not "" then
					repeat with eachDCA from 1 to 24
						make type "network"
						set theCue to last item of (selected as list)
						set the network patch name of theCue to networkPatchName
						set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", eachDCA, "Off"}
						set the pre wait of theCue to 0.01
						set the continue mode of theCue to auto_follow
						set the q number of theCue to ""
						set newQID to uniqueID of theCue
						move cue id newQID of parent of theCue to end of GroupQ
					end repeat
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					if DCAColumn is not false and text item DCAColumn of theRow is not "0" then
						set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", (text item DCAColumn of theRow as string), "On"}
					end if
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				if ChanColorColumn is not false and text item ChanColorColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "Label", "Color", (text item ChanColorColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				set iconWordsList to {"Kick", "Kick in", "Kick Out", "Snare", "Snare Top", "Snare Btm", "Snare Bottom", "Hi-Hat", "HiHat", "HH", "Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack", "Floor Tom", "Floor", "Tom3", "Tom 3", "Cymbal", "Crash", "Ride", "Drum Kit", "OH", "OH L", "OH R", "Percussion", "Mallets", "E. Bass", "Bass", "A. Guitar", "Acoustic", "E. Guitar", "Electric", "Bass Amp", "Guitar Amp", "A. Bass", "Direct Box", "Strings", "Violin", "Fiddle", "Viola", "Mandolin", "Trumpet", "Trump", "Trombone", "Bone", "Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari", "Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind", "Piano", "Piano L", "Piano H", "Organ", "Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R", "Male", "Men", "Female", "Women", "Choir", "BGV", "Dynamic Mic", "Condenser Mic", "Instrument Mic", "Wireless Mic", "Headset", "DPA Headset", "Speech Mic", "Podium", "Podium BU", "FOH", "Speaker", "Subwoofer", "Wedge", "Video", "In-Ear", "Monitor", "Effector", "Media 1", "Media 2", "Media 3", "Mixer", "PC", "QLab", "ClickFX", "Processor", "Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R", "Arrow Left", "Arrow Right", "Exclamation", "Smile", "Money", "Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4", "Star 2", "Blank"}
				
				if IconColumn is not false and text item IconColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", (text item IconColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
					--Even if there isn't an icon in an icon column, see if the source is named with an icon
				else if iconWordsList contains text item SourceColumn of theRow then
					if {"Kick", "Kick in", "Kick Out"} contains text item SourceColumn of theRow then
						set theIcon to "Kick"
					else if {"Snare Top", "Snare Btm", "Snare Bottom"} contains text item SourceColumn of theRow then
						set theIcon to "Snare"
					else if {"Hi-Hat", "HiHat", "HH"} contains text item SourceColumn of theRow then
						set theIcon to "Hi-Hat"
					else if {"Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack"} contains text item SourceColumn of theRow then
						set theIcon to "Tom Tom"
					else if {"Floor Tom", "Floor", "Tom3", "Tom 3"} contains text item SourceColumn of theRow then
						set theIcon to "Floor Tom"
					else if {"Cymbal", "Crash", "Ride"} contains text item SourceColumn of theRow then
						set theIcon to "Cymbal"
					else if {"Drum Kit", "OH", "OH L", "OH R"} contains text item SourceColumn of theRow then
						set theIcon to "Drum Kit"
					else if {"Percussion"} contains text item SourceColumn of theRow then
						set theIcon to "Percussion"
					else if {"Strings", "Violin", "Fiddle", "Viola", "Mandolin"} contains text item SourceColumn of theRow then
						set theIcon to "Strings"
					else if {"Trumpet", "Trump"} contains text item SourceColumn of theRow then
						set theIcon to "Trumpet"
					else if {"Trombone", "Bone"} contains text item SourceColumn of theRow then
						set theIcon to "Trombone"
					else if {"Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari"} contains text item SourceColumn of theRow then
						set theIcon to "Saxophone"
					else if {"Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind"} contains text item SourceColumn of theRow then
						set theIcon to "Flute"
					else if {"Piano", "Piano L", "Piano H"} contains text item SourceColumn of theRow then
						set theIcon to "Piano"
					else if {"Organ"} contains text item SourceColumn of theRow then
						set theIcon to "Organ"
					else if {"Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R"} contains text item SourceColumn of theRow then
						set theIcon to "Keyboard"
					else if {"Male", "Men"} contains text item SourceColumn of theRow then
						set theIcon to "Male"
					else if {"Female", "Women"} contains text item SourceColumn of theRow then
						set theIcon to "Female"
					else if {"Choir", "BGV"} contains text item SourceColumn of theRow then
						set theIcon to "Choir"
					else if {"Headset", "DPA Headset"} contains text item SourceColumn of theRow then
						set theIcon to "Headset"
					else if {"Speech Mic", "Podium", "Podium BU"} contains text item SourceColumn of theRow then
						set theIcon to "Speech Mic"
					else if {"PC", "QLab", "ClickFX"} contains text item SourceColumn of theRow then
						set theIcon to "PC"
					else if {"Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R"} contains text item SourceColumn of theRow then
						set theIcon to "Audience"
					else if {"Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4"} contains text item SourceColumn of theRow then
						set theIcon to "Star 1"
					end if
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Input Channel", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", theIcon}
					set the pre wait of theCue to 1.0E-3
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				
				
			end if -- If the source column for that row is not blank
		end repeat
		start GroupQ
		
	else if text item 2 of paragraph 1 of theFileContents is "Mix Name" then --If the csv file comes straight from the I/O sheet for outputs
		--make type "cue list"
		-- or make a group cue instead of a cue list. You'll have to "un-comment" 2 lines below as well
		--set q name of last cue list to "New Light Cues"
		--set current cue list to last cue list whose q name is "New Light Cues"
		make type "group"
		set GroupQ to last item of (selected as list)
		set the mode of GroupQ to start_first_and_enter
		set the q name of GroupQ to "Rivage Cues"
		set the q number of GroupQ to ""
		collapse GroupQ
		
		
		set SourceColumn to false
		set RivageChannelColumn to false
		set DCAColumn to false
		set ChanColorColumn to false
		set IconColumn to false
		
		
		--Determine which column headers there are
		repeat with eachColumn from 1 to thenumberofcolumns
			if text item eachColumn of paragraph 1 of theFileContents is "Mix Name" then
				set SourceColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Mix" then
				set RivageChannelColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "DCA" then
				set DCAColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Chan Color" then
				set ChanColorColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Icon" then
				set IconColumn to eachColumn
			end if
		end repeat
		
		
		
		if RivageChannelColumn is false then
			return
		end if
		
		repeat with makeCues from 2 to (thenumberofrows)
			set theRow to (paragraph makeCues) of theFileContents
			--if the row has a Rivage Channel Number
			if text item SourceColumn of theRow is not "" then --skip blank rows
				
				--Make OSC cue for Channel Name
				make type "network"
				set theCue to last item of (selected as list)
				set the network patch name of theCue to networkPatchName
				if the network patch name of theCue is not networkPatchName then
					display dialog ("Please create a network patch for Yamaha Rivage and name it: " & networkPatchName) with title "Rivage Cues" with icon 1
					return
				end if
				set SourceName to text item SourceColumn of theRow as string
				if (count of SourceName) > 8 then
					set truncatedName to text 1 thru 8 of SourceName
				else
					set truncatedName to SourceName
				end if
				set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Name", "\"" & truncatedName & "\""}
				
				set the pre wait of theCue to 0.01
				set the continue mode of theCue to auto_follow
				set the q number of theCue to ""
				set newQID to uniqueID of theCue
				move cue id newQID of parent of theCue to end of GroupQ
				
				if DCAColumn is not false and text item DCAColumn of theRow is not "" then
					repeat with eachDCA from 1 to 24
						make type "network"
						set theCue to last item of (selected as list)
						set the network patch name of theCue to networkPatchName
						set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", eachDCA, "Off"}
						set the pre wait of theCue to 0.01
						set the continue mode of theCue to auto_follow
						set the q number of theCue to ""
						set newQID to uniqueID of theCue
						move cue id newQID of parent of theCue to end of GroupQ
					end repeat
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					if DCAColumn is not false and text item DCAColumn of theRow is not "0" then
						set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", (text item DCAColumn of theRow as string), "On"}
					end if
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				if ChanColorColumn is not false and text item ChanColorColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Color", (text item ChanColorColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				set iconWordsList to {"Kick", "Kick in", "Kick Out", "Snare", "Snare Top", "Snare Btm", "Snare Bottom", "Hi-Hat", "HiHat", "HH", "Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack", "Floor Tom", "Floor", "Tom3", "Tom 3", "Cymbal", "Crash", "Ride", "Drum Kit", "OH", "OH L", "OH R", "Percussion", "Mallets", "E. Bass", "Bass", "A. Guitar", "Acoustic", "E. Guitar", "Electric", "Bass Amp", "Guitar Amp", "A. Bass", "Direct Box", "Strings", "Violin", "Fiddle", "Viola", "Mandolin", "Trumpet", "Trump", "Trombone", "Bone", "Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari", "Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind", "Piano", "Piano L", "Piano H", "Organ", "Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R", "Male", "Men", "Female", "Women", "Choir", "BGV", "Dynamic Mic", "Condenser Mic", "Instrument Mic", "Wireless Mic", "Headset", "DPA Headset", "Speech Mic", "Podium", "Podium BU", "FOH", "Speaker", "Subwoofer", "Wedge", "Video", "In-Ear", "Monitor", "Effector", "Media 1", "Media 2", "Media 3", "Mixer", "PC", "QLab", "ClickFX", "Processor", "Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R", "Arrow Left", "Arrow Right", "Exclamation", "Smile", "Money", "Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4", "Star 2", "Blank"}
				
				if IconColumn is not false and text item IconColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", (text item IconColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
					--Even if there isn't an icon in an icon column, see if the source is named with an icon
				else if iconWordsList contains text item SourceColumn of theRow then
					if {"Kick", "Kick in", "Kick Out"} contains text item SourceColumn of theRow then
						set theIcon to "Kick"
					else if {"Snare Top", "Snare Btm", "Snare Bottom"} contains text item SourceColumn of theRow then
						set theIcon to "Snare"
					else if {"Hi-Hat", "HiHat", "HH"} contains text item SourceColumn of theRow then
						set theIcon to "Hi-Hat"
					else if {"Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack"} contains text item SourceColumn of theRow then
						set theIcon to "Tom Tom"
					else if {"Floor Tom", "Floor", "Tom3", "Tom 3"} contains text item SourceColumn of theRow then
						set theIcon to "Floor Tom"
					else if {"Cymbal", "Crash", "Ride"} contains text item SourceColumn of theRow then
						set theIcon to "Cymbal"
					else if {"Drum Kit", "OH", "OH L", "OH R"} contains text item SourceColumn of theRow then
						set theIcon to "Drum Kit"
					else if {"Percussion"} contains text item SourceColumn of theRow then
						set theIcon to "Percussion"
					else if {"Strings", "Violin", "Fiddle", "Viola", "Mandolin"} contains text item SourceColumn of theRow then
						set theIcon to "Strings"
					else if {"Trumpet", "Trump"} contains text item SourceColumn of theRow then
						set theIcon to "Trumpet"
					else if {"Trombone", "Bone"} contains text item SourceColumn of theRow then
						set theIcon to "Trombone"
					else if {"Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari"} contains text item SourceColumn of theRow then
						set theIcon to "Saxophone"
					else if {"Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind"} contains text item SourceColumn of theRow then
						set theIcon to "Flute"
					else if {"Piano", "Piano L", "Piano H"} contains text item SourceColumn of theRow then
						set theIcon to "Piano"
					else if {"Organ"} contains text item SourceColumn of theRow then
						set theIcon to "Organ"
					else if {"Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R"} contains text item SourceColumn of theRow then
						set theIcon to "Keyboard"
					else if {"Male", "Men"} contains text item SourceColumn of theRow then
						set theIcon to "Male"
					else if {"Female", "Women"} contains text item SourceColumn of theRow then
						set theIcon to "Female"
					else if {"Choir", "BGV"} contains text item SourceColumn of theRow then
						set theIcon to "Choir"
					else if {"Headset", "DPA Headset"} contains text item SourceColumn of theRow then
						set theIcon to "Headset"
					else if {"Speech Mic", "Podium", "Podium BU"} contains text item SourceColumn of theRow then
						set theIcon to "Speech Mic"
					else if {"PC", "QLab", "ClickFX"} contains text item SourceColumn of theRow then
						set theIcon to "PC"
					else if {"Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R"} contains text item SourceColumn of theRow then
						set theIcon to "Audience"
					else if {"Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4"} contains text item SourceColumn of theRow then
						set theIcon to "Star 1"
					end if
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Mix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", theIcon}
					set the pre wait of theCue to 1.0E-3
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				
				
			end if -- If the source column for that row is not blank
		end repeat
		start GroupQ
		
	else if text item 2 of paragraph 1 of theFileContents is "Matrix Name" then --If the csv file comes straight from the I/O sheet for outputs
		--make type "cue list"
		-- or make a group cue instead of a cue list. You'll have to "un-comment" 2 lines below as well
		--set q name of last cue list to "New Light Cues"
		--set current cue list to last cue list whose q name is "New Light Cues"
		make type "group"
		set GroupQ to last item of (selected as list)
		set the mode of GroupQ to start_first_and_enter
		set the q name of GroupQ to "Rivage Cues"
		set the q number of GroupQ to ""
		collapse GroupQ
		
		
		set SourceColumn to false
		set RivageChannelColumn to false
		set DCAColumn to false
		set ChanColorColumn to false
		set IconColumn to false
		
		
		--Determine which column headers there are
		repeat with eachColumn from 1 to thenumberofcolumns
			if text item eachColumn of paragraph 1 of theFileContents is "Matrix Name" then
				set SourceColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Matrix" then
				set RivageChannelColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "DCA" then
				set DCAColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Chan Color" then
				set ChanColorColumn to eachColumn
			else if text item eachColumn of paragraph 1 of theFileContents is "Icon" then
				set IconColumn to eachColumn
			end if
		end repeat
		
		
		
		if RivageChannelColumn is false then
			return
		end if
		
		repeat with makeCues from 2 to (thenumberofrows)
			set theRow to (paragraph makeCues) of theFileContents
			--if the row has a Rivage Channel Number
			if text item SourceColumn of theRow is not "" then --skip blank rows
				
				--Make OSC cue for Channel Name
				make type "network"
				set theCue to last item of (selected as list)
				set the network patch name of theCue to networkPatchName
				if the network patch name of theCue is not networkPatchName then
					display dialog ("Please create a network patch for Yamaha Rivage and name it: " & networkPatchName) with title "Rivage Cues" with icon 1
					return
				end if
				set SourceName to text item SourceColumn of theRow as string
				if (count of SourceName) > 8 then
					set truncatedName to text 1 thru 8 of SourceName
				else
					set truncatedName to SourceName
				end if
				set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Name", "\"" & truncatedName & "\""}
				
				set the pre wait of theCue to 0.01
				set the continue mode of theCue to auto_follow
				set the q number of theCue to ""
				set newQID to uniqueID of theCue
				move cue id newQID of parent of theCue to end of GroupQ
				
				if DCAColumn is not false and text item DCAColumn of theRow is not "" then
					repeat with eachDCA from 1 to 24
						make type "network"
						set theCue to last item of (selected as list)
						set the network patch name of theCue to networkPatchName
						set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", eachDCA, "Off"}
						set the pre wait of theCue to 0.01
						set the continue mode of theCue to auto_follow
						set the q number of theCue to ""
						set newQID to uniqueID of theCue
						move cue id newQID of parent of theCue to end of GroupQ
					end repeat
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					if DCAColumn is not false and text item DCAColumn of theRow is not "0" then
						set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "DCA Assign", (text item DCAColumn of theRow as string), "On"}
					end if
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				if ChanColorColumn is not false and text item ChanColorColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Color", (text item ChanColorColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				set iconWordsList to {"Kick", "Kick in", "Kick Out", "Snare", "Snare Top", "Snare Btm", "Snare Bottom", "Hi-Hat", "HiHat", "HH", "Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack", "Floor Tom", "Floor", "Tom3", "Tom 3", "Cymbal", "Crash", "Ride", "Drum Kit", "OH", "OH L", "OH R", "Percussion", "Mallets", "E. Bass", "Bass", "A. Guitar", "Acoustic", "E. Guitar", "Electric", "Bass Amp", "Guitar Amp", "A. Bass", "Direct Box", "Strings", "Violin", "Fiddle", "Viola", "Mandolin", "Trumpet", "Trump", "Trombone", "Bone", "Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari", "Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind", "Piano", "Piano L", "Piano H", "Organ", "Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R", "Male", "Men", "Female", "Women", "Choir", "BGV", "Dynamic Mic", "Condenser Mic", "Instrument Mic", "Wireless Mic", "Headset", "DPA Headset", "Speech Mic", "Podium", "Podium BU", "FOH", "Speaker", "Subwoofer", "Wedge", "Video", "In-Ear", "Monitor", "Effector", "Media 1", "Media 2", "Media 3", "Mixer", "PC", "QLab", "ClickFX", "Processor", "Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R", "Arrow Left", "Arrow Right", "Exclamation", "Smile", "Money", "Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4", "Star 2", "Blank"}
				
				if IconColumn is not false and text item IconColumn of theRow is not "" then
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", (text item IconColumn of theRow as string)}
					set the pre wait of theCue to 0.01
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
					--Even if there isn't an icon in an icon column, see if the source is named with an icon
				else if iconWordsList contains text item SourceColumn of theRow then
					if {"Kick", "Kick in", "Kick Out"} contains text item SourceColumn of theRow then
						set theIcon to "Kick"
					else if {"Snare Top", "Snare Btm", "Snare Bottom"} contains text item SourceColumn of theRow then
						set theIcon to "Snare"
					else if {"Hi-Hat", "HiHat", "HH"} contains text item SourceColumn of theRow then
						set theIcon to "Hi-Hat"
					else if {"Tom", "Tom1", "Tom 1", "Tom2", "Tom 2", "Rack Tom", "Rack"} contains text item SourceColumn of theRow then
						set theIcon to "Tom Tom"
					else if {"Floor Tom", "Floor", "Tom3", "Tom 3"} contains text item SourceColumn of theRow then
						set theIcon to "Floor Tom"
					else if {"Cymbal", "Crash", "Ride"} contains text item SourceColumn of theRow then
						set theIcon to "Cymbal"
					else if {"Drum Kit", "OH", "OH L", "OH R"} contains text item SourceColumn of theRow then
						set theIcon to "Drum Kit"
					else if {"Percussion"} contains text item SourceColumn of theRow then
						set theIcon to "Percussion"
					else if {"Strings", "Violin", "Fiddle", "Viola", "Mandolin"} contains text item SourceColumn of theRow then
						set theIcon to "Strings"
					else if {"Trumpet", "Trump"} contains text item SourceColumn of theRow then
						set theIcon to "Trumpet"
					else if {"Trombone", "Bone"} contains text item SourceColumn of theRow then
						set theIcon to "Trombone"
					else if {"Saxophone", "Sax", "Alto Sax", "Tenor Sax", "Bari Sax", "Bari"} contains text item SourceColumn of theRow then
						set theIcon to "Saxophone"
					else if {"Flute", "Piccolo", "Clarinet", "Oboe", "Bassoon", "Woodwind"} contains text item SourceColumn of theRow then
						set theIcon to "Flute"
					else if {"Piano", "Piano L", "Piano H"} contains text item SourceColumn of theRow then
						set theIcon to "Piano"
					else if {"Organ"} contains text item SourceColumn of theRow then
						set theIcon to "Organ"
					else if {"Keyboard", "Keys", "KeysL", "Keys L", "KeysR", "Keys R"} contains text item SourceColumn of theRow then
						set theIcon to "Keyboard"
					else if {"Male", "Men"} contains text item SourceColumn of theRow then
						set theIcon to "Male"
					else if {"Female", "Women"} contains text item SourceColumn of theRow then
						set theIcon to "Female"
					else if {"Choir", "BGV"} contains text item SourceColumn of theRow then
						set theIcon to "Choir"
					else if {"Headset", "DPA Headset"} contains text item SourceColumn of theRow then
						set theIcon to "Headset"
					else if {"Speech Mic", "Podium", "Podium BU"} contains text item SourceColumn of theRow then
						set theIcon to "Speech Mic"
					else if {"PC", "QLab", "ClickFX"} contains text item SourceColumn of theRow then
						set theIcon to "PC"
					else if {"Audience", "Crowd", "CrowdL", "Crowd L", "CrowdR", "Crowd R"} contains text item SourceColumn of theRow then
						set theIcon to "Audience"
					else if {"Star 1", "Solo", "Solo1", "Solo 1", "Solo2", "Solo 2", "Solo3", "Solo 3", "Solo4", "Solo 4"} contains text item SourceColumn of theRow then
						set theIcon to "Star 1"
					end if
					make type "network"
					set theCue to last item of (selected as list)
					set the network patch name of theCue to networkPatchName
					set the parameter values of theCue to {"Matrix Bus", (text item RivageChannelColumn of theRow as integer as string), "Label", "Icon", theIcon}
					set the pre wait of theCue to 1.0E-3
					set the continue mode of theCue to auto_follow
					set the q number of theCue to ""
					set newQID to uniqueID of theCue
					move cue id newQID of parent of theCue to end of GroupQ
				end if
				
				
				
			end if -- If the source column for that row is not blank
		end repeat
		start GroupQ
		
	end if -- end if the csv file comes straight from the I/O sheet
end tell
set AppleScript's text item delimiters to thetids


--Rivage Icon List
--"Kick","Snare","Hi-Hat","Tom Tom","Floor Tom","Cymbal","Drum Kit","Percussion","Mallets","E. Bass","A. Guitar","E. Guitar","Bass Amp","Guitar Amp","A. Bass","Direct Box","Strings","Trumpet","Trombone","Saxophone","Flute","Piano","Organ","Keyboard","Male","Female","Choir","Dynamic Mic","Condenser Mic","Instrument Mic","Wireless Mic","Headset","Speech Mic","FOH","Speaker","Subwoofer","Wedge","Video","In-Ear","Monitor","Effector","Media 1","Media 2","Media 3","Mixer","PC","Processor","Audience","Arrow Left","Arrow Right","Exclamation","Smile","Money","Star 1","Star 2","Blank"
--Rivage Color List
--"Blue","Orange","Yellow","Purple","Sky blue","Pink","Green","Light green","White","Off"
