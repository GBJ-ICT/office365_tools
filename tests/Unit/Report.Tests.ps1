<#
    Export-SpoReport writes real files, so these tests use a temporary
    directory and assert on the contents.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    # Builds a finding without needing a tenant. Named with the New- verb for
    # readability; it only constructs an object, so ShouldProcess is moot.
    function New-TestFinding {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'Test helper that builds an in-memory object.')]
        [CmdletBinding()]
        param(
            [string]$RuleId = 'Test.Rule',
            [string]$Severity = 'Warning',
            [string]$Target = '/sites/team/Documents/x.docx'
        )
        [pscustomobject]@{
            PSTypeName = 'Office365Tools.Finding'
            RuleId     = $RuleId
            Severity   = $Severity
            Scope      = 'Item'
            List       = 'Documents'
            Target     = $Target
            Message    = 'Something needs attention.'
            Detail     = [pscustomobject]@{ Count = 1 }
            SiteUrl    = 'https://contoso.sharepoint.com/sites/team'
            DetectedAt = Get-Date
        }
    }
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Export-SpoReport' {

    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-report-$([guid]::NewGuid())"
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force
        }
    }

    It 'infers HTML from the extension' {
        $path = Join-Path $script:TempDir 'report.html'
        New-TestFinding | Export-SpoReport -Path $path

        Test-Path -LiteralPath $path | Should -BeTrue
        Get-Content -LiteralPath $path -Raw | Should -Match '<!DOCTYPE html>'
    }

    It 'infers CSV from the extension' {
        $path = Join-Path $script:TempDir 'report.csv'
        New-TestFinding | Export-SpoReport -Path $path

        $rows = Import-Csv -LiteralPath $path
        @($rows).Count   | Should -Be 1
        $rows[0].RuleId  | Should -Be 'Test.Rule'
    }

    It 'infers JSON from the extension' {
        $path = Join-Path $script:TempDir 'report.json'
        New-TestFinding | Export-SpoReport -Path $path

        $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $data.RuleId | Should -Be 'Test.Rule'
    }

    It 'honours an explicit -As over the extension' {
        $path = Join-Path $script:TempDir 'report.txt'
        New-TestFinding | Export-SpoReport -Path $path -As Csv

        Get-Content -LiteralPath $path -Raw | Should -Match 'RuleId'
    }

    It 'flattens the nested Detail column for CSV' {
        $path = Join-Path $script:TempDir 'report.csv'
        New-TestFinding | Export-SpoReport -Path $path

        $rows = Import-Csv -LiteralPath $path
        # Without flattening this would read 'System.Management.Automation.PSCustomObject'.
        $rows[0].Detail | Should -Match '"Count":1'
    }

    It 'creates missing parent directories' {
        $path = Join-Path $script:TempDir 'nested/deeper/report.html'
        New-TestFinding | Export-SpoReport -Path $path

        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It 'writes nothing with -WhatIf' {
        $path = Join-Path $script:TempDir 'report.html'
        New-TestFinding | Export-SpoReport -Path $path -WhatIf

        Test-Path -LiteralPath $path | Should -BeFalse
    }

    It 'passes objects through with -PassThru' {
        $path = Join-Path $script:TempDir 'report.html'
        $result = New-TestFinding | Export-SpoReport -Path $path -PassThru

        @($result).Count    | Should -Be 1
        $result[0].RuleId   | Should -Be 'Test.Rule'
        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It 'emits nothing without -PassThru' {
        $path = Join-Path $script:TempDir 'report.html'
        $result = New-TestFinding | Export-SpoReport -Path $path

        $result | Should -BeNullOrEmpty
    }

    It 'handles multiple findings across severities' {
        $path = Join-Path $script:TempDir 'report.html'
        @(
            New-TestFinding -Severity Error -RuleId 'A'
            New-TestFinding -Severity Warning -RuleId 'B'
            New-TestFinding -Severity Info -RuleId 'C'
        ) | Export-SpoReport -Path $path -Title 'Mixed'

        $html = Get-Content -LiteralPath $path -Raw
        $html | Should -Match 'Mixed'
        $html | Should -Match 'sev-Error'
        $html | Should -Match 'sev-Warning'
        $html | Should -Match 'sev-Info'
    }

    It 'writes a valid empty report for no input' {
        $path = Join-Path $script:TempDir 'empty.html'
        @() | Export-SpoReport -Path $path

        Get-Content -LiteralPath $path -Raw | Should -Match 'Nothing to report'
    }
}
