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


Function Get-JpegData
{
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSObject[]]$InputObject
    )

    $i=0
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

        $prop = [ordered]@{
            FileName      = $Item.Name
            DateTaken      = (Get-Exif $Item.FullName).DateTakenFS
            FileNameStamp  = $FileNameStamp
            LastWriteTime = $Item.LastWriteTime.ToString('yyyyMMdd_HHmmss')
            Path           = $Item.Directory
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

########
# MAIN #
########

#Locate the invocation directory and cd to it to be able to load local functions.
$parentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesDir = "$parentDir\"
cd $includesDir

# Include local config and functions using call operator
. .\Get-Exif.ps1

$Global:isDebug = $false
$Global:log=@{
    Location = "D:\Scripts\Logs\"
    Name = "$($MyInvocation.MyCommand.Name)_$(Get-Date -UFormat %Y-%m-%d.%H-%M-%S)"
    Extension = ".log"
}

# The * is required for -Include
$SourceDir = "E:\Pictures\Camera\testing2\*"
$Filter = @("*.jpg","*.jpeg")

$JpegData = gci -Path $SourceDir -Include $Filter | Get-JpegData

$i = 0
$JpegData | % {
    $i++
    Write-Progress -Activity "Writing files..." `
        -Status "Processed: $i of $($JpegData.Count)" `
        -PercentComplete (($i / $JpegData.Count) * 100)

    $SourcePath = "$($_.Path)\$($_.FileName)"
    $Destination = "$($_.Path)\$($_.Year)\$($month[[int]$($_.month)])\$($_.$($_.Preferred)).jpg"
    Write-Log "$SourcePath -Destination $Destination"
    Move-Item -Path $SourcePath -Destination $Destination -WhatIf
}