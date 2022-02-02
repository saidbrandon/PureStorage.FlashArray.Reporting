function Get-PfaChartData {
    <#
    .SYNOPSIS
    Retrieves all necessary data and preformats for New-PfaChart.

    .DESCRIPTION
    Uses Invoke-PfaApiRequest to retrieve data from Array that is preformatted for New-PfaChart.

    .PARAMETER Array
    FlashArray object to query.

    .PARAMETER Credential
    Username and Password needed for authentication.

    .PARAMETER Type
    Specifies the type of chart. Acceptable values are:
        Dashboard
        Performance
        Capacity
        Replication
    
    .PARAMETER ChartName
    Dynamic Parameter: Specifies the chart name. Only available if Type is Dashboard. Acceptable values are:
        Overview
        Capacity

    .PARAMETER Group
    Dynamic Parameter: Specifies the chart group. Acceptable values are dependent on which Type is specified.
        Type: Performance
            Group can be Array, Volume, Volumes, Volume Groups, and File System, Pods, Directories
        Type: Capacity
            Group can be Array, Volumes, Volume Groups, Pods, and Directories
        Type: Replication
            Group can be Array or Volume

    .PARAMETER Historical
    Specify a different timespan for chart. Acceptable values are 5m, 1h, 3h, 24h, 7d, 30d, 90d, and 1y. Only valid on Performance, Capacity, and Replication Charts.

    .PARAMETER Filter
    This parameter is here for future usage (hopefully). Not all API queries support this option. Currently, none used by Get-PfaChartData qualify.

    .PARAMETER Name
    This parameter is used to limit queries to specific names.

    .PARAMETER ApiVersion
    Optional parameter to specify the REST API version to interact with.

    .EXAMPLE
    Retrieve data to create a chart that resembles the "Dashboard -> Capacity" in the Purity//FA UI
    $DashboardMetrics = Get-PfaChartData -Array $FlashArray -Type Dashboard -ChartName Capacity

    .EXAMPLE
    Retrieve data to create a chart that resembles the "Storage -> ArrayName" in the Purity//FA UI
    $DashboardMetrics = Get-PfaChartData -Array $FlashArray -Type Dashboard -ChartName Overview

	.NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PureStorageRestApi]$Array,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Dashboard', 'Performance', 'Capacity', 'Replication')]
        [String]$Type,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [String]$ApiVersion = "2.7"
    )
    DynamicParam {
        $DynamicParameters = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        if ($Type -eq 'Dashboard') {
            New-DynamicParameter -Name 'ChartName' -Type ([string]) -Position 0 -Mandatory -ValidateSet @('Overview', 'Capacity') -Dictionary $DynamicParameters
        } elseif ($Type -eq 'Performance') {
            New-DynamicParameter -Name 'Group' -ValidateSet @('Array', 'Volume', 'Volumes', 'Volume Groups', 'File System', 'Pods', 'Directories') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Historical' -ValidateSet @('5m', '1h', '3h', '24h', '7d', '30d', '90d', '1y') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Filter' -Type ([String]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Name' -Type ([String]) -Position 0 -Dictionary $DynamicParameters
        } elseif ($Type -eq 'Capacity') {
            New-DynamicParameter -Name 'Group' -ValidateSet @('Array', 'Volumes', 'Volume Groups', 'Pods', 'Directories') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Historical' -ValidateSet @('5m', '1h', '3h', '24h', '7d', '30d', '90d', '1y') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Filter' -Type ([String]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Name' -Type ([String]) -Position 0 -Dictionary $DynamicParameters
        } elseif ($Type -eq 'Replication') {
            New-DynamicParameter -Name 'Group' -ValidateSet @('Array', 'Volume') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
            New-DynamicParameter -Name 'Historical' -ValidateSet @('5m', '1h', '3h', '24h', '7d', '30d', '90d', '1y') -Type ([string]) -Position 0 -Dictionary $DynamicParameters
        }
        $DynamicParameters
    }

    begin {
        New-DynamicParameter -CreateVariables -BoundParameters $PSBoundParameters
        if ($null -eq $Name) {
            $Name = "*"
        }
        switch ($Historical) {
            '5m'    {
                $Resolution = 1000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddMinutes(-5)).ToUnixTimeMilliseconds()
            }
            '1h'    {
                $Resolution = 30000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddHours(-1)).ToUnixTimeMilliseconds()
            }
            '3h'    {
                $Resolution = 30000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddHours(-3)).ToUnixTimeMilliseconds()
            }
            '24h'   {
                $Resolution = 300000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddHours(-24)).ToUnixTimeMilliseconds()
            }
            '7d'    {
                $Resolution = 1800000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddDays(-7)).ToUnixTimeMilliseconds()
            }
            '30d'   {
                $Resolution = 7200000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddDays(-30)).ToUnixTimeMilliseconds()
            }
            '90d'   {
                $Resolution = 28800000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddDays(-90)).ToUnixTimeMilliseconds()
            }
            '1y'    {
                $Resolution = 86400000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddYears(-1)).ToUnixTimeMilliseconds()
            }
            ''    {
                $Resolution = 300000
                $StartTime  = $([DateTimeOffset]$(Get-Date).AddHours(-24)).ToUnixTimeMilliseconds()
            }
        }
    }

    process {
        if ($Type -eq 'Dashboard') {
            if ($ChartName -eq 'Capacity') {
                try {
                    $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/arrays" -SkipCertificateCheck -ErrorAction Stop
                    [PSCustomObject]@{
                        Unique          = $RestResponse.Space.Unique
                        Snapshots       = $RestResponse.Space.Snapshots
                        Shared          = $RestResponse.Space.Shared
                        System          = $RestResponse.Space.System
                        Empty           = $RestResponse.Capacity - $RestResponse.Space.Total_Physical
                        DataReduction   = $RestResponse.Space.Data_Reduction
                        Used            = $RestResponse.Space.Total_Physical
                        Total           = $RestResponse.Capacity
                        TotalReduction  = $RestResponse.Space.Total_Reduction
                        ProvisionedSize = $RestResponse.Space.Total_Provisioned
                        Replication     = $RestResponse.Space.Replication
                    }
                } catch {
                    Write-Error $_
                }
            }
            if ($ChartName -eq 'Overview') {
                try {
                    [PSCustomObject]@{
                        Hosts                       =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/hosts" -SkipCertificateCheck -ErrorAction Stop).Count
                        HostGroups                  =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/host-groups" -SkipCertificateCheck -ErrorAction Stop).Count
                        Volumes                     =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volumes?destroyed=False&filter=SubType='Regular'" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volumes?destroyed=True&filter=SubType='Regular'" -SkipCertificateCheck -ErrorAction Stop).Count
                        VolumeSnapshots             =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volume-snapshots?destroyed=False" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volume-snapshots?destroyed=True" -SkipCertificateCheck -ErrorAction Stop).Count
                        VolumeGroups                =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volume-groups?destroyed=False" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/volume-groups?destroyed=True" -SkipCertificateCheck -ErrorAction Stop).Count
                        ProtectionGroups            =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/protection-groups?destroyed=False" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/protection-groups?destroyed=True" -SkipCertificateCheck -ErrorAction Stop).Count
                        ProtectionGroupSnapshots    =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/protection-group-snapshots?destroyed=False" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/protection-group-snapshots?destroyed=True" -SkipCertificateCheck -ErrorAction Stop).Count
                        Pods                        =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/pods?destroyed=False" -SkipCertificateCheck -ErrorAction Stop).Count + @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/pods?destroyed=True" -SkipCertificateCheck -ErrorAction Stop).Count
                        FileSystems                 =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/file-systems" -SkipCertificateCheck -ErrorAction Stop).Count
                        Directories                 =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/directories" -SkipCertificateCheck -ErrorAction Stop).Count
                        DirectorySnapshots          =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/directory-snapshots" -SkipCertificateCheck -ErrorAction Stop).Count
                        Policies                    =   @(Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method GET -Path "/policies" -SkipCertificateCheck -ErrorAction Stop).Count
                    }
                } catch {
                    Write-Error $_.Exception.Message
                }
            }
        } elseif ($Type -eq 'Performance') {
            if ($Group -eq 'Array') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/arrays/performance?resolution=$Resolution&start_time=$StartTime&protocol_group=all" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Volume') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/arrays/performance?resolution=$Resolution&start_time=$StartTime&protocol_group=block" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Volumes') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/volumes/performance?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Volume Groups') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/volume-groups/performance?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'File System') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/arrays/performance?resolution=$Resolution&start_time=$StartTime&protocol_group=file" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Pods') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/pods/performance?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Directories') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/directories/performance?resolution=$Resolution&start_time=$StartTime&protocol_group=all&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop
            }
        } elseif ($Type -eq 'Capacity') {
            if ($Group -eq 'Array') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/arrays/space?resolution=$Resolution&start_time=$StartTime&filter=$Filter" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Volumes') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/volumes/space?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop
            } elseif ($Group -eq 'Volume Groups') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/volume-groups/space?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop                
            } elseif ($Group -eq 'Pods') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/pods/space?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop                
            } elseif ($Group -eq 'Directories') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/directories/space?resolution=$Resolution&start_time=$StartTime&filter=$Filter&names=$Name" -SkipCertificateCheck -ErrorAction Stop                
            }
        } elseif ($Type -eq 'Replication') {
            if ($Group -eq 'Array') {
                $RestResponse = Invoke-PfaApiRequest -Array $Array -Request RestMethod -Method Get -Path "/protection-groups/performance/replication?resolution=$Resolution&start_time=$StartTime" -SkipCertificateCheck -ErrorAction Stop
            }
        }
        if ($Type -ne 'Dashboard') {
            $RestResponse | ForEach-Object {
                $_.Time = [DateTimeOffset]::FromUnixTimeMilliseconds($_.Time).DateTime
            }
            $RestResponse
        }
    }
    end {

    }
}
