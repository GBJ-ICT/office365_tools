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
      Package - build the shippable upload checker into out/
      All     - Analyze then Test (the default, and what CI effectively does)
.EXAMPLE
    ./build.ps1
    Runs analysis and unit tests.
.EXAMPLE
    ./build.ps1 -Task Test
    Runs only the unit tests.
.PARAMETER ProfileName
    Package only. Bakes this connection profile's site URL and client ID into
    the packaged settings file, so the recipient is never asked for them.
    Omit to ship the settings file with those fields empty.
.EXAMPLE
    ./build.ps1 -Task Package
    Writes out/UploadChecker-<version>.zip: the checker, its module, and a
    double-click launcher, for someone who does not use PowerShell.
.EXAMPLE
    ./build.ps1 -Task Package -ProfileName CDS
    Same, with the CDS site and client ID already filled in, so checking that
    an upload arrived works on their machine without them typing anything.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Analyze', 'Test', 'Import', 'Package')]
    [string]$Task = 'All',

    [Parameter()]
    [string]$ProfileName
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

function Invoke-PackageTask {
    param(
        [string]$ProfileName
    )

    Write-Host '==> Package' -ForegroundColor Cyan

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $version = $manifest.ModuleVersion

    $staging = Join-Path $repoRoot 'out/UploadChecker'
    $archive = Join-Path $repoRoot "out/UploadChecker-$version.zip"

    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }

    # The layout mirrors the repository rather than flattening it, so
    # Test-Upload.ps1 finds the module at the same relative path it always does
    # and the package needs no special-casing anywhere.
    New-Item -Path (Join-Path $staging 'scripts') -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $staging 'src') -ItemType Directory -Force | Out-Null

    Copy-Item -Path (Join-Path $repoRoot 'scripts/Test-Upload.ps1') -Destination (Join-Path $staging 'scripts') -Force
    Copy-Item -Path (Join-Path $repoRoot 'src/Office365Tools') -Destination (Join-Path $staging 'src') -Recurse -Force
    Copy-Item -Path (Join-Path $repoRoot 'packaging/Check-Upload.cmd') -Destination $staging -Force
    Copy-Item -Path (Join-Path $repoRoot 'packaging/Start-UploadCheck.ps1') -Destination $staging -Force
    Copy-Item -Path (Join-Path $repoRoot 'packaging/upload-check.xml') -Destination $staging -Force
    Copy-Item -Path (Join-Path $repoRoot 'packaging/READ-ME-FIRST.txt') -Destination $staging -Force
    Copy-Item -Path (Join-Path $repoRoot 'LICENSE') -Destination $staging -Force

    # Filling the tenant details in here is the difference between a recipient
    # who signs in and one who is asked for a site URL and an application ID
    # they have never heard of.
    if ($ProfileName) {
        $store = Join-Path $repoRoot 'config/profiles.json'

        if (-not (Test-Path -LiteralPath $store)) {
            throw "No config/profiles.json, so -ProfileName $ProfileName cannot be resolved."
        }

        $profiles = (Get-Content -Raw -LiteralPath $store | ConvertFrom-Json).profiles

        if (-not $profiles.PSObject.Properties.Name.Contains($ProfileName)) {
            throw "Profile '$ProfileName' is not in config/profiles.json."
        }

        $entry = $profiles.$ProfileName
        $settingsPath = Join-Path $staging 'upload-check.xml'

        # The site URL on its own is a destination the checker understands: it
        # gets the recipient signed in and then offers the libraries and
        # folders that are actually there. Which is as far as a profile can
        # take them -- a profile knows the site, not the folder they are
        # uploading into this week.
        $xml = New-Object System.Xml.XmlDocument
        $xml.Load($settingsPath)
        $xml.SelectSingleNode('/UploadCheck/Destination').InnerText = $entry.siteUrl
        $xml.SelectSingleNode('/UploadCheck/ClientId').InnerText = $entry.clientId
        $xml.Save($settingsPath)

        Write-Host "    settings prefilled from profile '$ProfileName' ($($entry.siteUrl))" -ForegroundColor Gray
    }

    # Prove the package works before it is handed over, through the same
    # bootstrap the recipient runs and under the same Windows PowerShell that
    # will run it -- so a settings file that does not parse, or a module file
    # left out of the copy, fails here rather than on someone else's desk.
    $bootstrap = Join-Path $staging 'Start-UploadCheck.ps1'

    $host51 = Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue
    if ($host51) {
        & $host51.Source -NoProfile -ExecutionPolicy Bypass -File $bootstrap -Folder $staging -NoPrompt | Out-Null
    }
    else {
        Write-Host '    (Windows PowerShell not found; self-testing under this host instead)' -ForegroundColor DarkGray
        & $bootstrap -Folder $staging -NoPrompt | Out-Null
    }

    # 0 is clean and 1 is "found something in the staging folder", which is
    # fine -- the package contains .ps1 files. 2 means the package is broken.
    if ($LASTEXITCODE -gt 1) {
        throw "The packaged checker reported a setup problem (exit $LASTEXITCODE) during its self-test."
    }

    Remove-Item -LiteralPath (Join-Path $staging 'out') -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive

    $size = [Math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 1)

    Write-Host "    $archive ($size MB)" -ForegroundColor Green
    Write-Host '    Send the zip. The recipient extracts it and runs Check-Upload.cmd.' -ForegroundColor Gray
}

switch ($Task) {
    'Analyze' { Invoke-AnalyzeTask }
    'Test' { Invoke-TestTask }
    'Import' { Invoke-ImportTask }
    'Package' { Invoke-PackageTask -ProfileName $ProfileName }
    'All' { Invoke-AnalyzeTask; Invoke-TestTask }
}
