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
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [PSObject[]]$InputObject
    ,
    [int]$i = 0        
  )

  Try {
    If ($arr) { Remove-Variable arr }
    $arr = @()

    Foreach ($Item in $Input) {
      $i++
      Write-Progress -Activity "Reading files..." `
        -Status "Processed: $i of $($Input.Count)" `
        -PercentComplete (($i / $Input.Count) * 100)

      #$m = $jpeg.BaseName -match "\d{8}_\d{6}"
      If ($Item.BaseName -match "\d{8}_\d{6}") { $FileNameStamp = $Matches[0] }
      ElseIf ($Item.BaseName -match "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}") { $FileNameStamp = $Matches[0] -replace "-", "" }
      Else { $FileNameStamp = $false }

      # Get Exif data if jpg file.
      If ($Item.Extension -like "*.jpg" -or $Item.Extension -like "*.jpeg") {
        $DateTaken = Get-DateTaken $Item.FullName
      }
      Else {
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
      If ($obj.DateTaken) { $obj | Add-Member -Type NoteProperty -Name Preferred -Value DateTaken }
            
      # Prefer FileNameStamp if it's less than LastWriteTime[0] (yyyyMMdd)
      ElseIf (($obj.FileNameStamp -split "_")[0] -lt ($obj.LastWriteTime -split "_")[0]) { $obj | Add-Member -Type NoteProperty -Name Preferred -Value FileNameStamp }

      # Prefer FileNameStamp if it's less than LastWriteTime[0,1] (yyyyMMdd,HHmmmss)
      ElseIf (($obj.FileNameStamp -split "_")[0] -eq ($obj.LastWriteTime -split "_")[0] `
          -and (($obj.FileNameStamp -split "_")[1] -lt ($obj.LastWriteTime -split "_")[1])) { $obj | Add-Member -Type NoteProperty -Name Preferred -Value FileNameStamp }
            
      # Last resort is prefer LastWriteTime
      Else { $obj | Add-Member -Type NoteProperty -Name Preferred -Value LastWriteTime }

      $obj | Add-Member -Type NoteProperty -Name Year -Value (($obj.($obj.Preferred) -split "_")[0]).substring(0, 4)
      $obj | Add-Member -Type NoteProperty -Name Month -Value (($obj.($obj.Preferred) -split "_")[0]).substring(4, 2)

      $arr += $obj
    }
    $arr
  }
  Catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
  }
}