function Format-PfaSecondsFromMidnight {
    <#
    .SYNOPSIS
    Formats seconds from midnight into a user friendly time.
    
    .DESCRIPTION
    Formats seconds from midnight into a user friendly time.
    
    .PARAMETER Seconds
    The number of seconds to convert.

    .PARAMETER AsInt
    Return value is an integer only.

    .EXAMPLE
    Format-PfaSecondsFromMidnight -Seconds 14400
    4am

    .EXAMPLE
    Format-PfaSecondsFromMidnight -Seconds 14400 -AsInt
    4

    .NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)][AllowNull()]
        $Seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$AsInt
    )
    if ($null -ne $Seconds) {
        if (-not $AsInt) {
            (Get-Date).Date.AddSeconds([Int64]$Seconds).ToString("htt").ToLower()
        } else {
            [Int64](Get-Date).Date.AddSeconds([Int64]$Seconds).ToString("h ").Trim()
        }
    } else {
        if (-not $AsInt) {
            "-"
        } else {
            [Int64]0
        }
    }
}