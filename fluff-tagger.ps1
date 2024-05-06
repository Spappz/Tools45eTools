# 5eTools Fluff Tagger
# =============================
#
# On some list pages, you will find the "Has Info" and "Has Images" filters under the Miscellaneous category. A
# statblock satisfies this filter if it either has the appropriate object in its `fluff` object, or if it has the
# `hasFluff` or `hasFluffImages` properties respectively. For statblocks with a referenced `_<datatype>Fluff`
# object in its fluff, this necessitates the last two properties (as appropriate).
#
# This script looks through a JSON file, or recursively scans a directory for JSON files, and then inspects each
# statblock. If that statblock has a `_<datatype>Fluff` object referencing some fluff *in the same file*, this
# script will add the `hasFluff` and `hasFluffImages` properties as appropriate to the statblock. The script can
# handle nested `_copy` references, as long as those references stay within the same file.
#
# Note: this script doesn't handle 'shared-fluff' datatypes. For instance, `subrace`s will not be tagged, nor will
# `baseitem`s. You can inspect the exact list of datatypes that are tagged yourself (see the `$fluffyDatatypes`
# array below), but, in general, the script will only operate on content properties named "<datatype>" which have
# a corresponding fluff property named "<datatype>Fluff".
#
# Note: this script exports JSON in a compressed (one-line) format. I recommend you run a prettifier (such as the
# homebrew repo's `npm run build:clean`) afterwards.
#
# Note: this script requires PowerShell 6 or higher. Windows 10 only has PowerShell 5 installed by default.
#
#
# Usage:
#   & <path to script> -Path <path to homebrew file/directory> [-Log <level>]
#
# Parameters:
#  -Path (string; required): absolute or relative path to a file or directory
#  -Log (string; default "Changes"): determines the logging level of the script.. "None" suppresses all logs;
#     "Errors" only logs errors; "Changes" logs errors and files that have been changed; "Skips" logs errors and
#     files which have *not* been changed; "All" displays all logs.
#
# Examples:
#   & .\fluff-tagger.ps1 -Path '.\homebrew'
#   & .\fluff-tagger.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json' -Log Changes
#   & .\fluff-tagger.ps1 -Path '.\homebrew' -Log All
#
#
# Spappz 2024
#
# MIT License

PARAM (
	[Parameter(Mandatory, ValueFromPipeline, Position = 0)]
	[String]$Path,

	[Parameter()]
	[ValidateScript(
		{ @('None', 'Errors', 'Changes', 'Skips', 'All') -match $_ },
		ErrorMessage = "Cannot bind parameter 'Log' due to enumeration values that are not valid. Select one of the following enumeration values and try again. The possible enumeration values are ""None"", ""Errors"", ""Changes"", ""Skips"", ""All""."
	)]
	[String]$Log = 'Changes'
)

$Log = $Log.toLower()

$fluffyDatatypes = @(
	'background'
	'charoption'
	'class'
	'condition'
	'disease'
	'feat'
	'hazard'
	'item'
	'language'
	'monster'
	'object'
	'optionalfeature'
	'race'
	'recipe'
	'reward'
	'spell'
	'subclass'
	'trap'
	'vehicle'
)

function Test-Fluff {
	PARAM (
		[Parameter(Mandatory, ValueFromPipeline, Position = 0)]
		[PSCustomObject]$InputObject,

		[Parameter(Mandatory)]
		[String]$DataType,

		[Parameter(Mandatory)]
		[String]$For
	)

	if ($InputObject.$For) {
		Write-Output $true
	} elseif (
		$InputObject._copy -and
		-not (
			$InputObject.PSObject.Properties.Name -contains $For -and
			-not $InputObject.$For
		) -and
		$InputObject._copy._mod.$For -ne 'remove'
	) {
		if (
			$InputObject._copy._mod.$For.mode -in @(
				'appendArr'
				'prependArr'
				'replaceArr'
				'insertArr'
				'replaceOrAppendArr'
				'appendIfNotExistsArr'
			)
		) {
			Write-Output $true
		} elseif ($InputObject._copy.source -in $brew._meta.sources.json) {
			$datatypeFluff = $DataType + 'Fluff'
			Write-Output (Test-Fluff $brew.$datatypeFluff[$brew.$datatypeFluff.name.indexOf($InputObject._copy.name)] -DataType $DataType -For $For)
		} else {
			Write-Output $false
		}
	} else {
		Write-Output $false
	}
}

