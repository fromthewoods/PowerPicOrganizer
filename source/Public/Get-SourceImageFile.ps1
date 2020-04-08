function Get-SourceImageFile {
  <#
    .SYNOPSIS
      Short description
    .DESCRIPTION
      Long description
    .PARAMETER Param1
      Specifies...
    .EXAMPLE
      Example here
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([object])]
  Param (
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $false,
      Position = 0)]
    [string]$Param1,

    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $false,
      Position = 1)]
    [string]$Param2
  )

  Begin { }
  Process {
    Try {
      Write-Verbose 'What are we doing?'
      If ($sometest -eq $true) {
        Write-Verbose 'Some message'
        Return $true
      }
      Else {
        Write-Verbose 'This did not work so return false.'
        Return $false
      }
    }
    Catch {
      # Custom message here Write-Verbose
      $message = $_.Exception.Message
      $position = $_.InvocationInfo.PositionMessage.Split('+')[0]
      Write-Verbose "ERROR: $message"
      Write-Verbose "ERROR: $position"
      Throw "$message $position"
    }
  }
}