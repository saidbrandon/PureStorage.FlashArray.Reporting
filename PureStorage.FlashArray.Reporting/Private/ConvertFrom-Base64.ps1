function ConvertFrom-Base64 {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$String
    )
    
    process {
        $ImageBytes = [Convert]::FromBase64String($String)
        $MemoryStream = New-Object IO.MemoryStream($ImageBytes, 0, $ImageBytes.Length)
        $MemoryStream.Write($ImageBytes, 0, $ImageBytes.Length)
        $MemoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        
        [System.Drawing.Image]::FromStream($MemoryStream, $true)
    }
}