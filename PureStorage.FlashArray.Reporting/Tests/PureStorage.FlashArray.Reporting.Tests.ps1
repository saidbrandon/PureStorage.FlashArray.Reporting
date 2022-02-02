#region Discovery
$ModuleName = 'PureStorage.FlashArray.Reporting'
#endregion Discovery

BeforeAll {
    $ModuleName = 'PureStorage.FlashArray.Reporting'
    $ModuleRoot = Split-Path $PSScriptRoot
    Write-Verbose $ModuleName
    Import-Module -Name "$ModuleRoot" -Force
}

Describe "$ModuleName Module Tests"  {
    Context 'Module Setup' {
        It "contains psm1" {
            "$ModuleRoot\$ModuleName.psm1" | Should -Exist
        }

        It "contains psd1" {
            "$ModuleRoot\$ModuleName.psd1" | Should -Exist
            "$ModuleRoot\$ModuleName.psd1" | Should -FileContentMatch "$ModuleName.psm1"
        }
    
        It "has Public functions" {
            "$ModuleRoot\Public\*.ps1" | Should -Exist
        }

        It "psm1 is valid PowerShell code" {
            $File = Get-Content -Path "$ModuleRoot\$ModuleName.psm1" -ErrorAction Stop
            $Errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($File, [ref]$Errors)
            $Errors.Count | Should -Be 0
        }
  }
}
Describe "$ModuleName Sanity Tests - Help Content" -Tags 'Module' {
    #region Discovery
    # The module will need to be imported during Discovery since we're using it to generate test cases / Context blocks
    Import-Module -Name "$(Split-Path $PSScriptRoot)" -Force
    $ShouldProcessParameters = 'WhatIf', 'Confirm'
    # Generate command list for generating Context / TestCases
    $Module = Get-Module $ModuleName
    $CommandList = @(
        $Module.ExportedFunctions.Keys
        $Module.ExportedCmdlets.Keys
    )
    #endregion Discovery

    $CommandList
    foreach ($Command in $CommandList) {
        Context "$Command - Help Content" {
            #region Discovery
            $Help = @{ Help = Get-Help -Name $Command -Full | Select-Object -Property * }
            $Parameters = Get-Help -Name $Command -Parameter * -ErrorAction Ignore |
                Where-Object { $_.Name -and $_.Name -notin $ShouldProcessParameters } |
                ForEach-Object {
                    @{
                        Name        = $_.name
                        Description = $_.Description.Text
                    }
                }
            $Ast = @{
                # Ast will be $null if the command is a compiled cmdlet
                Ast        = (Get-Content -Path "function:/$Command" -ErrorAction Ignore).Ast
                Parameters = $Parameters
            }
            $Examples = $Help.Help.Examples.Example | ForEach-Object { @{ Example = $_ } }
            #endregion Discovery

            It "has help content for $Command" -TestCases $Help {
                $Help | Should -Not -BeNullOrEmpty
            }

            It "contains a synopsis for $Command" -TestCases $Help {
                $Help.Synopsis | Should -Not -BeNullOrEmpty
            }

            It "contains a description for $Command" -TestCases $Help {
                $Help.Description | Should -Not -BeNullOrEmpty
            }

            It "lists the function author in the Notes section for $Command" -TestCases $Help {
                $Notes = $Help.AlertSet.Alert.Text -split '\n'
                $Notes[0].Trim() | Should -BeLike "Author: *"
            }

            # This will be skipped for compiled commands ($Ast.Ast will be $null)
            It "has a help entry for all parameters of $Command" -TestCases $Ast -Skip:(-not ($Parameters -and $Ast.Ast)) {
                @($Parameters).Count | Should -Be $Ast.Body.ParamBlock.Parameters.Count -Because 'the number of parameters in the help should match the number in the function script'
            }

            It "has a description for $Command parameter -<Name>" -TestCases $Parameters -Skip:(-not $Parameters) {
                $Description | Should -Not -BeNullOrEmpty -Because "parameter $Name should have a description"
            }

            It "has at least one usage example for $Command" -TestCases $Help {
                $Help.Examples.Example.Code.Count | Should -BeGreaterOrEqual 1
            }

            It "lists a description for $Command example: <Title>" -TestCases $Examples {
                $Example.Remarks | Should -Not -BeNullOrEmpty -Because "example $($Example.Title) should have a description!"
            }
        }
    }
}