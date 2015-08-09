<#
.Synopsis
   Scan picture and video files and attempts to organize them by date.
.DESCRIPTION
   Long description
.EXAMPLE
   .\PPO.ps1 'M:\Pictures\2009\0*' M:\Pictures -WhatIf -RecurseDir
.EXAMPLE
   Another example of how to use this cmdlet
#>
[CmdletBinding()]
Param
(
    # The source directory of the files. The * is required for -Include
    [Parameter(Mandatory=$true,Position=0)]
    #[ValidatePattern("^[a-z]\:\\.*\\\*$")] # Check for Drive letter and ending in '*'.
    [Alias('S')]
    [string]$SourceDir
,
    # The target location for writing files to.
    [Alias('D')]
    [Parameter(Mandatory=$false,Position=1)][string]$DestinationRoot
,
    [string]$LogsDir
,
    # Blocks the script from automatically generating year/month sub-directories.
    # Can only be used when $DesinationRoot is present.
    [switch]$ForceDestination
,
    # Toggles Copy instead of Move for writing files.
    [switch]$PreserveOriginal
,
    # Toggle recurse
    [switch]$RecurseDir
,
    # Verify changes before performing them
    [switch]$WhatIf
,
    # If the target file exists (not full path) skip it. This is different than if the
    # entire source path matches the dest path.
    [switch]$SkipDupeFile
,
    # File types to -Include.
    $Filter = @("*.jpg","*.jpeg","*.mov","*.mpg","*.mp4","*.avi","*.NEF")
,
    $Global:isDebug = $true
,
    $PSDefaultParameterValues=@{"Write-Log:DebugMode"=$true}
,
    # Include local config and functions.
    $dependencies = @("..\Write-log\Write-Log.ps1")
,
    $month = @{
        01 = "01 Jan"
        02 = "02 Feb"
        03 = "03 Mar"
        04 = "04 Apr"
        05 = "05 May"
        06 = "06 Jun"
        07 = "07 Jul"
        08 = "08 Aug"
        09 = "09 Sep"
        10 = "10 Oct"
        11 = "11 Nov"
        12 = "12 Dec"
    }
)

