#Written by Robert Paul Smith, mostly on 2015-09-24 to 2015-09-27 building on the shoulders of many great people who have graciously written about similar powershell techniques on the Internet.
#Usage: import the function (use ". c:/path/to/ReplaceStringInFileOrFolderNamesAndContents.ps1") and call the function ReplaceStringInFileOrFolderNamesAndContents
#If you call the function without any parameters and it will interactively prompt for all of the values required.
#SYNTAX: scriptname.ps1 -oldString foo -newString bar -path A:\Folder\Name -updateFileContents yes -updateFileNames yes -updateFolderNames yes
#Note 1: use any string instead of 'yes' if you want to turn off the update operations. (at least until these parts get refactored as switch parameters.)
#Note 2: refactor the '-like "*$oldString*"' parts of the script with -match if you want to use regex.
#Note 3: refactor the $excludeExtensions and $includeExtensions variables to accept dialog box or parameter input instead of the hard coded values found below.
function ReplaceStringInFileOrFolderNamesAndContents {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]
		[string[]]$oldString,
		
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
		[string[]]$newString,
		
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
		[string[]]$path,
		
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
		[string[]]$updateFileContents,
		
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
		[string[]]$updateFileNames,
		
		[parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
		[string[]]$updateFolderNames	
	)
	Set-StrictMode -Version Latest
	$ErrorActionPreference = "Stop"
	$scriptDir = Split-Path -LiteralPath $(if ($PSVersionTable.PSVersion.Major -ge 3) { $PSCommandPath } else { & { $MyInvocation.ScriptName } })
	$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	try {
	#set variable for toggle updateFileContents
	if (!$PSBoundParameters.ContainsKey('updateFileContents')) {
		$a = new-object -comobject wscript.shell 
		$intAnswer = $a.popup("Do you want replace the string in file contents?", 0,"Yes",3)
		If ($intAnswer -eq 6) { $updateFileContents = 'yes' } elseif ($intAnswer -eq 7) { $updateFileContents = 0 } else { throw 'You canceled the script.' }
	}
	#set variable for toggle updateFileNames
	if (!$PSBoundParameters.ContainsKey('updateFileNames')) {
		$b = new-object -comobject wscript.shell 
		$intAnswer = $b.popup("Do you want replace the string in file names?", 0,"Yes",3)
		If ($intAnswer -eq 6) { $updateFileNames = 'yes' } elseif ($intAnswer -eq 7) { $updateFileNames = 0 } else { throw 'You canceled the script.' }
	}
	#set variable for toggle updateFolderNames
	if (!$PSBoundParameters.ContainsKey('updateFolderNames')) {
		$c = new-object -comobject wscript.shell 
		$intAnswer = $c.popup("Do you want replace the string in folder names?", 0,"Yes",3)
		If ($intAnswer -eq 6) { $updateFolderNames = 'yes' } elseif ($intAnswer -eq 7) { $updateFolderNames = 0 } else { throw 'You canceled the script.' }
	}
	function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText) {
		Add-Type -AssemblyName Microsoft.VisualBasic
		return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText) }
	#set variable for oldString
	if (!$PSBoundParameters.ContainsKey('oldString')) {	$oldString = Read-InputBoxDialog -Message "What is the old string you want to change?" -WindowTitle "Old string to replace:" -DefaultText "someOldString" }
	Write-Host "Old Text:" $oldString
	#set variable for newString
	if (!$PSBoundParameters.ContainsKey('newString')) { $newString = Read-InputBoxDialog -Message "What is the new string you want to replace all instances of $oldString ?" -WindowTitle "New string to replace:" -DefaultText "someNewString"	}
	Write-Host "New Text:" $newString
	#set variable for path to folder with child items we want to rename
	if (!$PSBoundParameters.ContainsKey('path')) {
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
		$OpenFolderDialog = New-Object Windows.Forms.FolderBrowserDialog
		$OpenFolderDialog.RootFolder = [System.Environment+SpecialFolder]'MyComputer'
		$OpenFolderDialog.ShowNewFolderButton = $false
		$OpenFolderDialog.Description = "Select the folder that contains the files you want to recursively replace strings in."
		$OpenFolderDialog.ShowDialog() | Out-Null
		if ($OpenFolderDialog.SelectedPath -eq "" -Or $OpenFolderDialog.SelectedPath -eq $null) { Throw 'You did not select a valid path, or you clicked cancel.' }
		if ( (Test-Path $OpenFolderDialog.SelectedPath -pathType container) -eq $false ) { Throw 'This folder path does not pass Test-Path. Are you sure you have access and the path is correct?' }
		$path = $OpenFolderDialog.SelectedPath
		$OpenFolderDialog.Dispose()
	}
	#check if we have a real real path to operate on
	if ( (Test-Path $path -pathType container) -eq $false ) { Throw 'This location does not exist according to Test-Path. Are you sure you have access and the path is correct?' }
	#set $includeExtensions to *.* to operate on all files with an extension, or to a specific list of file extensions to operate on a whitelist of file extensions
	$includeExtensions = @("*.*")
	#set $excludeExtensions to binary file extensions (refactor *cough*cough*)
	$excludeExtensions = @("*.exe, *.dll, *.pdb, *.dbmdl, *.msi, *.iso, *.bin, *.bak, *.raw, *.dat, *.vhd*, *.mdf, *.ldf, *.doc*, *.xls*, *.zip, *.msg, *.png, *.dwg, *.jpg, *.jpeg, *.bmp, *.gif, *.ico, *.mp3, *.mp4, *.avi, *.pdf*")
		Get-ChildItem $path -Recurse -Include $includeExtensions -Exclude $excludeExtensions | ForEach-Object { $_.FullName } | Sort-Object -Property Length -Descending | ForEach-Object { ForEach-Object {
				Write-Host $_
				$Item = Get-Item $_
				$PathRoot = $Item.FullName | Split-Path
				$OldName = $Item.FullName | Split-Path -Leaf
				$NewName = $OldName -replace $oldString, $newString
				$NewPath = $PathRoot | Join-Path -ChildPath $NewName
				#replace string in file contents
				if ($updateFileContents -eq 'yes' -and !$Item.PsIsContainer) { (Get-Content $Item -Raw) | ForEach-Object {	if ($_ -like "*$oldString*") { 	$_ -replace $oldString, $newString	} } | Set-Content $Item	}
				#replace string in file names
				if ($updateFileNames -eq 'yes' -and !$Item.PsIsContainer) { if ($OldName -like "*$oldString*") { Rename-Item -Path $Item.FullName -NewName $NewPath } }
				#replace string in folder names
				if ($updateFolderNames -eq 'yes' -and $Item.PsIsContainer) { if ($OldName -like "*$oldString*") { Rename-Item -Path $Item.FullName -NewName $NewPath } }
			}
		}
	}
	finally { Write-Output "Done! $($stopwatch.Elapsed)" }
}