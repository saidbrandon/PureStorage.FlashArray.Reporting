function Show-PfaChart {
    <#
    .SYNOPSIS
    Displays a Pure Storage FlashArray chart on screen.
    
    .DESCRIPTION
    Displays a Pure Storage FlashArray Chart on screen.
    
    .PARAMETER Chart
    The Chart to display.

    .PARAMETER Title
    Optionally specify the title if Chart is an image or base64 encoded string or to overwrite the default.

    .EXAMPLE
    Sample scripts can be found in the "Examples" folder off of the module's root path.

    .NOTES
	Author: brandon said
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        $Chart,
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Title
    )
    process {
        $Form = New-Object Windows.Forms.Form
        $Form.Text = $Chart.Name
        if ($Chart -is [System.Windows.Forms.DataVisualization.Charting.Chart]) {
            $Form.Width = $Chart.Width
            $Form.Height = $Chart.Height + 40
            $Form.Controls.Add($Chart)
            $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
        } elseif ($Chart -is [byte[]] -or $Chart -is [string]) {        
            $Form.Text = $Title
            if ($Chart -is [byte[]]) {
                    $MemoryStream = New-Object IO.MemoryStream($Chart, 0, $Chart.Length)
                    $MemoryStream.Write($Chart, 0, $Chart.Length);
                    $Image = [System.Drawing.Image]::FromStream($MemoryStream, $true)
            } elseif ($Chart -is [string]) {
                $Bytes = [Convert]::FromBase64String($Chart)
                $MemoryStream = New-Object IO.MemoryStream($Bytes, 0, $Bytes.Length)
                $MemoryStream.Write($Bytes, 0, $Bytes.Length);
                $Image = [System.Drawing.Image]::FromStream($MemoryStream, $true)
            }
            $PictureBox = New-Object Windows.Forms.PictureBox
            $PictureBox.Width = $Image.Size.Width;
            $PictureBox.Height = $Image.Size.Height; 
            $PictureBox.Location = New-Object System.Drawing.Size(0,0) 
            $PictureBox.Image = $Image;

            $Form.Width = $Image.Size.Width
            $Form.Height = $Image.Size.Height + 50
            $Form.Controls.Add($PictureBox)
        } else {
            $Chart.GetType()
        }
        $Form.MinimizeBox = $False
        $Form.MaximizeBox = $False
        $Form.WindowState = "Normal"
        $Form.StartPosition = "CenterScreen"
        $Form.FormBorderStyle = "FixedDialog"
        $Form.Add_Shown({
            $Form.Activate()
        })
        $Form.ShowDialog() | Out-Null
    }
}