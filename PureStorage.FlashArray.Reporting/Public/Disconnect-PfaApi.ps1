function Disconnect-PfaApi {
    <#
    .SYNOPSIS
    Disconnects from a FlashArray REST API.

    .DESCRIPTION
    Disconnects from a FlashArray REST API and invalidates the FlashArray object.

    .PARAMETER Array
    FlashArray object to disconnect from.

    .PARAMETER SkipCertificateCheck
    Skips certificate validation checks. This includes all validations such as expiration, revocation, trusted root authority, etc.
    ** WARNING **
    Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .EXAMPLE
    Disconnect from the $FlashArray object.
    Disconnect-PfaApi -Array $FlashArray

	.NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi]$Array,

        [Switch]$SkipCertificateCheck
    )

    begin {
        $DefaultParameters = @{
            Verbose                 =   $false
            ErrorAction             =   'Stop'
        }
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $DefaultParameters.Add("UseBasicParsing", $true)
        }
        if ($SkipCertificateCheck) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $DefaultParameters.Add("SkipCertificateCheck", $true)
            } else {
                if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
                    Add-Type -TypeDefinition '
                        using System;
                        using System.Net;
                        using System.Net.Security;
                        using System.Security.Cryptography.X509Certificates;
                        public class ServerCertificateValidationCallback {
                            public static void Ignore() {
                                if (ServicePointManager.ServerCertificateValidationCallback == null) {
                                    ServicePointManager.ServerCertificateValidationCallback += 
                                        delegate (
                                            Object obj, 
                                            X509Certificate certificate, 
                                            X509Chain chain, 
                                            SslPolicyErrors errors
                                        ) {
                                            return true;
                                        };
                                }
                            }
                        }
                    '
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                    [ServerCertificateValidationCallback]::Ignore()
                }
            }
        }
    }
    process {
        try {
            Invoke-RestMethod "https://$($Array.ArrayName)/api/$(($Array.ApiVersion[1] | Select-Object -Last 1).ToString())/auth/session" -Method DELETE -WebSession $Array.Auth1x @DefaultParameters -ErrorVariable +DisconnectError | Out-Null
            $Array.Auth1x = $null
            if ($Array.ApiVersion.ContainsKey(1)) {
                $Array.ApiVersion.Remove(1)
            }
        } catch {
            Write-Error "($($Array.ArrayName)), error: $_"
        }
        try {
            Invoke-WebRequest "https://$($Array.ArrayName)/api/$(($Array.ApiVersion[2] | Select-Object -Last 1).ToString())/logout" -Method POST -Headers $Array.Auth2x @DefaultParameters -ErrorVariable +DisconnectError | Out-Null
            $Array.Auth2x = $null
            if ($Array.ApiVersion.ContainsKey(2)) {
                $Array.ApiVersion.Remove(2)
            }
        } catch {
            Write-Error "($($Array.ArrayName)), error: $_"
        }
        if ($DisconnectError.Count -eq 0) {
            $Array.Expires = [DateTime]::MinValue
        }
   }
}