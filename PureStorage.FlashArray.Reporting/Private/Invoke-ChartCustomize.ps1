function Invoke-ChartCustomize {
    [CmdletBinding()] 
    param ( 
        [Parameter(Mandatory = $true)] 
        [Object]$Sender, 
        [Parameter(Mandatory = $true)] 
        [Object]$EventArgs,
        [String]$Suffix,
        [ValidateSet('X', 'Y', 'Y2')]
        [String[]]$Axis
    )
    $Chart = $Sender -as [System.Windows.Forms.DataVisualization.Charting.Chart]
    if ($null -ne $Chart) {
        if ($Axis -contains 'X') {
            $Chart.ChartAreas[0].AxisX.CustomLabels | ForEach-Object {
                if ($null -ne $_.Text) {
                    [DateTime]$Date = [DateTime]::MinValue
                    if ([DateTime]::TryParseExact($_.Text, "d. MMM HH:mm", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$Date)) {
                        if ($Date.Hour -eq 0 -and $Date.Minute -eq 0) {
                            $_.Text = $Date.ToString("d. MMM")
                        } else {
                            $_.Text = $Date.ToString("HH:mm")
                        }
                    } elseif ([DateTime]::TryParseExact($_.Text, "M/d/yyyy", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$Date)) {
                        $_.Text = $Date.ToString("MMM \'yy")
                    }
                }
            }
        }
        if ($Axis -contains 'Y') {
            $Chart.ChartAreas[0].AxisY.CustomLabels | ForEach-Object {
                $Label = $_
                if ($null -ne $_.Text) {
                    switch ([long]$Label.Text) {
                        {$_ -ge 1000000000000000} {
                            $Label.Text = "{0:#.##} PB$Suffix" -f [math]::Round($_ / 1000000000000000, 2)
                            break
                        }
                        {$_ -ge 1000000000000} {
                            $Label.Text = "{0:#.##} TB$Suffix" -f [math]::Round($_ / 1000000000000, 2)
                            break
                        }
                        {$_ -ge 1000000000} {
                            $Label.Text = "{0:#.##} GB$Suffix" -f [math]::Round($_ / 1000000000, 2)
                            break
                        }
                        {$_ -ge 1000000} {
                            $Label.Text = "{0:#.##} MB$Suffix" -f [math]::Round($_ / 1000000, 2)
                            break
                        }
                        {$_ -ge 1000} {
                            $Label.Text = "{0:#.##} KB$Suffix" -f [math]::Round($_ / 1000, 2)
                            break
                        }
                        {$_ -eq 0} {
                            $Label.Text = ''
                            break
                        } default {
                            $Label.Text = "{0:#.##} B$Suffix" -f $_
                            break
                        }
                    }
                }
            }
        }
        if ($Axis -contains 'Y2') {
            $Chart.ChartAreas[0].AxisY2.CustomLabels | ForEach-Object {
                $Label = $_
                if ($null -ne $_.Text -and $_.Text -eq "-0.0") {
                    $Label.Text = ""
                }
            }
        }
    }
}
function Invoke-ChartCustomizeLegend {
    [CmdletBinding()] 
    param ( 
    [Parameter(Mandatory = $true)] 
    [Object]$Sender, 
    [Parameter(Mandatory = $true)] 
    [Object]$EventArgs
    )
    $Chart = $Sender -as [System.Windows.Forms.DataVisualization.Charting.Chart]
    if ($null -ne $Chart) {
        $LegendItems = $EventArgs.LegendItems -as [System.Windows.Forms.DataVisualization.Charting.LegendItemsCollection]
        $LegendItems | ForEach-Object {
            $_.Cells[0].SeriesSymbolSize = [System.Drawing.Size]::New($_.MarkerSize * 12, $_.MarkerSize * 12)
        }
    }
}
function Invoke-ChartPostPaint {
    [CmdletBinding()] 
    param ( 
    [Parameter(Mandatory = $true)] 
    [Object]$Sender, 
    [Parameter(Mandatory = $true)] 
    [Object]$EventArgs
    )
    $Chart = $Sender -as [System.Windows.Forms.DataVisualization.Charting.Chart]
    if ($null -ne $Chart) {
        $EventArgs.ChartGraphics.Graphics.DrawLine([System.Drawing.Pen]::New([System.Drawing.ColorTranslator]::FromHtml("#E8E8E8")), 510,10,510,110)
        $EventArgs.ChartGraphics.Graphics.DrawLine([System.Drawing.Pen]::New([System.Drawing.ColorTranslator]::FromHtml("#E8E8E8")), 803,10,803,110)
    }
}