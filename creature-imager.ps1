# 5eTools Creature Imager
# =======================
#
# Note: Requires PowerShell 7.2 or higher. This will not work with the version of PowerShell bundled with
#       Windows 10 by default.
#
# This script aims to speed up a somewhat common occurrence when converting creatures for 5eTools: adding
# images and tokens.
#
# The first three settings variables are mandatory:
#   - $brewRepo        The constant fragment of the raw image files' URL. If you're using the homebrew repo,
#                         all you need to change is the final 'directory' (currently `mme_v2`).
#   - $brewPath        The local path to the original 5eTools brew file.
#   - $outputPath      The local path to the folder you want to output everything into.
#
# Each of the next two bunches are only required if they're used—that is, if $processImages or $processTokens
# is set to $true. Setting it to $false will, amazingly, cause the script to not process any images or tokens
# respectively and therefore not care about those settings. I'll use 'xxx' to mean "either 'image' or
# 'token'" because they both work the same.
#   - $xxxList         The local path the comma-separated list of image/token files and the creatures they
#                         apply to (see below for more information).
#   - $xxxPath         The local path to the directory containing all those images/tokens. Although said
#                         directory need not contain only images/tokens, all the images/tokens you want to
#                         apply must be in the directory and in no directory deeper.
#   - $xxxOutputName   The name of the directory you want to sort applied images/tokens into. Can be the empty
#                         string ("") if you like.
#   - $prioritiseNewXxxs
#                      When set to $true, new images are placed at the top and new tokens are given primacy
#                         (i.e. made the default; displays first on 5eTools). When set to $false, new images
#                         are placed at the bottom and new tokens are relegated to 'variant art'.
#   - $tokenDescription
#                      Plutonium displays a 'name' for all non-default tokens when imported. This is required—
#                         if not strictly by Plutonium then by this script because I'm lazy. Just enter a
#                         short description of what the tokens are, like "New art" or "Roll20-style border";
#                         it's ignored if the creature doesn't already have a token, so it might not even be
#                         important for you.
#
# The comma-separated list should have at least 2 columns. One column should be called `Filename` and one
# should be called `Creature 1`. In each row, enter one image/token's filename in its column (including file
# extension!) and the creature you want to apply it to in the `Creature 1` column. If you want to apply it to
# multiple creatures, simply add more columns as necessary named `Creature 2`, `Creature 3`, etc. You can also
# optionally add a column called `Notes` which will flag information to the user (useful if you're collabor-
# ating the grunt work with someone else).
#
# The order of the columns doesn't matter. The `Creature N` columns don't need to be full—in fact all of them
# can be entirely empty and the file will just be skipped over—but where they contain a creature name that
# name must be exact. There's no fuzzy matching here.
#
# You can find an example here: https://9m.no/𐀋玛 (yes, that's a URL). Feel free to duplicate and edit it to
# your heart's content. You can export a `.csv`of the currently viewed sheet from the File > Download menu.
#
#
# Spappz 2022
#
# MIT License

# SETTINGS
  $brewRepo = "https://raw.githubusercontent.com/TheGiddyLimit/homebrew/master/_img/mme_v2/"
  $brewPath = "B:\5etools\homebrew\creature\Dragonix; Monster Manual Expanded.json"
  $outputPath = "D:\Documents\mme\done"
  
  $processImages = $true # $true or $false
  $imageList = "D:\Documents\mme\img.csv"
  $imagePath = "D:\Documents\mme\full2"
  $imageOutputName = "img"
  $prioritiseNewImages = $false # $true or $false

  $processTokens = $true # $true or $false
  $tokenList = "D:\Documents\mme\token.csv"
  $tokenPath = "D:\Documents\mme\token2"
  $tokenOutputName = "token"
  $prioritiseNewTokens = $false # $true or $false
  $tokenDescription = "v2 art"

# # # # # #

Clear-Host
Write-Host "5ETOOLS CREATURE IMAGER`n`n`nInitialising...`n"

# Tests and initialisation
if ($brewRepo -notmatch '/$') {
	$brewRepo = $brewRepo + '/'
}

if (Test-Path $brewPath) {
	$brew = Get-Content $brewPath -Encoding utf8 | ConvertFrom-Json
} else {
	throw "Brew JSON file path doesn't exist."
}

function Initialise-Directory {
	PARAM(
		$Path,
		$Type
	)
	if (-not (Test-Path $Path)) {
		if ((Read-Host "Your $Type ``$Path`` doesn't exist. Create it? [y/n]") -match 'y') {
			$null = New-Item -Path $Path -Type Directory
			Write-Host
		} else {
			throw "A valid $Type is required."
		}
	}
	$Path = Resolve-Path $Path | Select-Object -ExpandProperty Path
	$Path += "/"
	Write-Output $Path
}

$outputPath = Initialise-Directory -Path $outputPath -Type "output path"

