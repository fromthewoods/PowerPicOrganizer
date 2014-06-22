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
    # The source directory of the files. The * is required for -Include
    [Parameter(Mandatory=$true,Position=0)]
    #[ValidatePattern("^[a-z]\:\\.*\\\*$")] # Check for Drive letter and ending in '*'.
    [string]$SourceDir
,
    # The target location for writing files to.
    [Parameter(Mandatory=$false)][string]$DestinationRoot
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
    # Files types to -Include.
    $Filter = @("*.jpg","*.jpeg","*.mov","*.avi")
,
    $Global:isDebug = $true
,
    $PSDefaultParameterValues=@{"Write-Log:DebugMode"=$true}
,
    # Include local config and functions.
    $dependencies = @(
        "Get-Exif.ps1",
        "..\Write-log\Write-Log.ps1"
    )
,
    [string]$LogsDir = "D:\Scripts\Logs\"
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


Function Get-JpegData
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSObject[]]$InputObject
    ,
        [int]$i=0        
    )

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
            $DateTaken = (Get-Exif $Item.FullName).DateTakenFS
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
        
        # Prefer FileNameStamp if it's less than LastWriteTime[0]
        ElseIf (($obj.FileNameStamp -split "_")[0] -lt ($obj.LastWriteTime -split "_")[0]) { $obj | Add-Member -Type NoteProperty -Name Preferred -Value FileNameStamp }

        # Prefer FileNameStamp if it's less than LastWriteTime[0,1]
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

#########
# SETUP #
#########

#Locate the invocation directory and cd to it to be able to load local functions.
$parentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesDir = "$parentDir\"
cd $includesDir

# Create the log name from the script name
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

########
# MAIN #
########

# Setup target destination for writing files later
If ($DestinationRoot) { $Base = $DestinationRoot }
Else                  { $Base = $SourceDir }

# Add '\*' for gci -Include.
If ($SourceDir -notmatch "^[a-z]\:\\.*\\\*$") { $SourceDir = "$SourceDir\*" }

# Retrieve data
If ($JpegData) { Remove-Variable JpegData }
If ($RecurseDir) { $JpegData = gci -Path $SourceDir -Include $Filter -Recurse | Get-JpegData }
Else             { $JpegData = gci -Path $SourceDir -Include $Filter          | Get-JpegData }

$i = 0
$JpegData | % {
    $i++
    Write-Progress -Activity "Writing files..." `
        -Status "Processed: $i of $($JpegData.Count)" `
        -PercentComplete (($i / $JpegData.Count) * 100)

    $SourcePath      = "$($_.Path)\$($_.FileName)"
    If ($ForceDestination) { $DestinationDir = $DestinationRoot }
    Else                   { $DestinationDir  = "$Base\$($_.Year)\$($month[[int]$($_.month)])" }
    $DestinationFile = "$($_.$($_.Preferred))"
    $Destination     = "$DestinationDir\$DestinationFile$($_.Extension)"

    # Create dest dir if it doesn't exist and not Whatif
    If (!(Test-Path $DestinationDir) -and (!$WhatIf)) { mkdir $DestinationDir | Out-Null }
    If (Test-Path $Destination)
    {
        # Attempt to suffix up to 5
        For ($j = 1; $j -le 5; $j++) {
            # Iterate filename and check if exists.
            $Destination = "$DestinationDir\$DestinationFile ($j)$($_.Extension)"
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
                    Write-Log "$SourcePath,$Destination,$($_.Preferred)" -WhatIf
                    Break
                }
                Else
                {
                    # Write file and skip to next file.
                    If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
                    Else                   { Move-Item -Path $SourcePath -Destination $Destination }
                    Write-Log "$SourcePath,$Destination,$($_.Preferred)"
                    Break
                }
            }
        }
    }
    Else
    {
        If ($WhatIf)
        {
            Write-Log "$SourcePath,$Destination,$($_.Preferred)" -WhatIf
        }
        Else
        {
            If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
            Else                   { Move-Item -Path $SourcePath -Destination $Destination }
            Write-Log "$SourcePath,$Destination,$($_.Preferred)"
        }
    }
}