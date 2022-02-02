function Format-PfaSecond {
    <#
    .SYNOPSIS
    Formats seconds into a user friendly time.
    
    .DESCRIPTION
    Formats seconds into a user friendly time.
    
    .PARAMETER Seconds
    The number of seconds to convert.

    .PARAMETER AsInt
    Return value is an integer only.

    .EXAMPLE
    Format-PfaSecond -Seconds 14400
    4 hours

    .EXAMPLE
    Format-PfaSecond -Seconds 14400 -AsInt
    4

    .NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Int64]$Seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$AsInt
    )

    $TimeSpan = New-TimeSpan -Seconds $Seconds

    switch ($TimeSpan) {
        {($TimeSpan.TotalDays % 1) -eq 0} {
            if (-not $AsInt) {
                "$($TimeSpan.TotalDays) days"
            } else {
                [Int64]$($TimeSpan.TotalDays)
            }
            break
        }
        {($TimeSpan.TotalHours % 1) -eq 0} {
            if (-not $AsInt) {
                "$($TimeSpan.TotalHours) hours"
            } else {
                [Int64]$($TimeSpan.TotalHours)
            }
            break
        }
        {($TimeSpan.TotalMinutes % 1) -eq 0} {
            if (-not $AsInt) {
                "$($TimeSpan.TotalMinutes) minutes"
            } else {
                [Int64]$($TimeSpan.TotalMinutes)
            }
            break
        } default {
            if (-not $AsInt) {
                "$($TimeSpan.TotalSeconds) seconds"
            } else {
                [Int64]$($TimeSpan.TotalSeconds)
            }
            break
        }
    }
}