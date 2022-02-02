function New-PfaProtectionGroupReport {
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
        [PureStorageRestApi[]]$Connection
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
        th.align-left {
            text-align: left;
        }
        th.no-border {
            border: none;
        }
        td {
            padding: 2px 10px 2px 10px;
            text-align: center;
            white-space: nowrap;
        }
        td.align-left {
            text-align: left;
        }
        td.array {
            background-color: #333333;
            color: #ffffff;
            font-weight: bold;
            font-size: 18px;
            text-align: left;
            padding: 5px 10px 5px 10px;
        }
        td.top-border {
            border-top: 1px solid black;
        }
        td.no-padding {
            padding: 0px;l
        }
        td.pb-20 {
            padding-bottom: 20px;
        }
        .odd {
            background-color: #ffffff;
        }
        .even {
            background-color: #dddddd;
        }'

        $paramsErrorMessage = @{ 
            # Column name
            Column = "Error Message"
            # Test criteria: always highlight cell
            ScriptBlock = {$true}
            # CSS attribute to add if ScriptBlock is true
            CSSAttribute = "style"
        }

        $AllProtectionGroups = @()
        $AllErrors = @()

        if ($PSCmdlet.ParameterSetName -eq 'NewConnection') {
            foreach ($ArrayName in $Array) {
                $Connection += Connect-PfaApi -ArrayName $ArrayName -Credential $Credential -SkipCertificateCheck -ErrorVariable +ErrorMessage
            }
        }
        foreach ($FlashArray in $Connection) {
            try {
                $ProtectionGroups = Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/protection-groups" -SkipCertificateCheck -PipelineVariable ProtectionGroup -ErrorVariable +ErrorMessage -ErrorAction Stop | ForEach-Object {
                    $Replication = [PSCustomObject]@{
                        Frequency   =   $_.Replication_Schedule.Frequency / 1000
                        Time        =   $_.Replication_Schedule.At
                        Blackout    =   $_.Replication_Schedule.Blackout
                        Enabled     =   $_.Replication_Schedule.Enabled
                        Snapshot    =   [PSCustomObject]@{
                            Retention       =   $_.Target_Retention.All_For_Sec
                            RetentionDaily  =   $_.Target_Retention.Per_Day
                            RetentionDays   =   $_.Target_Retention.Days
                            Enabled         =   $_.Snapshot_Schedule.Enabled
                        }
                    }
                    $Snapshot = [PSCustomObject]@{
                        Frequency   =   $_.Snapshot_Schedule.Frequency / 1000
                        Time        =   $_.Snapshot_Schedule.At
                        Enabled     =   $_.Snapshot_Schedule.Enabled
                        Retention       =   $_.Source_Retention.All_For_Sec
                        RetentionDaily  =   $_.Source_Retention.Per_Day
                        RetentionDays   =   $_.Source_Retention.Days
                    }
                    $Volumes = (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/protection-groups/volumes?group_names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop).Member.Name
                    if ($Volumes.Count -gt 0) {
                        $Members = $Volumes | Select-Object -PipelineVariable VolumeName | ForEach-Object {
                            Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes/space?names=$VolumeName" -SkipCertificateCheck -PipelineVariable Member -ErrorAction Stop | ForEach-Object {
                                $HostConnections = Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/connections?volume_names=$VolumeName" -SkipCertificateCheck -ErrorAction Stop
                                [PSCustomObject]@{
                                    Name        = $Member.Name
                                    Size        =   $_.Space.Total_Provisioned
                                    Used        =   $_.Space.Unique
                                    LUN         =   if (-not $HostConnections.Host -and -not ($HostConnections.Host_Group)) {
                                                        ""
                                                    } else {
                                                        if (($HostConnections.Host_Group.Name | Sort-Object -Unique).Count -gt 0) {
                                                            (($HostConnections.Lun | Sort-Object -Unique) | ForEach-Object {
                                                                if ($_ -gt 255) {
                                                                    $_ | Format-Hex | Select-Object @{Expression = {"$($_.Bytes[0]):$($_.Bytes[4])"}} | Select-Object -ExpandProperty *
                                                                } else {
                                                                    $_
                                                                }
                                                            }) -join ", "
                                                        } else {
                                                            if (($HostConnections.Host.Name | Sort-Object -Unique).Count -gt 1) {
                                                                (($HostConnections.Lun | Sort-Object -Unique) | ForEach-Object {
                                                                    if ($_ -gt 255) {
                                                                        $_ | Format-Hex | Select-Object @{Expression = {"$($_.Bytes[0]):$($_.Bytes[4])"}} | Select-Object -ExpandProperty *
                                                                    } else {
                                                                        $_
                                                                    }
                                                                }) -join ", "
                                                            } else {
                                                                if ($HostConnections.Lun -gt 255) {
                                                                    $HostConnections.Lun | Format-Hex | Select-Object @{Expression = {"$($_.Bytes[0]):$($_.Bytes[4])"}} | Select-Object -ExpandProperty *
                                                                } else {
                                                                    $HostConnections.Lun
                                                                }
                                                            }
                                                        }
                                                    }
                                    Serial      =   (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/volumes?names=$VolumeName" -SkipCertificateCheck -ErrorAction Stop).Serial
                                    Source      =   (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/arrays" -SkipCertificateCheck -ErrorAction Stop).Name
                                    Target      =   (Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/protection-groups/targets?group_names=$($ProtectionGroup.Name)" -SkipCertificateCheck -PipelineVariable Member -ErrorAction Stop).Member.Name -join ", "
                                }
                            }
                        }
                    } else {
                        $Members = $null
                    }

                    [PSCustomObject]@{
                        Name                =   $_.Name
                        Size                =   ($Members.Size | Measure-Object -Sum).Sum
                        Used                =   ($Members.Used | Measure-Object -Sum).Sum
                        SnapshotSize        =   ((Invoke-PfaApiRequest -Array $FlashArray -Request RestMethod -Method GET -Path "/protection-group-snapshots?source_names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop).Items.Space.Snapshots | Measure-Object -Sum).Sum
                        Members             =   $Members
                        SnapshotStatus      =   $Replication.Snapshot.Enabled
                        SnapshotSchedule    =   $Snapshot
                        ReplicationStatus   =   $Replication.Enabled
                        ReplicationSchedule =   $Replication
                        Array               =   $FlashArray.ArrayName
                    }
                }
                $AllProtectionGroups += $ProtectionGroups
                if ($ErrorMessage) {
                    $AllErrors += [PSCustomObject]@{
                        ArrayName       =   $FlashArray.ArrayName
                        ErrorMessage    =   $ErrorMessage
                    }
                }
                if ($AllProtectionGroups.Count -gt 0) {
                    if (Get-Module -Name "PS2HTMLTable") {
                        $HTML = New-HTMLHead -Style $MyCSS -Title "Flash Array - Protection Group Report"
                        $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'
                        $AllProtectionGroups | Sort-Object Array, Name | Group-Object Array | ForEach-Object {
                            $HTML += '<tr><td colspan="11" class="array">{0} ({1})</td></tr>' -f $_.Name, $_.Count
                            $_.Group | Select-Object -PipelineVariable Group | ForEach-Object {
                                $HTML += '<tr><th class="no-border">Protection Group Name</th><th class="no-border">Size</th><th class="no-border">Used</th><th colspan="8" class="no-border align-left">Snapshot</th></tr>'
                                $HTMLTable = $_ | Select-Object Name, @{Name = "Size"; Expression = {Format-Byte $_.Size}}, @{Name = "Used"; Expression = {Format-Byte $_.Used}}, @{Name = "Snapshots"; Expression = {Format-Byte $_.SnapshotSize}} | New-HTMLTable -HTMLDecode -NestedTable -RemoveColumnGroup -RemoveHeader
                                $HTML += $HTMLTable
                                if ($_.Members.Count -gt 0) {
                                    $HTMLTable = $_.Members | Select-Object @{Name = "Members"; Expression = {$_.Name}}, @{Name = "Size"; Expression = {Format-Byte $_.Size}}, @{Name = "Used"; Expression = {Format-Byte $_.Used}}, LUN, Serial, Source, Target, @{Name = "Snapshot Status"; Expression = {if ($Group.SnapshotStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Snapshot Schedule"; Expression = {"$(Format-PfaSecond $Group.SnapshotSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.SnapshotSchedule.Time -AsInt)/$(Format-PfaSecond $Group.SnapshotSchedule.Retention -AsInt)/$($Group.SnapshotSchedule.RetentionDaily)/$(Format-PfaSecond $Group.SnapshotSchedule.RetentionDays -AsInt)"}}, @{Name = "Replication Status"; Expression = {if ($Group.ReplicationStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Replication Schedule"; Expression = {"$(Format-PfaSecond $Group.ReplicationSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Time -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.End -AsInt)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.Retention -AsInt)/$($Group.ReplicationSchedule.Snapshot.RetentionDaily)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.RetentionDays -AsInt)"}} | New-HTMLTable -HTMLDecode -SetAlternating -NestedTable -RemoveColumnGroup
                                    $HTMLTable += '<tr><td colspan="11" class="top-border no-padding"></td></tr>'
                                    $HTML += $HTMLTable
                                } else {
                                    $HTMLTable = "" | Select-Object @{Name = "Members"; Expression = {"None"}}, Size, Used, LUN, Serial, Source, Target, @{Name = "Snapshot Status"; Expression = {if ($Group.SnapshotStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Snapshot Schedule"; Expression = {"$(Format-PfaSecond $Group.SnapshotSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.SnapshotSchedule.Time -AsInt)/$(Format-PfaSecond $Group.SnapshotSchedule.Retention -AsInt)/$($Group.SnapshotSchedule.RetentionDaily)/$(Format-PfaSecond $Group.SnapshotSchedule.RetentionDays -AsInt)"}}, @{Name = "Replication Status"; Expression = {if ($Group.ReplicationStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Replication Schedule"; Expression = {"$(Format-PfaSecond $Group.ReplicationSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Time -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.End -AsInt)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.Retention -AsInt)/$($Group.ReplicationSchedule.Snapshot.RetentionDaily)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.RetentionDays -AsInt)"}} | New-HTMLTable -HTMLDecode -SetAlternating -NestedTable -RemoveColumnGroup
                                    $HTMLTable += '<tr><td colspan="11" class="top-border no-padding"></td></tr>'
                                    $HTML += $HTMLTable
                                }
                                $HTML += "<tr><td colspan=""11"">Create a snapshot on source every $(Format-PfaSecond $_.SnapshotSchedule.Frequency)$(if ($null -ne $_.SnapshotSchedule.Time) {" at {0}" -f (Format-PfaSecondsFromMidnight $_.SnapshotSchedule.Time)}). Retain all snapshots on source for $(Format-PfaSecond $_.SnapshotSchedule.Retention)$(if ($_.SnapshotSchedule.RetentionDaily -ne 0 -or $_.SnapshotSchedule.RetentionDays -ne 0) {", then retain {0} snapshots per day for {1} more days" -f $_.SnapshotSchedule.RetentionDaily, $(Format-PfaSecond $_.SnapshotSchedule.RetentionDays -AsInt)}).</td></tr>"
                                $HTML += "<tr><td colspan=""11"" class=""pb-20"">Replicate a snapshot to targets every $(Format-PfaSecond $_.ReplicationSchedule.Frequency)$(if ($null -ne $_.ReplicationSchedule.Time) {" at {0}" -f (Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Time)})$(if ($null -ne $_.ReplicationSchedule.Blackout.Start) {" except between $(Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Blackout.Start) and $(Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Blackout.End)"}). Retain all snapshots on targets for $(Format-PfaSecond $_.ReplicationSchedule.Snapshot.Retention)$(if ($_.ReplicationSchedule.Snapshot.RetentionDaily -ne 0 -or $_.ReplicationSchedule.Snapshot.RetentionDays -ne 0) {", then retain {0} snapshots per day for {1} more days" -f $_.ReplicationSchedule.Snapshot.RetentionDaily, $(Format-PfaSecond $_.ReplicationSchedule.Snapshot.RetentionDays -AsInt)}).</td></tr>"
                            }
                        }
                        if ($null -ne $AllErrors) {
                            $AllErrors | ForEach-Object {
                                $HTML += '<tr><td colspan="11" class="array">{0}</td></tr>' -f $_.Name
                                $HTMLTable = $_ | Select-Object @{Name = "Error Message";Expression = {($_.ErrorMessage.Exception.Message -split '\r\n')[0]}} | New-HTMLTable -HTMLDecode -SetAlternating -TableAttributes @{"width" = "100%"} -ColumnClass "align-left"
                                # Color "Error Message" red
                                $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "background-color:#ed5e3c;" @paramsErrorMessage
                                $HTMLTable += '<tr><td colspan="11" class="top-border no-padding"></td></tr>'
                                $HTML += "<tr><td colspan=""11"" style=""padding: 0px;"">$HTMLTable</td></tr>"
                            }
                        }
                        $HTML += "</table>"
                        $HTML = $HTML | Close-HTML -Validate
                    } else {
                        $HTML = @"
                        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
                            <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
                                <head>
                                    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                                    <title>Flash Array - Protection Group Report</title>
                                    <style>
                                    $MyCSS
                                    </Style>
                                </head>
                                <body>
"@
                        $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'
                        $AllProtectionGroups | Sort-Object Array, Name | Group-Object Array | ForEach-Object {
                            $HTML += '<tr><td colspan="11" class="array">{0} ({1})</td></tr>' -f $_.Name, $_.Count
                            $_.Group | Select-Object -PipelineVariable Group | ForEach-Object {
                                $Xml = [System.Xml.Linq.XDocument]::Parse(($_ | Select-Object @{Name = "Protection Group Name";Expression = {$_.Name}}, @{Name = "Size"; Expression = {Format-Byte $_.Size}}, @{Name = "Used"; Expression = {Format-Byte $_.Used}}, @{Name = "Snapshot"; Expression = {Format-Byte $_.SnapshotSize}} | ConvertTo-Html -Fragment))
                                $Xml.Element("table").Element("colgroup").Remove()
                                foreach ($XmlTr in $($Xml.Descendants("tr"))) {
                                    if ($XmlTr.Where({$_.Element('td')})) {
                                        if (($XmlTr.NodesBeforeSelf() | Measure-Object).Count % 2 -eq 0) {
                                            $XmlTr.SetAttributeValue("class", "even $($XMlTr.Attribute("class").Value)".Trim())
                                        } else {
                                            $XmlTr.SetAttributeValue("class", "odd $($XMlTr.Attribute("class").Value)".Trim())
                                        }
                                    }
                                    foreach ($XmlTh in $($XmlTr.Descendants("th"))) {
                                        $XmlTh.SetAttributeValue("class", "no-border")
                                        if ($null -eq $XmlTh.NextNode) {
                                            $XmlTh.SetAttributeValue("colspan", "8")
                                            $XmlTh.SetAttributeValue("class", "no-border align-left")
                                        }
                                    }
                                }
                                $HTMLTable = [System.Xml.Linq.XDocument]::Parse($Xml).Document.ToString().Replace("<table>", "").Replace("</table>", "")
                                $HTML += $HTMLTable
                                if ($_.Members.Count -gt 0) {
                                    $Xml = [System.Xml.Linq.XDocument]::Parse(($_.Members | Select-Object @{Name = "Members"; Expression = {$_.Name}}, @{Name = "Size"; Expression = {Format-Byte $_.Size}}, @{Name = "Used"; Expression = {Format-Byte $_.Used}}, LUN, Serial, Source, Target, @{Name = "Snapshot Status"; Expression = {if ($Group.SnapshotStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Snapshot Schedule"; Expression = {"$(Format-PfaSecond $Group.SnapshotSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.SnapshotSchedule.Time -AsInt)/$(Format-PfaSecond $Group.SnapshotSchedule.Retention -AsInt)/$($Group.SnapshotSchedule.RetentionDaily)/$(Format-PfaSecond $Group.SnapshotSchedule.RetentionDays -AsInt)"}}, @{Name = "Replication Status"; Expression = {if ($Group.ReplicationStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Replication Schedule"; Expression = {"$(Format-PfaSecond $Group.ReplicationSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Time -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.End -AsInt)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.Retention -AsInt)/$($Group.ReplicationSchedule.Snapshot.RetentionDaily)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.RetentionDays -AsInt)"}} | ConvertTo-Html -Fragment))
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
                                    $HTMLTable += '<tr><td colspan="11" class="top-border no-padding"></td></tr>'
                                    $HTML += $HTMLTable
                                } else {
                                    $Xml = [System.Xml.Linq.XDocument]::Parse(("" | Select-Object @{Name = "Members"; Expression = {"None"}}, Size, Used, LUN, Serial, Source, Target, @{Name = "Snapshot Status"; Expression = {if ($Group.SnapshotStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Snapshot Schedule"; Expression = {"$(Format-PfaSecond $Group.SnapshotSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.SnapshotSchedule.Time -AsInt)/$(Format-PfaSecond $Group.SnapshotSchedule.Retention -AsInt)/$($Group.SnapshotSchedule.RetentionDaily)/$(Format-PfaSecond $Group.SnapshotSchedule.RetentionDays -AsInt)"}}, @{Name = "Replication Status"; Expression = {if ($Group.ReplicationStatus -eq $true) {"Active"} else {"Inactive"}}}, @{Name = "Replication Schedule"; Expression = {"$(Format-PfaSecond $Group.ReplicationSchedule.Frequency)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Time -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.Start -AsInt)/$(Format-PfaSecondsFromMidnight $Group.ReplicationSchedule.Blackout.End -AsInt)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.Retention -AsInt)/$($Group.ReplicationSchedule.Snapshot.RetentionDaily)/$(Format-PfaSecond $Group.ReplicationSchedule.Snapshot.RetentionDays -AsInt)"}} | ConvertTo-Html -Fragment))
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
                                    $HTMLTable += '<tr><td colspan="11" class="top-border no-padding"></td></tr>'
                                    $HTML += $HTMLTable
                                }
                                $HTML += "<tr><td colspan=""11"">Create a snapshot on source every $(Format-PfaSecond $_.SnapshotSchedule.Frequency)$(if ($null -ne $_.SnapshotSchedule.Time) {" at {0}" -f (Format-PfaSecondsFromMidnight $_.SnapshotSchedule.Time)}). Retain all snapshots on source for $(Format-PfaSecond $_.SnapshotSchedule.Retention)$(if ($_.SnapshotSchedule.RetentionDaily -ne 0 -or $_.SnapshotSchedule.RetentionDays -ne 0) {", then retain {0} snapshots per day for {1} more days" -f $_.SnapshotSchedule.RetentionDaily, $(Format-PfaSecond $_.SnapshotSchedule.RetentionDays -AsInt)}).</td></tr>"
                                $HTML += "<tr><td colspan=""11"" class=""pb-20"">Replicate a snapshot to targets every $(Format-PfaSecond $_.ReplicationSchedule.Frequency)$(if ($null -ne $_.ReplicationSchedule.Time) {" at {0}" -f (Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Time)})$(if ($null -ne $_.ReplicationSchedule.Blackout.Start) {" except between $(Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Blackout.Start) and $(Format-PfaSecondsFromMidnight $_.ReplicationSchedule.Blackout.End)"}). Retain all snapshots on targets for $(Format-PfaSecond $_.ReplicationSchedule.Snapshot.Retention)$(if ($_.ReplicationSchedule.Snapshot.RetentionDaily -ne 0 -or $_.ReplicationSchedule.Snapshot.RetentionDays -ne 0) {", then retain {0} snapshots per day for {1} more days" -f $_.ReplicationSchedule.Snapshot.RetentionDaily, $(Format-PfaSecond $_.ReplicationSchedule.Snapshot.RetentionDays -AsInt)}).</td></tr>"
                            }
                        }
                        if ($null -ne $AllErrors) {
                            $AllErrors | ForEach-Object {
                                $HTML += '<tr><td colspan="11" class="array">{0}</td></tr>' -f $_.Name
                                $Xml = [System.Xml.Linq.XDocument]::Parse(($_ | Select-Object @{Name = "Error Message";Expression = {($_.ErrorMessage.Exception.Message -split '\r\n')[0]}}))
                                $Xml.Element("table").Element("colgroup").Remove()
                                $Xml.Element("table").SetAttributeValue("width", "100%")
                                foreach ($XmlTr in $($Xml.Descendants("tr"))) {
                                    if ($XmlTr.Where({$_.Element('td')})) {
                                        if (($XmlTr.NodesBeforeSelf() | Measure-Object).Count % 2 -eq 0) {
                                            $XmlTr.SetAttributeValue("class", "even $($XMlTr.Attribute("class").Value)".Trim())
                                        } else {
                                            $XmlTr.SetAttributeValue("class", "odd $($XMlTr.Attribute("class").Value)".Trim())
                                        }
                                    }
                                    foreach ($XmlTh in $($XmlTr.Descendants("th"))) {
                                        $XmlTh.SetAttributeValue("class", "align-left")
                                    }
                                }                                
                                $HTMLTable = [System.Xml.Linq.XDocument]::Parse($Xml).Document.ToString().Replace("<table>", "").Replace("</table>", "")
                                $HTML += "<tr><td colspan=""11"" style=""padding: 0px;"">$HTMLTable</td></tr>"
                            }
                        }
                        $HTML += "</table>"
                        $HTML += "</body></html>"
                    }
                    $HTML | Out-File "FlashArray - Protection Groups.html"
                }
            } catch {
                throw $_
            }
        }
    }
}