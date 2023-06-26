# 5eTools Creature Fluff Tagger
# =============================
#
# On the bestiary page, you will find the "Has Info" and "Has Images" filters under the Miscellaneous category. A
# creature satisfies this filter if it either has the appropriate object in its `fluff` object, or if it has the
# `hasFluff` or `hasFluffImages` properties respectively. For creatures with a referenced `_monsterFluff` object in
# its fluff, this necessitates the last two properties (as appropriate).
#
# This script looks through a JSON file, or recursively scans a directory for JSON files, and then inspects each
# creature. If that creature has a `_monsterFluff` object referencing some fluff *in the same file*, this script
# will add the `hasFluff` and `hasFluffImages` properties as appropriate to the creature. The script can handle
# nested `_copy` references, as long as those references stay within the same file.
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
#   & .\creature-fluff-tagger.ps1 -Path '.\homebrew'
#   & .\creature-fluff-tagger.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json' -Log Changes
#   & .\creature-fluff-tagger.ps1 -Path '.\homebrew' -Log All
#
#
# Spappz 2023
#
# MIT License

PARAM (
	[Parameter(Mandatory, ValueFromPipeline, Position = 0)]
	[String]$Path,

	[Parameter()]
	[ValidateScript(
		{ @("None", "Errors", "Changes", "Skips", "All") -match $_ },
		ErrorMessage = "Cannot bind parameter 'Log' due to enumeration values that are not valid. Select one of the following enumeration values and try again. The possible enumeration values are ""None"", ""Errors"", ""Changes"", ""Skips"", ""All""."
	)]
	[String]$Log = "Changes"
)

$Log = $Log.toLower()

function Test-Fluff {
	PARAM (
		[Parameter(Mandatory, ValueFromPipeline, Position = 0)]
		[PSCustomObject]$InputObject,

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
		$InputObject._copy._mod.$For -ne "remove"
	) {
		if (
			$InputObject._copy._mod.$For.mode -in @(
				"appendArr"
				"prependArr"
				"replaceArr"
				"insertArr"
				"replaceOrAppendArr"
				"appendIfNotExistsArr"
			)
		) {
			Write-Output $true
		} elseif ($InputObject._copy.source -in $brew._meta.sources.json) {
			Write-Output (Test-Fluff $brew.monsterFluff[$brew.monsterFluff.name.indexOf($InputObject._copy.name)] -For $For)
		} else {
			Write-Output $false
		}
	} else {
		Write-Output $false
	}
}

if ((Test-Path $Path)) {
	$target = Get-Item $Path
	if ($target.Extension -eq ".json") {
		try {
			$brew = Get-Content $target -Encoding Utf8 | ConvertFrom-Json
		} catch {
			if ($Log -ne "none") {
				Write-Host "  " -NoNewLine
				Write-Warning ("Invalid JSON in " + $target)
			}
		}
		if ($brew.monsterFluff) {
			$tagsApplied = $false
			$brew.monster = @(
				$brew.monster | ForEach-Object {
					if ($_.fluff._monsterFluff -and $_.fluff._monsterFluff.source -in $brew._meta.sources.json) {
						$fluff = $brew.monsterFluff[$brew.monsterFluff.name.indexOf($_.fluff._monsterFluff.name)]

						if (-not $_.hasFluff -and (Test-Fluff $fluff -For entries)) {
							$_ | Add-Member -MemberType NoteProperty -Name hasFluff -Value $true
							$tagsApplied = $true
						}

						if (-not $_.hasFluffImages -and (Test-Fluff $fluff -For images)) {
							$_ | Add-Member -MemberType NoteProperty -Name hasFluffImages -Value $true
							$tagsApplied = $true
						}
					}
					Write-Output $_
				}
			)

			if ($tagsApplied) {
				if ($Log -in @("changes", "all")) {
					Write-Host ("  Tagged " + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
				}
				ConvertTo-Json $brew -Depth 99 | Out-File -FilePath $target -Encoding Utf8
			} elseif ($Log -in @("skips", "all")) {
				Write-Host ("  Left unchanged " + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
			}
		} elseif ($Log -in @("skips", "all")) {
			Write-Host ("  Left unchanged " + ($target -replace '^.*[\\/]([^\\/]+[\\/][^\\/]+)$', '$1'))
		}
	} elseif ($target.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
		Get-ChildItem $target -Recurse -File |
			Where-Object { $_.Extension -eq '.json' } |
			ForEach-Object { . $PSCommandPath -Path $_ -Log $Log }
	} elseif ($Log -ne "none") {
		Write-Error "$target is not a ``.json``"
	}
} elseif ($Log -ne "none") {
	Write-Error "File/directory not found"
}