if ((Test-Path $Path)) {
	$target = Get-Item $Path
	if ($target.Extension -eq '.json') {
		try {
			$brew = Get-Content $target -Encoding Utf8 | ConvertFrom-Json
		} catch {
			if ($Log -ne 'none') {
				Write-Host '  ' -NoNewline
				Write-Warning ('Invalid JSON in ' + $target)
			}
		}

		$appliedTags = [System.Collections.Generic.List[String]]::new()
		foreach ($datatype in $fluffyDatatypes) {
			$datatypeFluff = $datatype + 'Fluff'
			$_datatypeFluff = '_' + $datatype + 'Fluff'
			if ($brew.$datatype -and $brew.$datatypeFluff) {
				$brew.$datatype = @(
					$brew.$datatype | ForEach-Object {
						if ($_.fluff.$_datatypeFluff -and $_.fluff.$_datatypeFluff.source -in $brew._meta.sources.json) {
							$fluff = $brew.$datatypeFluff[$brew.$datatypeFluff.name.indexOf($_.fluff.$_datatypeFluff.name)]

							if (-not $_.hasFluff -and (Test-Fluff $fluff -DataType $datatype -For entries)) {
								$_ | Add-Member -MemberType NoteProperty -Name hasFluff -Value $true
								$appliedTags.Add($datatype)
							}

							if (-not $_.hasFluffImages -and (Test-Fluff $fluff -DataType $datatype -For images)) {
								$_ | Add-Member -MemberType NoteProperty -Name hasFluffImages -Value $true
								$appliedTags.Add($datatype)
							}
						}
						Write-Output $_
					}
				)
			}
		}

		if ($appliedtags.Count) {
			ConvertTo-Json $brew -Depth 99 | Out-File -FilePath $target -Encoding Utf8
			if ($Log -eq 'changes') {
				Write-Host ('  Tagged: ' + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
			} elseif ($Log -eq 'all') {
				Write-Host ('  Tagged: ' + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
				Write-Host ('      ' + ($appliedtags | Select-Object -Unique | Join-String -Separator ', '))
			}
		} elseif ($Log -in @('skips', 'all')) {
			Write-Host ('  Left unchanged: ' + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
		}

	} elseif ($target.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
		$baseFiles = Get-ChildItem $target -File
		$i = $baseFiles.Name.IndexOf('.gitignore')
		if ($i -ne -1) {
			$gitignore = Get-Content $baseFiles[$i] -Encoding utf8 |
				Where-Object { $_ -and $_ -notmatch '^#' } |
				ForEach-Object {
					# Escape .
					# Convert * to any character
					# Convert ? to any single character
					# dir/ matches sub-paths
					# /xyz matches only within root
					# [!...] becomes [^...]
					# Make path-separators neutral
					$_ -replace '\.', '\.' `
						-replace '\*', '.*' `
						-replace '\?', '.' `
						-replace '/$', '/.+' `
						-replace '^/', [Regex]::Escape($target) `
						-replace '\[!([^]]+)\]', '[^$1]' `
						-replace '/', '[/|\\]'
				}
			$gitignore += 'package\.json$'
			$gitignore += 'package-lock\.json$'
			Get-ChildItem $target -Recurse -File |
				Where-Object { $_.Extension -eq '.json' -and -not (Select-String -Quiet -Pattern $gitignore -InputObject $_.FullName) } |
				ForEach-Object { . $PSCommandPath -Path $_ -Log $Log }
		} else {
			Get-ChildItem $target -Recurse -File |
				Where-Object { $_.Extension -eq '.json' } |
				ForEach-Object { . $PSCommandPath -Path $_ -Log $Log }
		}
	} elseif ($Log -ne 'none') {
		Write-Error "$target is not a ``.json``"
	}
} elseif ($Log -ne 'none') {
	Write-Error 'File/directory not found'
}
