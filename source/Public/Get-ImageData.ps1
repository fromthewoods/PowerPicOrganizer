function Get-ImageData {
  <#
    .SYNOPSIS
      Short description
    .DESCRIPTION
      Long description
    .PARAMETER FileName
      Specifies...
    .EXAMPLE
      Example here
  #>
  [CmdletBinding()]
  [OutputType([object])]
  Param (
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      Position = 0)]
    [string]$FileName
  )

  Begin {
    Add-Type -AssemblyName System.Drawing
    $imageExtensions = @(
      '.jpg'
      '.jpeg'
    )
  }
  Process {
    $fileObj = Get-Item -Path $FileName
    if ($fileObj.Extension -in $imageExtensions) {
      try {
        $bitMap = New-Object System.Drawing.Bitmap($FileName)

        $dateTakenByteArray = $bitMap.GetPropertyItem(36867).Value # Date Taken
        $bitMap.Dispose()

        if ($dateTakenByteArray) {
          $string = [System.Text.Encoding]::ASCII.GetString($dateTakenByteArray)
          $dateObject = [datetime]::ParseExact($string, "yyyy:MM:dd HH:mm:ss`0", $Null)
          return [PSCustomObject]@{
            DateTaken = $dateObject
          }
        }
      }
      catch {
        Write-Warning "Could not extract EXIF 'DateTaken'. Falling back to file 'lastWriteTime'."
        return [PSCustomObject]@{
          DateTaken = $fileObj.LastWriteTime
        }
      }
    }
    else {
      return [PSCustomObject]@{
        DateTaken = $fileObj.LastWriteTime
      }
    }
  }
  End {
  }
}