if ($processImages) {
	$imagePath = Initialise-Directory -Path $imagePath -Type "image path"
	if ($imageOutputName -and $imageOutputName -notmatch '[/\\]$') {
		$imageOutputName += '/'
	}
	$imageOutputPath = Initialise-Directory -Path ($outputPath + $imageOutputName) -Type "image output path"
	if (Test-Path $imageList) {
		$images = Get-Content $imageList |
			ConvertFrom-Csv |
			ForEach-Object {
				Write-Output @{
					file = $_.Filename
					note = $_.Notes
					creatures = @(
						$_.PSObject.Properties |
							Where-Object { $_.Name -match 'Creature|Monster' } |
							Select-Object -ExpandProperty Value |
							Where-Object { $_ }
					)
				}
			}
	} elseif ($imageList) {
		throw "Images CSV file path doesn't exist."
	}
}

if ($processTokens) {
	$tokenPath = Initialise-Directory -Path $tokenPath -Type "token path"
	if ($tokenOutputName -and $tokenOutputName -notmatch '[/\\]$') {
		$tokenOutputName += '/'
	}
	$tokenOutputPath = Initialise-Directory -Path ($outputPath + $tokenOutputName) -Type "token output path"
	if (Test-Path $tokenList) {
		$tokens = Get-Content $tokenList |
			ConvertFrom-Csv |
			ForEach-Object {
				Write-Output @{
					file = $_.Filename
					note = $_.Notes
					creatures = @(
						$_.PSObject.Properties |
							Where-Object { $_.Name -match 'Creature|Monster' } |
							Select-Object -ExpandProperty Value |
							Where-Object { $_ }
					)
				}
			}
		if (-not $tokenDescription) {
			throw "A token description is required for Plutonium. Set this to whatever the subordinate token (as defined by ``$prioritiseNewTokens``) is best summarised by, even if that's just ""Old token""."
		}
	} else {
		throw "Tokens CSV file path doesn't exist."
	}
}

if (-not $brew.monster) {
	throw "Brew file doesn't contain any creatures."
}

$needsHuman = [PSCustomObject]@{
	tokens = [System.Collections.Generic.List[Hashtable]]::new()
	images = [System.Collections.Generic.List[Hashtable]]::new()
}
$deleteable = [System.Collections.Generic.List[String]]::new()

