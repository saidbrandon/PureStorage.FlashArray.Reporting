function Invoke-PfaApiRequest {
    <#
    .SYNOPSIS
    Wrapper for Invoke-WebRequest/Invoke-RestMethod with specifics related to the FlashArray REST API.

    .DESCRIPTION
    Wrapper for Invoke-WebRequest/Invoke-RestMethod with specifics related to the FlashArray REST API.

    .PARAMETER Array
    FlashArray object to query.

    .PARAMETER Request
    Username and Password needed for authentication.

    .PARAMETER Method
    Specifies the method used for the web request. The acceptable values for this parameter are:
        Delete
        Get
        Post
        Put

    .PARAMETER Path
    API URI as defined in their documentation, e.g. /arrays or /arrays?sort&limit=1

    .PARAMETER ApiVersion
    REST API version to interact with. A value of 1 or 2 will use the latest version of that API endpoint. You can optionally use the full version to utilize an older endpoint such as 1.18.

    .PARAMETER SkipCertificateCheck
    Skips certificate validation checks. This includes all validations such as expiration, revocation, trusted root authority, etc.
    ** WARNING **
    Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .PARAMETER RawResponse
    Send Invoke-WebRequest response down the pipeline for user processing instead of response data.

    .EXAMPLE
    ApiVersion = 2
    Displays a list of connection paths to each of the connected arrays.
    (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/arrays" -SkipCertificateCheck -ErrorAction Stop).Items

    .EXAMPLE
    ApiVersion = 1
    Lists the attributes for the array, including the array name, Purity version and Purity revision number.
    Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/array" -ApiVersion 1 -SkipCertificateCheck -ErrorAction Stop

	.NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi]$Array,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('WebRequest', 'RestMethod')]
        [String]$Request,

        [Parameter(Position = 2)]
        [ValidateSet('Delete', 'Get', 'Post', 'Put')]
        [String]$Method = "Get",

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(Position = 4)]
        [ValidateScript({
            if ($_ -eq 1 -or $_ -eq 2) {
                $_ -eq 1 -or $_ -eq 2
            } elseif (([Version]$_).Major -eq 1 -or ([Version]$_).Major -eq 2) {
                return $Array.ApiVersion[([Version]$_).Major].Contains($_)
            }
        })]
        [String]$ApiVersion = 2,

        [Parameter(Position = 5)]
        [Switch]$RawResponse = $false,

        [Switch]$SkipCertificateCheck
    )

    begin {
        if ($ApiVersion -eq "1" -or $ApiVersion -eq "2") {
            $ApiUri = ($Array.ApiVersion[[Int]$ApiVersion] | Select-Object -Last 1).ToString()
        } else {
            $ApiUri = $ApiVersion
        }

        if ($Array.Expires.Kind -eq 'Utc') {
            if ([DateTime]::UtcNow -ge $Array.Expires) {
                Connect-PfaApi -Array $Array -SkipCertificateCheck:$SkipCertificateCheck
            }
        } else {
            if ([DateTime]::Now -ge $Array.Expires) {
                Connect-PfaApi -Array $Array -SkipCertificateCheck:$SkipCertificateCheck
            }
        }

        if (-not $Path.StartsWith('/')) {
            $Path = "/$Path"
        }
        if ($null -ne $PSBoundParameters['ErrorAction']) {
            $ErrorAction = $PSBoundParameters['ErrorAction']
        } else {
            $ErrorAction = $ErrorActionPreference
        }
    }
    
    process {
        if ([Math]::Truncate($ApiVersion) -eq 1) {
            $Params = @{
                WebSession = $Array.Auth1x
            }
        } elseif ([Math]::Truncate($ApiVersion) -eq 2) {
            $Params = @{
                Headers = $Array.Auth2x
            }
        }
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $Params.Add("UseBasicParsing", $true)
        }
        if ($Request -eq 'WebRequest') {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $WebRequest = Invoke-WebRequest -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path" @Params -SkipCertificateCheck:$SkipCertificateCheck -ErrorAction:$ErrorAction
            } else {
                $WebRequest = Invoke-WebRequest -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path" @Params -ErrorAction:$ErrorAction
            }
            if ($ApiVersion -eq 1) {
                if ($RawResponse) {
                    $WebRequest
                } else {
                    $WebRequest.Content | ConvertFrom-Json
                }
            } else {
                $WebResponse = $WebRequest.Content | ConvertFrom-Json
                if ($null -eq $WebResponse.Continuation_Token) {
                    if ($RawResponse) {
                        $WebRequest
                    } else {
                        $WebResponse.Items
                    }
                } else {
                    while ($WebResponse.More_Items_Remaining -ne $false) {
                        if ($Path.Contains("?")) {
                            $ContinuationToken = "&continuation_token=$($WebResponse.Continuation_Token)"
                        } else {
                            $ContinuationToken = "?continuation_token=$($WebResponse.Continuation_Token)"
                        }
                        $WebRequest = Invoke-WebRequest -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path$ContinuationToken" @Params -ErrorAction:$ErrorAction
                        $WebResponse = $WebRequest.Content | ConvertFrom-Json
                        if ($RawResponse) {
                            $WebRequest
                        } else {
                            $WebResponse
                        }
                    }
                }
            }
        } elseif ($Request -eq 'RestMethod') {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $RestRequest = Invoke-RestMethod -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path" @Params -SkipCertificateCheck:$SkipCertificateCheck -ErrorAction:$ErrorAction
            } else {
                $RestRequest = Invoke-RestMethod -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path" @Params -ErrorAction:$ErrorAction
            }
            if ([Math]::Truncate($ApiVersion) -eq 1) {
                $RestRequest
            } else {
                if ($null -eq $RestRequest.Continuation_Token) {
                    $RestRequest.Items
                } else {
                    while ($RestRequest.More_Items_Remaining -ne $false) {
                        if ($Path.Contains("?")) {
                            $ContinuationToken = "&continuation_token=$($RestRequest.Continuation_Token)"
                        } else {
                            $ContinuationToken = "?continuation_token=$($RestRequest.Continuation_Token)"
                        }
                        $RestRequest = Invoke-RestMethod -Method $Method -Uri "https://$($Array.ArrayName)/api/$ApiUri$Path$ContinuationToken" @Params -ErrorAction:$ErrorAction
                        $RestRequest
                    }
                }
            }
        }
    }
    end {
    }
}