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
  [Parameter(Mandatory = $true, Position = 0)]
  #[ValidatePattern("^[a-z]\:\\.*\\\*$")] # Check for Drive letter and ending in '*'.
  [Alias('S')]
  [string]$SourceDir,

  # The target location for writing files to.
  [Alias('D')]
  [Parameter(Mandatory = $false, Position = 1)]
  [string]$DestinationRoot,

  [string]$LogsDir = $PSScriptRoot,

  # Blocks the script from automatically generating year/month sub-directories.
  # Can only be used when $DesinationRoot is present.
  [switch]$ForceDestination,

  # Toggles Copy instead of Move for writing files.
  [switch]$PreserveOriginal,

  # Toggle recurse
  [switch]$RecurseDir,

  # Verify changes before performing them
  [switch]$WhatIf,

  # If the target file exists (not full path) skip it. This is different than if the
  # entire source path matches the dest path.
  [switch]$SkipDupeFile,

  # File types to -Include.
  $Filter = @("*.jpg", "*.jpeg", "*.mov", "*.mpg", "*.mp4", "*.avi", "*.NEF"),

  $Global:isDebug = $true
)

#region ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ SETUP ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

$PSDefaultParameterValues = @{
  "Write-Log:DebugMode" = $true
  "Write-Log:LogFile"   = $LogsDir
}

# Include local config and functions.
$dependencies = @("..\Write-log\Write-Log.psd1")

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

Push-Location

#Locate the invocation directory and cd to it to be able to load local functions.
$parentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesDir = "$parentDir\"
cd $includesDir

# Create the log name from the script name
If (!$LogsDir) { $LogsDir = $includesDir }
$Global:log = @{
  Location  = $LogsDir
  Name      = "$($MyInvocation.MyCommand.Name)_$(Get-Date -UFormat %Y-%m-%d.%H-%M-%S)"
  Extension = ".log"
}
$logFile = $log.Location + $log.Name + $log.Extension

# Source local config and functions using call operator (dot sourcing)
$dependencies | % {
  If (Test-Path ".\$_") {
    Import-Module ".\$_"
    Write-Verbose "$(Get-Date) Loaded dependency: $_" #| Tee-Object -FilePath $logFile -Append
  }
  Else {
    Write-Warning "$(Get-Date) ERROR: Failed to load dependency: $_" #| Tee-Object -FilePath $logFile -Append
    Exit 1
  }
}
#endregion

#region ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ MAIN ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Try {
  #$WhatIf=$true
  If ($JpegData) { Remove-Variable JpegData }
  # Setup target destination for writing files later
  If ($DestinationRoot) { $Base = $DestinationRoot }
  Else { $Base = $SourceDir }
    
  # Check to see if * (wildcard) is used in source path
  If ($SourceDir -match "^[a-z]\:\\.*\\.*\*.*$") {
    # Retrieve data
    If ($RecurseDir) { $JpegData = gci -Path $SourceDir -Recurse | Get-JpegData }
    Else { $JpegData = gci -Path $SourceDir | Get-JpegData }
  }
  # Add '\*' for gci -Include.
  ElseIf ($SourceDir -notmatch "^[a-z]\:\\.*\\\*$") {
    $SourceDir = "$SourceDir\*"
    # Retrieve data
    If ($RecurseDir) { $JpegData = gci -Path $SourceDir -Include $Filter -Recurse | Get-JpegData }
    Else { $JpegData = gci -Path $SourceDir -Include $Filter | Get-JpegData }
  }
  Else { Throw "Invalid source path: $SourceDir" }
   
  # Process the files
  $i = 0
  Foreach ($item in $JpegData) {
    $i++
    If ($JpegData.Count -gt 1) {
      Write-Progress -Activity "Writing files..." `
        -Status "Processed: $i of $($JpegData.Count)" `
        -PercentComplete (($i / $JpegData.Count) * 100)
    } 
    $SourcePath = "$($item.Path)\$($item.FileName)"
    If ($ForceDestination) { $DestinationDir = $DestinationRoot }
    Else { $DestinationDir = "$Base\$($item.Year)\$($month[[int]$($item.month)])" }
    $DestinationFile = "$($item.$($item.Preferred))"
    $Destination = "$DestinationDir\$DestinationFile$($item.Extension)"
    
    # Create dest dir if it doesn't exist and not Whatif
    If (!(Test-Path $DestinationDir) -and (!$WhatIf)) { mkdir $DestinationDir | Out-Null }
    
    If ($SourcePath -eq $Destination) {
      Write-Log "Skipping file because it is already properly named: $SourcePath"
    }
    ElseIf ((Test-Path $Destination) -and $SkipDupeFile) { 
      Write-Log "SKIP $SourcePath,$Destination SKIP"
      Continue
    }
    ElseIf (Test-Path $Destination) {
      # Attempt to suffix up to 5
      For ($j = 1; $j -le 5; $j++) {
        # Iterate filename and check if exists.
        $Destination = "$DestinationDir\$DestinationFile ($j)$($item.Extension)"
        If (Test-Path $Destination) {
          # The file still exists after 5 iterations, skip to next file.
          If ($j -eq 5) {
            If ($WhatIf) { Write-Log "$SourcePath,$Destination,ExistsAlready" -WhatIf ; Break }
            Else { Write-Log "$SourcePath,$Destination,ExistsAlready"         ; Break }
          }
        }
        Else {
          If ($WhatIf) {
            Write-Log "$SourcePath,$Destination,$($item.Preferred)" -WhatIf
            Break
          }
          Else {
            # Write file and skip to next file.
            If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
            Else { Move-Item -Path $SourcePath -Destination $Destination }
            Write-Log "$SourcePath,$Destination,$($item.Preferred)"
            Break
          }
        }
      }
    }
    Else {
      If ($WhatIf) {
        Write-Log "$SourcePath,$Destination,$($item.Preferred)"
      }
      Else {
        If ($PreserveOriginal) { Copy-Item -Path $SourcePath -Destination $Destination }
        Else { Move-Item -Path $SourcePath -Destination $Destination }
        Write-Log "$SourcePath,$Destination,$($item.Preferred)"
      }
    }
  }
}
Catch {
  Write-Log "ERROR: $($_.Exception.Message)"
  Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
}
Pop-Location
#endregion