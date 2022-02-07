function New-PfaChart {
    <#
    .SYNOPSIS
    Creates an MS Chart with data from Get-PfaChartData.

    .DESCRIPTION
    Creates an MS Chart with data from Get-PfaChartData. 

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
    Specifies the chart name. Acceptable values are dependent on which Type is specified.
        Type: Dashboard
            ChartName can be Overview or Capacity
        Type: Performance
            ChartName can be Latency, IOPS, or Bandwidth
        Type: Capacity
            ChartName can be Array Capacity or Host Capacity
        Type: Replication
            ChartName can be Bandwidth

    .PARAMETER ChartData
    Object containing result data from Get-PfaChartData.

    .PARAMETER Group
    Specifies the chart group. Acceptable values are dependent on which Type is specified.
        Type: Performance
            Group can be Array, Volume, Volumes, Volume Groups, and File System
        Type: Capacity
            Group can be Array, Volumes, Volume Groups, Pods, and Directories
        Type: Replication
            Group can be Array or Volume

    .PARAMETER Property
    Specifies which property or properties to include in chart. Acceptable values are dependent on which Type, Group, and ChartName are specified.
        Type: Dashboard -> ChartName: Overview
            Property can be Hosts, Host Groups, Volumes, Volume Snapshots, Volume Groups, Protection Groups, Protection Group Snapshots, Pods, File Systems, Directories, Directory Snapshots, or Policies.
        Type: Performance -> Group: Array, Volume, Volumes, Pods -> ChartName: Latency, IOPS, or Bandwidth
            Property can be Read, Write, MirroredWrite
        Type: Performance -> Group: File System, Directories -> ChartName: Latency, IOPS, or Bandwidth
            Property can be Read, Write, MirroredWrite

    .PARAMETER Width
    Optional parameter to change the width of the chart. The default value is 1175.

    .PARAMETER Height
    Optional parameter to change the height of the chart. The default value is 120.

    .PARAMETER Title
    Optional parameter to change the title (where applicable). The default value is "Type - ChartName".

    .PARAMETER AsChart
    Specifies the output type as an MS Chart Object.

    .PARAMETER AsImage
    Specifies the output type as a PNG Image in a byte array.

    .PARAMETER AsBase64
    Specifies the output type as a Base64 string.

    .OUTPUTS
    System.Windows.Forms.DataVisualization.Charting.Chart - MS Chart Object
    Byte[] - PNG Image as Byte Array
    String - PNG Image as Base64

    .EXAMPLE
    Retrieve data to create a chart that resembles the "Dashboard -> Capacity" in the Purity//FA UI
    $DashboardMetrics = Get-PfaChartData -Array $FlashArray -Type Dashboard -ChartName Capacity
    New-PfaChart -Type Dashboard -ChartName Capacity -ChartData $DashboardMetrics -AsChart | Show-PfaChart

    .EXAMPLE
    Retrieve data to create a chart that resembles the "Storage -> ArrayName" in the Purity//FA UI
    $DashboardMetrics = Get-PfaChartData -Array $FlashArray -Type Dashboard -ChartName Overview
    New-PfaChart -Type Dashboard -ChartName Overview -ChartData $DashboardMetrics -AsImage | Show-PfaChart

	.NOTES
	Author: brandon said
    #>
    [OutputType('[System.Windows.Forms.DataVisualization.Charting.Chart]', ParameterSetName = ("AsChart"))]
    [OutputType([Byte[]], ParameterSetName = ("AsImage"))]
    [OutputType([String], ParameterSetName = ("AsBase64"))]
    [CmdletBinding()]
    param (
        [ValidateSet("Dashboard", "Performance", "Capacity", "Replication")]
        [String]$Type,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("Array", "Volume", "Volumes", "Volume Groups", "Pods", "FileSystem", "Directories")]
        [String]$Group = "Array",

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateScript({
            if ($Type -eq "Dashboard") {
                if ($_ -eq "Capacity" -or $_ -eq "Overview") {
                    $_ -eq "Capacity" -or $_ -eq "Overview"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } elseif ($Type -eq "Performance") {
                if ($_ -eq "Latency" -or $_ -eq "IOPS" -or $_ -eq "Bandwidth") {
                    $_ -eq "Latency" -or $_ -eq "IOPS" -or $_ -eq "Bandwidth"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } elseif ($Type -eq "Capacity") {
                if ($_ -eq "Array Capacity" -or $_ -eq "Host Capacity") {
                    $_ -eq "Array Capacity" -or $_ -eq "Host Capacity"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } elseif ($Type -eq "Replication") {
                if ($_ -eq "Bandwidth") {
                    $_ -eq "Bandwidth"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            }
        })]
        [ValidateSet("Capacity", "Overview", "Latency", "IOPS", "Bandwidth", "Array Capacity", "Host Capacity")]
        [Alias("Name")]
        [String]$ChartName,

        [Alias("Data")]
        [Object]$ChartData,

        [ValidateScript({
            if ($Type -eq "Dashboard" -and $ChartName -eq "Overview") {
                if ($_ -eq "Hosts" -or $_ -eq "Host Groups" -or $_ -eq "Volumes" -or $_ -eq "Volume Snapshots" -or $_ -eq "Volume Groups" -or $_ -eq "Protection Groups" -or $_ -eq "Protection Group Snapshots" -or $_ -eq "Pods" -or $_ -eq "File Systems" -or $_ -eq "Directories" -or $_ -eq "Directory Snapshots" -or $_ -eq "Policies") {
                    $_ -eq "Hosts" -or $_ -eq "Host Groups" -or $_ -eq "Volumes" -or $_ -eq "Volume Snapshots" -or $_ -eq "Volume Groups" -or $_ -eq "Protection Groups" -or $_ -eq "Protection Group Snapshots" -or $_ -eq "Pods" -or $_ -eq "File Systems" -or $_ -eq "Directories" -or $_ -eq "Directory Snapshots" -or $_ -eq "Policies"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } elseif ($Type -eq "Performance" -and ($Group -eq "Array" -or $Group -eq "Volume" -or $Group -eq "Volumes" -or $Group -eq "Pods") -and ($ChartName -eq "Latency" -or $ChartName -eq "IOPS" -or $ChartName -eq "Bandwidth")) {
                if ($_ -contains "Read" -or $_ -contains "Write" -or $_ -contains "MirroredWrite") {
                    $_ -contains "Read" -or $_ -contains "Write" -or $_ -contains "MirroredWrite"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } elseif ($Type -eq "Performance" -and ($Group -eq "File System" -or $Group -eq "Directories") -and ($ChartName -eq "Latency" -or $ChartName -eq "IOPS" -or $ChartName -eq "Bandwidth")) {
                if ($_ -eq "Read" -or $_ -eq "Write" -or $_ -eq "MirroredWrite") {
                    $_ -eq "Read" -or $_ -eq "Write" -or $_ -eq "MirroredWrite"
                } else {
                    throw "$_ is not a valid parameter value for the $Type parameter"
                }
            } else {
                throw "Invalid parameter specified, or specified in the incorrect order"
            }
        })]
        [ValidateSet("Read", "Write", "MirroredWrite", "Hosts", "Host Groups", "Volumes", "Volume Snapshots", "Volume Groups", "Protection Groups", "Protection Group Snapshots", "Pods", "File Systems", "Directories", "Directory Snapshots", "Policies")]
        [String[]]$Property,
        

        [Int32]$Width = 1175,
        [Int32]$Height = 120,
        [String]$Title = "$Type - $ChartName",
        [Parameter(ParameterSetName = 'AsChart')]
        [Switch]$AsChart,

        [Parameter(ParameterSetName = 'AsImage')]
        [Switch]$AsImage,

        [Parameter(ParameterSetName = 'AsBase64')]
        [Switch]$AsBase64
    )

    begin {
        Add-Type -AssemblyName System.Windows.Forms.DataVisualization
    }

    process {
        if ($ChartName -eq "Capacity") {
            if (-not (Test-Path Variable:ChartColors)) {
                New-Variable -Name ChartColors -Value @{
                    'System'        = "#ffb8bebe"
                    'Replication'   = "#ddd000"
                    'Shared'        = "#ff55c707"
                    'Snapshots'     = "#ffb5a1dd"
                    'Unique'        = "#ff2ec6c8"
                    'Empty'         = "#fff4f2f3"
                } -Option Constant -Scope Script
            }
            $Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Name = $Title
            $Chart.Width = $Width
            $Chart.Height = $Height
            $Chart.BackColor = "White"
    
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Name = "ChartArea1"
            $ChartArea.Position.X = 0
            $ChartArea.Position.Y = 0
            $ChartArea.Position.Width = 20
            $ChartArea.Position.Height = 100 
            $Chart.ChartAreas.Add($ChartArea)
            [void]$Chart.Series.Add("Data")
            $Chart.Series["Data"].MarkerStyle = "Square"
            $Chart.Series["Data"].CustomProperties = "PieStartAngle = 270, PieLabelStyle = Disabled, DoughnutRadius = 35"
            $ChartData.PSObject.Properties | Where-Object {$_.Name -eq 'System' -or $_.Name -eq 'Replication' -or $_.Name -eq 'Shared' -or $_.Name -eq 'Snapshots' -or $_.Name -eq 'Unique' -or $_.Name -eq 'Empty'} | Sort-Object {@('System', 'Replication', 'Shared', 'Snapshots', 'Unique', 'Empty').IndexOf($_.Name)} | ForEach-Object {
                $DataPoint = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $_.Value)
                $DataPoint.Label = $_.Name
                $DataPoint.Color = $ChartColors.$($_.Name)
                $DataPoint.BorderColor = "#FFFFFF"
                $DataPoint.BorderWidth = 1
                $DataPoint.IsVisibleInLegend = $false
                $Chart.Series["Data"].Points.Add($DataPoint)
            }
            $Chart.Series["Data"].ChartType = "Doughnut"
    
            $Annotation = New-Object System.Windows.Forms.DataVisualization.Charting.TextAnnotation
            $Annotation.ForeColor = "#454545"
            $Annotation.Text = "$("{0:P0}" -f ([double]$ChartData.Used / [double]$ChartData.Total))"
            $Annotation.AnchorX = 10
            $Annotation.AnchorY = 67
            $Annotation.Font = [System.Drawing.Font]::new('Proxima Nova', 28, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $Chart.Annotations.Add($Annotation)
    
            $Annotation = New-Object System.Windows.Forms.DataVisualization.Charting.LineAnnotation
            $Annotation.LineWidth = 3
            $Annotation.LineColor = "#8d8d8d"
            $Annotation.AnchorX = 10
            $Annotation.AnchorY = 67
            $Annotation.Height = 2.5
            $Annotation.Width = 3
    
            $Annotation.AxisX = $Chart.ChartAreas["ChartArea1"].AxisX
            $Annotation.AxisY = $Chart.ChartAreas["ChartArea1"].AxisY
            $Chart.Annotations.Add($Annotation)
    
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Name = "ChartArea2"
            $ChartArea.Position.X = 20
            $ChartArea.Position.Y = 0
            $ChartArea.Position.Width = 30
            $ChartArea.Position.Height = 100 
            $Chart.ChartAreas.Add($ChartArea)
    
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Name = "ChartArea3"
            $ChartArea.Position.X = 50
            $ChartArea.Position.Y = 0
            $ChartArea.Position.Width = 25
            $ChartArea.Position.Height = 100 
            $Chart.ChartAreas.Add($ChartArea)
    
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Name = "ChartArea4"
            $ChartArea.Position.X = 75
            $ChartArea.Position.Y = 0
            $ChartArea.Position.Width = 25
            $ChartArea.Position.Height = 100 
            $Chart.ChartAreas.Add($ChartArea)
    
            $Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
            $Legend.Name = "Legend1"
            $Legend.Docking = "Left"
            $Legend.Alignment = "Center"
            $Legend.IsDockedInsideChartArea = $true
            $Chart.Legends.Add($Legend)
            $Legend.DockedToChartArea = "ChartArea2"
    
            $Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
            $Legend.Name = "Legend2"
            $Legend.Docking = "Left"
            $Legend.Alignment = "Center"
            $Legend.IsDockedInsideChartArea = $true
            $Chart.Legends.Add($Legend)
            $Legend.DockedToChartArea = "ChartArea3"
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$("{0:N2}" -f $ChartData.DataReduction) to 1", [System.Drawing.ContentAlignment]::MiddleCenter)
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "", [System.Drawing.ContentAlignment]::MiddleCenter)
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#454545"
            $LegendItem.Cells[0].CellSpan = 2
            [void]$Chart.Legends["Legend2"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "Data Reduction", [System.Drawing.ContentAlignment]::MiddleCenter)
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "", [System.Drawing.ContentAlignment]::MiddleCenter)
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#8d8d8d"
            $LegendItem.Cells[0].CellSpan = 2
            [void]$Chart.Legends["Legend2"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "", [System.Drawing.ContentAlignment]::MiddleCenter)
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "", [System.Drawing.ContentAlignment]::MiddleCenter)
            $LegendItem.Cells[0].CellSpan = 2
            [void]$Chart.Legends["Legend2"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$(Format-Byte $ChartData.Used)", [System.Drawing.ContentAlignment]::MiddleCenter)
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$(Format-Byte $ChartData.Total)", [System.Drawing.ContentAlignment]::MiddleCenter)
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#454545"
            $LegendItem.Cells[1].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[1].ForeColor = "#454545"
            [void]$Chart.Legends["Legend2"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "Used", [System.Drawing.ContentAlignment]::MiddleCenter)
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "Total", [System.Drawing.ContentAlignment]::MiddleCenter)
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#8d8d8d"
            $LegendItem.Cells[1].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[1].ForeColor = "#8d8d8d"
            [void]$Chart.Legends["Legend2"].CustomItems.Add($LegendItem)
    
            $Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
            $Legend.Name = "Legend3"
            $Legend.Docking = "Left"
            $Legend.Alignment = "Center"
            $Legend.IsDockedInsideChartArea = $true
            $Chart.Legends.Add($Legend)
            $Legend.DockedToChartArea = "ChartArea4"
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$("{0:N2}" -f $ChartData.TotalReduction) to 1", [System.Drawing.ContentAlignment]::MiddleCenter);
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#454545"
    
            [void]$Chart.Legends["Legend3"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "Total Reduction", [System.Drawing.ContentAlignment]::MiddleCenter);
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#8d8d8d"
            [void]$Chart.Legends["Legend3"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "", [System.Drawing.ContentAlignment]::MiddleCenter);
            [void]$Chart.Legends["Legend3"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$(Format-Byte $ChartData.ProvisionedSize)", [System.Drawing.ContentAlignment]::MiddleCenter);
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#454545"
            [void]$Chart.Legends["Legend3"].CustomItems.Add($LegendItem)
            $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
            [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "Provisioned Size", [System.Drawing.ContentAlignment]::MiddleCenter);
            $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $LegendItem.Cells[0].ForeColor = "#8d8d8d"
            [void]$Chart.Legends["Legend3"].CustomItems.Add($LegendItem)
    
            $Chart.ApplyPaletteColors()
    
            $Chart.Series.Points | Sort-Object {@('System', 'Replication', 'Shared', 'Snapshots', 'Unique', 'Empty').IndexOf($_.Label)} | ForEach-Object {
                $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                $LegendItem.MarkerStyle = $_.MarkerStyle
                $LegendItem.MarkerColor = $_.Color
                $LegendItem.MarkerSize = 11
                $LegendItem.ImageStyle = "Marker"
                $LegendItem.BorderColor = "#C5C5C5"
                $LegendItem.Color = $_.Color
    
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::SeriesSymbol, "", [System.Drawing.ContentAlignment]::MiddleCenter)
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, $_.Label, [System.Drawing.ContentAlignment]::MiddleLeft);
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, (Format-Byte $_.YValues[0]), [System.Drawing.ContentAlignment]::MiddleRight);
                $LegendItem.Cells[1].Font = [System.Drawing.Font]::new('Proxima Nova', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                $LegendItem.Cells[1].ForeColor = "#8d8d8d"
                $LegendItem.Cells[2].Font = [System.Drawing.Font]::new('Proxima Nova', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                $LegendItem.Cells[2].ForeColor = "#454545"
                [void]$Chart.Legends["Legend1"].CustomItems.Add($LegendItem)
            }
            $Chart.Add_CustomizeLegend({
                Invoke-ChartCustomizeLegend -Sender $Chart -EventArgs $_
            })
            $Chart.Add_PostPaint({
                Invoke-ChartPostPaint -Sender $Chart -EventArgs $_
            })
        } elseif ($ChartName -eq "Overview") {
            $Heros = @{
                "Hosts"                     	=	[PSCustomObject]@{
                                                        Name        =   "Hosts"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAADASURBVEhLY/z//z8DLQETlKYZGLWAIBi1gCBgXLJkCU0zAt2DKDEmJobx379/gVA+xQA5iB4ADVeEshmA4seBlAWEhwF2AIuYk1A2XoDsA4Xly5crgBjz588XAFIGIDY6ABrcCHSI558/fzoYGRkfQIVxAvRI/gDEO4DYAYglQAJI4AMw6BLj4uI2LFq0yIOJiWk9UIwDIoUboMcByOURQIxiONDVN4CutYQaHkGs4SAwWlwTBKMWEASjFhAADAwAhOU/CLw015EAAAAASUVORK5CYII='
                                                    }
                "Host Groups"	                =	[PSCustomObject]@{
                                                        Name        =   "Host Groups"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAHKSURBVEhL3ZW/T8JQEMdpAwmjbrrhxujIpmyyyQbhR+x/oJubMsnoplsNP0LcdIJNNnVjk03GbjKSQMDP0Qdpm7aSgJj4TS737vp69+7dffO0RqMxi/widKUXGCFdpTcCV4LxeHxQLBbTojE3ksR5RQOCS+A58L+iUrblwgDJsrdnm+Fw9WA6nWbK5XKnXq+nNE2TBF50qC4vi1gsdoXKIXtiB8F1Rbqut0n45Rd8NptVOHVG1tFo9AV1joQGF3ibLNhRegGLyrKlUunaNM0dCc4BDtW3v4fGfV+i47a5eWydaG/STNG2uT6cFYwYwV3DMEY0M84YfuILmhIL6dvLcDgTWIzhvlpH6M0H05JUphNdDpLlIMNWq5WYTCYJ5feFtwdV5JFrOiH4je1y4ZZDXDSbzSR77rCPbXcwVm3yEC4YsPyJ/cIBIZqXL76QBLI5DBbVVAqFQl+IRm9MfCsF3wqkgjb6nxCNu35gOtLIvXKtDWcFlrxkQjQx8AvRgma8wyHe1ToUzgqWfRAmo3z7QuD5uwDBqlQsr1sovD3oEuCZH49Yn9quJZZcqNVqOR4nGdcfh2OlJpO0x0OTzefzA/af4ZLgKyAS+QYpPdGbXFtN8AAAAABJRU5ErkJggg=='
                                                    }
                "Volumes"                       =   [PSCustomObject]@{
                                                        Name        =   "Volumes"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAG/SURBVEhL7VXPS8JgGN634XAQzawYOxgERSuIoEsRBB3qVOcgQrE/IPwT1h9Qt6CDJ1EjpXMgXToUeAi6JRIeTEgUnGlFm0PXsx9IESLFvPnAs/f93vfZ+37bXj+JYRjUIEE7dmAYNuiLgTcgjqVSqZS/1WptEkLWMFkSQrPwJ2BHLUEPQPsJXQXuE5jvdDpZ2OtQKFQ18ySZTI4heAJ/H0LWDLoAHTUv0fyQxkVG4QMXi5vw0DS9Bx7T6HSKwL0ddw/Y+DManFnfQJZlWpKk1Xa7vY3lOpLzzvv/C1QwD2Zxf0ZRlKtIJKKReDy+EAwGHy3JN6TTaV7XdRHicdBjWoZhulOHzbxhEyqsglw1HA5XsP5x7sRisSmSSCSQN+6wPoc4A2HBTv8P0WjUz3HcFmruYrljNbBTNhqNRqVYLD6Uy+V8rVYr1ev1F1VVm+CHI7HAsizn9XpHeJ4XfD6fKAjCTCAQWBRFcQ5P0n3SXw3chjmmOcd3Haj9SmuatgL/CCxZUReAwhp4AS53jwpMDYNmS5jdDfw2lhAyj4tpvM9JS9Ab7yhkbq4AbQ7+LfwbTGbTTA7/0fpi2KAPKOoL18/SlQH0BdwAAAAASUVORK5CYII='
                                                    }
                "Volume Snapshots"              =   [PSCustomObject]@{
                                                        Name        =   "Volume Snapshots"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAHASURBVEhLvZQ7U8JAEMeTIzCUlpTQWVpqJXZ8hQyPMZXjN9CSCjtbuzA8JnaWYkVLSakdpaUlAwH877FkEskduVH8zezs7RF2724f9mazsY6JzVqL7/ulQqHQwWGueSsLo+Vy6Qk2tOTz+cDQOVFzHGd88Aa9Xq8mhHhl05iDAQaDQQfqbmtZc9zkqtlsTtjeIwiCchiGL7Ztn5Gd5YnOWRMTnXPCdd0ZbjxlM1OAX5GpikwZDof+rihkAJRhEZVCG5eQEu1pmK7X67dWqzVie49EAErKarUaY12mjawgid16ve6xmSAeQMB5AG3knCAH/X5/V11KKMnxKplBHvDntkKe8PuX/BLgFje8VOKwlqC1LzzP+2QzFZz6A44f2SzTGNH9x0YjRdOu0WhkaTx6W39rWVYul6vMAcbCKdkITs9NzSmL5U/6ABVYg+MxCUwKHlWicQCUqPYJf/BsHACnnPNSCYrhHXKPJ3eNc4AkV/kpJJQDmj9s7nH0WfS/AdDistQOIOf8DlRo1HhpJHIA6ONolqdQhCQ6H3mr8DoVgYR1eU2cQKoaiTsn2qyViMVicQutHL0qaDbh9PHDpWBZ35IIvWZTg9OYAAAAAElFTkSuQmCC'
                                                    }
                "Volume Groups"                 =   [PSCustomObject]@{
                                                        Name        =   "Volume Groups"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAANNSURBVEhLrZVfSNNRFMf3++2fbjrnjBUJhRhtSIGB1EP5MCWIQVAPKqGweui1l14D2WP0XNBDSioDtR5SyKIXg8QIBCOk2cNKImv0Z7r//9fnbHMoOozmFw7n3HvOPX/uPfdeRVPG5OSkLZ1O9yiKcp6hs1AonERuQW4qGlQBdglYENtP8FXGi6qqvhocHPwlemVqaqoplUrdQ/ZgZJDJWkGQNMxnMBhuq2TtxfHNg3IuEF/Q9Uwmc1fNZrMjRFwp6w4SX3O53EjxDIaHh1WHw9Gbz+evMuwiYBsZHBLdv4I1cdgafIkzmLPZbE/dbndKzkDb39+fK5kVDZXp6Wk1Fos1Go3GVoLambaIjqCH0auISSiEnNVqtUHkdZ1OF+zr68tjUxBbgfhSJiYm1pDvU85sIBBY9Xq9+ZL6/+Hz+Y7i3EVytyRAMSIT4vgnNE8W71F+ptR1+Ca6NAlExW4LVGfGTovOgs0Rpo5DHVA3dAKdDq6pBKgGCQwJdlSGA9kqhSSEV4XKwtdleU+II8BWa/XbSeb2c47vDyql9uLkEoNnzH0vqWpCBF8L8Bv47qo8FYLR0dE6grXSEV0MOyHpIBsLqj4X2G/AfnMOqxT0DtvloaGhCPPFrVfGx8cfcoCPTCbTMu0qV7xmyL1yOp3H8HuteMhADlC25znyG/Z4hYyCyWQybrFYEna7PeNyubLF1WXI/cHWwFOjZ2jG3sq6dubOkf1luBNurNpFPCEpFieFk0kWB5XLKJADLh+4Tq/X1/Ow1ZdVOyAB5FmVZ/nAQRVxlcinkB9AP6Cab3EZYegJVZ+pdNHMzIwpFAp1UPJFhp1Eb5eOghsZ65B39Tw6HhtFGkNueYDhCvQSH4uVD4ctusPEY7/f/22Pd0gZGxsz0c9GHO36LyKRSK6hoSE6MDAgv9oO0J0Wgl3Z6iLJYgmaQ17gHvhZuEEXSefktr+22yGdRNWq1WrVsdXGcDjcxtqz+HBD3STVXK2LCvF4fDMajf7hO40lEokIc7vOh8IacVxnNpubSahFGqusqkAuWmqv8g8CVJFXcS4/2CzjTGm6dohj2Fu6qKfSRfJJMNGLeAGD03AHwW1F5f7IsOYL9h+R57mYLzweD7JG8xfONcpcwZLWdQAAAABJRU5ErkJggg=='
                                                    }
                "Protection Groups"             =   [PSCustomObject]@{
                                                        Name        =   "Protection Groups"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJ7SURBVEhLjZYrcBNRFIY3r5nKShzgkNRFFldJFTB5TOLqSlWnCuJAJSjiUvKYSkC1DiQSRySOysjOJJP0+2/Obvdxs8s/c+ecvXf3/Of899yblDabTSCUSiVn05hOp89ZO+W9jk3d4n9arVbDbre7sLkEwpjCTgIFxrxjvHQTWSyMaJAmyiWYTCaH+Oe4R26iGAp+uVwuP0J0qwkvARkrsDI+dBNZ3PHunHdUmQ93jKGIOp2OIxLKZlXBD4wvuD4c8OHTVqt1AMkLnn+6lST2GG+r1ariRIgqmM1mD3VtEWUUlh6HSemtuNFoRBvqJWBuyOb1fIHTEBGmH5cuThBJFAdlerP2Adkk1/ftUxZVsztBhnWy+4r7aDvjcIN0xyQhGXPhrSCFz4x4cOGIKk/Mz0UuAa17Ytoq04NmsyltP2hNGzwajdLEGeQSsNmn5g4J/lsO0vQw2p/9Wq1WeBhzCcjyr7l1swFBn2Fc5uv1urARivbgwmx9PB6/lkPQJ1TWwx632+0bt5oDLwEyKMtAsuhMyC+Xy3003yPoN1rzvazmBdYem5uBl6BSqbwyN+DAqYoBY8585mYVKUnE50NZHeIn+R8m6gqTIMpyF+i0K4yTzzDgJJ+Zn6jg0qwDZV+he26XkNQIEw+udv6ydbdI/B6QjU5sQgbWz9BcEkVAFrWo3k1cdGHVYUwhsQds7hsWXb+HgLgP8XV4qFQVwf/gJoLz3YVP0kQFgmV3jRv1vkG/XLrYMhut4FTpTrgQryBDIKgzuGt0BRfdNwtk6aYzLyQIgTT6J9Fn7LuJJH7xTZeOmdtzhP8mEKQ9kqlboo7im54Omz1m8EAQBPcEskjysSPpNQAAAABJRU5ErkJggg=='
                                                    }
                "Protection Group Snapshots"    =   [PSCustomObject]@{
                                                        Name        =   "Protection Group Snapshots"
                                                        Label       =   "Protection Group\nSnapshots"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAALVSURBVEhLlVYrbBtBEL2zbOugywITlrKGpbCsYTFr5Y9i5qDWqClyjFKjOqhljvyRyxqWQkOzBIY1rIaBJ/lzeW9v5nSfta0+abUzs7Mzu7Mzc+cGQeC4ruv8LyaTyf56vW5j/5mIZuC79Xr9VnjH2N7loN/ve/l8/ni5XM4ajYYPvlQoFPpYOg01koC9R9jrVqvVm60OaAiGz7D2Bewexhy6XTj6CQeHkH8Cr6efY1AnjqdKpXKQcSCGP9MA2FIoTUAd3XieZ9Z9359jTzN2GAM4cCMHMLyHk9FoE8NmOI1n7L2Gox5C90yBhJOHuyJPBzkSo9HoCsb/grzASBiHkQeMFmcRKUow1Oa+4XB4SQHfCA5+mVWBcQDQsBeSIWgQWVGu1WpHGD3O5CF/FBWFcTQYDKyPrg4ixA3HU44gD/lrkA2MJyMU5HI5a1jTDmY2w2kwBTEOQDJ7tiIvs8KX2QDXfo/rHwtLTHGAqdBEQp/Ao+8zaRSZECnw8G9w7TvGNzbuKBeVDJhF0DEZpNjoAPgh8y3epYP5DwYToU2hDcioD5j0xuaNrA4YGkxUnC8Wi48IyyVmPixjfoq0jIfNBoauTGLbDQie2GQHqjaiETpTWBvASj9BEpi6sTpAFjEczCQ2Npa/gxscYmMXKXyCCk3XguIBeqybKBFMqxiPx4HwPhResSLlMe9DsXOkJ1JIa/knrMPaSac3badvwF7CXsRcZ4t4i9HB5nSndKCnndQAztKtxMDcAKe9R3pp+vlyGobJCrYFvMNvYYkpDvRO6AjxG5xjaNF43AwjTLkMcJgm1ifCEtzXCsksonbNjeA19xU9vMlX/ZIVi8Xv0E+ExhZ7hbGtDgi2XdCJQsI6P4HXIClPvAXWWsiYnrAZZBwQEl9+c7d9dPixYceN96UMrA4I/jGsVivG2VaxM4StjLDt7KQbHShSIfOh28Gpvwm/E0EQOC8EvZUseAimBgAAAABJRU5ErkJggg=='
                                                    }
                "Pods"                          =   [PSCustomObject]@{
                                                        Name        =   "Pods"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJ5SURBVEhLpZQtcBNREMfvMkkmjsjK4lIFsjiiKA4HnXwMp8DRKloHqkS1VeCuk49JUSDjwDWuoAiKOpCRmckXv3237+bueoHm+p95tx9vb/e93X3rOreA7/vlYrF4vFwun6vKYui6rler1UaZA+C8lM/nL3B0X1VJTFgPcgG/PgqFwlHC+WfkM+g4EJ0SN/Mz3YDTbxDgF2yJNcHR40aj8TWydwG7KXKmG+DgFUScCwbWucDzvD8EPFVx/QCSe0hYVNJiUxICneTfYO0AFPYAshFIjsNpdyQtKlo8Ver8swbyIw4rKm5zskfQh4EYg6Slpbd5wdo2WvTXAnS7Xbl+1CgrpPjVMECv16ug8GFv61hwhS9Pim8C9Pv9zfl8fglbFjkrcDoiTafT6fSMbjKFdqUraLsf8KZvFRMMzxeLxXfpCH68B32GPvUA7H9jHTabzYGqQridTmePn49VNsa5XG5X5oiqDPQB9WGTRZ5w4rvS/yrH4FLU31DbZmOMt6wxwY2z2Ww2lCtrEElltC3P6/X6rvLXIO8g2tMt65zAX7iZWbTqJc7Lsic2xliB/FPZVCQf2lA+7Xb7CSRMBUEqBNlTPhwLN0EsAD+Hk1BpCPbuKA3HgAD5StlUJG9gxi8tK6eMFk066aMw7NmXbUCnpRbXQgJEh5W8YDMROVkV9gTHH1hVHo1JHx0mk9RirIdZCemiT1DJuQHO3uLsjYox0FUHBD5SUXBCB+0rnwpXX7E8tGjeBwRq2faUdsXxa/Q7wXYAdFvJ95KEGRXc4iXkvfBr4B2nP1R+JUyRMZQ8i3GsQ1ZB6nIT54LYuP7fRGVvxNpPmznpcJy/dA8fM1Mpht4AAAAASUVORK5CYII='
                                                    }
                "File Systems"                  =   [PSCustomObject]@{
                                                        Name        =   "File Systems"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAFeSURBVEhL7ZW7ToRAFIa59pZbaqeddrbbWdoSIJEn8TXsMATCWvkIWlpiZ+eWW25pAgH/M3sYZwUcl2n3S2bPhcn5Z87Ajt11nUXYti1sT5ZlN8hdczgJ5qzrul4lSfLFKYGsOyaA4reO4zxzqAU1qqZplhDZckoKOOL3FxC7ZPdf0HzP817SND3hlGRUQKVt2wCrWY4NniKYEvHYTuL7/lsQBGsO98jznL0digiJi3bJHWDyJ0ZXluUpp2bRi3C41yKjwirqGWrPQMOK7SRGAlEUBTBX/aHTC7F78oPpDkikiuP4lQa9EJyWGAvoOApoOQpokfdBURTCcV33DP/td/jc7ymmjwf+hnwdqLXAPVKSH4ahuGC0AnPpBUZbBNGKXWMGO8DKL6D+gfgc7VmIhweCGlvUEIscCCB+gHki/xDQ+w0tjEN5Jw8E5oJVP0Ig4fDvS38OaOc7uwqW9Q1tTLLT6+ojZwAAAABJRU5ErkJggg=='
                                                    }
                "Directories"                   =   [PSCustomObject]@{
                                                        Name        =   "Directories"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEGSURBVEhLY/z//z8DLQETlKYZYFy8eLEDkAZhdPDhz58/CxISEj5A+WQBxiVLlnwH0hwQLgZ4wMzM7BgREfEAyicZgIIIl+EgoPD379/zQEdYQPkkA5APwLEsLi7OICYmBhb8/fs3w40bN8BsKPgBxIXABIEiSAjExMQcgFugq6vLoKenB5YAgcePHzMcPXqUAegDqAhZYAPOVCQrK8vg7u7OwMbGBhUhCwTg9AEMfP36leHy5csMX758gYoQBu/fv2f49esXmE3QAnLAnj17GF6+fAlm0zyjjVpAEIxaQBAMfQvgOVlZWZlBUVERLEgpOHv2LLi4AAG4BbQCtA+iId6qYGAAAL8tX/+7ydsAAAAAAElFTkSuQmCC'
                                                    }
                "Directory Snapshots"           =   [PSCustomObject]@{
                                                        Name        =   "Directory Snapshots"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAH2SURBVEhLtZY7awJBEMfnLj4SUImFmgiChaIgGrGQgI3pQho/gBZ+i3ycFCqYKnYBsQhWaQTF5joLLRQExfcTMzu3mlyi8Uy4Hyw7/+Fu5nb2dcJmswEtUZ0gl8uF8dlLLonVaiWl0+k2l3tRlQCDp7F7kpWCGb5/l0ql3rn+gcj7Y+wLzjgXBOEln8+7uf6BmhFcFgqF3ng8BoPBAD6fj5ytVgt6vR7ZGEPC7pmEkjdKkMlk7kVRfOROBXa73RqLxW6KxSLg10IikSD/dDoF5huNRqQPcebxeG4x+CvaHmxsqIqGX341GAwgHo9Do9HYjUCv14PT6YR2uw3z+Zx8+xCy2eyhCVTg9/vB6/WCxWLhnk+63S6s12uuZCqVCpVQxzURDAYhFApxBdBsNqFcLpMtSRIYjUaw2Wykv8Pmx2q1ciVrhiLBd1wuF4TDYahWq6RrtRr1hzCZTBCJROi9LUeXaSAQoNKogU14vV7nSkbVPohGo4AriSbV4XDsbduSbJfull9L9BW3203tEKVSCTqdDlefqN3JJ4FnFLCNydAkgU6n221ATRJ8oa9JguFw+MpO2eVyea1JArPZ/IBH+BveFTOtS6T5HCgTTCYTWst/aYvFgkdRovo0PYFZMpm84DaIeImw+7Qvy/+D8fLcJDT+bQH4AHs818VkTmYyAAAAAElFTkSuQmCC'
                                                    }
                "Policies"                      =   [PSCustomObject]@{
                                                        Name        =   "Policies"
                                                        Image       =   'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKoSURBVEhLlZUrcFNREIbznImjMo7iqKI4ZOuCIrhMkg6po444qgKKqQIHjjB5NDJVBNXKysrKyutAdpI04fs3557evJN/Zmd3z7l395x9nfh4PI6tQqPRyCUSiXPEHeie70/L5fI329wACx3U6/VMOp3+gliBZDjGd7fxePy5ZIcu+mmxWLx1+kIkHPfAeBbjNcQPkBkHwXA4fImTH04X8qPR6LzT6ew6fSH8DZrN5gEnUiiytjBBj/0zjF9XKpV7LfDdK757g/hRukOAs+Ojo6Oe0z28g1ar9RcWntjA3g3sYqI9AgcvYPmJ5qH8HJKfa6cboiEKjR9joC4Bvg/VZoktM64DcPK3iAGUgd5pPYrZHASlUqne7/dPdJp1ROheExYl20IDjxaBIRoiCXc4eGYLW4B/v8JUFFf8f2iLDnNVtClUykq4ZIxWOf0eYlV6FFvfAMM7lLFyoFyoRDvQGf+pIOaw1gHrl04UFONoGU8BWzfc5J/kMFSbhOggQlHjV5BGhirIgPF9WPitIeX4KqjBMjod/AIjQTKZ7BUKhTvbJe4uFzn2nsDfQypZwyYOdELF+teyIeeayxqMkCo/fnxsU0VTXb4CU99t4sBizMh+atoKqMJg2zkgrjaOyYFP3DKQm5wTPdY6eHh4+OPE3bCxloFbasoKfuDNOsiqQ51swEEXZqOa2+gRWgiSqxItSOa24aHmGm12RPdUIeyp9L5rgf3PrH2SHEKPDgdRQ6p6gsFgsMf7YQ0XvYGVoJoFio5mdaVeMjWW9mvtdvunS6g9QBHjMT08oXHB30DggS8QR810Hyb29chfYzCbSqV+6wBuK2BPo1q3M6BXZ3tlysE6KD8MOj2rc6+ZezI1+KawlYMQ3DTPTZUTzaYuMT8hLH4mPSIW+w9lblYfOQCQzgAAAABJRU5ErkJggg=='
                                                    }
            }
            $Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Name = $Title
            switch ($Property.Count) {
                9 {
                    $Chart.Width = 1017
                } 10 {
                    $Chart.Width = 1119
                } 11 {
                    $Chart.Width = 1243
                } 12 {
                    $Chart.Width = 1398
                } default {
                    $Chart.Width = 1175
                }
            }
            $Chart.Height = 120
            $Chart.BackColor = "White"
            if ($null -eq $Property) {
                $Property = @("Hosts", "Host Groups", "Volumes", "Volume Snapshots", "Volume Groups", "Protection Groups", "Protection Group Snapshots", "Pods")
            }
            0..($Property.Count - 1) | ForEach-Object {
                $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
                $ChartArea.Name = "ChartArea$_"
                $ChartArea.Position.Y = 0
                $ChartArea.Position.Height = 100
                if (([Math]::Floor(100 / $Property.Count) * $Property.Count) -eq 100) {
                    $ChartArea.Position.X = $_ * (100 / $Property.Count)
                    $ChartArea.Position.Width = (100 / $Property.Count)
                } elseif (([Math]::Floor(100 / $Property.Count) * $Property.Count) -eq 99) {
                    $ChartArea.Position.X = $_ * [Math]::Floor(100 / $Property.Count)
                    $ChartArea.Position.Width = [Math]::Floor(100 / $Property.Count)
                } else {
                    $ChartArea.Position.X = $_ * [Math]::Floor(100 / $Property.Count) + ((100 - ([Math]::Floor(100 / $Property.Count) * $Property.Count)) / 2)
                    $ChartArea.Position.Width = [Math]::Floor(100 / $Property.Count)
                }
                $Chart.ChartAreas.Add($ChartArea)
            
                $Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
                $Legend.Name = "ChartArea$_"
                $Legend.Docking = "Top"
                $Legend.Alignment = "Center"
                $Legend.LegendStyle = "Column"
                $Legend.IsDockedInsideChartArea = $true
                $Legend.DockedToChartArea = "ChartArea$_"
                $Chart.Legends.Add($Legend)
                $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "\n", [System.Drawing.ContentAlignment]::MiddleCenter)
                $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 4, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                $Chart.Images.Add([System.Windows.Forms.DataVisualization.Charting.NamedImage]::new($Heros[$Property[$_]].Name, $(ConvertFrom-Base64($Heros[$Property[$_]].Image))))
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Image, $Heros[$Property[$_]].Name, [System.Drawing.ContentAlignment]::MiddleCenter)
                [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                
                $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, $(if ($null -eq $Heros[$Property[$_]].Label) {"\n{0}" -f $Heros[$Property[$_]].Name.Replace(" ", "\n")} else {"\n{0}" -f $Heros[$Property[$_]].Label}), [System.Drawing.ContentAlignment]::MiddleCenter)
                $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 11, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                $LegendItem.Cells[0].ForeColor = "#888888"
                [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                
                if ($Heros[$Property[$_]].Name -eq "Hosts" -or $Heros[$Property[$_]].Name -eq "Volumes" -or $Heros[$Property[$_]].Name -eq "Pods" -or $Heros[$Property[$_]].Name -eq "Directories" -or $Heros[$Property[$_]].Name -eq "Policies") {
                    $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                    [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "\n", [System.Drawing.ContentAlignment]::MiddleCenter)
                    $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 7, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                    [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                } else {
                    $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                    [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "\n", [System.Drawing.ContentAlignment]::MiddleCenter)
                    $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 2, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                    [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                }
                
                $LegendItem = New-Object System.Windows.Forms.DataVisualization.Charting.LegendItem
                if ($null -ne $ChartData.$($Heros[$Property[$_]].Name.Replace(' ', ''))) {
                    [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "$("{0:N0}" -f $ChartData.$($Heros[$Property[$_]].Name.Replace(' ', '')))", [System.Drawing.ContentAlignment]::MiddleCenter)
                    $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                    $LegendItem.Cells[0].ForeColor = "#5ab0ee"
                    [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                } else {
                    [void]$LegendItem.Cells.Add([System.Windows.Forms.DataVisualization.Charting.LegendCellType]::Text, "*", [System.Drawing.ContentAlignment]::MiddleCenter)
                    $LegendItem.Cells[0].Font = [System.Drawing.Font]::new('Proxima Nova', 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                    $LegendItem.Cells[0].ForeColor = "#f37430"
                    [void]$Chart.Legends["ChartArea$_"].CustomItems.Add($LegendItem)
                }
            }
        } else {
            $Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Name = $Title
            $Chart.Width = $Width
            $Chart.Height = $Height
            $Chart.BackColor = "White"
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Position.X = 0
            $ChartArea.Position.Y = 0
            $ChartArea.Position.Width = 98
            $ChartArea.Position.Height = 100
            $TimeSpan = New-TimeSpan $ChartData[0].Time $ChartData[$ChartData.Count - 1].Time
            switch ($TimeSpan) {
                {$_.Days -eq 0 -or $_.Days -eq 1} {
                    switch ($TimeSpan) {
                        {$_.Hours -eq 0} {
                            $ChartArea.AxisX.IntervalType = "Minutes"
                            $ChartArea.AxisX.Interval = 5
                            break
                        }
                        {$_.Hours -eq 2 -or $_.Hours -eq 3} {
                            $ChartArea.AxisX.IntervalType = "Minutes"
                            $ChartArea.AxisX.Interval = 10
                            break
                        }
                        {$_.Hours -eq 23} {
                            $ChartArea.AxisX.IntervalType = "Hours"
                            $ChartArea.AxisX.Interval = 1
                            break
                        }
                    }
                    $ChartArea.AxisX.LabelStyle.Format = "{0:d. MMM HH:mm}"
                    break
                }
                {$_.Days -eq 6 -or $_.Days -eq 7} {
                    $ChartArea.AxisX.IntervalType = "Hours"
                    $ChartArea.AxisX.Interval = 12
                    $ChartArea.AxisX.LabelStyle.Format = "{0:d. MMM HH:mm}"
                    break
                }
                {$_.Days -eq 29 -or $_.Days -eq 30} {
                    $ChartArea.AxisX.IntervalType = "Days"
                    $ChartArea.AxisX.Interval = 2
                    $ChartArea.AxisX.LabelStyle.Format = "{0:d. MMM}"
                    break
                }
                {$_.Days -eq 89 -or $_.Days -eq 90} {
                    $ChartArea.AxisX.IntervalType = "Weeks"
                    $ChartArea.AxisX.Interval = 1
                    $ChartArea.AxisX.LabelStyle.Format = "{0:d. MMM}"
                    break
                }
                {$_.Days -eq 364 -or $_.Days -eq 365} {
                    $ChartArea.AxisX.IntervalType = "Months"
                    $ChartArea.AxisX.Interval = 1
                    $ChartArea.AxisX.LabelStyle.Format = "{0:MMM \'yy}"
                }
            }
            $ChartArea.AxisX.LineColor = "#8d8d8d"
            $ChartArea.AxisY.LineColor = "#FFFFFF"
            $ChartArea.AxisY2.LineColor = "#FFFFFF"

            $ChartArea.AxisX.IsLabelAutoFit = $false
            $ChartArea.AxisY.IsLabelAutoFit = $false
            $ChartArea.AxisY2.IsLabelAutoFit = $false

            $ChartArea.AxisX.LabelStyle.Font = "Helvetica, 8pt"
            $ChartArea.AxisY.LabelStyle.Font = "Helvetica, 8pt"
            $ChartArea.AxisY2.LabelStyle.Font = "Helvetica, 8pt"

            $ChartArea.AxisX.LabelStyle.ForeColor = "#8d8d8d"
            $ChartArea.AxisY.LabelStyle.ForeColor = "#8d8d8d"
            $ChartArea.AxisY2.LabelStyle.ForeColor = "#8d8d8d"

            $ChartArea.AxisX.MajorGrid.LineColor = "#FFFFFF"
            $ChartArea.AxisY.MajorGrid.LineColor = "#F0F0F0"
            $ChartArea.AxisY.MajorGrid.LineDashStyle = "Dash"
            $ChartArea.AxisY2.MajorGrid.LineColor = "#FFFFFF"

            $ChartArea.AxisX.MajorTickMark.LineColor = "#FFFFFF"
            $ChartArea.AxisY.MajorTickMark.LineColor = "#FFFFFF"
            $ChartArea.AxisY2.MajorTickMark.LineColor = "#FFFFFF"

            $ChartArea.AxisY.Minimum = 0
            
            $ChartArea.AxisX.IsMarginVisible = $true
            if ($ChartName -eq "Latency") {
                $ChartArea.AxisY.LabelStyle.Format = "0.## ms;'';''"
            }
            if ($ChartName -eq "IOPS") {
                $ChartArea.AxisY.LabelStyle.Format = "#, K;'';''"
            }
            $Chart.ChartAreas.Add($ChartArea)
        }
        if ($Type -eq "Performance" -and ($Group -eq "Array" -or $Group -eq "Volume")) {
            if ($ChartName -eq "Latency") {
                [void]$Chart.Series.Add("ReadLatency")
                $Chart.Series["ReadLatency"].ChartType = "Spline"
                $Chart.Series["ReadLatency"].Color = "#0D98E3"
                $Chart.Series["ReadLatency"].BorderWidth = 2
                [void]$Chart.Series.Add("WriteLatency")
                $Chart.Series["WriteLatency"].ChartType = "Spline"
                $Chart.Series["WriteLatency"].Color = "#F37430"
                $Chart.Series["WriteLatency"].BorderWidth = 2
                [void]$Chart.Series.Add("MirroredWriteLatency")
                $Chart.Series["MirroredWriteLatency"].ChartType = "Spline"
                $Chart.Series["MirroredWriteLatency"].Color = "#9F49F6"
                $Chart.Series["MirroredWriteLatency"].BorderWidth = 2
                [void]$Chart.Series.Add("QueueTime")
                $Chart.Series["QueueTime"].ChartType = "Spline"
                $Chart.Series["QueueTime"].Color = "#50AE54"
                $Chart.Series["QueueTime"].BorderWidth = 2
                if ($Group -eq "Array" -or $Group -eq "Volume") {
                    $ChartData | ForEach-Object {
                        $Chart.Series["ReadLatency"].Points.AddXY($_.Time, $_.Usec_Per_Read_Op / 1000) | Out-Null
                        $Chart.Series["WriteLatency"].Points.AddXY($_.Time, $_.Usec_Per_Write_Op / 1000) | Out-Null
                        $Chart.Series["MirroredWriteLatency"].Points.AddXY($_.Time, $_.Usec_Per_Mirrored_Write_Op / 1000) | Out-Null
                        $Chart.Series["QueueTime"].Points.AddXY($_.Time, $_.Local_Queue_Usec_Per_Op / 1000) | Out-Null
                    }
                }
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X'
                })
            }
            if ($ChartName -eq "IOPS") {
                [void]$Chart.Series.Add("ReadIOPS")
                $Chart.Series["ReadIOPS"].ChartType = "Spline"
                $Chart.Series["ReadIOPS"].Color = "#0D98E3"
                $Chart.Series["ReadIOPS"].BorderWidth = 2
                [void]$Chart.Series.Add("WriteIOPS")
                $Chart.Series["WriteIOPS"].ChartType = "Spline"
                $Chart.Series["WriteIOPS"].Color = "#F37430"
                $Chart.Series["WriteIOPS"].BorderWidth = 2
                [void]$Chart.Series.Add("MirroredWriteIOPS")
                $Chart.Series["MirroredWriteIOPS"].ChartType = "Spline"
                $Chart.Series["MirroredWriteIOPS"].Color = "#9F49F6"
                $Chart.Series["MirroredWriteIOPS"].BorderWidth = 2
                if ($Group -eq "Array" -or $Group -eq "Volume") {
                    $ChartData | ForEach-Object {
                        $Chart.Series["ReadIOPS"].Points.AddXY($_.Time, $_.Reads_Per_Sec) | Out-Null
                        $Chart.Series["WriteIOPS"].Points.AddXY($_.Time, $_.Writes_Per_Sec) | Out-Null
                        $Chart.Series["MirroredWriteIOPS"].Points.AddXY($_.Time, $_.Mirrored_Writes_Per_Sec) | Out-Null
                    }
                } else {
                }
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X'
                })
            }
            if ($ChartName -eq "Bandwidth") {
                [void]$Chart.Series.Add("ReadBandwidth")
                $Chart.Series["ReadBandwidth"].ChartType = "Spline"
                $Chart.Series["ReadBandwidth"].Color = "#0D98E3"
                $Chart.Series["ReadBandwidth"].BorderWidth = 2
                [void]$Chart.Series.Add("WriteBandwidth")
                $Chart.Series["WriteBandwidth"].ChartType = "Spline"
                $Chart.Series["WriteBandwidth"].Color = "#F37430"
                $Chart.Series["WriteBandwidth"].BorderWidth = 2
                [void]$Chart.Series.Add("MirroredWriteBandwidth")
                $Chart.Series["MirroredWriteBandwidth"].ChartType = "Spline"
                $Chart.Series["MirroredWriteBandwidth"].Color = "#9F49F6"
                $Chart.Series["MirroredWriteBandwidth"].BorderWidth = 2
                if ($Group -eq "Array" -or $Group -eq "Volume") {
                    $ChartData | ForEach-Object {
                        $Chart.Series["ReadBandwidth"].Points.AddXY($_.Time, $_.Read_Bytes_Per_Sec) | Out-Null
                        $Chart.Series["WriteBandwidth"].Points.AddXY($_.Time, $_.Write_Bytes_Per_Sec) | Out-Null
                        $Chart.Series["MirroredWriteBandwidth"].Points.AddXY($_.Time, $_.Mirrored_Write_Bytes_Per_Sec) | Out-Null
                    }
                } else {
                    $ChartData | Group-Object Time | ForEach-Object {
                        if ($Chart.Series.Name -notcontains $_.Name) {
                            [void]$Chart.Series.Add($_.Name)
                        }
                        $Chart.Series["ReadBandwidth"].Points.AddXY($_.Time, ($_.Group.Output_Per_Sec | Measure-Object -Sum).Sum) | Out-Null
                        $Chart.Series["WriteBandwidth"].Points.AddXY($_.Time, ($_.Group.Input_Per_Sec | Measure-Object -Sum).Sum) | Out-Null
                    }
                }
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Suffix "/s"  -Axis 'X', 'Y'
                })
            }
        }
        if ($Type -eq "Performance" -and ($Group -eq "Volumes" -or $Group -eq "Volume Groups")) {
            $Colors = @{
                0   =   @{Read = "#1F5E23";Write = "#50AE54"}
                1   =   @{Read = "#005A99";Write = "#1D8CE3"}
                2   =   @{Read = "#E44F12";Write = "#FA8A1C"}
                3   =   @{Read = "#87124F";Write = "#D61D60"}
                4   =   @{Read = "#5C3F37";Write = "#8D6E64"}
            }
            if ($ChartName -eq "Latency") {
                $ColorIndex = 0
                $ChartData | Group-Object Name | ForEach-Object {
                    $_.Group | ForEach-Object {
                        if ($Chart.Series.Name -notcontains "$($_.Name)Read" -and $Chart.Series.Name -notcontains "$($_.Name)Write") {
                            if ($Property -contains "Read") {
                                [void]$Chart.Series.Add("$($_.Name)Read")
                                $Chart.Series["$($_.Name)Read"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Read"].Color = $Colors[$ColorIndex].Read
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Read"].BorderWidth = 2
                            }
                            if ($Property -contains "Write") {
                                [void]$Chart.Series.Add("$($_.Name)Write")
                                $Chart.Series["$($_.Name)Write"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Write"].Color = $Colors[$ColorIndex].Write
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Write"].BorderWidth = 2
                            }
                        }
                        if ($Property -contains "Read") {
                            $Chart.Series["$($_.Name)Read"].Points.AddXY($_.Time, $_.Usec_Per_Read_Op  / 1000) | Out-Null
                        }
                        if ($Property -contains "Write") {
                            $Chart.Series["$($_.Name)Write"].Points.AddXY($_.Time, $_.Usec_Per_Write_Op / 1000) | Out-Null
                        }
                        if ($ColorIndex -eq 4) {
                            $ColorIndex = 0
                        } else {
                            $ColorIndex++
                        }
                    }
                }
            }
            if ($ChartName -eq "IOPS") {
                $ColorIndex = 0
                $ChartData | Group-Object Name | ForEach-Object {
                    $_.Group | ForEach-Object {
                        if ($Chart.Series.Name -notcontains "$($_.Name)Read" -and $Chart.Series.Name -notcontains "$($_.Name)Write") {
                            if ($Property -contains "Read") {
                                [void]$Chart.Series.Add("$($_.Name)Read")
                                $Chart.Series["$($_.Name)Read"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Read"].Color = $Colors[$ColorIndex].Read
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Read"].BorderWidth = 2
                            }
                            if ($Property -contains "Write") {
                                [void]$Chart.Series.Add("$($_.Name)Write")
                                $Chart.Series["$($_.Name)Write"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Write"].Color = $Colors[$ColorIndex].Write
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Write"].BorderWidth = 1
                            }
                        }
                        if ($Property -contains "Read") {
                            $Chart.Series["$($_.Name)Read"].Points.AddXY($_.Time, $_.Reads_Per_Sec) | Out-Null
                        }
                        if ($Property -contains "Write") {
                            $Chart.Series["$($_.Name)Write"].Points.AddXY($_.Time, $_.Writes_Per_Sec) | Out-Null
                        }
                        if ($ColorIndex -eq 4) {
                            $ColorIndex = 0
                        } else {
                            $ColorIndex++
                        }
                    }
                }
            }
            if ($ChartName -eq "Bandwidth") {
                $ColorIndex = 0
                $ChartData | Group-Object Name | ForEach-Object {
                    $_.Group | ForEach-Object {
                        if ($Chart.Series.Name -notcontains "$($_.Name)Read" -and $Chart.Series.Name -notcontains "$($_.Name)Write") {
                            if ($Property -contains "Read") {
                                [void]$Chart.Series.Add("$($_.Name)Read")
                                $Chart.Series["$($_.Name)Read"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Read"].Color = $Colors[$ColorIndex].Read
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Read"].BorderWidth = 2
                            }
                            if ($Property -contains "Write") {
                                [void]$Chart.Series.Add("$($_.Name)Write")
                                $Chart.Series["$($_.Name)Write"].ChartType = "Spline"
                                try {
                                    $Chart.Series["$($_.Name)Write"].Color = $Colors[$ColorIndex].Write
                                } finally {
                                }
                                $Chart.Series["$($_.Name)Write"].BorderWidth = 1
                            }
                        }
                        if ($Property -contains "Read") {
                            $Chart.Series["$($_.Name)Read"].Points.AddXY($_.Time, $_.Read_Bytes_Per_Sec) | Out-Null
                        }
                        if ($Property -contains "Write") {
                            $Chart.Series["$($_.Name)Write"].Points.AddXY($_.Time, $_.Write_Bytes_Per_Sec) | Out-Null
                        }
                        if ($ColorIndex -eq 4) {
                            $ColorIndex = 0
                        } else {
                            $ColorIndex++
                        }
                    }
                }
            }
            if ($ChartName -eq "IOPS" -or $ChartName -eq "Latency") {
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X'
                })
            } else {
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X', 'Y'
                })
            }
        }
        if ($Type -eq "Capacity") {
            if ($Group -eq "Array") {
                if ($Chartname -eq "Array Capacity") {
                    [void]$Chart.Series.Add("Unique")
                    $Chart.Series["Unique"].ChartType = "StackedArea"
                    $Chart.Series["Unique"].Color = "#62D4D6"
                    $Chart.Series["Unique"].BorderColor = "#2EC6C8"
                    $Chart.Series["Unique"].BorderWidth = 2
                    $Chart.Series["Unique"].YAxisType = "Primary"
                    [void]$Chart.Series.Add("Snapshots")
                    $Chart.Series["Snapshots"].ChartType = "StackedArea"
                    $Chart.Series["Snapshots"].Color = "#C8B9E6"
                    $Chart.Series["Snapshots"].BorderColor = "#B5A1DD"
                    $Chart.Series["Snapshots"].BorderWidth = 2
                    $Chart.Series["Snapshots"].YAxisType = "Primary"
                    [void]$Chart.Series.Add("Shared")
                    $Chart.Series["Shared"].ChartType = "StackedArea"
                    $Chart.Series["Shared"].Color = "#80D545"
                    $Chart.Series["Shared"].BorderColor = "#55C707"
                    $Chart.Series["Shared"].BorderWidth = 2
                    $Chart.Series["Shared"].YAxisType = "Primary"
                    if ($null -ne $ChartData.Space.Replication) {
                        [void]$Chart.Series.Add("Replication")
                        $Chart.Series["Replication"].ChartType = "StackedArea"
                        $Chart.Series["Replication"].Color = "#DDD000"
                        $Chart.Series["Replication"].BorderColor = "#DDD000"
                        $Chart.Series["Replication"].BorderWidth = 2
                        $Chart.Series["Replication"].YAxisType = "Primary"
                    }
                    [void]$Chart.Series.Add("System")
                    $Chart.Series["System"].ChartType = "StackedArea"
                    $Chart.Series["System"].Color = "#CACECE"
                    $Chart.Series["System"].BorderColor = "#B8BEBE"
                    $Chart.Series["System"].BorderWidth = 2
                    $Chart.Series["System"].YAxisType = "Primary"
                    [void]$Chart.Series.Add("Empty")
                    $Chart.Series["Empty"].ChartType = "StackedArea"
                    $Chart.Series["Empty"].Color = "#F7F5F6"
                    $Chart.Series["Empty"].YAxisType = "Primary"
                    [void]$Chart.Series.Add("Usable")
                    $Chart.Series["Usable"].ChartType = "Line"
                    $Chart.Series["Usable"].Color = "#DB843D"
                    $Chart.Series["Usable"].BorderWidth = 1
                    $Chart.Series["Usable"].YAxisType = "Primary"
                    [void]$Chart.Series.Add("DataReduction")
                    $Chart.Series["DataReduction"].ChartType = "Line"
                    $Chart.Series["DataReduction"].Color = "#ACACAC"
                    $Chart.Series["DataReduction"].BorderWidth = 1
                    $Chart.Series["DataReduction"].BorderDashStyle = "Dash"
                    $Chart.Series["DataReduction"].YAxisType = "Secondary"
                    $Chart.ChartAreas[0].AxisY2.IsStartedFromZero = $true
                    $Chart.ChartAreas[0].AxisY2.Interval = "{0:N1}" -f (([Math]::Floor(($ChartData.Space | Measure-Object -Average -Property Data_Reduction).Average * 10) / 10) / 2)
                    $Chart.ChartAreas[0].AxisY2.Maximum = "{0:N1}" -f (([Math]::Floor(($ChartData.Space | Measure-Object -Average -Property Data_Reduction).Average * 10) / 10) * 2)
                    $Chart.ChartAreas[0].AxisY2.LabelStyle.Format = "0.0"
        
                    $ChartData | Group-Object Name -PipelineVariable CurrentItem | Select-Object -First 1 | ForEach-Object {
                        $_.Group | ForEach-Object {
                            $Chart.Series["Empty"].Points.AddXY($_.Time, ($_.Capacity - $_.Space.Unique - $_.Space.Snapshots - $_.Space.Shared - $_.Space.Replication - $_.Space.System)) | Out-Null
                            $Chart.Series["System"].Points.AddXY($_.Time, $_.Space.System) | Out-Null
                            if ($null -ne $_.Space.Replication) {
                                $Chart.Series["Replication"].Points.AddXY($_.Time, $_.Space.Replication) | Out-Null
                            }
                            $Chart.Series["Shared"].Points.AddXY($_.Time, $_.Space.Shared) | Out-Null
                            $Chart.Series["Snapshots"].Points.AddXY($_.Time, $_.Space.Snapshots) | Out-Null
                            $Chart.Series["Unique"].Points.AddXY($_.Time, $_.Space.Unique) | Out-Null
                            $Chart.Series["Usable"].Points.AddXY($_.Time, $_.Capacity) | Out-Null
                            if (($CurrentItem.Group.IndexOf($_) % 2) -eq 0) {
                                $Chart.Series["DataReduction"].Points.AddXY($_.Time, $_.Space.Data_Reduction) | Out-Null
                            }
                        }
                    }
                } elseif ($ChartName -eq "Host Capacity") {
                    [void]$Chart.Series.Add("Provisioned")
                    $Chart.Series["Provisioned"].ChartType = "Line"
                    $Chart.Series["Provisioned"].Color = "#52C8FD"
                    $Chart.Series["Provisioned"].BorderWidth = 1
                    $Chart.Series["Provisioned"].YAxisType = "Primary"
                    $ChartData | Group-Object Name | Select-Object -First 1 | ForEach-Object {
                        $_.Group | ForEach-Object {
                            $Chart.Series["Provisioned"].Points.AddXY($_.Time, $_.Space.Total_Provisioned) | Out-Null
                        }
                    }
                }
        
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_  -Axis 'X', 'Y', 'Y2'
                })
            } elseif ($Group -eq "Volume" -or $Group -eq "Volumes") {
                if ($ChartName -eq 'Array Capacity') {
                    $ChartData | Group-Object Time | Sort-Object {$_.Name -as [DateTime]} -Descending | ForEach-Object -Begin {
                    } -Process {
                        $CurrentTime = $_.Group[0].Time
                        $CurrentItem = $_
                        Compare-Object ($ChartData.Name | Sort-Object -Unique) $_.Group.Name -IncludeEqual | ForEach-Object {
                            if ($Chart.Series.Name -notcontains "$($_.InputObject)Snapshots") {
                                [void]$Chart.Series.Add("$($_.InputObject)Snapshots")
                                $Chart.Series["$($_.InputObject)Snapshots"].ChartType = "StackedArea"
                                $Chart.Series["$($_.InputObject)Snapshots"].Color = "#AB90C5"
                                $Chart.Series["$($_.InputObject)Snapshots"].BorderWidth = 1
                                $Chart.Series["$($_.InputObject)Snapshots"].BorderColor = "#52C8FD"
                            }
                            if ($Chart.Series.Name -notcontains "$($_.InputObject)Unique") {
                                [void]$Chart.Series.Add("$($_.InputObject)Unique")
                                $Chart.Series["$($_.InputObject)Unique"].ChartType = "StackedArea"
                                $Chart.Series["$($_.InputObject)Unique"].Color = "#7DD6FE"
                                $Chart.Series["$($_.InputObject)Unique"].BorderWidth = 1
                                $Chart.Series["$($_.InputObject)Unique"].BorderColor = "#8F6BB2"
                            }
                            if ($_.SideIndicator -eq "<=") {
                                $Chart.Series["$($_.InputObject)Unique"].Points.AddXY($CurrentTime, [double]::NaN) | Out-Null
                                $Chart.Series["$($_.InputObject)Snapshots"].Points.AddXY($CurrentTime, [double]::NaN) | Out-Null
                            } elseif ($_.SideIndicator -eq "==") {
                                $IO = $_.InputObject
                                $DataLookup = $CurrentItem.Group | Where-Object {$_.Name -eq $IO} | Select-Object -ExpandProperty Space
                                $Chart.Series["$($_.InputObject)Unique"].Points.AddXY($CurrentTime, $DataLookup.Unique) | Out-Null
                                $Chart.Series["$($_.InputObject)Snapshots"].Points.AddXY($CurrentTime, $DataLookup.Snapshots) | Out-Null
                            }
                        }
                    } -End {
                    }
                    $Chart.Add_Customize({
                        Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X', 'Y'
                    })
                } elseif ($Chartname -eq 'Host Capacity') {
                    $ChartData | Group-Object Time | Sort-Object {$_.Name -as [DateTime]} -Descending | ForEach-Object -Begin {
                    } -Process {
                        $CurrentTime = $_.Group[0].Time
                        $CurrentItem = $_
                        Compare-Object ($ChartData.Name | Sort-Object -Unique) $_.Group.Name -IncludeEqual | ForEach-Object {
                            if ($Chart.Series.Name -notcontains "$($_.InputObject)Provisioned") {
                                [void]$Chart.Series.Add("$($_.InputObject)Provisioned")
                                $Chart.Series["$($_.InputObject)Provisioned"].ChartType = "Line"
                                $Chart.Series["$($_.InputObject)Provisioned"].Color = "#52C8FD"
                                $Chart.Series["$($_.InputObject)Provisioned"].BorderWidth = 1
                                $Chart.Series["$($_.InputObject)Provisioned"].YAxisType = "Primary"
                            }
                            if ($_.SideIndicator -eq "<=") {
                                $Chart.Series["$($_.InputObject)Provisioned"].Points.AddXY($CurrentTime, [double]::NaN) | Out-Null
                            } elseif ($_.SideIndicator -eq "==") {
                                $IO = $_.InputObject
                                $DataLookup = $CurrentItem.Group | Where-Object {$_.Name -eq $IO} | Select-Object -ExpandProperty Space
                                $Chart.Series["$($_.InputObject)Provisioned"].Points.AddXY($CurrentTime, $DataLookup.Total_Provisioned) | Out-Null
                            }
                        }
                    } -End {
                    }
                    $Chart.Add_Customize({
                        Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Axis 'X', 'Y'
                    })
                }
            }
        }
        if ($Type -eq "Replication" -and $Group -eq "Array") {
            if ($Group -eq "Array") {
                $ChartData | Group-Object Time | ForEach-Object {
                    $_.Group | ForEach-Object {
                        if ($Chart.Series.Name -notcontains $_.Name) {
                            [void]$Chart.Series.Add($_.Name)
                        }
                        $Chart.Series[$_.Name].Points.AddXY($_.Time, $_.Bytes_Per_Sec) | Out-Null
                        $Chart.Series[$_.Name].ChartType = "Spline"
                        $Chart.Series[$_.Name].BorderWidth = 1
                        $Chart.Series[$_.Name].IsVisibleInLegend = $true
                    }
                    if ($Chart.Series.Name -notcontains "Total") {
                        [void]$Chart.Series.Add("Total")
                    }
                    $Chart.Series["Total"].Points.AddXY($_.Group[0].Time, ($_.Group.Bytes_Per_Sec | Measure-Object -Sum).Sum) | Out-Null
                    $Chart.Series["Total"].ChartType = "Spline"
                    $Chart.Series["Total"].Color = "#0D98E3"
                    $Chart.Series["Total"].BorderWidth = 1
                    $Chart.Series["Total"].IsVisibleInLegend = $true
                }
                $Chart.Add_Customize({
                    Invoke-ChartCustomize -Sender $Chart -EventArgs $_ -Suffix "/s"  -Axis 'X', 'Y'
                })
            }
        }
   }

    end {
        if ($PSCmdlet.ParameterSetName -eq "AsChart") {
            $Chart
        } else {
            $MemoryStream = New-Object System.IO.MemoryStream
            $Chart.SaveImage($MemoryStream, "png")
            if ($PSCmdlet.ParameterSetName -eq "AsImage") {
                Write-Output ($MemoryStream.GetBuffer()) -NoEnumerate
            } else {
                [Convert]::ToBase64String($MemoryStream.GetBuffer())
            }
        }
    }
}