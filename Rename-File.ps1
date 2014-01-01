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

#[CmdletBinding()]
#Param
#(
#    # The source path containing files to be renamed.
#    [Parameter(Mandatory=$true,
#               ValueFromPipelineByPropertyName=$true,
#               Position=0)]
#    $Path = "E:\Pictures\Camera\"
#,
#    # The destination directory where the renamed files will be placed.
#    [Parameter(Mandatory=$true,
#               Position=1)]
#    $Destination = "E:\Pictures\Camera\Testing\"
#,
#    # Specify the extension of the files to be renamed
#    [Parameter(Mandatory=$true,
#               Position=2)]
#    [ValidateSet("*.jpg")]
#    $Extension = "*.jpg"
#,
#    [switch]$DeleteSourceFiles
#)

$Path = "E:\Pictures\Camera\"
$Destination = "E:\Pictures\Camera\Testing\"
$Extension = "*.jpg"
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
function Verb-Noun
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $File,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
        $prefix = $File.LastWriteTime.ToString('yyyyMMdd_HHmmss')
        $Name = $prefix + $File.Name
    }
    End
    {
    }
}

<#
.Synopsis
   Returns an single item of Generic Exif data
.Description
   Returns the data part of a single EXIF property item -not the type. 
.Example
   C:\PS> Get-ExifItem -image $image -ExifID $ExifIDModel
   Returns the Camera model string
.Parameter image
   The image from which the data will be read 
.Parameter ExifID
   The ID of the required data field. 
   The module defines constants with names beginning $ExifID for the most used ones. 
#>
Function Get-ExifItem
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        [__ComObject]
        $Image
    ,
        [Parameter(Mandatory=$true)]
        $ExifID = "36867"
    )

    Process
    {
        Foreach ($ID in $ExifID) {
            Try   {$item = $Image.Properties.Item("$ID")  }
            Catch { Write-Verbose "Error getting exif item $ID - probably doesn't exist"  ; continue   }
            If ($item) {
                Write-Verbose "Type is $($item.type)"
                # "Rational"=1006;"URational"=1007
                #If (($item.Type -eq 1007) -or ($item.Type -eq 1006) ) {
                #    If (($ExifID -eq $ExifIDExposuretime) -and ($item.Value.Numerator -eq 1)) {"1/$($item.Value.Denominator)"} 
                #    Else {$item.value.value}
                #}
                # "VectorOfByte"=1101
                #ElseIf (($item.type -eq 1101) -or ($item.type -eq 1100)) {$item.value.string() }
                #Else {
                    $item.value
                #}
            }
        }
    }
}

Get-ExifItem -Image (gci -Path $Path -Filter $Extension).FullName