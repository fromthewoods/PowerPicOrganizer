$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\..\Public\$sut"

Describe "Get-ImageData" {
  It -Name 'should exist' -Test {
    Get-Command -Name 'Get-ImageData' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
  }
  It -Name "returns exif for image" -Test {
    Get-ImageData -FileName "$here\Resources\Images\2020-03-01 13.53.42.jpg" -Verbose | Should -BeLike '*13:53:42*'
  }
  It -Name "returns lastwritetime for non image" -Test {
    $testFile = "$here\Resources\Images\video.mkv"
    $expected = (Get-Item -Path $testFile).LastWriteTime
    Get-ImageData -FileName $testFile -Verbose | Should -Be $expected
  }
}