# Token application
if ($processTokens) {
	Write-Host "`nApplying tokens...`n"
	:token foreach ($token in $tokens) {
		Write-Host $("Applying ``" + $token.file + "``...")
		if ($token.note) {
			$noteAction = Read-Host $(
				"``" + $token.file + "`` has the following note:`n   " +
				$token.note +
				"`nProceed? [y/n]`n "
			)
			if ($noteAction -match '[no]' -or $noteAction -notmatch 'y') {
				Write-Host "Skipping token."
				$needsHuman.tokens.Add($token)
				continue
			}
		}
		if ($token.creatures.Count) {
			:creature foreach ($creature in $token.creatures) {
				$filter = $brew.monster | Where-Object { $_.name -eq $creature }
				if ($filter.Count -gt 1) {
					Write-Warning $("Multiple creatures are called """ + $creature + """; skipping creature.")
					$token.imagerNote += @("Multiple creatures in brew file named """ + $creature + """; application was skipped.")
					continue creature
				} elseif ($filter.name) { # i.e. not $null
					$i = $brew.monster.IndexOf($filter)
					$superToken = $null
					$subToken = $null
					if ($prioritiseNewTokens) {
						$superToken = $brewRepo + $tokenOutputName + $token.file
						if ($filter.tokenUrl) {
							$subToken = $filter.tokenUrl
						}
					} else {
						if ($filter.tokenUrl) {
							$superToken = $filter.tokenUrl
							$subToken = $brewRepo + $tokenOutputName + $token.file
						} else {
							$superToken = $brewRepo + $tokenOutputName + $token.file
						}
					}
					if ($filter.tokenUrl) {
						$filter.tokenUrl = $superToken
					} else {
						$filter | Add-Member -MemberType NoteProperty -Name tokenUrl -Value $superToken
					}
					if ($subToken) {
						if ($filter.altArt) {
							$hash = @($filter.altArt.name) -match $tokenDescription | ForEach-Object { [Boolean]$_ } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
							$filter.altArt += @{
								tokenUrl = $subToken
								source = $filter.source
								name = $tokenDescription + ($hash ? " " + ($hash + 1) : $null)
							}
						} else {
							$filter | Add-Member -MemberType NoteProperty -Name altArt -Value @(
								@{
									tokenUrl = $subToken
									source = $filter.source
									name = $tokenDescription
								}
							)
						}
					}
					$brew.monster[$i] = $filter
				} else {
					Write-Warning $("No creature called """ + $creature + """ found; skipping creature.")
					$token.imagerNote += @("No creature called """ + $creature + """ found in brew file; application was skipped.")
					continue creature
				}
			}
			try {
				Copy-Item -Path ($tokenPath + $token.file) -Destination ($tokenOutputPath + $token.file)
			} catch {
				Write-Warning ("Failed to copy token: ``" + $token.file + "`` doesn't exist.")
				$token.imagerNote += @("Failed to copy token: ``" + $token.file + "`` doesn't exist.")
				$needsHuman.tokens.Add($token)
			}
			if ($token.imagerNote) {
				$needsHuman.tokens.Add($token)
			}
		} else {
			Write-Host $("No creatures to assign ``" + $token.file + "``.")
			$deleteable.Add($token.file)
			continue
		}
	}
}

# Image application
if ($processImages) {
	Write-Host "`n`nApplying images...`n"
	:image foreach ($image in $images) {
		Write-Host $("Applying ``" + $image.file + "``...")
		if ($image.note) {
			$noteAction = Read-Host $(
				"``" + $image.file + "`` has the following note:`n   " +
				$image.note +
				"`nProceed? [y/n]`n "
			)
			if ($noteAction -match '[no]' -or $noteAction -notmatch 'y') {
				Write-Host "Skipping image."
				$needsHuman.images.Add($image)
				continue
			}
		}
		if ($image.creatures.Count) {
			:creature foreach ($creature in $image.creatures) {
				$filter = $brew.monster | Where-Object { $_.name -eq $creature }
				if ($filter.Count -gt 1) {
					Write-Warning $("Multiple creatures are called """ + $creature + """; skipping creature.")
					$image.imagerNote += @("Multiple creatures in brew file named """ + $creature + """; application was skipped.")
					continue creature
				} elseif ($filter.name) { # i.e. not $null
					if ($filter.fluff._monsterFluff) {
						# $filter2 = $brew.monsterFluff | Where-Object { $_.name -eq $filter.fluff._monsterFluff.name -and $_.source -eq $filter.fluff._monsterFluff.source }
						# $j = $brew.monsterFluff.IndexOf($filter2)
						# nah this is too much effort sorry lads
						Write-Warning $("""" + $filter.name + """ uses a referenced ``_monsterFluff`` instead of standard ``images``; skipping application.")
						$image.imagerNote += @("""" + $filter.name + """ uses a referenced ``_monsterFluff`` instead of standard ``images``; application was skipped.")
						continue creature
					}
					$i = $brew.monster.IndexOf($filter)
					if (-not $filter.fluff) {
						$filter | Add-Member -MemberType NoteProperty -Name fluff -Value ([PSCustomObject]@{
							images = [System.Collections.Generic.List[PSObject]]::new()
						})
					} elseif (-not $filter.fluff.images) {
						$filter.fluff | Add-Member -MemberType NoteProperty -Name images -Value ([System.Collections.Generic.List[PSObject]]::new())
					} else {
						$filter.fluff.images = [System.Collections.Generic.List[PSObject]]$filter.fluff.images
					}
					if ($prioritiseNewImages) {
						$filter.fluff.images = [System.Collections.Generic.List[PSObject]]@(
							@{
								type = 'image'
								href = @{
									type = 'external'
									url = $brewRepo + $imageOutputName + $image.file
								}
							}
							$filter.fluff.images
						)
					} else {
						$filter.fluff.images.Add(
							@{
								type = 'image'
								href = @{
									type = 'external'
									url = $brewRepo + $imageOutputName + $image.file
								}
							}
						)
					}
					$brew.monster[$i] = $filter
				} else {
					Write-Warning $("No creature called """ + $creature + """ found; skipping creature.")
					$image.imagerNote += @("No creature called """ + $creature + """ found in brew file; application was skipped.")
					continue creature
				}
			}
			try {
				Copy-Item -Path ($imagePath + $image.file) -Destination ($imageOutputPath + $image.file)
			} catch {
				Write-Warning ("Failed to copy image: ``" + $image.file + "`` doesn't exist.")
				$image.imagerNote += @("Failed to copy image: ``" + $image.file + "`` doesn't exist.")
				$needsHuman.images.Add($image)
			}
			if ($image.imagerNote) {
				$needsHuman.images.Add($image)
			}
		} else {
			Write-Host ("No creatures to assign ``" + $image.file + "``.")
			$deleteable.Add($image.file)
			continue
		}
	}
}

# Tidying up
Write-Host "`n`nComplete.`n`nFinishing up...`n"
$brew | ConvertTo-Json -Depth 99 | Out-File -Path ($outputPath + $brew._meta.sources[0].authors[0] + '; ' + $brew._meta.sources[0].full + '.json') -Encoding utf8
if ($needsHuman.tokens.Count -or $needsHuman.images.Count) {
	Write-Warning ("Process completed with " + ($needsHuman.tokens.Count + $needsHuman.images.Count) + " warnings.")
	$logName = $outputPath + 'imager log ' + (Get-Date -UFormat %s) + '.json'
	$needsHuman | ConvertTo-Json -Depth 5 | Out-File -Path $logName -Encoding utf8
	Write-Host ("Please see ``" + $logName + "`` for more information.`n")
}
if ($deleteable.Count) {
	Write-Warning ("" + $deleteable.Count + " files were unused.")
	$delName = $outputPath + 'imager unused ' + (Get-Date -UFormat %s) + '.csv'
	$deleteable | ForEach-Object {
		Write-Output @{
			Filename = $_
		}
	} | ConvertTo-Csv | Out-File -Path $delName -Encoding utf8
	Write-Host ("A list of these files can be found in ``" + $delName + "``.`n")
}

Read-Host "`nPress Enter to exit"