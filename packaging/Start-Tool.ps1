<#
.SYNOPSIS
    The repository's half of the double-click launcher: finds the tools, asks
    which one, and hands over to it.
.DESCRIPTION
    packaging/Office365-Tools.cmd is handed out, and a copy on someone's
    machine never changes. So it does as little as it can: it finds a copy of
    this repository, or fetches one, and hands over to this script, which is
    fetched afresh with everything else. Whatever happens after that -- the
    menu, the settings file, how a tool is started -- can change with a push
    and reaches everyone who already has a launcher.

    The parameters below are what every launcher handed out passes. They are
    the contract: a launcher from before a parameter was added does not pass
    it, so a new one needs a default that does what that launcher expects, and
    none of them can be renamed or removed. tests/Unit/Launcher.Tests.ps1
    checks that what the launcher passes is accepted here.

    Runs under Windows PowerShell 5.1 -- no ternaries, no ??, no -Parallel --
    and stays plain ASCII.
.PARAMETER Root
    The copy of the repository the launcher found or fetched.
.PARAMETER LauncherPath
    The launcher itself. The settings files and the Reports folder live beside
    it, where the person running it can find them.
.PARAMETER Tool
    The tool a launcher is pinned to, the name of its folder under packaging\.
    Empty: every tool there.
.PARAMETER Dropped
    A folder dragged onto the launcher, if there was one.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Root,

    [Parameter(Mandatory)]
    [string]$LauncherPath,

    [string]$Tool = '',

    [string]$Dropped = ''
)

$ErrorActionPreference = 'Stop'

# Every folder in here with a tool.psd1 in it is a tool.
$ToolFolder = 'packaging'
$Reports    = 'Reports'

$SETUP_PROBLEM = 2

$here = Split-Path -Parent $LauncherPath

function Write-Problem {
    param(
        [string]$Title,
        [string[]]$Detail
    )

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Red
    Write-Host ''
    foreach ($line in $Detail) {
        Write-Host "  $line" -ForegroundColor Gray
    }
    Write-Host ''
}

# A tool.psd1 is read as data -- the way Import-PowerShellDataFile reads one,
# which a Windows PowerShell started from PowerShell 7 can fail to find. Plain
# values only; anything that would have to run to produce a value is refused.
function Read-Tool {
    param(
        [string]$Folder
    )

    $name = Split-Path -Leaf $Folder
    $path = Join-Path $Folder 'tool.psd1'
    $shown = "$ToolFolder\$name\tool.psd1"

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "$shown does not parse: $($parseErrors[0].Message)"
    }

    $table = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if (-not $table) {
        throw "$shown describes no tool"
    }

    $entry = $table.SafeGetValue()
    foreach ($field in 'Title', 'Entry', 'Settings') {
        if (-not $entry[$field]) {
            throw "$shown has no $field"
        }
    }

    $entry.Name = $name
    $entry.Folder = $Folder
    return $entry
}

# A launcher pinned to one tool reads that tool's folder and no other, so a
# mistake in another tool's tool.psd1 cannot stop it.
function Get-ToolSet {
    param(
        [string]$Pinned
    )

    $folder = Join-Path $Root $ToolFolder

    if ($Pinned) {
        $folders = @(Join-Path $folder $Pinned)
    }
    else {
        $folders = @(Get-ChildItem -LiteralPath $folder -Directory | Sort-Object Name | ForEach-Object { $_.FullName })
    }

    $tools = @()
    foreach ($candidate in $folders) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'tool.psd1')) {
            $tools += Read-Tool -Folder $candidate
        }
    }

    return $tools
}

function Select-Tool {
    param(
        [object[]]$Tools,
        [string]$Pinned
    )

    if ($Pinned) {
        foreach ($entry in $Tools) {
            if ($entry.Name -eq $Pinned) { return $entry }
        }

        Write-Problem -Title "This launcher runs '$Pinned', and the copy it found does not have that." -Detail @(
            "There is no $ToolFolder\$Pinned\tool.psd1 in",
            "    $Root",
            '',
            'Show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    if ($Tools.Count -eq 0) {
        Write-Problem -Title "There are no tools in $ToolFolder\, so there is nothing to run." -Detail @(
            'Show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    if ($Tools.Count -eq 1) {
        return $Tools[0]
    }

    Write-Host ''
    Write-Host '  What would you like to do?' -ForegroundColor Cyan
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        Write-Host ('    {0}) {1}' -f ($i + 1), $Tools[$i].Title)
        if ($Tools[$i].Description) {
            Write-Host "       $($Tools[$i].Description)" -ForegroundColor Gray
        }
    }

    $choice = 0
    while ($choice -lt 1 -or $choice -gt $Tools.Count) {
        Write-Host ''
        $answer = "$(Read-Host '  Number [1]')".Trim()
        if (-not $answer) { $answer = '1' }
        $choice = 0
        [void][int]::TryParse($answer, [ref]$choice)
    }

    return $Tools[$choice - 1]
}

try {
    $chosen = Select-Tool -Tools @(Get-ToolSet -Pinned $Tool) -Pinned $Tool

    # Read with a pattern rather than Import-PowerShellDataFile, for the same
    # reason tool.psd1 is.
    $manifest = Join-Path $Root 'src\Office365Tools\Office365Tools.psd1'
    $version = ''
    $line = Select-String -LiteralPath $manifest -Pattern "ModuleVersion\s*=\s*.([0-9.]+)" | Select-Object -First 1
    if ($line) { $version = $line.Matches[0].Groups[1].Value }

    try { $Host.UI.RawUI.WindowTitle = $chosen.Title } catch { Write-Verbose $_ }

    Write-Host ''
    Write-Host "  $($chosen.Title) $version" -ForegroundColor Cyan
    Write-Host "  from $Root" -ForegroundColor DarkGray

    $entryPath = Join-Path $chosen.Folder $chosen.Entry

    # The settings live beside the launcher, where the person running it can
    # find them, and survive the code being fetched afresh. The first run puts
    # the template there.
    $settingsName = Split-Path -Leaf $chosen.Settings
    $settingsPath = Join-Path $here $settingsName
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        Copy-Item -LiteralPath (Join-Path $chosen.Folder $chosen.Settings) -Destination $settingsPath
        Write-Host ''
        Write-Host "  Created $settingsName beside $(Split-Path -Leaf $LauncherPath). Your settings go in there;" -ForegroundColor Cyan
        Write-Host '  open it in Notepad to fill them in. Until then, you are asked.' -ForegroundColor Cyan
    }

    $arguments = @{
        SettingsPath = $settingsPath
        ReportFolder = (Join-Path $here $Reports)
    }

    if ($Dropped) {
        $arguments.Folder = $Dropped
    }

    & $entryPath @arguments
    exit $LASTEXITCODE
}
catch {
    Write-Problem -Title 'This stopped unexpectedly.' -Detail @(
        $_.Exception.Message,
        '',
        'Show this window to whoever sent you this file.')
    exit $SETUP_PROBLEM
}
