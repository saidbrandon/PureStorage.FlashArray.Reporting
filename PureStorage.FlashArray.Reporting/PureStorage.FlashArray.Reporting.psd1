#
# Module manifest for module 'PureStorage.FlashArray.Reporting'
#
# Generated by: brandon said
#
# Generated on: 6/23/2021
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PureStorage.FlashArray.Reporting.psm1'

# Version number of this module.
ModuleVersion = '1.0.4'

# Supported PSEditions
CompatiblePSEditions = 'Desktop'

# ID used to uniquely identify this module
GUID = '7fc9cd3b-4601-49f1-9102-a521493c9c13'

# Author of this module
Author = 'brandon said'

# Company or vendor of this module
# CompanyName = 'None'

# Copyright statement for this module
Copyright = '(c) brandon said. All rights reserved.'

# Description of the functionality provided by this module
Description = @'
Reporting Module for the Pure Storage REST API using MS Charts

* Easily create charts that can be saved, emailed, or displayed on-screen
* Works on both Windows PowerShell (5.1) and PowerShell Core (6+) (Windows Only)
* Create reports that contain multiple charts
* Query the Pure Storage REST API directly, no additional modules required
* Example scripts to help get you started

Requires Purity OS 5.3.0 or newer to create charts. Querying the REST API directly has no requirements.
'@

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @('Microsoft.PowerShell.Commands.Utility', 'System.Windows.Forms.DataVisualization', 'System.Xml.Linq')

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @('Classes\PureStorageRestApi.ps1')

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Connect-PfaApi'
    'Disconnect-PfaApi'
    'Format-Byte'
    'Format-PfaSecond'
    'Format-PfaSecondsFromMidnight'
    'Get-PfaChartData'
    'Invoke-PfaApiRequest'
    'New-PfaChart'
    'Show-PfaChart'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @(
    'PureStorage.FlashArray.Reporting.psd1'
    'PureStorage.FlashArray.Reporting.psm1'
    'Classes\PureStorageRestApi.ps1'
    'Public\Connect-PfaApi.ps1'
    'Public\Disconnect-PfaApi.ps1'
    'Public\Format-Byte.ps1'
    'Public\Format-PfaSecond.ps1'
    'Public\Format-PfaSecondsFromMidnight.ps1'
    'Public\Get-PfaChartData.ps1'
    'Public\Invoke-PfaApiRequest.ps1'
    'Public\Get-PfaChartData.ps1'
    'Public\New-PfaChart.ps1'
    'Public\Show-PfaChart.ps1'
    'Private\ConvertFrom-Base64.ps1'
    'Private\Invoke-ChartCustomize.ps1'
    'Private\New-DynamicParameter.ps1'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{
    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('PureStorage', 'FlashArray', 'FlashBlade', 'HTML', 'Status', 'Report', 'MSChart', 'Chart', 'Charts', 'RESTAPI')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/saidbrandon/PureStorage.FlashArray.Reporting/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/saidbrandon/PureStorage.FlashArray.Reporting'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''
}