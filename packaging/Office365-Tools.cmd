<# : office365_tools -- double-click this file, or drag a folder onto it.
@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title office365_tools

rem ---------------------------------------------------------------------------
rem  This is a batch file and a PowerShell script in one. cmd reads only these
rem  first lines -- to cmd the top line is a label -- and they start Windows
rem  PowerShell on this same file. PowerShell reads all of it, and to
rem  PowerShell everything down to the closing mark below is a comment.
rem  So: a file Windows lets you double-click, written in PowerShell.
rem ---------------------------------------------------------------------------

rem The path of this file, and the folder dragged onto it, go across in the
rem environment, where no quoting rule on either side can mangle them.
rem
rem A folder with an & in its name cannot be dragged onto any .cmd file:
rem Explorer leaves it unquoted and cmd splits the line before this starts.
rem Picking it in the folder window works.
set "LAUNCHER_PATH=%~f0"
set "LAUNCHER_DROPPED=%~1"

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%PS%" goto run
set "PS=pwsh.exe"
where pwsh.exe >nul 2>&1 && goto run

echo.
echo   No PowerShell was found on this computer, which is unusual.
echo   Ask whoever sent you this file for help.
echo.
pause
exit /b 2

:run
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:LAUNCHER_PATH)))"
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
#>

# ===========================================================================
#  PowerShell from here on -- Windows PowerShell 5.1, so nothing 7-only:
#  no ternaries, no ??, no -Parallel. Plain ASCII, because cmd reads the top.
# ===========================================================================

# Which tool this launcher runs: the name of its folder under packaging\.
# Empty: a menu of every tool there. A ZIP built for one tool has that tool's
# name here and goes straight into it; build.ps1 -Task Package -Tool <name>
# writes it in, and looks for this exact line.
$Tool       = ''

# Where the tools come from. A release is a tag named vX.Y -- v1.4, not
# v1.4.2, not a branch -- and the newest one is what runs. Nothing else is
# ever downloaded, so a push reaches nobody until it is tagged.
$Repository = 'GBJ-ICT/office365_tools'

# This file is handed out and never changes on anyone's machine, so it only
# fetches the newest release and hands over to packaging\Start-Tool.ps1 in
# it. It does the same wherever it is started from: code that happens to be
# beside it is not used. Everything after the hand-over -- the menu, the
# settings, starting the tool -- arrives with the release.

$ErrorActionPreference = 'Stop'

# Windows PowerShell redraws its progress bar for every block it downloads or
# unpacks, which makes both many times slower.
$ProgressPreference = 'SilentlyContinue'

$SETUP_PROBLEM = 2

$launcher = $env:LAUNCHER_PATH

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

# The newest of the names that are releases: vX.Y exactly, compared as
# numbers, so v0.10 is newer than v0.9. Nothing if none of them is one.
function Select-Release {
    param(
        [string[]]$Name
    )

    $Name | Where-Object { $_ -cmatch '^v\d+\.\d+$' } | Sort-Object { [version]$_.Substring(1) } | Select-Object -Last 1
}

try {
    # Explorer runs a file double-clicked inside a ZIP from a temporary copy,
    # alone: no settings beside it, and reports written where nobody finds
    # them. It names that folder after the ZIP, which is what gives it away.
    if ((Split-Path -Parent $launcher) -match '\\Temp\d*_[^\\]*\.zip(\\|$)') {
        Write-Problem -Title 'This was opened straight from the ZIP.' -Detail @(
            'Extract the ZIP first: right-click it, choose "Extract All...", and',
            "run $(Split-Path -Leaf $launcher) from the folder that creates.")
        exit $SETUP_PROBLEM
    }

    # One folder per release, in the user's AppData. A tag does not change,
    # so a release that is already there is never fetched again.
    $cache = Join-Path $env:LOCALAPPDATA 'office365_tools'
    $reason = $null

    try {
        # GitHub accepts nothing older than TLS 1.2, which Windows PowerShell
        # does not offer unless asked. A company proxy that wants a sign-in
        # gets the one the user is already signed in with.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        try { [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials } catch { Write-Verbose $_ }

        $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/tags?per_page=100" -UseBasicParsing
        $newest = Select-Release -Name @($tags | ForEach-Object { $_.name })
        if (-not $newest) {
            throw "$Repository has no release: no tag named vX.Y"
        }

        $target = Join-Path $cache $newest
        if (-not (Test-Path -LiteralPath $target)) {
            Write-Host ''
            Write-Host "  Fetching $newest from GitHub ($Repository)..." -ForegroundColor Gray

            $zip = "$target.zip"
            $unpacked = "$target.unpacked"
            New-Item -Path $cache -ItemType Directory -Force | Out-Null

            Invoke-WebRequest -Uri "https://github.com/$Repository/archive/refs/tags/$newest.zip" -OutFile $zip -UseBasicParsing
            Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force

            # GitHub wraps everything in one folder. It gets the release's
            # name only once it is complete, so a folder with that name is
            # always a whole release.
            $top = Get-ChildItem -LiteralPath $unpacked -Directory | Select-Object -First 1
            Move-Item -LiteralPath $top.FullName -Destination $target

            Remove-Item -LiteralPath $zip, $unpacked -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $reason = $_.Exception.Message
    }

    # Whatever happened above, run the newest release this computer has.
    $have = $null
    if (Test-Path -LiteralPath $cache) {
        $have = Select-Release -Name @(Get-ChildItem -LiteralPath $cache -Directory | ForEach-Object { $_.Name })
    }

    if (-not $have) {
        Write-Problem -Title 'The tools could not be fetched.' -Detail @(
            $reason,
            '',
            'They are downloaded from GitHub, and this computer could not get them.',
            'Check that you are online and run this again. If that does not help,',
            'show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    if ($reason) {
        Write-Host ''
        Write-Host "  Could not look for a newer release, so this uses $have." -ForegroundColor Yellow
        Write-Host "  ($reason)" -ForegroundColor DarkGray
    }

    # What is passed here is what Start-Tool.ps1 has to accept from every copy
    # of this file already handed out: add, never rename or remove.
    $root = Join-Path $cache $have
    $start = Join-Path $root 'packaging\Start-Tool.ps1'
    if (-not (Test-Path -LiteralPath $start)) {
        Write-Problem -Title "Release $have is not something this launcher can run." -Detail @(
            'It has no packaging\Start-Tool.ps1.',
            '',
            'Show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    & $start -Root $root -LauncherPath $launcher -Tool $Tool -Dropped "$env:LAUNCHER_DROPPED"
    exit $LASTEXITCODE
}
catch {
    Write-Problem -Title 'This stopped unexpectedly.' -Detail @(
        $_.Exception.Message,
        '',
        'Show this window to whoever sent you this file.')
    exit $SETUP_PROBLEM
}
