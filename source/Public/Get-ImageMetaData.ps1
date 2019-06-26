﻿## Get-ImageMetaData -- pull EXIF, XMP, and other data from images using the BitmapMetaData
##   Usage:  ls *.jpg | Get-ImageMetaData | ft Length, LastWriteTime, Name, "36867"
##   Note that '36867' is the decimal value of (0x9003) the EXIF tag for DateTimeOriginal
##   For more information see: http://owl.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html
##   http://poshcode.org/617
#####################################################################################################
## History:
##  - v1.0  - First release, retrieves all the data and stacks it somehow onto a FileInfo object
#####################################################################################################
# filter Get-ImageMetadata {
PARAM($file)
BEGIN {
    Try
    {
        $null = [Reflection.Assembly]::LoadWithPartialName("PresentationCore");
        
        function Get-ImageMetadata
        {
            PARAM([System.Windows.Media.Imaging.BitmapFrame]$bitmapFrame, [string]$path)
            PROCESS 
            {
                Try
                {
                    #Write-Log $path
                    if($path -is [string]) 
                    {
                        ## To read metadata, you use GetQuery.  To write metadata, you use SetQuery
                        ## To WRITE metadata, you need a writer, 
                        ##    but first you have to open the file ReadWrite, instead of Read only
                        #  $writer = $bitmapFrame.CreateInPlaceBitmapMetadataWriter();
                        #  if ($writer.TrySave()){ 
                        #     $writer.SetQuery("/tEXt/{str=Description}", "Have a nice day."); 
                        #  } else {
                        #    Write-Host "Couldn't save data" -Fore Red
                        #  }
                        $next=$bitmapFrame.MetaData.GetQuery($path);
                        if($next.Location)
                        {
                            $next | ForEach-Object { Get-ImageMetadata $bitmapFrame "$($next.Location)$_" }
                        } 
                        else 
                        {
                            if($path.Split("/")[-1] -match "{ushort=(?<code>\d+)}") 
                            {
                                # $path = "0x{0:X}" -f [int]$matches["code"]
                                $path = [int]$matches["code"]
                            }
                            Add-Member -in ($Global:ImageMetaData) -Type NoteProperty -Name $path -value $next -Force
                            # @{$path=$next}
                        }
                    } 
                    else 
                    {
                        $bitmapFrame.Metadata | ForEach-Object { Get-ImageMetadata $bitmapFrame $_ }
                    }
                }
                Catch
                {
                    Write-Log "ERROR: $($_.Exception.Message)"
                    Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
                    #Write-Log $path
                }
            }
        }
    }
    Catch
    {
        Write-Log "ERROR: $($_.Exception.Message)"
        Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
    }
}
PROCESS 
{
    Try
    {
        if($_) { $file = $_ }
        
        if($file -is [IO.FileInfo])
        {
            $file = [string]$file.FullName;
        } 
        elseif($file -is [String])
        {
            $file = [string](Resolve-Path $file)
        } 

        $Global:ImageMetaData = New-Object IO.FileInfo $file
        
        $stream = new-object IO.FileStream $file, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read);
        & {
            $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create( $stream, "None", "Default" )
            $bitmapFrame = $decoder.Frames[0];
            $bitmapFrame.Metadata | ForEach-Object {
                #Write-Log $_
                Get-ImageMetadata $bitmapFrame $_ 
            }
        }
        trap 
        { 
           Write-Error "WARNING: $_"
           continue; 
        }
        
        $stream.Close()
        $stream.Dispose()
        
        Write-Output $Global:ImageMetaData
    }
    Catch
    {
        Write-Log "ERROR: $($_.Exception.Message)"
        Write-Log "ERROR: $($_.InvocationInfo.PositionMessage.Split('+')[0])"
    }
}