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
      Package - build a hand-out ZIP of the double-click tools into out/
      Release - Analyze, Test, then tag this commit vX.Y and push the tag,
                which is what every launcher handed out runs from then on
      All     - Analyze then Test (the default, and what CI effectively does)
.EXAMPLE
    ./build.ps1
    Runs analysis and unit tests.
.EXAMPLE
    ./build.ps1 -Task Test
    Runs only the unit tests.
.PARAMETER Tool
    Package only. Build the ZIP for this one tool -- the name of its folder
    under packaging/. Its launcher is named for it (Check-Upload.cmd for
    UploadCheck), runs it alone and keeps its own copy of the code, so tools
    added later never appear for this recipient and nothing done to another
    tool reaches them. Omit to ship Office365-Tools.cmd, which offers every
    tool under packaging/.
.PARAMETER ProfileName
    Package only. Bakes this connection profile's details into the packaged
    settings files -- whichever settings each tool's Prefill names -- so the
    recipient is never asked for them. Omit to ship those fields empty.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck
    Writes out/Check-Upload.zip: the double-click launcher, its settings file
    and a read-me, for someone who does not use PowerShell. The code itself
    is the newest vX.Y tag on GitHub when they run it.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck -ProfileName CDS
    Same, with the CDS site and client ID already filled in, so checking that
    an upload arrived works on their machine without them typing anything.
.EXAMPLE
    ./build.ps1 -Task Package
    Writes out/Office365-Tools.zip, whose launcher offers every tool under
    packaging/ -- and every tool added there later.
.PARAMETER Version
    Release only. The tag to create, as vX.Y. Omit for the next one: the
    newest release with its minor number raised, v0.9 to v0.10, or v0.1 when
    there is none. Give it to start a new major version: -Version v1.0.
.EXAMPLE
    ./build.ps1 -Task Release
    Checks the working tree is committed, runs the analyzer and the tests,
    tags this commit with the next version and pushes the tag. Nothing is
    tagged if anything fails.
.EXAMPLE
    ./build.ps1 -Task Release -Version v1.0
    Same, as v1.0.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Analyze', 'Test', 'Import', 'Package', 'Release')]
    [string]$Task = 'All',

    [Parameter()]
    [string]$Tool,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [ValidatePattern('^v\d+\.\d+$')]
    [string]$Version
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

# The tools under packaging/, read the way the launcher reads them -- each
# tool.psd1 as data -- so a tool the launcher would refuse fails the build too.
# Name is the folder's name; Folder is relative to the repository.
function Get-ToolSet {
    $tools = @()

    foreach ($folder in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'packaging') -Directory | Sort-Object Name) {
        $path = Join-Path $folder.FullName 'tool.psd1'
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $shown = "packaging/$($folder.Name)/tool.psd1"

        if ($folder.Name -notmatch '^[A-Za-z][A-Za-z0-9-]*$') {
            throw "packaging/$($folder.Name): a tool's folder name is its name, and has to be letters, digits and hyphens, starting with a letter."
        }

        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) {
            throw "$shown does not parse: $($parseErrors[0].Message)"
        }

        $entry = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false).SafeGetValue()
        foreach ($field in 'Title', 'Entry', 'Settings', 'Launcher') {
            if (-not $entry[$field]) {
                throw "$shown has no $field"
            }
        }

        $entry.Name = $folder.Name
        $entry.Folder = "packaging/$($folder.Name)"
        $tools += $entry
    }

    return $tools
}

