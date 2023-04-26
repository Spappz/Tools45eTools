# 5eTools Homebrew Merger
# =======================
#
# This script looks for 5eTools-style homebrew JSONs within the current directory. It then stitches them together,
# outputting a single JSON to the same directory with all the content included, saving you having to lug around
# many files at once. The output file will be named `merged-brew-<gibberish>.json`.
#
# Note that while it does work with 5eTools homebrew JSONs made outside the Homebrew Builder, it will ignore any
# custom datatypes you defined in the `_meta`. If you don't know what that means, you're good. 😎👍
#
#
# Spappz 2022
#
# MIT License



# Initialise final brew file
$brew = [PSCustomObject]@{
    siteVersion = $null
    _meta = [PSCustomObject]@{
        sources = [Collections.Generic.List[object]]::new()
        dateAdded = [uInt32]::new()
        dateLastModified = [uInt32](Get-Date -UFormat %s)
    }
}

# Get files
$fileCounter = 0
Get-ChildItem | Where-Object { $_.name -match '\.json$' -and $_.name -notmatch '^merged-homebrew-\w{8}\.json' } | ForEach-Object {
    # Load file
    $file = $_ | Get-Content -Encoding utf8 | ConvertFrom-Json
    $fileCounter++
    
    # (Roughly) check that it's 5etools-compliant
    if ($file._meta) {
        # Add siteVersion, unless it already exists, in which case replace it if this file's one is older
        if ($brew.siteVersion) {
            if ($brew.siteVersion -lt $file.siteVersion) {
                $brew.siteVersion = $file.siteVersion
            }
        } elseif ($file.siteVersion) {
            $brew.siteVersion = $file.siteVersion
        }

        # Add dateAdded timestamp, unless it already exists, in which case replace it if this file's one is older
        if ($brew._meta.dateAdded) {
            if ($brew._meta.dateAdded -gt $file._meta.dateAdded) {
                $brew._meta.dateAdded = $file._meta.dateAdded
            }
        } else {
            $brew._meta.dateAdded = $file._meta.dateAdded
        }

        # Iterate through file's sources, adding it to the output array if it doesn't already exist
        foreach ($newSource in $file._meta.sources) {
            if (
                -not @(
                    foreach ($oldSource in $brew._meta.sources) {
                        Compare-Object $oldSource $newSource -Property full -IncludeEqual -ExcludeDifferent
                    }
                )
            ) {
                $brew._meta.sources.Add($newSource)
            }
        }

        # If a content-type already exists, add to that array; otherwise, create it
        $file | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notin 'siteVersion', '_meta' } | Select-Object -ExpandProperty Name | ForEach-Object {
            if ($brew.$_) {
                foreach ($thing in $file.$_) {
                    $brew.$_.Add($thing)
                }
            } else {
                $brew | Add-Member -MemberType NoteProperty -Name $_ -Value ([Collections.Generic.List[object]]$file.$_)
            }
        }
    }
}

if ($fileCounter) {
    # Remove `siteVersion` if unused
    if (-not $brew.siteVersion) {
        $brew.PSObject.Properties.Remove('siteVersion')
    }

    # Pick a non-existent filename
    do {
        $outputFile = 'merged-homebrew-' + (-join (97..122 | Get-Random -Count 8 | ForEach-Object { [char]$_ })) + '.json'
    } while (Test-Path $outputFile)

    # ConvertTo-Json collapses pretty much all symbols into `\uXXXX` codes; this reverses it 
    ([Regex]::Replace(
        (ConvertTo-Json $brew -Depth 99 -Compress),
        "\\u(?<Value>\w{4})",
        {
            PARAM($matches)
            ([char]([int]::Parse($matches.Groups['Value'].Value, [System.Globalization.NumberStyles]::HexNumber))).ToString()
        }
    ) -replace '—', '\u2014' -replace '–', '\u2013' -replace '−', '\u2212') | Out-File $outputFile -Encoding utf8

    Read-Host "Merged $fileCounter brews into ``$outputFile``.`n`nPress Enter to close"
} else {
    Read-Host "Nothing to merge!`n`nPress Enter to close"
}
