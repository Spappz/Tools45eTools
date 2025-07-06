# 5eTools Homebrew Splitter
# =========================
#
# This script splits out each and every content-entity in a combined 5eTools homebrew file into a unique file. A
# subdirectory for each data-type is created, and the single-entity files are sorted into those subdirectories.
#
# For instance, if a homebrew file contains 2 monsters, 3 spells, and a language, then the resulting file
# structure would look like:
#   <destination>
#   ├───language
#   │   └───<language one>.json
#   ├───monster
#   │   ├───<monster one>.json
#   │   └───<monster two>.json
#   └───spell
#       ├───<spell one>.json
#       ├───<spell two>.json
#       └───<spell three>.json
#
# The `_meta` object is included in each file so that any given file is verifiable using the schema. You can use
# `homebrew-merger.ps1` to recombine the files.
#
# Usage:
#   & <path to script> [-Path] <path to input file> [[-Destination] <path to output directory>]
#
# Parameters:
#   -Path (string; required): absolute or relative path to a file
#   -Destination (string; optional): absolute or relative path to a directory.
#      By default, the destination directory is placed in the current working directory, and named as per the
#      input filename.
#
# Examples:
#   & .\homebrew-splitter.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json'
#   & .\homebrew-splitter.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json' -Destination 'brew'
#
#
# Spappz 2025
#
# MIT License



param (
	# A path to a file or directory of files to test
	[Parameter(Mandatory, Position = 0, ValueFromPipeline)]
	[String]$Path,
	
	# A path to a file or directory of files to test
	[Parameter(Position = 1)]
	[String]$Destination
)

if (-not (Test-Path $Path)) {
	throw 'Path does not exist.'
}

if (-not $Destination) {
	$Destination = (Split-Path $Path -Leaf) -replace '\.json$'
}

if ((Test-Path $Destination)) {
	throw 'Destination already exists.'
}
if ($Destination -notmatch '\w') {
	throw 'Destination is invalid.'
}
if (($Destination | Split-Path | Test-Path)) {
	throw "Destination's parent cannot be found."
}

$brew = Get-Content $Path -Encoding utf8 | ConvertFrom-Json
if ($brew -isnot [PSCustomObject] -or -not $brew._meta) {
	throw 'Invalid 5eTools JSON.'
}

$null = New-Item $Destination -ItemType Directory

$brew.PSObject.Properties
| Where-Object { $_.Name -ne '_meta' -and $_.Name -notmatch 'schema$' }
| ForEach-Object {
	$subdir = "$Destination/$($_.Name)"
	$null = New-Item $subdir -ItemType Directory
	foreach ($entity in $_.Value) {
		$obj = [PSCustomObject]@{
			_meta      = $brew._meta
			$($_.Name) = @($entity)
		}
		$obj
		| ConvertTo-Json -Depth 99
		| Out-File -FilePath "$subdir/$($entity.name -replace '[<>:"/\\|?*]', '_').json" -Encoding utf8
	}
}
