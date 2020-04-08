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
[CmdletBinding(SupportsShouldProcess)]
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
  [string]$DestinationRoot
)

Write-Host 'do things'
