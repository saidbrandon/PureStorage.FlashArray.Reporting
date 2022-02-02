# Get public and private function definition files.
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Classes = @(Get-ChildItem -Path $PSScriptRoot\Classes\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($File in @($Private + $Public + $Classes)) {
	try {
		. $File.FullName
	} catch {
		Write-Error -Message "Failed to import function $($File.FullName): $_"
	}
}

Export-ModuleMember -Function ($Public | Select-Object -ExpandProperty BaseName)