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

    It 'renders a run summary above the findings' {
        $path = Join-Path $script:TempDir 'summary.html'
        New-TestFinding | Export-SpoReport -Path $path -Summary ([ordered]@{
                'Folder checked' = 'C:\ToUpload'
                'Files'          = '312'
            })

        $html = Get-Content -LiteralPath $path -Raw
        $html | Should -Match 'Folder checked'
        # -Match is a regex, so the backslash is escaped rather than the path
        # being repeated verbatim.
        $html | Should -Match 'ToUpload'
        $html | Should -Match '312'
    }

    It 'renders the summary even when there is nothing to report' {
        # The reason the parameter exists: a report of no findings is a blank
        # page, and a blank page is indistinguishable from a tool that never
        # ran. Someone handed that page has to be able to see what was checked.
        $path = Join-Path $script:TempDir 'empty-with-summary.html'
        @() | Export-SpoReport -Path $path -Summary ([ordered]@{ 'Folder checked' = 'C:\ToUpload' })

        $html = Get-Content -LiteralPath $path -Raw
        $html | Should -Match 'Folder checked'
        $html | Should -Match 'Nothing to report'
    }

    It 'HTML-encodes summary values' {
        $path = Join-Path $script:TempDir 'summary-encoded.html'
        @() | Export-SpoReport -Path $path -Summary ([ordered]@{ 'Folder' = 'C:\<draft>' })

        Get-Content -LiteralPath $path -Raw | Should -Match '&lt;draft&gt;'
    }
}

Describe 'Export-SpoReport with a folder comparison' {

    BeforeAll {
        function New-TestComparison {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '',
                Justification = 'Test helper that builds an in-memory object.')]
            [CmdletBinding()]
            param(
                [string]$RelativePath,
                [string]$Status
            )
            [pscustomobject]@{
                PSTypeName     = 'Office365Tools.FolderComparison'
                RelativePath   = $RelativePath
                Status         = $Status
                LocalPath      = "C:\Up\$RelativePath"
                RemoteUrl      = "/sites/team/Docs/$RelativePath"
                LocalSize      = 2048
                RemoteSize     = 2048
                LocalModified  = [datetime]::new(2026, 3, 1, 12, 0, 0, [System.DateTimeKind]::Utc)
                RemoteModified = $null
                List           = 'Docs'
            }
        }
    }

    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-report-$([guid]::NewGuid())"
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
        $script:Path = Join-Path $script:TempDir 'verify.html'
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force
        }
    }

    It 'lists synchronised files as well as the differences' {
        @(
            New-TestComparison -RelativePath 'a.docx' -Status 'Match'
            New-TestComparison -RelativePath 'b.docx' -Status 'MissingRemote'
            New-TestComparison -RelativePath 'c.docx' -Status 'MissingLocal'
        ) | Export-SpoReport -Path $script:Path

        $html = Get-Content -LiteralPath $script:Path -Raw

        $html | Should -Match 'a\.docx'
        $html | Should -Match 'Synchronised'
        $html | Should -Match 'Missing in SharePoint'
        $html | Should -Match 'Missing on this computer'
        $html | Should -Not -Match 'Different size'
    }

    It 'gives every status a tick box that hides its rows without a script' {
        @(
            New-TestComparison -RelativePath 'a.docx' -Status 'Match'
            New-TestComparison -RelativePath 'b.docx' -Status 'LocalNewer'
        ) | Export-SpoReport -Path $script:Path

        $html = Get-Content -LiteralPath $script:Path -Raw

        $html | Should -Match 'id="show-Match" checked'
        $html | Should -Match 'id="show-LocalNewer" checked'
        $html | Should -Match 'body:has\(#show-Match:not\(:checked\)\) tr\.st-Match'
        $html | Should -Not -Match '<script'
    }

    It 'counts zero for the statuses a reader always wants an answer to' {
        New-TestComparison -RelativePath 'a.docx' -Status 'Match' | Export-SpoReport -Path $script:Path

        $html = Get-Content -LiteralPath $script:Path -Raw

        $html | Should -Match '<span class="n">0</span><span class="l"><input type="checkbox" id="show-MissingRemote"'
    }

    It 'encodes file names' {
        New-TestComparison -RelativePath 'Q1 <draft>.docx' -Status 'Match' | Export-SpoReport -Path $script:Path

        Get-Content -LiteralPath $script:Path -Raw | Should -Match 'Q1 &lt;draft&gt;\.docx'
    }

    It 'shows sizes and dates in readable form' {
        New-TestComparison -RelativePath 'a.docx' -Status 'Match' | Export-SpoReport -Path $script:Path

        $html = Get-Content -LiteralPath $script:Path -Raw

        $html | Should -Match '2[.,]0 KB'
        $html | Should -Match '2026-03-01 \d\d:00'
    }

    It 'shows exact byte counts where the sizes are what differs' {
        $row = New-TestComparison -RelativePath 'deck.pptx' -Status 'SizeDiffers'
        $row.LocalSize = 5242880
        $row.RemoteSize = 5251072
        $row | Export-SpoReport -Path $script:Path

        $html = Get-Content -LiteralPath $script:Path -Raw

        # Whatever the reader's thousands separator: , . ' or a thin space.
        $html | Should -Match '5\D?242\D?880 B'
        $html | Should -Match '5\D?251\D?072 B'
    }
}
