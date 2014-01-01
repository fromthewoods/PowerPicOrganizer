<#
.Synopsis
   Returns an single item of Generic Exif data
.DESCRIPTION
   Returns the data part of a single EXIF property item -not the type. 
.EXAMPLE
   Get-ExifItem -ImageFile "E:\Pictures\Camera\Testing\Date.jpg" -ExifID 36867
   Returns the Camera model string
.EXAMPLE
   (gci -Path "E:\Pictures\Camera\Testing").FullName | Get-ExifItem -ExifID 36867
.Parameter ImageFile
   The image from which the data will be read 
.Parameter ExifID
   The ID of the required data field. 
   The module defines constants with names beginning $ExifID for the most used ones.
   List of ID's and definitions: http://msdn.microsoft.com/en-us/library/ms534416.aspx 
#>

Function Get-ExifItem
{
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        $ImageFile
    ,
        [Parameter(Mandatory=$true)]
        $ExifID
    )
    Process
    {
        $FileStream=New-Object System.IO.FileStream($ImageFile,
                                                    [System.IO.FileMode]::Open,
                                                    [System.IO.FileAccess]::Read,
                                                    [System.IO.FileShare]::Read,
                                                    1024,     # Buffer size
                                                    [System.IO.FileOptions]::SequentialScan
                                                    )
        $Img = [System.Drawing.Imaging.Metafile]::FromStream($FileStream)
        Try { 
            $ExifDT = $Img.GetPropertyItem($ExifID)
        } Catch {
            #$_.Exception
            #Write-Log "$ImageFile :: Error getting exif item $ExifID - probably doesn't exist"
            Return $false
        }

        $ExifDtString=[System.Text.Encoding]::ASCII.GetString($ExifDT.Value)
                
        $DateTime=[datetime]::ParseExact($ExifDtString,"yyyy:MM:dd HH:mm:ss`0",$Null)
        $FileStream.Close(); $Img.Dispose()
        Return $DateTime
    }
}

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
Function Get-ImageDateTaken
{
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        $fileName
    )
    Process
    {
        $date = Get-ExifItem -ImageFile $fileName -ExifID 36867
        If ($date) {
            $result = $date.ToString('yyyyMMdd_HHmmss')
            Write-Log "$fileName  DateTaken: $result" -DebugMode
            Return $result
        } Else { 
            Write-Log "$fileName  ERROR getting exif item 36867 - probably doesn't exist" -DebugMode
            Return $false
        }
    }
}

Function Get-JpegData
{
    Param
    (
        [Parameter(Mandatory=$true)]
        $folderToRenameFilesIn
    )

    gci -Path $folderToRenameFilesIn -Filter *.jpg | % {
        #$newStamp = Get-ImageDateTaken -fileName $_.FullName
        #$currentStamp = $_.BaseName

        #$m = $_.BaseName -match "\d{8}_\d{6}"
        If     ($_.BaseName -match "\d{8}_\d{6}")                         { $FileNameStamp = $Matches[0] }
        ElseIf ($_.BaseName -match "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}") { $FileNameStamp = $Matches[0] -replace "-","" }
        Else { $FileNameStamp = $false }

        $prop = [ordered]@{
            FileName      = $_.Name
            DateTaken      = Get-ImageDateTaken -fileName $_.FullName
            FileNameStamp  = $FileNameStamp
            LastWriteTime = $_.LastWriteTime.ToString('yyyyMMdd_HHmmss')
            #Path           = $_.Directory
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
        Return $obj
    }
}

$Global:log=@{
    Location = "D:\Scripts\Logs\"
    Name = "$($MyInvocation.MyCommand.Name)_$(Get-Date -UFormat %Y-%m-%d.%H-%M-%S)"
    Extension = ".log"
}
$Global:isDebug = $false
#$log.Location + $log.Name + $log.Extension

Write-Log "Debug Message" -DebugMode
Write-Log "Regular Message"

$obj = Get-JpegData -folderToRenameFilesIn "E:\Pictures\Camera"

$obj | FT

##$dateTakenForFilename = GetDateTakenForFilename("D:\videos\test\153-P1040727.jpg")
##echo $dateTakenForFilename
