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
.PARAMETER Ref
    Package only. The branch, tag or commit the launcher fetches from GitHub.
    Defaults to master, so every push reaches the recipient on their next
    run. A tag pins them to that version until you send them a new ZIP.
.PARAMETER ProfileName
    Package only. Bakes this connection profile's details into the packaged
    settings files -- whichever settings each tool's Prefill names -- so the
    recipient is never asked for them. Omit to ship those fields empty.
.PARAMETER IncludeCode
    Package only. Put the code in the ZIP as well, for a machine that cannot
    reach GitHub. Without it the ZIP holds only the launcher, the settings and
    the read-me, and the launcher fetches the code from GitHub when it runs.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck
    Writes out/Check-Upload.zip: the double-click launcher, its settings file
    and a read-me, for someone who does not use PowerShell. The code itself
    comes from GitHub when they run it, so it is always current.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck -ProfileName CDS
    Same, with the CDS site and client ID already filled in, so checking that
    an upload arrived works on their machine without them typing anything.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck -IncludeCode
    Writes out/Check-Upload-<version>-offline.zip, which has everything in it
    and needs no access to GitHub.
.EXAMPLE
    ./build.ps1 -Task Package -Tool UploadCheck -Ref v0.7.0
    Same, pinned to the v0.7.0 tag: pushes to master no longer reach this
    recipient. The tag has to be on GitHub.
.EXAMPLE
    ./build.ps1 -Task Package
    Writes out/Office365-Tools.zip, whose launcher offers every tool under
    packaging/ -- and every tool added there later.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Analyze', 'Test', 'Import', 'Package')]
    [string]$Task = 'All',

    [Parameter()]
    [string]$Tool,

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._/-]*$')]
    [string]$Ref = 'master',

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [switch]$IncludeCode
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
        [string]$Ref,
        [string]$ProfileName,
        [switch]$IncludeCode
    )

    Write-Host '==> Package' -ForegroundColor Cyan

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $version = $manifest.ModuleVersion

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

    # The launcher hands over to packaging/Start-Tool.ps1 in what it fetches,
    # and refuses a download without it. A ref from before that script existed
    # makes a launcher that can never start, so stop here instead. Looked up
    # as GitHub has it where possible: origin/<branch>, then the ref itself.
    if (-not $IncludeCode -and (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        $commit = $null
        foreach ($candidate in "origin/$Ref", $Ref) {
            $commit = git -C $repoRoot rev-parse --verify --quiet "$candidate^{commit}" 2>$null
            if ($LASTEXITCODE -eq 0 -and $commit) { break }
            $commit = $null
        }

        if (-not $commit) {
            Write-Warning "Cannot find $Ref in this checkout, so whether it has packaging/Start-Tool.ps1 is unchecked."
        }
        else {
            git -C $repoRoot cat-file -e "${commit}:packaging/Start-Tool.ps1" 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "$Ref has no packaging/Start-Tool.ps1, which this launcher hands over to. Push it to $Ref first, or pick a later -Ref."
            }
        }
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($launcherName)
    $name = if ($IncludeCode) { "$base-$version-offline" } else { $base }
    $staging = Join-Path $repoRoot "out/$name"
    $archive = Join-Path $repoRoot "out/$name.zip"

    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
    New-Item -Path $staging -ItemType Directory -Force | Out-Null

    # -- The launcher, pinned to the tool and the ref -------------------------
    # Edited as text, on the lines it reserves for this. Kept ASCII with its
    # CRLF endings, which cmd needs.
    $launcherText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'packaging/Office365-Tools.cmd'))

    $pins = [ordered]@{
        "`$Tool       = ''"       = "`$Tool       = '$Tool'"
        "`$Ref        = 'master'" = "`$Ref        = '$Ref'"
    }
    foreach ($line in $pins.Keys) {
        if (([regex]::Matches($launcherText, [regex]::Escape($line))).Count -ne 1) {
            throw "packaging/Office365-Tools.cmd no longer has exactly one line reading: $line"
        }
        $launcherText = $launcherText.Replace($line, $pins[$line])
    }

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

    # -- The code, for a machine that cannot reach GitHub ---------------------
    # The repository's own layout, so the launcher finds the code beside itself
    # exactly as it does in a checkout. Only the packaged tools' folders, and
    # all of scripts/, because an entry script is free to call any of them.
    if ($IncludeCode) {
        foreach ($folder in 'packaging', 'scripts', 'src') {
            New-Item -Path (Join-Path $staging $folder) -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path (Join-Path $repoRoot 'packaging/Start-Tool.ps1') -Destination (Join-Path $staging 'packaging') -Force

        foreach ($entry in $tools) {
            Copy-Item -Path (Join-Path $repoRoot $entry.Folder) -Destination (Join-Path $staging 'packaging') -Recurse -Force
        }

        Copy-Item -Path (Join-Path $repoRoot 'scripts/*.ps1') -Destination (Join-Path $staging 'scripts') -Force
        Copy-Item -Path (Join-Path $repoRoot 'src/Office365Tools') -Destination (Join-Path $staging 'src') -Recurse -Force
    }

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

    # With the code in the ZIP, run each tool: through the entry script the
    # launcher hands over to, under the same Windows PowerShell, against the
    # staging folder itself.
    if ($IncludeCode) {
        $host51 = Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue

        foreach ($settingsName in $settingsFiles.Keys) {
            $entry = $settingsFiles[$settingsName]
            $entryPath = Join-Path $staging "$($entry.Folder)/$($entry.Entry)"
            $selfTestReports = Join-Path ([System.IO.Path]::GetTempPath()) "office365-tools-selftest-$([guid]::NewGuid().ToString('N'))"

            $selfTestArgs = @{
                SettingsPath = (Join-Path $staging $settingsName)
                Folder       = $staging
                ReportFolder = $selfTestReports
                NoPrompt     = $true
            }

            if ($host51) {
                & $host51.Source -NoProfile -ExecutionPolicy Bypass -File $entryPath `
                    -SettingsPath $selfTestArgs.SettingsPath -Folder $staging -ReportFolder $selfTestReports -NoPrompt | Out-Null
            }
            else {
                Write-Host '    (Windows PowerShell not found; self-testing under this host instead)' -ForegroundColor DarkGray
                & $entryPath @selfTestArgs | Out-Null
            }
            $selfTestExit = $LASTEXITCODE

            Remove-Item -LiteralPath $selfTestReports -Recurse -Force -ErrorAction SilentlyContinue

            # 0 is clean and 1 is "found something in the staging folder",
            # which is fine. 2 means the package is broken.
            if ($selfTestExit -gt 1) {
                throw "$($entry.Title) reported a setup problem (exit $selfTestExit) during the package self-test."
            }
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
    if (-not $IncludeCode) {
        Write-Host "    fetches $Ref from GitHub" -ForegroundColor Gray
    }
    Write-Host '    Send the ZIP, or put it where they can download it. They extract it and' -ForegroundColor Gray
    Write-Host "    double-click $launcherName." -ForegroundColor Gray
    if (-not $IncludeCode) {
        Write-Host "    The code comes from GitHub when they run it: push $Ref before you send this." -ForegroundColor Yellow
    }
}

switch ($Task) {
    'Analyze' { Invoke-AnalyzeTask }
    'Test' { Invoke-TestTask }
    'Import' { Invoke-ImportTask }
    'Package' { Invoke-PackageTask -Tool $Tool -Ref $Ref -ProfileName $ProfileName -IncludeCode:$IncludeCode }
    'All' { Invoke-AnalyzeTask; Invoke-TestTask }
}
