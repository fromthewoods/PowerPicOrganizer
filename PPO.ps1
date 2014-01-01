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
            Write-Log "$fileName  CreationDate: $result"
            Return $result
        } Else { 
            Write-Log "$fileName  ERROR getting exif item 36867 - probably doesn't exist"
            Return $false
        }
    }
}

Function PrefixAllJpegsWithDateTaken($folderToRenameFilesIn)
{
    foreach ($filepath in [System.IO.Directory]::GetFiles($folderToRenameFilesIn))
    {
        $file = New-Object System.IO.FileInfo($filepath);
        $filename = $file.Name
        
        $datePrefix = $file.LastWriteTime.ToString('yyyyMMdd_HHmmss')
        
        if ($filename.EndsWith(".jpg"))
        {
           $dateTaken = GetDateTakenForFilename($filepath)
           echo "Date Taken: $dateTaken"
           $datePrefix = $dateTaken
        }
        
        $targetPath = $folderToRenameFilesIn + '\' + $datePrefix + $filename
        echo $targetPath
        [System.IO.File]::Copy($filepath, $targetPath)
       # $newfile = New-Object System.IO.FileInfo($targetPath);
       # $newCreationDate = $newfile.CreationTime.ToString('yyyyMMdd-hhmmss')
       # $newLastWriteTime = $newfile.LastWriteTime.ToString('yyyyMMdd-hhmmss') 
       # echo "Original Filename: $filename  Creation Time: $date  Last Write Time:  $lastWriteTime Target Path: $targetPath New File Creation Time: $newCreationDate New File Last Write Time:  $newLastWriteTime"
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

#PrefixAllJpegsWithDateTaken("d:\videos\test")
(gci -Path "E:\Pictures\Camera\Testing").FullName | Get-ImageDateTaken


##$dateTakenForFilename = GetDateTakenForFilename("D:\videos\test\153-P1040727.jpg")
##echo $dateTakenForFilename
