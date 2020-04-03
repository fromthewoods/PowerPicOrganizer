﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\..\Public\$sut"

Describe "Get-ImageData" {
  It -Name 'should exist' -Test {
    Get-Command -Name 'Get-ImageData' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
  }

  Context -Name 'Image' -Fixture {
    $testFile = "$here\Resources\Images\2020-03-01 13.53.42.jpg"
    $actual = Get-ImageData -FileName $testFile -Verbose

    It -Name 'returns DateTime Object' -Test {
      $actual.GetType().Name | Should -Be 'DateTime'
    }

    It -Name "returns exif date taken for image" -Test {
      $actual | Should -BeLike '*13:53:42*'
    }

    It -Name 'should fall back to lastwritetime if bitmap fails' -Test {
      Mock -CommandName New-Object -MockWith { Throw 'Failed'}
      Mock -CommandName Write-Warning -MockWith { }
      $actual = Get-ImageData -FileName $testFile -Verbose
      $expected = (Get-Item -Path $testFile).LastWriteTime

      $actual | Should -Be $expected
      Assert-MockCalled -CommandName Write-Warning -Times 1 -Exactly
    }
  }

  Context -Name 'Video' -Fixture {
    $testFile = "$here\Resources\Images\video.mkv"
    $actual = Get-ImageData -FileName $testFile -Verbose
    $expected = (Get-Item -Path $testFile).LastWriteTime

    It -Name 'returns DateTime Object' -Test {
      $actual.GetType().Name | Should -Be 'DateTime'
    }

    It -Name "returns lastwritetime for non image" -Test {
      $actual | Should -Be $expected
    }
  }

}
