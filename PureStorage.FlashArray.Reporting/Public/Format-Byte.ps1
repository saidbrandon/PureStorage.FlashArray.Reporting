function Format-Byte {
    <#
    .SYNOPSIS
    Formats an integer size into a user friendly byte size.
    
    .DESCRIPTION
    Formats an integer size into a user friendly value of Bytes, KB, MB, GB, TB, PB size. For Example, 259471491072 returns 241.65 GB.
    
    .PARAMETER Bytes
    The number of bytes to convert.
    
    .PARAMETER Precision
    The maximum number of decimal places to maintain.
    
    .PARAMETER Prefix
    Specifies a string to add to the beginining of the resultant string.
    
    .PARAMETER Suffix
    Specifies a string to add to the end of the resultant string.
    
    .EXAMPLE
    Format-Byte -Bytes 134217728
    128.00 MB
    
    .EXAMPLE
    Format-Byte -Bytes 259471491072
    241.65 GB

    .EXAMPLE
    Format-Byte -Bytes 151398131 -Suffix "/s"
    144.38 MB/s

    .NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)][Int64]$Bytes,
        [Int]$Precision = 2,
        [String]$Prefix,
        [String]$Suffix
    )

    switch ($Bytes) {
        {$Bytes -ge 1PB} {
            $result = "$Prefix{0:$("N$Precision")} PB$Suffix" -f [Math]::Round(($Bytes / 1PB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -ge 1TB} {
            $result = "$Prefix{0:$("N$Precision")} TB$Suffix" -f [Math]::Round(($Bytes / 1TB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -ge 1GB} {
            $result = "$Prefix{0:$("N$Precision")} GB$Suffix" -f [Math]::Round(($Bytes / 1GB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -ge 1MB} {
            $result = "$Prefix{0:$("N$Precision")} MB$Suffix" -f [Math]::Round(($Bytes / 1MB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -ge 1KB} {
            $result = "$Prefix{0:$("N$Precision")} KB$Suffix" -f [Math]::Round(($Bytes / 1KB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -le -1PB} {
            $result = "$Prefix{0:$("N$Precision")} PB$Suffix" -f [Math]::Round(($Bytes / 1PB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -le -1TB} {
            $result = "$Prefix{0:$("N$Precision")} TB$Suffix" -f [Math]::Round(($Bytes / 1TB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -le -1GB} {
            $result = "$Prefix{0:$("N$Precision")} GB$Suffix" -f [Math]::Round(($Bytes / 1GB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -le -1MB} {
            $result = "$Prefix{0:$("N$Precision")} MB$Suffix" -f [Math]::Round(($Bytes / 1MB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        }
        {$Bytes -le -1KB} {
            $result = "$Prefix{0:$("N$Precision")} KB$Suffix" -f [Math]::Round(($Bytes / 1KB), $Precision, [MidPointRounding]::AwayFromZero)
            break
        } default {
            $result = "$Prefix$Bytes B$Suffix"
            break
        }
    }
    return $result
}
