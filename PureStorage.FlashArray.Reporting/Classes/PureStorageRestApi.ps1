class PureStorageRestApi {
    [String]$ArrayName
    [Microsoft.PowerShell.Commands.WebRequestSession]$Auth1x
    [Hashtable]$Auth2x
    [DateTime]$Expires
    [Hashtable]$ApiVersion

    PureStorageRestApi([String]$ArrayName, [Microsoft.PowerShell.Commands.WebRequestSession]$Auth1x, [Hashtable]$Auth2x, [DateTime]$Expires, [Hashtable]$ApiVersion){
        $this.ArrayName = $ArrayName
        $this.Auth1x = $Auth1x
        $this.Auth2x = $Auth2x
        $this.Expires = $Expires
        $this.ApiVersion = $ApiVersion
    }
}