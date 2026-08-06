<#
.SYNOPSIS
    Developer entry point: lint, test, and import the Office365Tools module.
.DESCRIPTION
    A tiny task runner so contributors and CI run exactly the same commands.
    No build framework, no dependencies beyond Pester and PSScriptAnalyzer.
.PARAMETER Task
    Which task to run:
      Analyze - run PSScriptAnalyzer over the repository
      Test    - run the Pester unit tests (no tenant required)
      Import  - import the module into the current session
      All     - Analyze then Test (the default, and what CI effectively does)
.EXAMPLE
    ./build.ps1
    Runs analysis and unit tests.
.EXAMPLE
    ./build.ps1 -Task Test
    Runs only the unit tests.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Analyze', 'Test', 'Import')]
    [string]$Task = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot     = $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'src/Office365Tools/Office365Tools.psd1'

function Invoke-AnalyzeTask {
    Write-Host '==> PSScriptAnalyzer' -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
        throw 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    }

    $results = Invoke-ScriptAnalyzer -Path $repoRoot -Recurse `
        -Settings (Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1')

    if ($results) {
        $results | Format-Table -AutoSize | Out-String -Width 250 | Write-Host
        throw "PSScriptAnalyzer reported $(@($results).Count) issue(s)."
    }

    Write-Host '    clean' -ForegroundColor Green
}

function Invoke-TestTask {
    Write-Host '==> Pester (unit)' -ForegroundColor Cyan

    $pester = Get-Module -ListAvailable Pester |
        Where-Object { $_.Version -ge [version]'5.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $pester) {
        throw 'Pester 5+ is not installed. Run: Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck'
    }

    Import-Module $pester.Path -Force

    $config = New-PesterConfiguration
    $config.Run.Path            = Join-Path $repoRoot 'tests/Unit'
    $config.Run.Exit            = $false
    $config.Run.PassThru        = $true
    $config.Output.Verbosity    = 'Detailed'
    $config.TestResult.Enabled  = $true
    $config.TestResult.OutputPath = Join-Path $repoRoot 'testResults.xml'

    $result = Invoke-Pester -Configuration $config

    if ($result.FailedCount -gt 0) {
        throw "$($result.FailedCount) test(s) failed."
    }

    Write-Host "    $($result.PassedCount) passed" -ForegroundColor Green
}

function Invoke-ImportTask {
    Write-Host '==> Import module' -ForegroundColor Cyan
    Import-Module $manifestPath -Force -Global
    $commands = Get-Command -Module Office365Tools | Sort-Object Name
    Write-Host "    $(@($commands).Count) command(s) exported" -ForegroundColor Green
    $commands | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor Gray }
}

switch ($Task) {
    'Analyze' { Invoke-AnalyzeTask }
    'Test' { Invoke-TestTask }
    'Import' { Invoke-ImportTask }
    'All' { Invoke-AnalyzeTask; Invoke-TestTask }
}
