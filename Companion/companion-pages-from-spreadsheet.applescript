-- Name:        Companion Pages from Spreadsheet
-- Description: Makes a batch of Bitfocus Companion pages from one template page and a
--              spreadsheet. Each spreadsheet row becomes its own page file, with the
--              placeholder text in the template replaced by that row's values.
-- Works with:  Bitfocus Companion page exports (.companionconfig), CSV or TSV spreadsheets
-- How to use:  1. In Companion, build one template page. Anywhere something should change
--                 from page to page, type a placeholder instead, e.g. {{MIC_NAME}}.
--                 Export the page.
--              2. Make a spreadsheet laid out like this, and export it as TSV (or CSV):
--                   Row 1:    titles for you to read (the script ignores this row)
--                   Row 2:    column A is ignored; columns B onward are the placeholders
--                   Row 3 on: column A is the file name for that page; columns B onward
--                             are the values that replace the placeholders above them
--              3. Run the script. Choose the spreadsheet, then the template page export.
--              4. Import the new .companionconfig files into Companion.
-- Notes:       - New pages are saved in the same folder as the template. They replace older
--                files with the same name, but never the template itself.
--              - Rows with no file name in column A are skipped.
--              - TSV is safer than CSV: in a CSV, a cell with a comma in it splits in two.
--              - Use placeholders that don't contain each other. With MIC1 and MIC10,
--                replacing MIC1 also changes part of MIC10. Wrapping them, like {{MIC1}}
--                and {{MIC10}}, avoids this.
-- Author:      Taylor Glad

-- ============================================================
-- SETTINGS (change these to fit your show)
-- ============================================================

--the spreadsheet row that holds the placeholders
set placeholderRow to 2

--the first spreadsheet row that becomes a page (every row after it does too)
set firstPageRow to 3

-- ============================================================
-- SCRIPT
-- ============================================================

-- ------------------------------------------------------------
-- 1. Choose the files and read them
-- ------------------------------------------------------------

set theSheetFile to choose file of type {"tsv", "csv"} with prompt "Select tsv or csv file:"
set thePageFile to choose file of type {"companionconfig"} with prompt "Select Companion page export:"

--read the files as UTF-8, so accented letters, symbols, and emoji come through correctly
--(some spreadsheet apps don't save as UTF-8, so if that fails, read it the old way)
try
	set theSheetContents to read theSheetFile as «class utf8»
on error
	set theSheetContents to read theSheetFile
end try --reading the spreadsheet
set thePageContents to read thePageFile as «class utf8»

--get the folder the template is in (the new pages get saved there), and the spreadsheet's file type
tell application "System Events"
	set outputFolder to POSIX path of (container of disk item (POSIX path of thePageFile))
	set sheetType to name extension of disk item (POSIX path of theSheetFile)
end tell --System Events

-- ------------------------------------------------------------
-- 2. Split the spreadsheet into rows and cells
--    "Text item delimiters" is how AppleScript splits text apart and joins it back together.
--    Save the original setting so it can be put back at the end.
-- ------------------------------------------------------------

set originalDelimiters to AppleScript's text item delimiters

--CSV cells are split by commas, TSV cells by tabs
if sheetType is "csv" then
	set sheetDelimiter to ","
else
	set sheetDelimiter to tab
end if --CSV or TSV

set sheetRows to paragraphs of theSheetContents
set AppleScript's text item delimiters to sheetDelimiter
set placeholders to text items of (item placeholderRow of sheetRows)

-- ------------------------------------------------------------
-- 3. Make a page for each row
-- ------------------------------------------------------------

set pagesMade to 0
set skippedRows to {} --notes about rows that were skipped, to show at the end

repeat with rowNumber from firstPageRow to (count of sheetRows)
	set AppleScript's text item delimiters to sheetDelimiter
	set rowValues to text items of (item rowNumber of sheetRows)

	--check whether the row has anything in it at all
	--(a completely blank line has no cells, so this has to come before reading column A)
	set rowIsEmpty to true
	repeat with eachValue in rowValues
		if contents of eachValue is not "" then
			set rowIsEmpty to false
			exit repeat
		end if --if this cell has something in it
	end repeat --each cell in the row

	if rowIsEmpty then
		--skip empty rows quietly (spreadsheet exports often end with one)

	else if item 1 of rowValues is "" then
		set end of skippedRows to "Row " & rowNumber & ": no file name in column A"

	else
		set pageName to item 1 of rowValues

		--replace characters that aren't allowed in file names (/ and :) with -
		set AppleScript's text item delimiters to {"/", ":"}
		set nameParts to text items of pageName
		set AppleScript's text item delimiters to "-"
		set safeName to nameParts as text
		set outputPath to outputFolder & "/" & safeName & ".companionconfig"

		if outputPath is (POSIX path of thePageFile) then
			--never overwrite the template
			set end of skippedRows to "Row " & rowNumber & ": same name as the template"

		else
			-- ------------------------------------------------------------
			-- 3a. Find and replace each placeholder with this row's value
			-- ------------------------------------------------------------

			set newPageContents to thePageContents

			repeat with columnNumber from 2 to (count of placeholders)
				set placeholder to item columnNumber of placeholders

				--skip columns with no placeholder (finding "" would put the value between every single character)
				if placeholder is not "" then

					--if the row is missing cells at the end, treat them as blank
					if columnNumber ≤ (count of rowValues) then
						set newValue to item columnNumber of rowValues
					else
						set newValue to ""
					end if --if the row has a cell in this column

					--a " in the value would break the page file, so write it as \" (the way the file stores quotes)
					set AppleScript's text item delimiters to quote
					set valueParts to text items of newValue
					set AppleScript's text item delimiters to "\\\""
					set newValue to valueParts as text

					--find and replace: split the page apart at the placeholder, then join it back together with the new value
					set AppleScript's text item delimiters to placeholder
					set pageParts to text items of newPageContents
					set AppleScript's text item delimiters to newValue
					set newPageContents to pageParts as text

				end if --if the column has a placeholder
			end repeat --each column

			-- ------------------------------------------------------------
			-- 3b. Save the new page file
			--     (creates the file, or empties and replaces an older one with the same name)
			-- ------------------------------------------------------------

			set openFile to open for access (POSIX file outputPath) with write permission
			try
				set eof of openFile to 0
				write newPageContents to openFile as «class utf8»
				close access openFile
			on error errorMessage
				--always close the file, even if writing failed, then stop and show what went wrong
				close access openFile
				set AppleScript's text item delimiters to originalDelimiters
				display dialog ("Couldn't save " & safeName & ".companionconfig:" & return & errorMessage) with icon 2 buttons {"OK"} default button "OK"
				return
			end try --writing the file

			set pagesMade to pagesMade + 1

		end if --if the name matches the template
	end if --if the row is empty, has no name, or is a page
end repeat --each row

-- ------------------------------------------------------------
-- 4. Report what happened
-- ------------------------------------------------------------

set reportText to "Made " & pagesMade & " Companion page file(s) in:" & return & outputFolder
if skippedRows is not {} then
	set AppleScript's text item delimiters to return
	set reportText to reportText & return & return & "Skipped:" & return & (skippedRows as text)
end if --if any rows were skipped

--put the text item delimiters back the way they were
set AppleScript's text item delimiters to originalDelimiters

display dialog reportText buttons {"Show in Finder", "OK"} default button "OK"
if button returned of result is "Show in Finder" then
	do shell script "open " & quoted form of outputFolder
end if --if Show in Finder was clicked
