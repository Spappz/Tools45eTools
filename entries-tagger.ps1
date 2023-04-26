# 5eTools Entries Tagger
# ======================
#
# A hastily spun-out auto-tagger for `entries`-like strings. This script recursively traverses through a given
# JSON file, looking for any property named `entries`, `entry`, or `items`. If it finds any of these properties,
# it applies the `Tag-Entry` function below onto it, which is itself just a huge bundle of regex to try to tag
# some content by semantics. It then spits out a new JSON file with "_TAGGED" appended to the filename in the
# same directory.
#
# The regex was written originally for use in my bulk creature converters, so some extra work could be done if you
# want (though good luck). It aims to accurately tag things with minimal false positives, so you're more likely to
# have false negatives (i.e. things that should be tagged but aren't). It also obviously can't tag formatting
# choices (e.g. `{@b bold text}`) or 'innumerable' lists (e.g. creatures, items, spells). It should ignore text
# that is already tagged, but I wouldn't trust that necessarily and instead recommend you just don't tag text
# before running this. In summary, don't expect it to do all the work for you, but it'll get you 60% of the way
# there!
#
# Note: this script requires PowerShell 6 or higher. Windows 10 only has PowerShell 5 installed by default.
#
# Usage:
#   & <path to script> -Path <path to homebrew file>
#
# Parameters:
#  -Path (string; required): absolute or relative path to a file or directory
#
# Examples:
#   & .\entries-tagger.ps1 -Path ".\Anti-Brew-Conversion Gang; Spappz's Scroll of Suffering.json"
#
#
# Spappz 2023
#
# MIT License


PARAM (
	[Parameter(Mandatory, ValueFromPipeline, Position = 0)][String]$Path
)

function Tag-Entry {
	PARAM(
		[Parameter(Mandatory)][String]$text
	)
	PROCESS {
		return (
			$text -replace '^\s+' -replace '\s+$' -replace ' {2,}', ' ' `
				-replace '(?<=\()([\dd \+\-×x\*÷\/\*]+\d)(?=\))', '{@damage $1}' `
				-replace '\b(\d+d[\dd \+\-×x\*÷/]*\d)(?=( (\w){4,11})? damage\b)', '{@damage $1}' `
				-replace '(?<=\brolls? (a )?)(d\d+)\b(?![}|])', '{@dice $2}' `
				-replace '(?<!@d(amage|ice)) (\d+d[\dd \+\-×x\*÷/]*\d)\b(?![}|])', ' {@dice $2}' `
				-creplace '(?<!\w)\+?(\-?\d)(?= (to hit|modifier))', '{@hit $1}' `
				-creplace '\bDC ?(\d+)\b(?![}|])', '{@dc $1}' `
				-replace "(?<=\b(be(comes?)?|is( ?n[o']t)?|while|a(nd?|lso)?|or|th(e|at)) )(blinded|charmed|deafened|frightened|grappled|in(capacitated|nvisible)|p(aralyz|etrifi|oison)ed|restrained|stunned|unconscious)\b", '{@condition $6}' `
				-replace "(?<=\b(knocked|pushed|shoved|becomes?|falls?|while|lands?) )(prone|unconscious)\b", '{@condition $2}' `
				-replace "(?<=levels? of )exhaustion\b", "{@condition exhaustion}" `
				-creplace '(?<=\()(A(thletics|crobatics|rcana|nimal Handling)|Per(ception|formance|suasion)|S(leight of Hand|tealth|urvival)|In(sight|vestigation|timidation)|Nature|Religion|Medicine|History|Deception)(?=\))', '{@skill $1}' `
				-creplace '\b(A(thletics|crobatics|rcana|nimal Handling)|Per(ception|formance|suasion)|S(leight of Hand|tealth|urvival)|In(sight|vestigation|timidation)|Nature|Religion|Medicine|History|Deception)(?= (check|modifier|bonus|roll|score))', '{@skill $1}' `
				-replace '(?<!cast (the )?)\b(darkvision|blindsight|tr(emorsense|uesight))\b(?!( spell|[}|]))', '{@sense $2}' `
				-creplace "\b(Attack(?! roll)|Cast a Spell|D(ash|isengage|odge)|H(elp|ide)|Ready|Search|Use an Object)\b(?![}|])", '{@action $1}' `
				-replace '\bopportunity attack\b(?![}|])', '{@action opportunity attack}' `
				-replace '\b(opportunity attacks|attacks? of opportunity)\b', '{@action opportunity attack||$1}' `
				-replace '\b(\d\d?) percent chance\b', '{@chance $1} chance'
			)
	}
}

###

# Preamble rubbish
if ((Test-Path $Path)) {
	$target = Get-Item $Path
	if ($target.Extension -eq ".json") {
		try {
			$brew = Get-Content $target -Encoding Utf8 | ConvertFrom-Json
			if (-not $brew._meta) {
				Write-Error "``$target`` doesn't contain 5eTools homebrew JSON."
				break
			}
		} catch {
			Write-Error "``$target`` contains invalid JSON."
			break
		}
	} else {
		Write-Error "``$target`` isn't a JSON file."
		break
	}
} else {
	Write-Error "``$Path`` doesn't exist."
	break
}

###

# Recursive JSON object walker to pick out entry-like strings

function Traverse-Tree {
	PARAM(
		[Parameter(Mandatory, Position = 0)]$obj,
		[Parameter(Mandatory, Position = 1)][bool]$isEntry
	)
	PROCESS {
		if ($isEntry -and $obj -is [String]) {
			 return (Tag-Entry $obj)
		} elseif ($obj -is [PSCustomObject]) {
			foreach ($prop in $obj.PSObject.Properties) {
				if ($prop.Name -in @('entries', 'items', 'entry')) {
					$isEntry = $true
				} else {
					$isEntry = $false
				}
				$prop.Value = Traverse-Tree $prop.Value $isEntry
			}
			return $obj
		} elseif ($obj -is [Array]) {
			for ($i = 0; $i -lt $obj.Count; $i++) {
				$obj[$i] = Traverse-Tree $obj[$i] $isEntry
			}
			Write-Output @($obj) -NoEnumerate
		} else {
			return $obj
		}
	}
}

$brew = Traverse-Tree $brew $false

###

# Output the rubbish

$outPath = $Path -replace '\.json$', '_TAGGED.json'
(
	[Regex]::Replace(
		(ConvertTo-Json $brew -Depth 99),
			"\\u(?<Value>\w{4})",
			{
				PARAM($Matches)
				(
					[char](
						[int]::Parse(
								$Matches.Groups['Value'].Value, [System.Globalization.NumberStyles]::HexNumber
						)
					)
				).ToString()
			}
		) -replace '—', '\u2014' -replace '–', '\u2013' -replace '−', '\u2212'
	) | Out-File -FilePath $outPath -Encoding UTF8