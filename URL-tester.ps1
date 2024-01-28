# 5eTools URL tester
# ==================
#
# This script will scan your file, or every JSON file in a directory recursively, for media-file URLs. If any found
# URLs don't return a file (i.e. the link is dead), it will compile an error object for manual correction.
# 
# Be aware of the following caveats:
#   - This script doesn't locate invalid URLs (for example, it can't warn you about mistyping "http://" as "http//:").
#   - This script only tests whether the URL gives a valid response. If the image-hoster redirects requests to a
#     generic 'image not found' file, the script will interpret it as an acceptable response (for example, see
#     `https://i.vgy.me/RPk2RT.png`).
#   - Although you can use the `-LogErrors` switch to be informed of errors as they're found, the script doesn't
#     actually return anything until all files have been tested.
#
# To write the errors to a file, you should first convert the output to JSON (see examples below).
#
# Note: this script requires PowerShell 7 or higher. Windows 10 only has PowerShell 5 installed by default.
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
#   & .\URL-tester.ps1 -Path '.\homebrew'
#   & .\URL-tester.ps1 -Path '.\homebrew\creature\badooga; Better Greatwyrms.json'
#   & .\URL-tester.ps1 -Path '.\homebrew' -LogErrors
#   & .\URL-tester.ps1 -Path '.\homebrew' | ConvertTo-Json | Out-File '.\badURLs.json' -Encoding utf8
#
#
# Spappz 2024
#
# MIT License

PARAM (
	# A path to a file or directory of files to test
	[Parameter(Mandatory, Position = 0)]
	[String]$Path,

	# Log erroneous files to the console early (useful if testing a large directory)
	[switch]$LogErrors
)

Write-Progress -Activity 'Initialising...' -Id 1 -Status ' ' -PercentComplete 0
$target = Get-Item (Resolve-Path $Path -ErrorAction Stop)
switch ($target.Attributes) {
	Archive {
		if ($target.Extension -eq '.json') {
			$files = @($target)
		} else {
			throw "Not a JSON file: $($target.FullName)"
		}
		break
	}
	Directory {
		$files = @(Get-ChildItem $target -File -Recurse -Exclude 'node_modules' | Where-Object { $_.Extension -eq '.json' })
		if (-not $files.Count) {
			Write-Error "No JSON files found in $([System.IO.Path]::GetRelativePath($PWD.Path, $target.FullName))" -ErrorAction Stop
		}
		break
	}
	Default {
		Write-Error "Not a file or directory: $([System.IO.Path]::GetRelativePath($PWD.Path, $target.FullName))" -ErrorAction Stop
		exit 1
	}
}

Write-Progress -Activity 'Scanning files...' -Id 1 -Status "1 of $fileCount" -PercentComplete 0
$fileCount = $files.Count
$tests = [System.Collections.Generic.List[hashtable]]::new()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt $fileCount; $i++) {
	if ($stopwatch.Elapsed.TotalMilliseconds -gt 1000) {
		Write-Progress -Activity 'Scanning files...' -Id 1 -Status "$($i + 1) of $fileCount" -PercentComplete (($i * 100) / $fileCount)
		$stopwatch.Reset()
		$stopwatch.Start()
	}
	
	$URLs = [regex]::Matches(
		(Get-Content $files[$i] -Encoding utf8),
		'\b(https?://[^\\|"]+\.(png|jpe?p|web[pm]|gif|bmp|tiff|mp\d)/?)\b'
	) | ForEach-Object {
		$_.Groups[1].Value
	}

	if ($URLs.Count) {
		$tests.Add(
			@{
				path         = $files[$i].FullName
				relativePath = [System.IO.Path]::GetRelativePath($PWD.Path, $files[$i].FullName)
				URLs         = @($URLs)
			}
		)
	}
}

$URLCounter = 0
$URLCountTotal = $tests.URLs.Count
$testCount = $tests.Count
$errors = [System.Collections.Generic.List[hashtable]]::new()
Write-Progress -Activity "Testing file 1 of $testCount..." -Id 1 -Status "0 of $URLCountTotal URLs tested" -PercentComplete 0
$stopwatch.Reset()
$stopwatch.Start()
for ($i = 0; $i -lt $testCount; $i++) {
	$URLCount = $tests[$i].URLs.Count
	$badURLsFound = $false
	for ($j = 0; $j -lt $URLCount; $j++) {
		if ($stopwatch.Elapsed.TotalMilliseconds -gt 1000) {
			Write-Progress -Activity "Testing file $($i + 1) of $testCount..." -Id 1 -Status "$URLCounter of $URLCountTotal URLs tested" -PercentComplete (($URLCounter * 100) / $URLCountTotal)
			$stopwatch.Reset()
			$stopwatch.Start()
		}

		$requestError = $false
		try {
			$req = Invoke-WebRequest -Uri $tests[$i].URLs[$j] -DisableKeepAlive -Method Head
		} catch {
			$requestError = $true
		}

		if ($requestError -or $req.StatusCode -ne 200) {
			$errorLog = @{
				path         = $tests[$i].path
				relativePath = $tests[$i].relativePath
				URL          = $tests[$i].URLs[$j]
			}

			if ($LogErrors -and -not $badURLsFound) {
				if (-not $errors.Count) {
					Write-Host ('Dead URLs found in:')
				}
				Write-Host ("`t" + $tests[$i].relativePath)
			}

			$errors.Add($errorLog)
			$badURLsFound = $true
		}

		$URLCounter++
	}
}

if ($errors.Count) {
	Write-Host "$($errors.Count) bad URLs found."
} else {
	Write-Host 'No bad URLs found.'
}

return $errors
