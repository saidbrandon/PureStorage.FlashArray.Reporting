#Require -PSEdition Desktop
#Requires -Modules @{ModuleName="VMware.VimAutomation.Core";ModuleVersion="11.5.0.0"}
#VMware.VimAutomation.Storage

function Get-PfaDiskUsage {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param ( 
        [String[]]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = "IncludeShares")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [Switch]$IncludeShares,
        [Parameter(ParameterSetName = "IncludeShares")]
        [Switch]$IgnoreSpecialShares,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi[]]$Connection,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$VIConnection,
        [Switch]$SendEmail
    )

    begin {
        $StartTime = Get-Date
        $ErrorMessage = $null

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
    }

    process {
        $Computers = @($ComputerName | ForEach-Object {
            $Computer = $_
            try {
                if ($null -ne $Credential) {
                    $CimSession = New-CimSession -ComputerName $_ -Credential $Credential -ErrorVariable +ErrorMessage -ErrorAction SilentlyContinue
                } else {
                    $CimSession = New-CimSession -ComputerName $_ -ErrorVariable +ErrorMessage -ErrorAction SilentlyContinue
                }
                $Disks = @(Get-CimInstance -CimSession $CimSession -Class CIM_LogicalDisk -ErrorVariable +ErrorMessage -ErrorAction Stop | Where-Object DriveType -eq '3' | Select-Object SystemName, DeviceId, VolumeName, Description, Size, FreeSpace)
                $VM = Get-VM | Where-Object {$_.ExtensionData.Guest.Hostname -like "$($Computer)*"}

                $WindowsVolumes = @{}
                Get-CimInstance -CimSession $CimSession -ClassName Win32_DiskDrive -PipelineVariable Disk | ForEach-Object {
                    Get-CimAssociatedInstance -InputObject $Disk -ResultClassName Win32_DiskPartition -PipelineVariable Partition | ForEach-Object {
                        Get-CimAssociatedInstance -InputObject $Partition -ResultClassName Win32_LogicalDisk | ForEach-Object {
                            if ($null -eq $WindowsVolumes["$($Disk.SCSIBus):$($Disk.SCSITargetId)"]) {
                                $WindowsVolumes.Add("$($Disk.SCSIBus):$($Disk.SCSITargetId)", $_.DeviceID)
                            } else {
                                $WindowsVolumes["$($Disk.SCSIBus):$($Disk.SCSITargetId)"] = ,@("$($WindowsVolumes["$($Disk.SCSIBus):$($Disk.SCSITargetId)"]),$($_.DeviceID)")
                            }
                        }
                    }
                }
                $PureVolumes = Get-ScsiController -VM $VM -PipelineVariable Controller | ForEach-Object {
                    Get-HardDisk -VM $VM -PipelineVariable Disk | Where-Object {$_.ExtensionData.ControllerKey -eq $Controller.Key} | ForEach-Object {
                        $Connection | ForEach-Object {
                            $VVol = Invoke-PfaApiRequest -Array $_ -Request RestMethod -Method Get -Path "/volume?tags=true&filter=value='$($Disk.ExtensionData.Backing.BackingObjectId)'&limit=1" -SkipCertificateCheck -ApiVersion 1.18 -ErrorVariable +ErrorMessage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                            if ($null -ne $VVol) {
                                $VolumeMetrics = Invoke-PfaApiRequest -Array $_ -Request RestMethod -Method Get -Path "/volumes/space?names=$VVol" -SkipCertificateCheck -ErrorVariable +ErrorMessage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Space
                                [PSCustomObject][Ordered]@{
                                        VM          =   $VM.name
                                        HD          =   $Disk.Name
                                        VMDK        =   $Disk.Filename
                                        Device      =   "$($Controller.ExtensionData.BusNumber):$($Disk.ExtensionData.UnitNumber)"
                                        vVol        =   $VVol
                                        Drive       =   Invoke-Command -Command {
                                                            $WindowsVolumes["$($Controller.ExtensionData.BusNumber):$($Disk.ExtensionData.UnitNumber)"]
                                                        }
                                        Snapshots   =   $VolumeMetrics.Snapshots
                                        Size        =   $VolumeMetrics.Unique
                                        Reduction   =   $VolumeMetrics.Total_Reduction
                                }
                            }
                        }
                    }
                }
                
                if ($IncludeShares) {
                    if ($IgnoreSpecialShares) {
                        $Filter = @{
                            "Filter" = "Type = 0"
                        }
                    } else {
                        $Filter = @{
                            "Filter" = "Type = 0 OR Type >= 3"
                        }
                    }
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        $AdminShares = 'A'..'Z' | ForEach-Object { "$_$" } -End {"ADMIN$";"IPC$"}
                    } else {
                        $AdminShares = @("A$","B$","C$","D$","E$","F$","G$","H$","I$","J$","K$","L$","M$","N$","O$","P$","Q$","R$","S$","T$","U$","V$","W$","X$","Y$","Z$", "ADMIN$", "IPC$")
                    }
                    $Shares = @(Get-CimInstance -CimSession $CimSession -Class Win32_Share @Filter -ErrorAction SilentlyContinue) | Sort-Object {
                        $Index = $AdminShares.IndexOf($_.Name)
                        if ($Index -ne -1) {
                            $Index
                        } else {
                            [System.Double]::PositiveInfinity
                        }
                    }
                }
                $Disks | ForEach-Object {
                    $Disk = $_
                    if ($null -ne $Shares) {
                        $Share = ($Shares | Where-Object {$_.Path.StartsWith($Disk.DeviceId)}).Name  -join ", "
                    } else {
                        $Share = ""
                    }
                    if ($null -ne $PureVolumes) {
                        $PureDisk = $PureVolumes | Where-Object {$_.Drive -eq $Disk.DeviceId -or $_.Drive -match $Disk.DeviceId}
                    }
                    $_ | Add-Member -NotePropertyMembers @{
                        "Used"              =   $_.Size - $_.FreeSpace
                        "Shares"            =   $Share
                        "Utilization"       =   ($_.Size - $_.FreeSpace) / $_.Size * 100
                        "VVolName"          =   $PureDisk.VVol
                        "VVolSize"          =   $PureDisk.Size
                        "VVolSnapshotSize"  =   $PureDisk.Snapshots
                        "VVolReduction"     =   $PureDisk.Reduction
                    }
                }
                $ComputerObject = [PSCustomObject]@{
                    "ComputerName"  = $_
                    "Disks"         = @($Disks | Select-Object -ExcludeProperty SystemName)
                }
                $ComputerObject
            } finally {
                if ($null -ne $CimSession) {
                    Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
                }
            }
        })
        if ($Computers.Count -gt 0) {
            if (Get-Module -Name "PS2HTMLTable") {
                $HTML = New-HTMLHead -Theme light -Title "Disk Usage Report"
                $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'
                $Computers | ForEach-Object {
                    $HTML += "<tr><td style=""border: none;text-align: left;"" colspan=""10""><h3>$($_.ComputerName) ($($_.Disks.Count))</h3></td></tr><tr><th colspan=""7"" style=""background: black;border-right: 1px solid #dddddd;border-top: 1px solid black;border-left: 1px solid black;""></th><th colspan=""4"" style=""background: black;color:white;border-right: 1px solid #dddddd;border-top: 1px solid black;"">Pure Storage</th></tr>"
                    $HTMLTable = $_.Disks | Select-Object @{Name = "Drive";Expression = {$_.DeviceId}}, 
                                                          @{Name = "Label";Expression = {$_.VolumeName}}, 
                                                          @{Name = "Size";Expression = {Format-Bytes -Bytes $_.Size}},
                                                          @{Name = "Used";Expression = {Format-Bytes -Bytes ($_.Size - $_.FreeSpace)}},
                                                          @{Name = "Free Space";Expression = {Format-Bytes -Bytes $_.FreeSpace}},
                                                          Shares,
                                                          Utilization,
                                                          @{Name = "Volume Name";Expression = {$_.VVolName}},
                                                          @{Name = "Volume Usage";Expression = {Format-Bytes -Bytes $_.VVolSize}},
                                                          @{Name = "Snapshot Usage";Expression = {Format-Bytes -Bytes $_.VVolSnapshotSize}},
                                                          @{Name = "Volume Reduction";Expression = {if ($null -ne $_.VVolReduction) {"{0:N2}x" -f $_.VVolReduction} else {"1.00x"}}} |
                                                          New-HTMLTable -HTMLDecode -SetAlternating -NestedTable -RemoveColumnGroup -ColumnClassPrefix "col"
                    # Color "Utilization" cell yellow if value is greater than or equal to 60%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 60 -CSSAttributeValue "background-color:#fac13a;" @paramsUtilization
                    # Color "Utilization" cell orange if value is greater than or equal to 75%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 75 -CSSAttributeValue "background-color:#fa8a1c;" @paramsUtilization
                    # Color "Utilization" cell red if value is greater than or equal to 90%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 90 -CSSAttributeValue "background-color:#e44f12;" @paramsUtilization -ApplyFormat
                    #HTMLTable += "<tr><td></td><td></td><td>$(Format-Bytes ($_.Disks.Size | Measure-Object -Sum).Sum)</td><td>$(Format-Bytes (($_.Disks.Size | Measure-Object -Sum).Sum - ($_.Disks.FreeSpace | Measure-Object -Sum).Sum))</td><td>$(Format-Bytes ($_.Disks.FreeSpace | Measure-Object -Sum).Sum)</td><td></td><td>$("{0:N2} %" -f ($_.Disks.Utilization | Measure-Object -Average).Average)</td><td></td><td>$(Format-Bytes ($_.Disks.VVolSize | Measure-Object -Sum).Sum)</td><td>$(Format-Bytes ($_.Disks.VVolSnapshotSize | Measure-Object -Sum).Sum)</td><td>$("{0:N2}x" -f ($_.Disks.VVolReduction | Measure-Object -Average).Average)</td></tr>"
                    $HTMLTable += "<tr><td class=""top-border""></td><td class=""top-border""></td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.Size | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$(Format-Bytes (($_.Disks.Size | Measure-Object -Sum).Sum - ($_.Disks.FreeSpace | Measure-Object -Sum).Sum))</td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.FreeSpace | Measure-Object -Sum).Sum)</td><td class=""top-border""></td><td class=""top-border bold"">$("{0:N2} %" -f ($_.Disks.Utilization | Measure-Object -Average).Average)</td><td class=""top-border""></td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.VVolSize | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.VVolSnapshotSize | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$("{0:N2}x" -f ($_.Disks.VVolReduction | Measure-Object -Average).Average)</td></tr>"
                    $HTML += $HTMLTable
                }
                $HTML += "</table>"
                $HTML = $HTML | Close-HTML -Validate
            } else {
                $HTML = @"
                    <!DOCTYPE html>
                    <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
                        <head>
                            <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                            <title>Disk Usage Report</title>
                            <style>
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
                            tr.last-child {
                                border-bottom: 1px solid black;
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
                            td {
                                padding: 2px 10px 2px 10px;
                                text-align: center;
                                white-space: nowrap;
                            }
                            td.bold {
                                font-weight: bold;
                            }
                            td.top-border {
                                border-top: 1px solid black;
                            }
                            .odd {
                                background-color: #dddddd;
                            }
                            .even {
                                background-color: #ffffff;
                            }
                            
                            </style>
                        </head>
                        <body>
"@
                $HTML += '<table id="container" cellpadding="0" cellspacing="0" border="0">'
                $Computers | ForEach-Object {
                    $HTML += "<tr><td style=""border: none;text-align: left;"" colspan=""10""><h3>$($_.ComputerName) ($($_.Disks.Count))</h3></td></tr><tr><th colspan=""7"" style=""background: black;border-right: 1px solid #dddddd;border-top: 1px solid black;border-left: 1px solid black;""></th><th colspan=""4"" style=""background: black;color:white;border-right: 1px solid #dddddd;border-top: 1px solid black;"">Pure Storage</th></tr>"
                    $Xml = [System.Xml.Linq.XDocument]::Parse("$($_.Disks | Select-Object @{Name = "Drive";Expression = {$_.DeviceId}}, 
                                                          @{Name = "Label";Expression = {$_.VolumeName}}, 
                                                          @{Name = "Size";Expression = {Format-Bytes -Bytes $_.Size}},
                                                          @{Name = "Used";Expression = {Format-Bytes -Bytes ($_.Size - $_.FreeSpace)}},
                                                          @{Name = "Free Space";Expression = {Format-Bytes -Bytes $_.FreeSpace}},
                                                          Shares,
                                                          @{Name = "Utilization";Expression = {"{0:N2} %" -f $_.Utilization}},
                                                          @{Name = "Volume Name";Expression = {$_.VVolName}},
                                                          @{Name = "Volume Usage";Expression = {Format-Bytes -Bytes $_.VVolSize}},
                                                          @{Name = "Snapshot Usage";Expression = {Format-Bytes -Bytes $_.VVolSnapshotSize}},
                                                          @{Name = "Volume Reduction";Expression = {if ($null -ne $_.VVolReduction) {"{0:N2}x" -f $_.VVolReduction} else {"1.00x"}}} |
                                                          ConvertTo-Html -Fragment)")
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
                    $HTMLTable += "<tr><td class=""top-border""></td><td class=""top-border""></td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.Size | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$(Format-Bytes (($_.Disks.Size | Measure-Object -Sum).Sum - ($_.Disks.FreeSpace | Measure-Object -Sum).Sum))</td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.FreeSpace | Measure-Object -Sum).Sum)</td><td class=""top-border""></td><td class=""top-border bold"">$("{0:N2} %" -f ($_.Disks.Utilization | Measure-Object -Average).Average)</td><td class=""top-border""></td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.VVolSize | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$(Format-Bytes ($_.Disks.VVolSnapshotSize | Measure-Object -Sum).Sum)</td><td class=""top-border bold"">$("{0:N2}x" -f ($_.Disks.VVolReduction | Measure-Object -Average).Average)</td></tr>"
                    $HTML += $HTMLTable
                }
                $HTML += "</table>"
                $HTML += "</body></html>"
            }
            try {
                $HTML | Out-File PfaDiskUsage.html
            } catch {
                throw $_
            }
        }
        $ErrorMessage | Sort-Object OriginInfo | ForEach-Object {
            Write-Host "$($_.OriginInfo) - $($_.Exception.Message)"
        }
    }
}