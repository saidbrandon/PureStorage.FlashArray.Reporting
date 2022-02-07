function Connect-PfaApi {
    <#
    .SYNOPSIS
    Connects to a FlashArray REST API.

    .DESCRIPTION
    Connects or Reconnects to a FlashArray REST API.

    .PARAMETER ArrayName
    Hostname or IP Address of the FlashArray.

    .PARAMETER Credential
    Username and Password needed for authentication.

    .PARAMETER Array
    FlashArray object to reconnect to.

    .PARAMETER SkipCertificateCheck
    Skips certificate validation checks. This includes all validations such as expiration, revocation, trusted root authority, etc.
    ** WARNING **
    Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .EXAMPLE
    Connect to the FlashArray "flasharray01.example.domain.com" and skip certificate verification. If Successful, it will save the resultant object to $FlashArray.
    $FlashArray = Connect-PfaApi -ArrayName flasharray01.example.domain.com

    .EXAMPLE
    Reconnect to a FlashArray object.
    Connect-PfaApi -Array $FlashArray

	.NOTES
	Author: brandon said
    #>
    [CmdletBinding(DefaultParameterSetName = "NewConnection")]
    [OutputType('PureStorageRestApi')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$ArrayName,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 1)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reconnect', Position = 0)]
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
        if ($PSCmdlet.ParameterSetName -eq 'NewConnection') {
            try {
                Write-Verbose "Getting Array Capabilities"
                $CompatibleAPIs = Invoke-RestMethod -Method GET -Uri "https://$ArrayName/api/api_version" @DefaultParameters
                $Api1x = @($CompatibleAPIs.Version | ForEach-Object {[Version]$_} | Where-Object {$_.Major -eq 1})
                $ApiUri1x = ($Api1x | Select-Object -Last 1).ToString()

                $Api2x = @($CompatibleAPIs.Version | ForEach-Object {[Version]$_} | Where-Object {$_.Major -eq 2})
                $ApiUri2x = ($Api2x | Select-Object -Last 1).ToString()
            } catch {
                Write-Error "Unable to connect to FlashArray ($ArrayName), error: $_"
            }
        }
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Reconnect') {
                if ($null -eq $Array.Auth1x -or $null -eq $Array.Auth2x) {
                    throw "Invalid connection. Please try creating a new connection instead."
                }
                Write-Verbose "Attempting to Reconnect to $($Array.ArrayName)"
                $ArrayName = $Array.ArrayName
                $ApiUri1x = ($Array.ApiVersion[1] | Select-Object -Last 1).ToString()
                $ApiUri2x = ($Array.ApiVersion[2] | Select-Object -Last 1).ToString()
                $Credential = New-Object System.Management.Automation.PSCredential($Array.Auth1x.Credentials.UserName, $Array.Auth1x.Credentials.SecurePassword)
            }
            $ApiToken = Invoke-RestMethod "https://$ArrayName/api/$ApiUri1x/auth/apitoken" -Method POST -Body (@{"username" = $Credential.Username;"password" = $Credential.GetNetworkCredential().Password} | ConvertTo-Json) -ContentType 'application/json' @DefaultParameters | Select-Object -ExpandProperty api_token
            $Username = Invoke-RestMethod "https://$ArrayName/api/$ApiUri1x/auth/session" -Method POST -Body @{"api_token" = $ApiToken} -SessionVariable WebSession -Credential $Credential @DefaultParameters | Select-Object -ExpandProperty Username
            Invoke-RestMethod "https://$ArrayName/api/$ApiUri1x/admin/$Username" -Method PUT -Body '{"action" : "refresh"}' -ContentType 'application/json' -WebSession $WebSession @DefaultParameters | Out-Null
            $Authorization = Invoke-WebRequest "https://$ArrayName/api/$ApiUri2x/login" -Method POST -Headers @{"api-token" = $ApiToken} @DefaultParameters
            $IRMHeader = @{"x-auth-token" = ($Authorization.Headers."x-auth-token") | Select-Object -First 1}
            if ($PSCmdlet.ParameterSetName -eq 'NewConnection') {
                [PureStorageRestApi]::new($ArrayName, $WebSession, $IRMHeader, $WebSession.Cookies.GetCookies("https://$ArrayName").Expires, @{1 = $Api1x;2 = $Api2x})
            } else {
                $Array.Auth1x = $WebSession
                $Array.Auth2x = $IRMHeader
                $Array.Expires = $WebSession.Cookies.GetCookies("https://$ArrayName").Expires
            }
            
        } catch {
            Write-Error "Unable to authenticate with the FlashArray ($ArrayName), error: $_"
        }
    }
}