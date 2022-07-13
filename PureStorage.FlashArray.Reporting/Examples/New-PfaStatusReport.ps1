function New-PfaStatusReport {
    param ( 
        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 0)]
        [String]$Array,
        [Parameter(Mandatory = $true, ParameterSetName = 'NewConnection', Position = 1)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $true, ParameterSetName = 'ExistingConnection', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi]$Connection,

        [Parameter()][ValidateSet("All", "Capacity", "Overview", "Health", "Latency", "IOPS", "Bandwidth", "Replication")]
        [String[]]$IncludeCharts = "None",
        [Switch]$SkipVolumesReport,
        [String]$DataFolder = $env:APPDATA + "\PureStorage",
        [Switch]$SendEmail = $false,
        [Switch]$SaveAsHTML = $false,
        [Switch]$SaveCharts = $false,
        [String]$FromAddress = "First.Last@domain.com",
        [String]$RecipientAddress = "recipient@domain.com",
        [String]$SMTPServer = "",
        [Int32]$SMTPPort = 25
        )

    begin {
        $StartTime = Get-Date
        $MyCSS = '
        body {
            color: #333333;
            font-family: Calibri,Tahoma,Arial,Verdana;
            font-size: 11pt;
        }
        h3 {
            margin-top: 0px;
            margin-bottom: 5px;
            text-align: left;
        }
        h4 {
            margin-top: 10px !important;
            margin-bottom: 10px !important;
        }
        table {
            border-collapse: collapse;
        }
        table#volumes {
            width: 100%;
        }
        table#volumes tfoot tr th {
            border: none !important;
            background-color: transparent;
            color: #333333;
        }
        th {
            text-align: center;
            font-weight: bold;
            color: #ffffff;
            background-color: #444444;
            padding: 5px;
            white-space: nowrap;
            border-top: 1px solid black;
            border-bottom: 1px solid black;
        }
        th.col-0 {
            text-align: left;
            border-left: 1px solid black;
        }
        th.single-col {
            border-left: 1px solid black;
            border-right: 1px solid black;
            text-align: left;
        }
        th.instant-data {
            text-align: right;
            border-right: 1px solid black;
        }
        table#info th.col-4 {
            border-right: 1px solid black;
        }
        table#volumes th {
            border: none;
        }
        table#volumes th.col-0 {
            border-left: 1px solid black;
        }
        table#volumes th.col-15 {
            border-right: 1px solid black;
        }
        td {
            padding: 5px;
            border: 1px solid black;
            text-align: center;
            white-space: nowrap;
        }
        td.col-0 {
            text-align: left;
        }
        ul {
            margin-top: 5px;
        }
        .odd {
            background-color:#ffffff;
        }
        .even {
            background-color:#e6e6e6;
        }'
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

        try {
            if ($StartTime.DayOfWeek -ne [Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.FirstDayOfWeek) {
                $Today = $StartTime.Date
                $FirstDayOfWeek = $Today.AddDays(-($Today).DayOfWeek.Value__)
                $StartOfWeekData = Get-Content "$DataFolder\$Array-$($FirstDayOfWeek.ToString("yyyyMMdd")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            } else {
                $StartOfWeekData = Get-Content "$DataFolder\$Array-$($StartTime.AddDays(-1).ToString("yyyyMMdd")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            }
            if ($StartTime.Day -eq 1) {
                $StartOfMonthData = Get-Content "$DataFolder\$Array-$($StartTime.AddDays(-1).ToString("yyyyMMdd")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            } else {
                $StartOfMonthData = Get-Content "$DataFolder\$Array-$($StartTime.ToString("yyyyMM01")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            }
            if ($StartTime.Month -eq 1 -and $StartTime.Day -eq 1) {
                $StartOfYearData = Get-Content "$DataFolder\$Array-$($StartTime.AddDays(-1).ToString("yyyyMMdd")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            } else {
                $StartOfYearData = Get-Content "$DataFolder\$Array-$($StartTime.ToString("yyyy0101")).json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            }

            if (-not (Test-Path -PathType Container $DataFolder)) {
                New-Item -ItemType Directory -Path $DataFolder -Force -ErrorAction Stop | Out-Null
            }

            if ($PSCmdlet.ParameterSetName -eq 'NewConnection') {
                try {
                    $Connection = Connect-PfaApi -ArrayName $Array -Credential $Credential -SkipCertificateCheck -ErrorAction Stop
                } catch {
                    Write-Error $_.Exception.Message
                }
            }

            $ArrayAttributes = Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/array" -ApiVersion 1 -SkipCertificateCheck -ErrorAction Stop | Select-Object array_name, version, revision, id
            if (-not (($Connection.ApiVersion[2].Minor | Select-Object -Last 1) -gt 1)) {
                $ArrayAttributes | Add-Member -MemberType NoteProperty -Name model -Value (Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/array?controllers=true" -ApiVersion 1.18 -SkipCertificateCheck -ErrorAction Stop | Select-Object -Unique -Property model).model
            } else {
                $Request = Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/controllers" -SkipCertificateCheck -ErrorAction Stop
                if ($null -ne $Request) {
                    $ArrayAttributes | Add-Member -MemberType NoteProperty -Name model -Value (Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/controllers" -SkipCertificateCheck -ErrorAction Stop | Select-Object -Unique -Property model).model
                    $ArrayAttributes | Add-Member -MemberType NoteProperty -Name parity -Value (Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/arrays" -SkipCertificateCheck -ErrorAction Stop).parity
                    $ArrayAttributes | Add-Member -MemberType NoteProperty -Name raw -Value (Invoke-PfaApiRequest -Array $FlashArrayC01 -Request RestMethod -Method GET -Path "/drives" -SkipCertificateCheck | Measure-Object -Sum capacity).sum
                }
            }

            $PfaVolumes = Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/volumes" -SkipCertificateCheck -ErrorAction Stop | Where-Object {$_.Name -ne 'pure-protocol-endpoint'} | ForEach-Object {
                $Volume = $_
                $VolumeMetrics = Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/volumes/space?names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop
                $HostConnections = Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/connections?volume_names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop
                [PSCustomObject]@{
                    Name                =   $_.Name
                    Size                =   $_.Provisioned
                    Volumes             =   $VolumeMetrics.Space.Total_Physical
                    Snapshots           =   $VolumeMetrics.Space.Snapshots
                    Reduction           =   $VolumeMetrics.Space.Data_Reduction
                    Shared              =   if ($null -ne $VolumeMetrics.Space.Shared) {
                                                $VolumeMetrics.Space.Shared
                                            } else {
                                                "-"
                                            }
                    System              =   if ($null -ne $VolumeMetrics.Space.System) {
                                                $VolumeMetrics.Space.System
                                            } else {
                                                "-"
                                            }
                    ThinProvisioning    =   $VolumeMetrics.Space.Thin_Provisioning
                    Written             =   ((1 - $VolumeMetrics.Space.Thin_Provisioning) * $VolumeMetrics.Space.Total_Physical)
                    Total               =   $VolumeMetrics.Space.Total_Physical
                    Protected           =   if (-not (Invoke-PfaApiRequest -Array $Connection -Request RestMethod -Method GET -Path "/volume-snapshots?names=$($_.Name)" -SkipCertificateCheck -ErrorAction Stop)) {
                                                "No"
                                            } else {
                                                "Yes"
                                            }
                    Connection          =   if (-not $HostConnections.Host -and -not ($HostConnections.Host_Group)) {
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
                    ChangedThisWeek     =   if ($null -ne $StartOfWeekData.Volumes) {
                                                $PreviousData = $StartOfWeekData.Volumes | Where-Object {$_.Name -eq $Volume.Name}
                                                Get-PercentChanged $PreviousData.Written $((1 - $VolumeMetrics.Space.Thin_Provisioning) * $VolumeMetrics.Space.Total_Physical)
                                            } else {
                                                "n/a"
                                            }
                    ChangedThisMonth    =   if ($null -ne $StartOfMonthData.Volumes) {
                                                $PreviousData = $StartOfMonthData.Volumes | Where-Object {$_.Name -eq $Volume.Name}
                                                Get-PercentChanged $PreviousData.Written $((1 - $VolumeMetrics.space.Thin_Provisioning) * $VolumeMetrics.Space.Total_Physical)
                                            } else {
                                                "n/a"
                                            }
                    ChangedThisYear     =   if ($null -ne $StartOfYearData.Volumes) {
                                                $PreviousData = $StartOfYearData.Volumes | Where-Object {$_.Name -eq $Volume.Name}
                                                Get-PercentChanged $PreviousData.Written $((1 - $VolumeMetrics.Space.Thin_Provisioning) * $VolumeMetrics.Space.Total_Physical)
                                            } else {
                                                "n/a"
                                            }
                }
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Overview") {
                $OverviewMetrics = Get-PfaChartData -Array $Connection -Type Dashboard -ChartName Overview
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Health") {
                $HealthMetrics = Get-PfaChartData -Array $Connection -Type Dashboard -ChartName Health
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Capacity") {
                $SpaceMetrics = Get-PfaChartData -Array $Connection -Type Dashboard -ChartName Capacity
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Latency") {
                try {
                    $IOLatencyMetrics = Get-PfaChartData -Array $Connection -Type Performance -Group Array
                } finally {
                }
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "IOPS" -or $IncludeCharts -contains "Bandwidth") {
                try {
                    $IOMetrics = Get-PfaChartData -Array $Connection -Type Performance -Group Array
                } finally {
                }
            }
            if ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Replication") {
                try {
                    $IOReplicationBandwidthMetrics = Get-PfaChartData -Array $Connection -Type Replication -Group Array -Historical '24h'
                } finally {
                }
            }
        } catch {
            throw $_
        } finally {
            if ($PSCmdlet.ParameterSetName -eq 'NewConnection' -and $null -ne $Connection) {
                Disconnect-PfaApi -Array $Connection -SkipCertificateCheck | Out-Null
            }
        }
    }
    process {
        $ResultsObj = [PSCustomObject]@{
            Attributes  =   $ArrayAttributes
            Volumes     =   $PfaVolumes
            Metrics     =   [PSCustomObject]@{
                                Space       =   $SpaceMetrics
                                IOLatency   =   $IOLatencyMetrics
                                IO          =   $IOMetrics
                                Replication =   $IOReplicationBandwidthMetrics
                            }
            Overview    =   if ($null -ne $OverviewMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Overview")) {
                                New-PfaChart -Type Dashboard -ChartName Overview -ChartData $OverviewMetrics -AsBase64
                            } else {
                                $null
                            }
            Health      =   if ($null -ne $HealthMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Health")) {
                                New-PfaChart -Type Dashboard -ChartName Health -ChartData $HealthMetrics -AsBase64
                            } else {
                                $null
                            }
            Capacity    =   if ($null -ne $SpaceMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Capacity")) {
                                New-PfaChart -Type Dashboard -ChartName Capacity -ChartData $SpaceMetrics -AsBase64
                            } else {
                                $null
                            }
            Latency     =   if ($null -ne $IOLatencyMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Latency")) {
                                New-PfaChart -Type Performance -Group Array -ChartName Latency -ChartData $IOLatencyMetrics -Property "Read","Write" -AsBase64
                            } else {
                                $null
                            }
            IOPS        =   if ($null -ne $IOMetrics-and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "IOPS")) {
                                New-PfaChart -Type Performance -Group Array -ChartName IOPS -ChartData $IOMetrics -AsBase64
                            } else {
                                $null
                            }
            Bandwidth   =   if ($null -ne $IOMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Bandwidth")) {
                                New-PfaChart -Type Performance -Group Array -ChartName Bandwidth -ChartData $IOMetrics -AsBase64
                            } else {
                                $null
                            }
            Replication =   if ($null -ne $IOReplicationBandwidthMetrics -and ($IncludeCharts -contains "All" -or $IncludeCharts -contains "Replication")) {
                                New-PfaChart -Type Performance -Group Array -ChartName Latency -ChartData $IOReplicationBandwidthMetrics -Property "Read","Write" -AsBase64
                            } else {
                                $null
                            }
        }
        if (-not $SaveCharts) {
            $ExcludedProperties = @("Overview", "Health", "Capacity", "Latency", "IOPS", "Bandwidth", "Replication")
        }
        $ResultsObj | Select-Object * -ExcludeProperty $ExcludedProperties | ConvertTo-Json -Depth 5 -Compress | Out-File "$DataFolder\$Array-$(($StartTime).ToString("yyyyMMdd")).json" -Encoding utf8 -ErrorAction SilentlyContinue

        if (-not $SkipVolumesReport) {
            $Volumes = $PfaVolumes |
                Sort-Object Name | ForEach-Object {
                    $VolumeObj = [PSCustomObject]@{
                        Name                =   $_.Name
                        Size                =   Format-Byte $_.Size
                        Volumes             =   Format-Byte $_.Volumes
                        Utilization         =   (($_.Volumes / $_.Size) * 100)
                        Snapshots           =   Format-Byte $_.Snapshots
                        Reduction           =   "{0:N2} to 1" -f $_.Reduction
                        Shared              =   Invoke-Command -Command {
                                                    if ($_.Shared -ne "-") {
                                                        Format-Byte $_.Shared
                                                    } else {
                                                        "-"
                                                    }
                                                }
                        System              =   Invoke-Command -Command {
                                                    if ($_.System -ne "-") {
                                                        Format-Byte $_.System
                                                    } else {
                                                        "-"
                                                    }
                                                }
                        Total               =   Format-Byte $_.Total
                        "Thin Provisioning" =   "{0:N3}" -f $_.ThinProvisioning
                        Written             =   Format-Byte $_.Written
                        Protected           =   $_.Protected
                        "Connection(s)"     =   $_.Connection
                    }
                    if ($null -ne $StartOfWeekData.Volumes) {
                        $VolumeObj | Add-Member -MemberType NoteProperty -Name "This Week" -Value $_.ChangedThisWeek
                    }
                    if ($null -ne $StartOfMonthData.Volumes) {
                        $VolumeObj | Add-Member -MemberType NoteProperty -Name "This Month" -Value $_.ChangedThisMonth
                    }
                    if ($null -ne $StartOfYearData.Volumes) {
                        $VolumeObj | Add-Member -MemberType NoteProperty -Name "This Year" -Value $_.ChangedThisYear
                    }
                    $VolumeObj
            }
        }
        if ($SendEmail -or $SaveAsHTML) {
            $HTMLCharts = ""
            
            if (-not $SkipVolumesReport) {
                if ($null -ne $StartOfWeekData.Volumes) {
                    if ($null -eq $StartOfMonthData.Volumes -and $null -eq $StartOfYearData.Volumes) {
                        $MyCSS += '
                            table#volumes th.col-13 {
                                border-right: 1px solid black;
                                border-left: 1px solid #dddddd;
                            }
                        '
                    }
                } else {
                    $MyCSS += '
                        table#volumes th.col-12 {
                            border-right: 1px solid black;
                        }
                        table#volumes th {
                            border-top: 1px solid black;
                        }
                    '
                }
                if ($null -ne $StartOfMonthData.Volumes) {
                    if ($null -eq $StartOfYearData.Volumes) {
                        $MyCSS += '
                            table#volumes th.col-13 {
                                border-left: 1px solid #dddddd;
                            }
                            table#volumes th.col-14 {
                                border-right: 1px solid black;
                            }
                    '
                    } else {
                        $MyCSS += '
                            table#volumes th.col-13 {
                                border-left: 1px solid #dddddd;
                            }
                        '
                    }
                }
            }
            if ($null -ne $ResultsObj.Overview) {
                $HTMLCharts += "<table><tr><th class=""single-col"">Overview</th></tr><tr><td><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Overview)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.Capacity) {
                $HTMLCharts += "<table><tr><th class=""single-col"">Capacity</th></tr><tr><td><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Capacity)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.Health) {
                $HTMLCharts += "<table><tr><th class=""col-0"">Health</th><th class=""instant-data""><span style=""color: #8d8d8d;"">Raw Capacity:</span> $("{0:N2}" -f (Format-Byte $ResultsObj.Attributes.raw)) | <span style=""color: #8d8d8d;"">Parity:</span> $("{0:N2} %" -f ($ResultsObj.Attributes.parity * 100))</th></tr><tr><td colspan=""2""><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Health)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.Latency) {
                $HTMLCharts += "<table><tr><th class=""col-0"">Latency</th><th class=""instant-data""><span style=""color: #0d98e3;"">R</span> $("{0:N2}" -f ($ResultsObj.Metrics.IOLatency[$ResultsObj.Metrics.IOLatency.Count - 1].Usec_Per_Read_Op / 1000)) ms | <span style=""color: #f37430;"">W</span> $("{0:N2}" -f ($ResultsObj.Metrics.IOLatency[$ResultsObj.Metrics.IOLatency.Count - 1].Usec_Per_Write_Op / 1000)) ms | <span style=""color: #50ae54;"">Q</span> $("{0:N2}" -f ($ResultsObj.Metrics.IOLatency[$ResultsObj.Metrics.IOLatency.Count - 1].Queue_Usec_Per_Write_Op / 1000)) ms</th></tr><tr><td colspan=""2""><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Latency)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.IOPS) {
                $HTMLCharts += "<table><tr><th class=""col-0"">IOPS</th><th class=""instant-data""><span style=""color: #0d98e3;"">R</span> $("{0:N2}" -f ($ResultsObj.Metrics.IO[$ResultsObj.Metrics.IO.Count - 1].Reads_Per_Sec / 1000)) K | <span style=""color: #f37430;"">W</span> $("{0:N2}" -f ($ResultsObj.Metrics.IO[$ResultsObj.Metrics.IO.Count - 1].Writes_Per_Sec / 1000)) K</th></tr><tr><td colspan=""2""><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.IOPS)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.Bandwidth) {
                $HTMLCharts += "<table><tr><th class=""col-0"">Bandwidth</th><th class=""instant-data""><span style=""color: #0d98e3;"">R</span> $(Format-Byte -Bytes $ResultsObj.Metrics.IO[$ResultsObj.Metrics.IO.Count - 1].Output_Per_Sec -Suffix "/s") | <span style=""color: #f37430;"">W</span> $(Format-Byte -Bytes $ResultsObj.Metrics.IO[$ResultsObj.Metrics.IO.Count - 1].Input_Per_Sec -Suffix "/s")</th></tr><tr><td colspan=""2""><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Bandwidth)""></img></td></tr></table><br/>"
            }
            if ($null -ne $ResultsObj.Replication) {
                $HTMLCharts += "<table><tr><th class=""col-0"">Replication</th><th class=""instant-data""><span style=""color: #0d98e3;"">T</span> $(Format-Byte -Bytes ($ResultsObj.Metrics.Replication | Group-Object Time | Select-Object -Last 1 -ExpandProperty Group | Measure-Object -Sum Bytes_Per_Sec).Sum -Suffix "/s")</th></tr><tr><td colspan=""2""><img src=""data:image/png;charset=utf-8;base64,$($ResultsObj.Replication)""></img></td></tr></table><br/>"
            }
            
            if (Get-Module -Name "PS2HTMLTable") {
                $HTML = New-HTMLHead -Style $MyCSS -Title "$Array - Status Report"
                $HTML += "<h3>Array Information</h3>"
                $HTML += '<table id="container" cellpadding="0" cellspacing="0"><tr><td style="border: none; text-align: left;">'
                $HTMLTable = $ArrayAttributes | Select-Object @{Name = "Name";Expression = {$_.Array_Name}},
                                                              @{Name = "Purity//FA";Expression = {$_.Version}},
                                                              @{Name = "Revision";Expression = {$_.Revision}},
                                                              @{Name = "ID";Expression = {$_.Id}},
                                                              @{Name = "Model";Expression = {$_.Model}} |
                                                              New-HTMLTable -HTMLDecode -ColumnClassPrefix "col" -TableAttributes @{width = "1186";id = "info"}
                $HTML += $HTMLTable + "<br />"
                $HTML += $HTMLCharts
                if (-not $SkipVolumesReport) {
                    $HTML += "<h3>Volumes ($($Volumes.Count))</h3>"
                    $HTML += '<table id="volumes" cellpadding="0" cellspacing="0" border="0">'
                    if ($null -ne $Volumes[0]."This Week") {
                        $Header = "<tr><th colspan=""13"" style=""border-right: 1px solid #dddddd;border-left: 1px solid black;border-top: 1px solid black;""></th><th colspan=""3"" style=""border-left: 1px solid #dddddd;border-right: 1px solid black;border-top: 1px solid black;"">Growth</th></tr>"
                    }
                    $HTMLTable = $Volumes | New-HTMLTable -HTMLDecode -SetAlternating -ColumnClassPrefix "col" -PrependHeader $Header -NestedTable -AddTableTags
                    $HTMLTable += "<tfoot><tr><th></th><th>$(Format-Byte ($PfaVolumes.Size | Measure-Object -Sum).Sum)</th><th>$(Format-Byte ($PfaVolumes.Volumes | Measure-Object -Sum).Sum)</th><th>$("{0:N2} %" -f (($Volumes.Utilization | Measure-Object -Maximum).Maximum))</th><th>$(Format-Byte ($PfaVolumes.Snapshots | Measure-Object -Sum).Sum)</th><th>$("{0:N2} to 1" -f ($PfaVolumes.Reduction | Measure-Object -Average).Average)</th><th></th><th></th><th>$(Format-Byte ($PfaVolumes.Total | Measure-Object -Sum).Sum)</th><th></th><th>$(Format-Byte ($PfaVolumes.Written | Measure-Object -Sum).Sum)</th><th></th><th></th>$(if ($null -ne $Volumes[0].'This Week') {"<th>{0:N2} %</th>" -f (($Volumes.'This Week' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})$(if ($null -ne $Volumes[0].'This Month') {"<th>{0:N2} %</th>" -f (($Volumes.'This Month' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})$(if ($null -ne $Volumes[0].'This Year' -and $null -ne ($Volumes.'This Year' | Where-Object {$_ -ne "n/a"})) {"<th>{0:N2} %</th>" -f (($Volumes.'This Year' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})</tr></tfoot>"
                    # Color "Utilization" cell yellow if value is greater than or equal to 60%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 60 -CSSAttributeValue "background-color:#fac13a;" @paramsUtilization
                    # Color "Utilization" cell orange if value is greater than or equal to 75%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 75 -CSSAttributeValue "background-color:#fa8a1c;" @paramsUtilization
                    # Color "Utilization" cell red if value is greater than or equal to 90%
                    $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -Argument 90 -CSSAttributeValue "background-color:#e44f12;" @paramsUtilization -ApplyFormat
                    if ($null -ne $Volumes[0]."This Week") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "This Week" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "This Week" @paramsPercentChangedNegative
                    }
                    if ($null -ne $Volumes[0]."This Month") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "This Month" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "This Month" @paramsPercentChangedNegative
                    }
                    if ($null -ne $Volumes[0]."This Year") {
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#fe5000;" -Column "This Year" @paramsPercentChanged
                        $HTMLTable = Add-HTMLTableColor -HTML $HTMLTable -CSSAttributeValue "color:#0d98e3;" -Column "This Year" @paramsPercentChangedNegative
                    }
                    $HTML += $HTMLTable
                    $HTML += "</table>"
                }
                $HTML += "</td></tr></table>"
                $HTML = $HTML | Close-HTML -Validate
            } else {
                $HTML = @"
                <!DOCTYPE html>
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
                $HTML += "<h3>Array Information</h3>"
                $HTML += '<table id="container" cellpadding="0" cellspacing="0"><tr><td style="border: none; text-align: left;">'
                $HTML += ($ArrayAttributes | Select-Object @{Name = "Name";Expression = {$_.Array_Name}},
                                                           @{Name = "Purity//FA";Expression = {$_.Version}},
                                                           @{Name = "Revision";Expression = {$_.Revision}},
                                                           @{Name = "ID";Expression = {$_.Id}},
                                                           @{Name = "Model";Expression = {$_.Model}} |
                                                           ConvertTo-HTML -Fragment).Replace("<table>",'<table width="1186">').Replace("<tr><th>",'<tr><th style="text-align: left;border-left: 1px solid black;">').Replace("<th>Model</th>",'<th style="border-right: 1px solid black;">Model</th>').Replace("<tr><td>",'<tr><td class="col-0">')
                $HTML += "<br />"

                $HTML += $HTMLCharts
                if (-not $SkipVolumesReport) {
                    $HTML += "<h3>Volumes ($($Volumes.Count))</h3>"

                    $HTMLTable = $Volumes | Select-Object Name,
                                                    Size,
                                                    Volumes,
                                                    @{Name = "Utilization";Expression = {"{0:N2} %" -f $_.Utilization}},
                                                    Snapshots,
                                                    Reduction,
                                                    Shared,
                                                    System,
                                                    Total,
                                                    'Thin Provisioning',
                                                    Written,
                                                    Protected,
                                                    'Connection(s)',
                                                    'This Week',
                                                    'This Month',
                                                    'This Year' |
                                                    ConvertTo-HTML -Fragment -Property $Volumes[0].PSObject.Properties.Name | Out-String
                    $HTMLTable = $HTMLTable.Replace("<th>Name</th>",'<th class="col-0">Name</th>').Replace("<th>Growth This Year</th>",'<th style="border-right: 1px solid black;">Growth This Year</th>').Replace("<tr><td>",'<tr><td class="col-0">').Replace("<table>", '<table id="volumes">').Replace("</table>", "<tfoot><tr><th></th><th>$(Format-Byte ($PfaVolumes.Size | Measure-Object -Sum).Sum)</th><th>$(Format-Byte ($PfaVolumes.Volumes | Measure-Object -Sum).Sum)</th><th>$("{0:N2} %" -f (($Volumes.Utilization | Measure-Object -Maximum).Maximum))</th><th>$(Format-Byte ($PfaVolumes.Snapshots | Measure-Object -Sum).Sum)</th><th>$("{0:N2} to 1" -f ($PfaVolumes.Reduction | Measure-Object -Average).Average)</th><th></th><th></th><th>$(Format-Byte ($PfaVolumes.Total | Measure-Object -Sum).Sum)</th><th></th><th>$(Format-Byte ($PfaVolumes.Written | Measure-Object -Sum).Sum)</th><th></th><th></th>$(if ($null -ne $Volumes[0].'This Week') {"<th>{0:N2} %</th>" -f (($Volumes.'This Week' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})$(if ($null -ne $Volumes[0].'This Month') {"<th>{0:N2} %</th>" -f (($Volumes.'This Month' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})$(if ($null -ne $Volumes[0].'This Year') {"<th>{0:N2} %</th>" -f (($Volumes.'This Year' | Where-Object {$_ -ne "n/a"}).Replace(' %','') | Measure-Object -Average).Average})</tr></tfoot></table>")
                    $HTML += $HTMLTable
                }
                $HTML += "</td></tr></table>"
                $HTML += "</body></html>"
            }
            if ($SaveAsHTML) {
                try {
                    $HTML | Out-File "$DataFolder\$Array.html" -Encoding utf8
                } finally {
                }
            }
            if ($SendEmail) {
                try {
                    $Message = New-Object Net.Mail.MailMessage $FromAddress, $RecipientAddress
                    $ResultsObj.PSObject.Properties | Where-Object {$_.Name -eq "Overview" -or $_.Name -eq "Health" -or $_.Name -eq "Capacity" -or $_.Name -eq "Latency" -or $_.Name -eq "IOPS" -or $_.Name -eq "Bandwidth" -or $_.Name -eq "Replication"} | ForEach-Object {
                        if ($null -ne $_.Value) {
                            $HTML = $HTML.Replace("data:image/png;charset=utf-8;base64,$($_.Value)", "cid:$($_.Name).png")
                            $ImageBytes = [Convert]::FromBase64String($_.Value)
                            $MemoryStream = New-Object IO.MemoryStream($ImageBytes, 0, $ImageBytes.Length)
                            $MemoryStream.Write($ImageBytes, 0, $ImageBytes.Length)
                            $MemoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
                            $AttachmentObj = New-Object Net.Mail.Attachment($MemoryStream, (New-Object Net.Mime.ContentType));
                            $AttachmentObj.ContentType.MediaType = "image/png"
                            $AttachmentObj.ContentId = "$($_.Name).png"
                            $AttachmentObj.ContentDisposition.Inline = $true
                            $AttachmentObj.ContentDisposition.DispositionType = "Inline"
                            $Message.Attachments.Add($AttachmentObj)
                        }
                    }
                    $Message.IsBodyHtml = $true
                    $Message.Subject = "$Array - Status Report"
                    $Message.Body = $HTML
                    try {
                        $HTML | Out-File "$DataFolder\$Array.eml" -Encoding utf8
                    } finally {
                    }
                    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer)
                    $SMTPClient.EnableSsl = $false
                    $SMTPClient.Send($Message)
                } catch {
                    throw $_
                }
            }
        }
    }
}