function Get-JpegData {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSObject[]]$InputObject
    ,
        [int]$i=0        
    )

    Try
    {
        If ($arr) { Remove-Variable arr }
        $arr = @()

        Foreach ($Item in $Input) {
            $i++
            Write-Progress -Activity "Reading files..." `
                           -Status "Processed: $i of $($Input.Count)" `
                           -PercentComplete (($i / $Input.Count) * 100)

            #$m = $jpeg.BaseName -match "\d{8}_\d{6}"
            If     ($Item.BaseName -match "\d{8}_\d{6}")                         { $FileNameStamp = $Matches[0] }
            ElseIf ($Item.BaseName -match "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}") { $FileNameStamp = $Matches[0] -replace "-","" }
            Else { $FileNameStamp = $false }

            # Get Exif data if jpg file.
            If ($Item.Extension -like "*.jpg" -or $Item.Extension -like "*.jpeg")
            {
                $DateTaken = Get-DateTaken $Item.FullName
            }
            Else
            {
                $DateTaken = ""
            }

            $prop = [ordered]@{
                FileName      = $Item.Name
                DateTaken     = $DateTaken
                FileNameStamp = $FileNameStamp
                LastWriteTime = $Item.LastWriteTime.ToString('yyyyMMdd_HHmmss')
                Path          = $Item.Directory
                Extension     = $Item.Extension
            }
            $obj = New-Object -TypeName psobject -Property $prop

            # Prefer DateTaken if it exists
            If ($obj.DateTaken)                                                                { $obj | Add-Member -Type NoteProperty -Name Preferred -Value DateTaken }
            
            # Prefer FileNameStamp if it's less than LastWriteTime[0] (yyyyMMdd)
            ElseIf (($obj.FileNameStamp -split "_")[0] -lt ($obj.LastWriteTime -split "_")[0]) { $obj | Add-Member -Type NoteProperty -Name Preferred -Value FileNameStamp }

            # Prefer FileNameStamp if it's less than LastWriteTime[0,1] (yyyyMMdd,HHmmmss)
            ElseIf (($obj.FileNameStamp -split "_")[0] -eq ($obj.LastWriteTime -split "_")[0] `
              -and (($obj.FileNameStamp -split "_")[1] -lt ($obj.LastWriteTime -split "_")[1])){ $obj | Add-Member -Type NoteProperty -Name Preferred -Value FileNameStamp }
            
            # Last resort is prefer LastWriteTime
            Else { $obj | Add-Member -Type NoteProperty -Name Preferred -Value LastWriteTime }

            $obj | Add-Member -Type NoteProperty -Name Year -Value (($obj.($obj.Preferred) -split "_")[0]).substring(0,4)
            $obj | Add-Member -Type NoteProperty -Name Month -Value (($obj.($obj.Preferred) -split "_")[0]).substring(4,2)

            $arr += $obj
        }
        $arr
        }
    Catch
    {
        Write-Log "ERROR: $($_.Exception.Message)"
        Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
    }
}

function Get-DateTaken {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $file
    )

    Try
    {
        #Write-Log $file
        $ImageMetaData = .\Get-ImageMetaData.ps1 -file $file

        # ExifDTOrig (0x9003): Date and time when the original image data was generated. For a DSC, the date 
        # and time when the picture was taken. The format is YYYY:MM:DD HH:MM:SS with time shown in 24-hour 
        # format and the date and time separated by one blank character (0x2000). The character string length 
        # is 20 bytes including the NULL terminator. When the field is empty, it is treated as unknown.
        If ($ImageMetaData.36867)
        {
            $ExifDTOrig = $ImageMetaData.36867
            If ($ExifDTOrig -match "\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d")
            {
                $ExifDTOrig = $ExifDTOrig.Replace(":","").Replace(" ","_")
            }
            Else # Sometimes EXIF data taken is a datetime string
            {
                Try { $ExifDTOrig = ([datetime]$ExifDTOrig).ToString("yyyyMMdd_HHmmss") }
                Catch {}
            }
            # Confirm output is expected
            If ($ExifDTOrig -notmatch "\d{8}_\d{6}")
            {
                #Write-Log "ERROR: The file $file has unsupported ExifDTOrig(36867|0x9003) data." -DebugMode
                $ExifDTOrig = $false
            }
        }

        # ExifDTDigitized (0x9004): Date and time when the image was stored as digital data. If, for example, 
        # an image was captured by DSC and at the same time the file was recorded, then DateTimeOriginal and 
        # DateTimeDigitized will have the same contents. The format is YYYY:MM:DD HH:MM:SS with time shown in 
        # 24-hour format and the date and time separated by one blank character (0x2000). The character string 
        # length is 20 bytes including the NULL terminator. When the field is empty, it is treated as unknown.
        If ($ImageMetaData.36868)
        {
            $ExifDTDigitized = $ImageMetaData.36868
            If ($ExifDTDigitized -match "\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d")
            {
                $ExifDTDigitized = $ExifDTDigitized.Replace(":","").Replace(" ","_")
            }
            Else # Sometimes EXIF data taken is a datetime string
            {
                $ExifDTDigitized = ([datetime]$ExifDTDigitized).ToString("yyyyMMdd_HHmmss")
            }
            # Confirm output is expected
            If ($ExifDTDigitized -notmatch "\d{8}_\d{6}")
            {
                #Write-Log "ERROR: The file $file has unsupported ExifDTDigitized(36868|0x9004) data." -DebugMode
                $ExifDTDigitized = $false
            }
        }

        # Error out if both EXIF types exist
        If ($ExifDTOrig -and $ExifDTDigitized)
        {
            # If metadata dates match then return one.
            If ($ExifDTOrig -like $ExifDTDigitized) { $ExifDate = $ExifDTOrig }
            Else
            {
                Write-Log "ERROR: Two Exif types exist for file $file. ExifDTOrig: $ExifDTOrig, ExifDTDigitized: $ExifDTDigitized"
                Exit 1
            }
        }

        # Decide which exif metadata to use.
        If ($ExifDTOrig)
        {
            #Write-Log "Using ExifDTOrig"
            $ExifDate = $ExifDTOrig
        }
        If ($ExifDTDigitized)
        {
            #Write-Log "Using ExifDTDigitized"
            $ExifDate = $ExifDTDigitized
        }

        # Parse XMP metadata
        If ($ImageMetaData.'/xmp/exif:DateTimeOriginal')
        {
            $XmpDate = $ImageMetaData.'/xmp/exif:DateTimeOriginal'
            $XmpDate = ([datetime]$XmpDate).ToString("yyyyMMdd_HHmmss")
            # Confirm output is expected
            If ($XmpDate -notmatch "\d{8}_\d{6}") { Write-Log "ERROR: The file $file has unsupported xmp data."; Exit 1 }
        }

        # Error out if both exist
        If ($ExifDate -and $XmpDate)
        {
            # If metadata dates match then return one
            If ([string]$ExifDate -like [string]$XmpDate) { Return $ExifDate }
            Else
            {
                Write-Log "ERROR: Both Exif date ($ExifDate) and XMP date ($XmpDate) exist for file $file."
                Exit 1
            }
        }
        # Pick whichever exists
        If ($ExifDate) { Return $ExifDate }
        If ($XmpDate ) { Return $XmpDate  }
    }
    Catch
    {
        Write-Log "ERROR: $($_.Exception.Message)"
        Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
    }
}

#region ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ SETUP ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#Locate the invocation directory and cd to it to be able to load local functions.
$parentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesDir = "$parentDir\"
cd $includesDir

# Create the log name from the script name
If (!$LogsDir) { $LogsDir = $includesDir }
$Global:log=@{
    Location = $LogsDir
    Name = "$($MyInvocation.MyCommand.Name)_$(Get-Date -UFormat %Y-%m-%d.%H-%M-%S)"
    Extension = ".log"
}
$logFile = $log.Location + $log.Name + $log.Extension

# Source local config and functions using call operator (dot sourcing)
$dependencies | % {
    If (Test-Path ".\$_")
    {
        . ".\$_"
        Write-Output "$(Get-Date) Loaded dependency: $_" #| Tee-Object -FilePath $logFile -Append
    }
    Else 
    {
        Write-Output "$(Get-Date) ERROR: Failed to load dependency: $_" #| Tee-Object -FilePath $logFile -Append
        Exit 1
    }
}
#endregion

#region ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ MAIN ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Try
{
    #$WhatIf=$true
    If ($JpegData) { Remove-Variable JpegData }
    # Setup target destination for writing files later
    If ($DestinationRoot) { $Base = $DestinationRoot }
    Else                  { $Base = $SourceDir }
    
    # Check to see if * (wildcard) is used in source path
    If ($SourceDir -match "^[a-z]\:\\.*\\.*\*.*$")
    {
        # Retrieve data
        If ($RecurseDir) { $JpegData = gci -Path $SourceDir -Recurse | Get-JpegData }
        Else             { $JpegData = gci -Path $SourceDir          | Get-JpegData }
    }
    # Add '\*' for gci -Include.
    ElseIf ($SourceDir -notmatch "^[a-z]\:\\.*\\\*$")
    {
        $SourceDir = "$SourceDir\*"
        # Retrieve data
        If ($RecurseDir) { $JpegData = gci -Path $SourceDir -Include $Filter -Recurse | Get-JpegData }
        Else             { $JpegData = gci -Path $SourceDir -Include $Filter          | Get-JpegData }
    }
    Else { Throw "Invalid source path: $SourceDir" }
   
    # Process the files
    $i = 0
    Foreach ($item in $JpegData)
    {
        $i++
        If ($JpegData.Count -gt 1)
        {
            Write-Progress -Activity "Writing files..." `
                -Status "Processed: $i of $($JpegData.Count)" `
                -PercentComplete (($i / $JpegData.Count) * 100)
        } 
        $SourcePath      = "$($item.Path)\$($item.FileName)"
        If ($ForceDestination) { $DestinationDir = $DestinationRoot }
        Else                   { $DestinationDir  = "$Base\$($item.Year)\$($month[[int]$($item.month)])" }
        $DestinationFile = "$($item.$($item.Preferred))"
        $Destination     = "$DestinationDir\$DestinationFile$($item.Extension)"
    
        # Create dest dir if it doesn't exist and not Whatif
        If (!(Test-Path $DestinationDir) -and (!$WhatIf)) { mkdir $DestinationDir | Out-Null }
    
        If ($SourcePath -eq $Destination)
        {
            Write-Log "Skipping file because it is already properly named: $SourcePath"
        }
        ElseIf ((Test-Path $Destination) -and $SkipDupeFile)
        { 
            Write-Log "SKIP $SourcePath,$Destination SKIP"
            Continue
        }
        ElseIf (Test-Path $Destination)
        {
            # Attempt to suffix up to 5
            For ($j = 1; $j -le 5; $j++) {
                # Iterate filename and check if exists.
                $Destination = "$DestinationDir\$DestinationFile ($j)$($item.Extension)"
                If (Test-Path $Destination)
                {
                    # The file still exists after 5 iterations, skip to next file.
                    If ($j -eq 5)
                    {
                        If ($WhatIf) { Write-Log "$SourcePath,$Destination,ExistsAlready" -WhatIf ; Break }
                        Else         { Write-Log "$SourcePath,$Destination,ExistsAlready"         ; Break }
                    }
                }
                Else
                {
                    If ($WhatIf)
                    {
                        Write-Log "$SourcePath,$Destination,$($item.Preferred)" -WhatIf
                        Break
                    }
                    Else
                    {
                        # Write file and skip to next file.
                        If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
                        Else                   { Move-Item -Path $SourcePath -Destination $Destination }
                        Write-Log "$SourcePath,$Destination,$($item.Preferred)"
                        Break
                    }
                }
            }
        }
        Else
        {
            If ($WhatIf)
            {
                Write-Log "$SourcePath,$Destination,$($item.Preferred)" -WhatIf
            }
            Else
            {
                If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
                Else                   { Move-Item -Path $SourcePath -Destination $Destination }
                Write-Log "$SourcePath,$Destination,$($item.Preferred)"
            }
        }
    }
}
Catch
{
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
}
#endregion