function Invoke-PackageTask {
    param(
        [string]$Tool,
        [string]$ProfileName
    )

    Write-Host '==> Package' -ForegroundColor Cyan

    $allTools = @(Get-ToolSet)

    if ($Tool) {
        $tools = @($allTools | Where-Object { $_.Name -eq $Tool })
        if ($tools.Count -eq 0) {
            throw "No tool '$Tool': there is no packaging/$Tool/tool.psd1. Known: $(($allTools | ForEach-Object { $_.Name }) -join ', ')."
        }
        $launcherName = $tools[0].Launcher
    }
    else {
        $tools = $allTools
        $launcherName = 'Office365-Tools.cmd'
    }

    $name = [System.IO.Path]::GetFileNameWithoutExtension($launcherName)
    $staging = Join-Path $repoRoot "out/$name"
    $archive = Join-Path $repoRoot "out/$name.zip"

    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
    New-Item -Path $staging -ItemType Directory -Force | Out-Null

    # -- The launcher, pinned to the tool ------------------------------------
    # Edited as text, on the line it reserves for this. Kept ASCII with its
    # CRLF endings, which cmd needs.
    $launcherText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'packaging/Office365-Tools.cmd'))

    $line = "`$Tool       = ''"
    if (([regex]::Matches($launcherText, [regex]::Escape($line))).Count -ne 1) {
        throw "packaging/Office365-Tools.cmd no longer has exactly one line reading: $line"
    }
    $launcherText = $launcherText.Replace($line, "`$Tool       = '$Tool'")

    [System.IO.File]::WriteAllText((Join-Path $staging $launcherName), $launcherText, [System.Text.Encoding]::ASCII)

    # -- What the recipient reads and edits -----------------------------------
    $settingsFiles = @{}

    foreach ($entry in $tools) {
        $settingsName = Split-Path -Leaf $entry.Settings
        if ($settingsFiles.ContainsKey($settingsName)) {
            throw "Two tools keep their settings in $settingsName; they would overwrite each other beside the launcher."
        }
        $settingsFiles[$settingsName] = $entry

        Copy-Item -Path (Join-Path $repoRoot "$($entry.Folder)/$($entry.Settings)") -Destination (Join-Path $staging $settingsName) -Force

        if ($entry.ReadMe) {
            $readMeName = if ($Tool) { 'READ-ME-FIRST.txt' } else { "READ-ME-FIRST - $($entry.Title).txt" }
            Copy-Item -Path (Join-Path $repoRoot "$($entry.Folder)/$($entry.ReadMe)") -Destination (Join-Path $staging $readMeName) -Force
        }
    }

    Copy-Item -Path (Join-Path $repoRoot 'LICENSE') -Destination $staging -Force

    # -- Tenant details -------------------------------------------------------
    # Filling these in here is the difference between a recipient who signs in
    # and one who is asked for a site URL and an application ID they have
    # never heard of. Each tool's Prefill says which of its settings take
    # which profile property.
    if ($ProfileName) {
        $store = Join-Path $repoRoot 'config/profiles.json'

        if (-not (Test-Path -LiteralPath $store)) {
            throw "No config/profiles.json, so -ProfileName $ProfileName cannot be resolved."
        }

        $profiles = (Get-Content -Raw -LiteralPath $store | ConvertFrom-Json).profiles

        if (-not $profiles.PSObject.Properties.Name.Contains($ProfileName)) {
            throw "Profile '$ProfileName' is not in config/profiles.json."
        }

        $connection = $profiles.$ProfileName

        foreach ($settingsName in $settingsFiles.Keys) {
            $entry = $settingsFiles[$settingsName]
            if (-not $entry.Prefill) { continue }

            $settingsPath = Join-Path $staging $settingsName
            $xml = New-Object System.Xml.XmlDocument
            $xml.Load($settingsPath)

            foreach ($element in $entry.Prefill.Keys) {
                $node = $xml.DocumentElement.SelectSingleNode($element)
                if (-not $node) {
                    throw "$settingsName has no <$element> for the profile's $($entry.Prefill[$element]) to go into."
                }
                $node.InnerText = $connection.($entry.Prefill[$element])
            }

            $xml.Save($settingsPath)
        }

        Write-Host "    settings prefilled from profile '$ProfileName' ($($connection.siteUrl))" -ForegroundColor Gray
    }

    # -- Self-test: fail here rather than on someone else's desk -------------
    $launcherPath = Join-Path $staging $launcherName
    $bytes = [System.IO.File]::ReadAllBytes($launcherPath)

    # cmd misreads labels in a file with bare LF endings. .gitattributes
    # keeps the checkout CRLF; this catches a copy that did not get the memo.
    $bareLf = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i - 1] -ne 13)) { $bareLf++ }
    }
    if ($bareLf -gt 0) {
        throw "$launcherName has $bareLf line(s) ending in LF alone; cmd needs CRLF. Run: git add --renormalize packaging/Office365-Tools.cmd"
    }

    # The whole file is PowerShell -- the batch half is a comment to it -- so
    # it parses as one script or the launcher is broken.
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseInput(
        [System.Text.Encoding]::ASCII.GetString($bytes), [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors) {
        throw "$launcherName does not parse as PowerShell: $($parseErrors[0].Message) (line $($parseErrors[0].Extent.StartLineNumber))"
    }

    foreach ($settingsName in $settingsFiles.Keys) {
        try {
            $check = New-Object System.Xml.XmlDocument
            $check.Load((Join-Path $staging $settingsName))
        }
        catch {
            throw "The packaged $settingsName does not load: $($_.Exception.Message)"
        }
    }

    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive

    # The ZIP is the product. A staging copy left behind is a second set of
    # scripts under out/ that the analyzer would then report on, stale.
    Remove-Item -LiteralPath $staging -Recurse -Force

    $size = [Math]::Round((Get-Item -LiteralPath $archive).Length / 1KB)

    Write-Host "    $archive ($size KB)" -ForegroundColor Green
    Write-Host "    $(($tools | ForEach-Object { $_.Title }) -join ', ')" -ForegroundColor Gray
    Write-Host '    Send the ZIP, or put it where they can download it. They extract it and' -ForegroundColor Gray
    Write-Host "    double-click $launcherName." -ForegroundColor Gray
    Write-Host '    The code is the newest vX.Y tag on GitHub when they run it: nothing reaches them until it is tagged.' -ForegroundColor Yellow
}

