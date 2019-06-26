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
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      Position = 0)]
    $file
  )

  Try {
    #Write-Log $file
    $ImageMetaData = Get-ImageMetaData -file $file

    # ExifDTOrig (0x9003): Date and time when the original image data was generated. For a DSC, the date 
    # and time when the picture was taken. The format is YYYY:MM:DD HH:MM:SS with time shown in 24-hour 
    # format and the date and time separated by one blank character (0x2000). The character string length 
    # is 20 bytes including the NULL terminator. When the field is empty, it is treated as unknown.
    If ($ImageMetaData.36867) {
      $ExifDTOrig = $ImageMetaData.36867
      If ($ExifDTOrig -match "\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d") {
        $ExifDTOrig = $ExifDTOrig.Replace(":", "").Replace(" ", "_")
      }
      Else {
        # Sometimes EXIF data taken is a datetime string
        Try { $ExifDTOrig = ([datetime]$ExifDTOrig).ToString("yyyyMMdd_HHmmss") }
        Catch { }
      }
      # Confirm output is expected
      If ($ExifDTOrig -notmatch "\d{8}_\d{6}") {
        #Write-Log "ERROR: The file $file has unsupported ExifDTOrig(36867|0x9003) data." -DebugMode
        $ExifDTOrig = $false
      }
    }

    # ExifDTDigitized (0x9004): Date and time when the image was stored as digital data. If, for example, 
    # an image was captured by DSC and at the same time the file was recorded, then DateTimeOriginal and 
    # DateTimeDigitized will have the same contents. The format is YYYY:MM:DD HH:MM:SS with time shown in 
    # 24-hour format and the date and time separated by one blank character (0x2000). The character string 
    # length is 20 bytes including the NULL terminator. When the field is empty, it is treated as unknown.
    If ($ImageMetaData.36868) {
      $ExifDTDigitized = $ImageMetaData.36868
      If ($ExifDTDigitized -match "\d\d\d\d:\d\d:\d\d \d\d:\d\d:\d\d") {
        $ExifDTDigitized = $ExifDTDigitized.Replace(":", "").Replace(" ", "_")
      }
      Else {
        # Sometimes EXIF data taken is a datetime string
        $ExifDTDigitized = ([datetime]$ExifDTDigitized).ToString("yyyyMMdd_HHmmss")
      }
      # Confirm output is expected
      If ($ExifDTDigitized -notmatch "\d{8}_\d{6}") {
        #Write-Log "ERROR: The file $file has unsupported ExifDTDigitized(36868|0x9004) data." -DebugMode
        $ExifDTDigitized = $false
      }
    }

    # Error out if both EXIF types exist
    If ($ExifDTOrig -and $ExifDTDigitized) {
      # If metadata dates match then return one.
      If ($ExifDTOrig -like $ExifDTDigitized) { $ExifDate = $ExifDTOrig }
      Else {
        Write-Log "ERROR: Two Exif types exist for file $file. ExifDTOrig: $ExifDTOrig, ExifDTDigitized: $ExifDTDigitized"
        Exit 1
      }
    }

    # Decide which exif metadata to use.
    If ($ExifDTOrig) {
      #Write-Log "Using ExifDTOrig"
      $ExifDate = $ExifDTOrig
    }
    If ($ExifDTDigitized) {
      #Write-Log "Using ExifDTDigitized"
      $ExifDate = $ExifDTDigitized
    }

    # Parse XMP metadata
    If ($ImageMetaData.'/xmp/exif:DateTimeOriginal') {
      $XmpDate = $ImageMetaData.'/xmp/exif:DateTimeOriginal'
      $XmpDate = ([datetime]$XmpDate).ToString("yyyyMMdd_HHmmss")
      # Confirm output is expected
      If ($XmpDate -notmatch "\d{8}_\d{6}") { Write-Log "ERROR: The file $file has unsupported xmp data."; Exit 1 }
    }

    # Error out if both exist
    If ($ExifDate -and $XmpDate) {
      # If metadata dates match then return one
      If ([string]$ExifDate -like [string]$XmpDate) { Return $ExifDate }
      Else {
        Write-Log "ERROR: Both Exif date ($ExifDate) and XMP date ($XmpDate) exist for file $file."
        Exit 1
      }
    }
    # Pick whichever exists
    If ($ExifDate) { Return $ExifDate }
    If ($XmpDate ) { Return $XmpDate }
  }
  Catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
  }
}