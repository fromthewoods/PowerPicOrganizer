$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\..\Public\$sut"

Describe -Name 'Get-SourceImageFile' -Tag 'Unit' -Fixture {
  Context -Name 'Primary Tests' -Fixture {
    It -Name 'should exist' -Test {
      (Get-Command Get-SourceImageFile).Name | Should -Be 'Get-SourceImageFile'
    }
    It -Name 'should throw when an error is encountered' -Test {
      Mock -CommandName Write-Verbose -MockWith { Throw 'Mocked' }
      { Get-SourceImageFile -Param1 'i' -Param2 1 } | Should -Throw 'Mocked'
    }
  }
}