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
        [Parameter(Mandatory=$true)]
        $SourceDir
    )
    $i=0
    $Filter = @("*.jpg","*.jpeg")
    $jpegs = gci -Path $SourceDir -Include $Filter
    $hash = @()
    Foreach ($jpeg in $jpegs) {
        $i++
        Write-Progress -Activity "Reading files..." `
            -Status "Processed: $i of $($jpegs.Count)" `
            -PercentComplete (($i / $jpegs.Count) * 100)

        #$m = $jpeg.BaseName -match "\d{8}_\d{6}"
        If     ($jpeg.BaseName -match "\d{8}_\d{6}")                         { $FileNameStamp = $Matches[0] }
        ElseIf ($jpeg.BaseName -match "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}") { $FileNameStamp = $Matches[0] -replace "-","" }
        Else { $FileNameStamp = $false }

        $prop = [ordered]@{
            FileName      = $jpeg.Name
            DateTaken      = (Get-Exif $jpeg.FullName).DateTakenFS
            FileNameStamp  = $FileNameStamp
            LastWriteTime = $jpeg.LastWriteTime.ToString('yyyyMMdd_HHmmss')
            Path           = $jpeg.Directory
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
        $hash += $obj
    }
    $hash
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

$JpegData = Get-JpegData -SourceDir "E:\Pictures\Camera\*"

$i = 0
Foreach ($item in $JpegData)
{
    $i++
    Write-Progress -Activity "Writing files..." `
        -Status "Processed: $i of $($JpegData.Count)" `
        -PercentComplete (($i / $JpegData.Count) * 100)

    Write-Log "$($item.Path)\$($item.FileName) -Destination $($item.Path)\$($item.Year)\$($month[[int]$($item.month)])\$($item.$($item.Preferred)).jpg"
    #Move-Item -Path ($item.Path + "\" + $item.FileName) -Destination ($item.Path + "\" + $item.Year + "\" + $month[($item.month)] + "\" + $item.DateTaken) }
}

##$dateTakenForFilename = GetDateTakenForFilename("D:\videos\test\153-P1040727.jpg")
##echo $dateTakenForFilename
