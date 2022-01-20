# MASK RESCALER
# =============
#
# If the PDF image extractor has given you masks that don't match the image dimensions, this script can help. First, make sure to remove ALL files from the
# directory that aren't the mismatched images/masks. Also remove any unwanted images; the images must be in the 'image, mask, image, mask, ...' order that
# the extractor requires.
#
# Place this script in the same directory as the images/masks. If on Windows, right-click and select 'Run with PowerShell'. If on macOS/Linux, you'll
# probably have to install PowerShell and run this script via command line.
#
# Rescaled masks have `_resized` appended to their name, and all old masks are moved to a new directory surprisingly called `old_masks`.
#
# If you still don't understand what this script does, I recommend not using it.
#
#
# Spappz 2022
#
# MIT License

Add-Type -Assembly System.Drawing

# Resize-Image function (copied 2022-01-20) by Christopher Walker at https://gist.github.com/someshinyobject/617bf00556bc43af87cd
Function Resize-Image {
    [CmdLetBinding(
        SupportsShouldProcess=$true, 
        PositionalBinding=$false,
        ConfirmImpact="Medium",
        DefaultParameterSetName="Absolute"
    )]
    Param (
        [Parameter(Mandatory=$True)]
        [ValidateScript({
            $_ | ForEach-Object {
                Test-Path $_
            }
        })][String[]]$ImagePath,
        [Parameter(Mandatory=$False)][Switch]$MaintainRatio,
        [Parameter(Mandatory=$False, ParameterSetName="Absolute")][Int]$Height,
        [Parameter(Mandatory=$False, ParameterSetName="Absolute")][Int]$Width,
        [Parameter(Mandatory=$False, ParameterSetName="Percent")][Double]$Percentage,
        [Parameter(Mandatory=$False)][System.Drawing.Drawing2D.SmoothingMode]$SmoothingMode = "HighQuality",
        [Parameter(Mandatory=$False)][System.Drawing.Drawing2D.InterpolationMode]$InterpolationMode = "HighQualityBicubic",
        [Parameter(Mandatory=$False)][System.Drawing.Drawing2D.PixelOffsetMode]$PixelOffsetMode = "HighQuality",
        [Parameter(Mandatory=$False)][String]$NameModifier = "resized"
    )
    Begin {
        If ($Width -and $Height -and $MaintainRatio) {
            Throw "Absolute Width and Height cannot be given with the MaintainRatio parameter."
        }
 
        If (($Width -xor $Height) -and (-not $MaintainRatio)) {
            Throw "MaintainRatio must be set with incomplete size parameters (Missing height or width without MaintainRatio)"
        }
 
        If ($Percentage -and $MaintainRatio) {
            Write-Warning "The MaintainRatio flag while using the Percentage parameter does nothing"
        }
    }
    Process {
        ForEach ($Image in $ImagePath) {
            $Path = (Resolve-Path $Image).Path
            $Dot = $Path.LastIndexOf(".")

            #Add name modifier (OriginalName_{$NameModifier}.jpg)
            $OutputPath = $Path.Substring(0,$Dot) + "_" + $NameModifier + $Path.Substring($Dot,$Path.Length - $Dot)
            
            $OldImage = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Path
            # Grab these for use in calculations below. 
            $OldHeight = $OldImage.Height
            $OldWidth = $OldImage.Width
 
            If ($MaintainRatio) {
                $OldHeight = $OldImage.Height
                $OldWidth = $OldImage.Width
                If ($Height) {
                    $Width = $OldWidth / $OldHeight * $Height
                }
                If ($Width) {
                    $Height = $OldHeight / $OldWidth * $Width
                }
            }
 
            If ($Percentage) {
                $Product = ($Percentage / 100)
                $Height = $OldHeight * $Product
                $Width = $OldWidth * $Product
            }

            $Bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Width, $Height
            $NewImage = [System.Drawing.Graphics]::FromImage($Bitmap)
             
            #Retrieving the best quality possible
            $NewImage.SmoothingMode = $SmoothingMode
            $NewImage.InterpolationMode = $InterpolationMode
            $NewImage.PixelOffsetMode = $PixelOffsetMode
            $NewImage.DrawImage($OldImage, $(New-Object -TypeName System.Drawing.Rectangle -ArgumentList 0, 0, $Width, $Height))

            If ($PSCmdlet.ShouldProcess("Resized image based on $Path", "save to $OutputPath")) {
                $Bitmap.Save($OutputPath)
            }
            
            $Bitmap.Dispose()
            $NewImage.Dispose()
            $OldImage.Dispose()
        }
    }
}

# Grab paths to all the files in the directory
$imageList = Get-ChildItem | Where-Object {$_.Name -match '\.png$'} | Select-Object -ExpandProperty Name | Resolve-Path | Select-Object -ExpandProperty Path

# Assume the order is image, mask, image, mask
for ($i = 0; $i -lt $imageList.Count; $i = $i + 2) {
    # Read image for reference
    $image = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $imageList[$i]
    # Rescale and save mask based on the image's dimensions
    Resize-Image -Width $image.Width -Height $image.Height -ImagePath $imageList[$i + 1]
}

# Move old masks into an `old_masks` directory as clean-up 
$imageListNew = Get-ChildItem | Where-Object {$_.Name -match '\.png$'} | Select-Object -ExpandProperty Name
$null = New-Item -ItemType Directory -Name old_masks
for ($i = 1; $i -lt $imageListNew.Count; $i = $i + 3) {
    Move-Item -Path $imageListNew[$i] -Destination old_masks
}