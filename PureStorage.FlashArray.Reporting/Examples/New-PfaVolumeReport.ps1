function New-PfaVolumeReport {
    param ( 
        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 0)]
        [String[]]$Array,
        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 1)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $true, ParameterSetName = 'ExistingConnection', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi[]]$Connection,

        [Switch]$ShowTotals
    )
    begin {
        $MyCSS = '
        body {
            color: #333333;
            font-family: Calibri,Tahoma,Arial,Verdana;
            font-size: 11pt;
            margin: 0px;
            padding: 0px;
        }
        h3 {
            margin: 5px 0px 5px 0px;
        }
        h4 {
            margin: 0px;
        }
        table {
            border-collapse: collapse;
            
        }
        th {
            text-align: center;
            font-weight: bold;
            border-top: 1px solid black;
            border-bottom: 1px solid black;
            white-space: nowrap;
            padding: 0px 10px 0px 10px;
        }
        td {
            padding: 2px 10px 2px 10px;
            text-align: center;
            white-space: nowrap;
        }
        .odd {
            background-color: #ffffff;
        }
        .even {
            background-color: #dddddd;
        }'
        # Define parameters array for the bytes columns
        $paramsFormat = @{ 
            # Test criteria: None. Used only for Formatting.
            CommandFormat = ${function:Format-Byte}
        }
        # Define parameters array for the Reduction column
        $paramsReduction = @{ 
            # Test criteria: None. Used only for Formatting.
            StringFormat = "{0:N2} to 1"
        }
        # Define parameters array for the "Growth" columns
        $paramsPercentChanged = @{ 
            # Test criteria: Is value a positive percent?
            ScriptBlock = {([string]$args[0] -ne "n/a" -and [string]$args[0] -ne "0.00 %") -and -not ([string]$args[0]).StartsWith("-")}
            # CSS attribute to add if ScriptBlock is true
            CSSAttribute = "style"
        }
        # Define parameters array for the "Growth" columns
        $paramsPercentChangedNegative = @{ 
            # Test criteria: Is value a positive percent?
            ScriptBlock = {([string]$args[0]).StartsWith('-')}  
            # CSS attribute to add if ScriptBlock is true
            CSSAttribute = "style"
        }
        # Define parameters array for the "Utilization" column
        $paramsUtilization = @{ 
            # Column name
            Column = "Utilization"
            # Test criteria: Is value greater than or equal to Argument?
            ScriptBlock = {[double]$args[0] -ge [double]$args[1]}  
            # CSS attribute to add if ScriptBlock is true
            CSSAttribute = "style"
            # Format column with 2 decimal places and add a percent symbol
            StringFormat = "{0:N2} %"
        }
        
        function Get-PercentChanged {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [double]$Reference,
                [Parameter(Mandatory = $true, Position = 1)]
                [double]$Difference
            )
            if (($null -ne $Reference -and $Reference -ne 0) -and ($null -ne $Difference -and $Difference -ne 0)) {
                $Result = [math]::Round((($Difference - $Reference) / $Reference * 100), 2, [MidPointRounding]::AwayFromZero)
                if ($Result -ne -0) {
                    "{0:N2} %" -f $Result
                } else {
                    "0.00 %"
                }
            } else {
                "n/a"
            }
        }

        $AllVolumes = @()
        $AllErrors = @{}
        
        if ($PSCmdlet.ParameterSetName -eq 'NewConnection') {
            foreach ($ArrayName in $Array) {
                try {
                    $Connection += Connect-PfaApi -ArrayName $ArrayName -Credential $Credential -SkipCertificateCheck
                } catch {
                    Write-Error $_.Exception.Message
                }
            }
        }
        foreach ($FlashArray in $Connection) {
            try {
                $Volumes = Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes?destroyed=false" -SkipCertificateCheck -ErrorAction Stop -PipelineVariable Volume | Where-Object {$_.Name -ne 'pure-protocol-endpoint'} | ForEach-Object {
                    $VolumeMetrics = Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes/space?names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop
                    $HostConnections = Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/connections?volume_names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop
                    [PSCustomObject]@{
                        Name                =   $_.Name
                        Size                =   $_.Space.Total_Provisioned
                        Volumes             =   $VolumeMetrics.Space.Unique
                        Utilization         =   (($VolumeMetrics.Space.Total_Physical / $_.Space.Total_Provisioned) * 100)
                        Snapshots           =   $VolumeMetrics.Space.Snapshots
                        Reduction           =   $VolumeMetrics.Space.Data_Reduction
                        Shared              =   if ($null -ne $VolumeMetrics.Space.Shared) {
                                                    $VolumeMetrics.Space.Shared
                                                } else {
                                                    "-"
                                                }
                        System              =   if ($null -ne $VolumeMetrics.System) {
                                                    $VolumeMetrics.Space.System
                                                } else {
                                                    "-"
                                                }
                        ThinProvisioning    =   $VolumeMetrics.Space.Thin_Provisioning
                        Written             =   ((1 - $VolumeMetrics.Space.Thin_Provisioning) * $VolumeMetrics.Space.Total_Physical)
                        Total               =   $VolumeMetrics.Space.Total_Physical
                        Protected           =   if (-not (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volume-snapshots?names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop)) {
                                                    "No"
                                                } else {
                                                    "Yes"
                                                }
                        Connections         =   if (-not $HostConnections.Host -and -not ($HostConnections.Host_Group)) {
                                                    "Not Connected"
                                                } else {
                                                    if (($HostConnections.Host_Group.Name | Sort-Object -Unique).Count -gt 0) {
                                                        ($HostConnections.Host_Group | Sort-Object -Unique Name | Select-Object -ExpandProperty Name) -join ", "
                                                    } else {
                                                        if (($HostConnections.Host.Name | Sort-Object -Unique).Count -gt 1) {
                                                            ($HostConnections.Host | Sort-Object -Unique Name | Select-Object -ExpandProperty Name) -join ", "
                                                        } else {
                                                            $HostConnections.Host.Name
                                                        }
                                                    }
                                                }
                        '7DayGrowth'        =   Invoke-Command -Command {
                                                    try {
                                                        Get-PercentChanged (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes/space?resolution=1800000&start_time=$(([DateTimeOffset]$(Get-Date).AddDays(-7)).ToUnixTimeMilliseconds())&end_time=$(([DateTimeOffset]$(Get-Date).AddDays(-7).AddMilliseconds(1800000)).ToUnixTimeMilliseconds())&names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop).Space.Total_Physical $VolumeMetrics.Space.Total_Physical
                                                    } catch {
                                                        throw $_
                                                    }
                                                }
                        '30DayGrowth'       =   Invoke-Command -Command {
                                                    try {
                                                        Get-PercentChanged $(Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes/space?resolution=7200000&start_time=$(([DateTimeOffset]$(Get-Date).AddDays(-30)).ToUnixTimeMilliseconds())&end_time=$(([DateTimeOffset]$(Get-Date).AddDays(-30).AddMilliseconds(7200000)).ToUnixTimeMilliseconds())&names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop).Space.Total_Physical $VolumeMetrics.Space.Total_Physical
                                                    } catch {
                                                        "n/a"
                                                    }
                                                }
                        '1YearGrowth'       =   Invoke-Command -Command {
                                                    try {
                                                        Get-PercentChanged $(Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes/space?resolution=86400000&start_time=$(([DateTimeOffset]$(Get-Date).AddYears(-1)).ToUnixTimeMilliseconds())&end_time=$(([DateTimeOffset]$(Get-Date).AddYears(-1).AddMilliseconds(86400000)).ToUnixTimeMilliseconds())&names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop).Space.Total_Physical $VolumeMetrics.Space.Total_Physical
                                                    } catch {
                                                        "n/a"
                                                    }
                                                }
                        Array               =   $FlashArray.ArrayName
                    }
                }
                $AllVolumes += $Volumes
                if ($ErrorMessages) {
                    $AllErrors += [PSCustomObject]@{
                        Array           =   $FlashArray
                        ErrorMessage    =   $ErrorMessage
                    }
                }
            } catch {
                throw $_
            }
        }
    }
    process {
        if ($AllVolumes.Count -gt 0 -or $AllErrors.Count -gt 0) {
            if (Get-Module -Name "PS2HTMLTable") {
                $HTML = New-HTMLHead -Style $MyCSS -Title "Flash Array - Volume Report"
                $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'

                $AllVolumes | Sort-Object Array, Name | Group-Object Array | ForEach-Object -Begin {$HTMLTable = $null} -Process {
                    $HTML += "<tr><td style=""text-align: left;"" colspan=""6""><h3>$($_.Name) - Volumes ($($_.Group.Count))</h3></td></tr>"
                    $HTMLTable = $_.Group | Select-Object Name, Size, Volumes, Utilization, Snapshots, Reduction, Shared, System, @{Name = "Thin Provisioning";Expression = {"{0:N3}" -f $_.ThinProvisioning}}, Written, Total, Protected, @{Name = "Connection(s)";Expression = {$_.Connections}}, @{Name = "7 Day Growth";Expression = {$_.'7DayGrowth'}}, @{Name = "30 Day Growth";Expression = {$_.'30DayGrowth'}}, @{Name = "1 Year Growth";Expression = {$_.'1YearGrowth'}} | New-HTMLTable -HTMLDecode -SetAlternating -NestedTable -RemoveColumnGroup

                    # Format Column Data
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Size" @paramsFormat -ApplyFormat
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Volumes" @paramsFormat -ApplyFormat
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Snapshots" @paramsFormat -ApplyFormat
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Written" @paramsFormat -ApplyFormat
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Total" @paramsFormat -ApplyFormat
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Column "Reduction" @paramsReduction -ApplyFormat

                    # Color "Utilization" cell yellow if value is greater than or equal to 60%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 60 -CSSAttributeValue "background-color:#fac13a;" @paramsUtilization
                    # Color "Utilization" cell orange if value is greater than or equal to 75%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 75 -CSSAttributeValue "background-color:#fa8a1c;" @paramsUtilization
                    # Color "Utilization" cell red if value is greater than or equal to 90%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 90 -CSSAttributeValue "background-color:#e44f12;" @paramsUtilization -ApplyFormat

                    if ($null -ne $_.Group[0]."7DayGrowth") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "7 Day Growth" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "7 Day Growth" @paramsPercentChangedNegative
                    }
                    if ($null -ne $_.Group[0]."30DayGrowth") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "30 Day Growth" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "30 Day Growth" @paramsPercentChangedNegative
                    }
                    if ($null -ne $_.Group[0]."1YearGrowth") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "1 Year Growth" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "1 Year Growth" @paramsPercentChangedNegative
                    }
                    if ($ShowTotals) {
                        $HTMLTable += "<tr><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Size | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Volumes | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$("{0:N2} %" -f (($_.Group.Utilization | Measure-Object -Maximum).Maximum))</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Snapshots | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$("{0:N2} to 1" -f ($_.Group.Reduction | Measure-Object -Average).Average)</td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Total | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Written | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'7DayGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'7DayGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'30DayGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'30DayGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'1YearGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'1YearGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td></tr>"
                    } else {
                        $HTMLTable += '<tr><td colspan="16" style="border-top: 1px solid black;padding: 0px 10px 0px 10px;"></td></tr>'
                    }
                    $HTML += $HTMLTable
                }
                $HTML += "</table>"
                $HTML = $HTML | Close-HTML -Validate
            } else {
                $HTML = @"
                <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
                    <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
                        <head>
                            <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                            <title>$Array - Status Report</title>
                            <style>
                            $MyCSS
                            </Style>
                        </head>
                        <body>
"@
                $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'
                $AllVolumes | Sort-Object Array, Name | Group-Object Array | ForEach-Object -Begin {$HTMLTable = $null} -Process {
                    $HTML += "<tr><td style=""text-align: left;"" colspan=""6""><h3>$($_.Name) - Volumes ($($_.Group.Count))</h3></td></tr>"
                    $Xml = [System.Xml.Linq.XDocument]::Parse("$($_.Group | Select-Object Name, @{Name = "Size";Expression = {Format-Byte $_.Size}}, @{Name = "Volumes";Expression = {Format-Byte $_.Volumes}}, @{Name = "Utilization";Expression = {"{0:N2} %" -f $_.Utilization}}, @{Name = "Snapshots";Expression = {Format-Byte $_.Snapshots}}, @{Name = "Reduction";Expression = {"{0:N3} to 1" -f $_.Reduction}}, Shared, System, @{Name = "Thin Provisioning";Expression = {"{0:N3}" -f $_.ThinProvisioning}}, @{Name = "Written";Expression = {Format-Byte $_.Written}}, @{Name = "Total";Expression = {Format-Byte $_.Total}}, Protected, @{Name = "Connection(s)";Expression = {$_.Connections}}, @{Name = "7 Day Growth";Expression = {$_.'7DayGrowth'}}, @{Name = "30 Day Growth";Expression = {$_.'30DayGrowth'}}, @{Name = "1 Year Growth";Expression = {$_.'1YearGrowth'}} | ConvertTo-Html -Fragment)")
                    $Xml.Element("table").Element("colgroup").Remove()
                    foreach ($XmlTr in $($Xml.Descendants("tr"))) {
                        if ($XmlTr.Where({$_.Element('td')})) {
                            if (($XmlTr.NodesBeforeSelf() | Measure-Object).Count % 2 -eq 0) {
                                $XmlTr.SetAttributeValue("class", "even $($XMlTr.Attribute("class").Value)".Trim())
                            } else {
                                $XmlTr.SetAttributeValue("class", "odd $($XMlTr.Attribute("class").Value)".Trim())
                            }
                        }
                    }
                    $HTMLTable = [System.Xml.Linq.XDocument]::Parse($Xml).Document.ToString().Replace("<table>", "").Replace("</table>", "")

                    if ($ShowTotals) {
                        $HTMLTable += "<tr><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Size | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Volumes | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$("{0:N2} %" -f (($_.Group.Utilization | Measure-Object -Maximum).Maximum))</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Snapshots | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$("{0:N2} to 1" -f ($_.Group.Reduction | Measure-Object -Average).Average)</td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Total | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(Format-Byte ($_.Group.Written | Measure-Object -Sum).Sum)</td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;""></td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'7DayGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'7DayGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'30DayGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'30DayGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td><td style=""border-top: 1px solid black;font-weight: bold;"">$(if ($null -ne ($_.Group.'1YearGrowth' | Where-Object {$_ -ne 'n/a'})) {"{0:N2} %" -f (($_.Group.'1YearGrowth' | Where-Object {$_ -ne 'n/a'}).Replace(' %', '') | Measure-Object -Maximum).Maximum})</td></tr>"
                    } else {
                        $HTMLTable += '<tr><td colspan="16" style="border-top: 1px solid black;padding: 0px 10px 0px 10px;"></td></tr>'
                    }
                    $HTML += $HTMLTable
                }
                $HTML += "</table>"
                $HTML += "</body></html>"
            }
            $HTML | Out-File "FlashArray - Volumes.html"
        }
    }
}