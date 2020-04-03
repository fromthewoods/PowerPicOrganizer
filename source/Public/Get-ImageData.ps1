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
  [CmdletBinding(SupportsShouldProcess = $True)]
  [OutputType([object])]
  Param (
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $false,
      Position = 0)]
    [string[]]$FileName
  )

  Begin {
    Add-Type -AssemblyName System.Drawing
    $imageExtensions = @(
      '.jpg'
    )
  }
  Process {
    $fileObj = Get-Item -Path $FileName
    if ($fileObj.Extension -in $imageExtensions) {
      try {
        $bitMap = New-Object System.Drawing.Bitmap($FileName)

        $byteArray = $bitMap.GetPropertyItem(36867).Value # Date Taken
        $bitMap.Dispose()

        if ($byteArray) {
          $string = [System.Text.Encoding]::ASCII.GetString($byteArray)
          $exactDate = [datetime]::ParseExact($string, "yyyy:MM:dd HH:mm:ss`0", $Null)
          return $exactDate
        }
      }
      catch {
        # Custom message here Write-Verbose
        $message = $_.Exception.Message
        $position = $_.InvocationInfo.PositionMessage.Split('+')[0]
        Write-Verbose "ERROR: [$message]"
        Write-Verbose "ERROR: [$position]"
        Write-Warning "Could not extract EXIF 'DateTaken'. Falling back to file 'lastWriteTime'."
        # Throw $_
      }
    }
    else {
      return $fileObj.LastWriteTime
    }
  }
  End {
  }
}