# A release is a tag named vX.Y on GitHub: the launcher runs the newest one
# and nothing else. So this is the whole of releasing -- check, tag, push the
# tag -- and the order matters: nothing is tagged unless everything passed.
function Invoke-ReleaseTask {
    param(
        [string]$Version
    )

    Write-Host '==> Release' -ForegroundColor Cyan

    # What is tagged is the commit, not the working tree. With changes lying
    # about, the checks below would pass or fail on something else.
    if (git -C $repoRoot status --porcelain) {
        throw 'There are uncommitted changes. A release is a commit: commit them first.'
    }

    git -C $repoRoot fetch --tags --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not fetch the tags from GitHub, so the next version is unknown.'
    }

    # The launcher's rule: vX.Y exactly, newest by number.
    $newest = git -C $repoRoot tag --list |
        Where-Object { $_ -cmatch '^v\d+\.\d+$' } |
        Sort-Object { [version]$_.Substring(1) } |
        Select-Object -Last 1

    if (-not $Version) {
        $Version = 'v0.1'
        if ($newest) {
            $number = [version]$newest.Substring(1)
            $Version = "v$($number.Major).$($number.Minor + 1)"
        }
    }
    elseif ($newest -and [version]$Version.Substring(1) -le [version]$newest.Substring(1)) {
        throw "$Version is not newer than $newest, so no launcher would run it."
    }

    Write-Host "    $Version, after $(if ($newest) { $newest } else { 'no release yet' })" -ForegroundColor Gray

    Invoke-AnalyzeTask
    Invoke-TestTask

    git -C $repoRoot tag $Version
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the tag $Version."
    }

    # The tag alone: it takes its commit with it, whatever branch that is on.
    git -C $repoRoot push --quiet origin $Version
    if ($LASTEXITCODE -ne 0) {
        git -C $repoRoot tag --delete $Version | Out-Null
        throw "Could not push $Version to GitHub; the tag was removed again, so nothing is released."
    }

    Write-Host "    $Version is released: every launcher runs it from its next start." -ForegroundColor Green
}

switch ($Task) {
    'Analyze' { Invoke-AnalyzeTask }
    'Test' { Invoke-TestTask }
    'Import' { Invoke-ImportTask }
    'Package' { Invoke-PackageTask -Tool $Tool -ProfileName $ProfileName }
    'Release' { Invoke-ReleaseTask -Version $Version }
    'All' { Invoke-AnalyzeTask; Invoke-TestTask }
}
