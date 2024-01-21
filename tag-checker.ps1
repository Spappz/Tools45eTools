# 5eTools Tag Checker
# ===================
#
# This script will scan your file, or every JSON file in a directory recursively, for `@tag`s. If any found `@tag`
# does not match against its list of known 5eTools tags, it will compile an error object for manual correction.
# Note that, although you can use the `-LogErrors` switch to be informed of errors as they're found, the script
# doesn't actually return anything until all files have been tested.
#
# To write the errors to a file, you should first convert the output to JSON (see examples below).
#
#
# Usage:
#   & <path to script> [-Path] <path to file/directory> [-LogErrors]
#
# Parameters:
#  -Path (string; required): absolute or relative path to a file or directory
#  -LogErrors (switch): outputs error-containing files to the console early
#
# Examples:
#   & .\tag-checker.ps1 -Path '.\homebrew'
#   & .\tag-checker.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json'
#   & .\tag-checker.ps1 -Path '.\homebrew' -LogErrors
#   & .\tag-checker.ps1 -Path '.\homebrew' | ConvertTo-Json | Out-File '.\badFiles.json' -Encoding utf8
#
#
# Spappz 2023
#
# MIT License

PARAM (
	# A path to a file or directory of files to test
	[Parameter(Mandatory, Position = 0)]
	[String]$Path,

	# Log erroneous files to the console early (useful if testing a large directory)
	[switch]$LogErrors
)

$keywords = @(
	'b'
	'bold'
	'i'
	'italic'
	's'
	'strike'
	'u'
	'underline'
	'sup'
	'sub'
	'kbd'
	'code'
	'style'
	'font'
	'comic'
	'comicH1'
	'comicH2'
	'comicH3'
	'comicH4'
	'comicNote'
	'note'
	'unit'
	'h'
	'm'
	'atk'
	'hitYourSpellAttack'
	'dc'
	'dcYourSpellSave'
	'chance'
	'd20'
	'damage'
	'dice'
	'autodice'
	'hit'
	'recharge'
	'ability'
	'savingThrow'
	'skillCheck'
	'scaledice'
	'scaledamage'
	'coinflip'
	'5etools'
	'adventure'
	'book'
	'filter'
	'footnote'
	'link'
	'loader'
	'color'
	'highlight'
	'help'
	'quickref'
	'area'
	'action'
	'background'
	'boon'
	'charoption'
	'class'
	'condition'
	'creature'
	'cult'
	'deck'
	'disease'
	'feat'
	'hazard'
	'item'
	'itemMastery'
	'language'
	'legroup'
	'object'
	'optfeature'
	'psionic'
	'race'
	'recipe'
	'reward'
	'vehicle'
	'vehupgrade'
	'sense'
	'skill'
	'spell'
	'status'
	'table'
	'trap'
	'variantrule'
	'card'
	'deity'
	'classFeature'
	'subclassFeature'
	'homebrew'
	'itemEntry'
	'cite'
)

$target = Get-Item (Resolve-Path $Path -ErrorAction Stop)
switch ($target.Attributes) {
	Archive {
		$files = @($target)
		break
	}
	Directory {
		$files = @(Get-ChildItem $target -File -Recurse | Where-Object { $_.Extension -eq '.json' })
		if (-not $files.Count) {
			throw "No JSON files found in $($target.FullName)"
			exit 1
		}
		break
	}
	Default {
		throw "Not a file or directory: $($target.FullName)"
		exit 1
	}
}

$fileCount = $files.Count
$errors = [System.Collections.Generic.List[psobject]]::new()
for ($i = 0; $i -lt $fileCount; $i++) {
	Write-Progress -Activity 'Checking files...' -Id 1 -Status $files[$i].FullName -PercentComplete (100 * ($i / $fileCount))
	$tags = [regex]::Matches((Get-Content $files[$i] -Encoding utf8NoBOM), '\{@(?<tag>[^|}\s]+)\b')
	$badTags = $tags.groups.Where({ $_.Name -eq 'tag' -and $_.Value -cnotin $keywords })
	if ($badTags.Count) {
		$errorLog = [PSCustomObject]@{
			path    = $files[$i].FullName
			badTags = @($badTags.Value | Select-Object -Unique)
		}
		if ($LogErrors) {
			if (-not $errors.Count) {
				Write-Warning 'Bad tags found in:'
			}
			Write-Host ("`t" + $errorLog.path)
		}
		$errors.Add($errorLog)
	}
}

if ($LogErrors -and -not $errors.Count) {
	Write-Host 'No errors found.'
}

return $errors
