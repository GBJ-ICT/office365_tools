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
# Empty: every tool there -- straight into it when there is one, a menu when
# there are several. A ZIP built for one tool has that tool's name here,
# written in by build.ps1 -Task Package -Tool <name>, which looks for this
# exact line.
$Tool       = ''

# Where the tools come from. $Ref is a branch, a tag or a commit. A branch
# means every push reaches everyone the next time they run this -- convenient,
# and exactly as trustworthy as everyone who can push to it. A tag or a
# commit pins it; build.ps1 -Task Package -Ref <tag> writes it in, on this
# exact line.
$Repository = 'GBJ-ICT/office365_tools'
$Ref        = 'master'

# This file is handed out and never changes on anyone's machine, so it only
# finds a copy of the code, or fetches one, and hands over to $Handover in
# $ToolFolder there. Everything after that -- the menu, the settings, starting
# the tool -- is in that script and arrives with every fetch.
$ToolFolder = 'packaging'
$Handover   = 'Start-Tool.ps1'

$ErrorActionPreference = 'Stop'

# Windows PowerShell redraws its progress bar for every block it downloads or
# unpacks, which makes both many times slower.
$ProgressPreference = 'SilentlyContinue'

$SETUP_PROBLEM = 2

$launcher = $env:LAUNCHER_PATH
$here = Split-Path -Parent $launcher

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

# A copy of the code next to this file wins over fetching one: this file at the
# top of an offline package, or in packaging\ of a checkout or of a ZIP
# downloaded from GitHub by hand. Both pieces must be there -- a folder that
# happens to hold one of them is not a copy.
function Find-LocalCopy {
    foreach ($candidate in @($here, (Split-Path -Parent $here))) {
        if (-not $candidate) { continue }

        $hasTools  = Test-Path -LiteralPath (Join-Path (Join-Path $candidate $ToolFolder) $Handover) -PathType Leaf
        $hasModule = Test-Path -LiteralPath (Join-Path $candidate 'src\Office365Tools\Office365Tools.psd1')

        if ($hasTools -and $hasModule) { return $candidate }
    }

    return $null
}

# Which of the paths in $Required, relative to $Folder, are not there.
function Get-MissingPart {
    param(
        [string]$Folder,
        [string[]]$Required
    )

    foreach ($part in $Required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Folder $part))) { $part }
    }
}

# Fetches the repository as GitHub's ZIP of $Ref and unpacks it into the
# user's AppData. Fetched fresh every run -- it is a few hundred KB -- so a fix
# reaches people without anyone sending anything. The previous copy is kept
# until the new one is in place, and used when GitHub cannot be reached.
#
# Each tool gets a copy of its own: %LOCALAPPDATA%\office365_tools\<tool>\<ref>.
# A tool is fetched, checked and fallen back on by itself, so a push that
# breaks or removes one tool leaves the others running from their own copies,
# and one tool never swaps out a copy another tool is running from. Within a
# tool, one copy per ref: two launchers pinned to different versions would
# otherwise replace each other's copy on every run.
function Get-RemoteCopy {
    $url    = "https://github.com/$Repository/archive/$Ref.zip"
    $source = "$Repository@$Ref"
    $key    = $Ref -replace '[^A-Za-z0-9._-]', '_'

    # What a download must contain to be any use to this launcher: the script
    # it hands over to, and the tool it is pinned to. A launcher with no tool
    # of its own shares one copy across all of them; tool names start with a
    # letter, so _all is never one of them.
    $required = @(Join-Path $ToolFolder $Handover)
    if ($Tool) {
        $owner    = $Tool
        $required += Join-Path (Join-Path $ToolFolder $Tool) 'tool.psd1'
    }
    else {
        $owner    = '_all'
    }

    # For trying a build before it is pushed: a path to a ZIP laid out the way
    # GitHub lays them out, or another URL. Kept apart from every real ref.
    if ($env:OFFICE365TOOLS_ARCHIVE) {
        $url = $env:OFFICE365TOOLS_ARCHIVE
        $source = $url

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($url))
        $key = 'custom-' + ([System.BitConverter]::ToString($hash, 0, 4) -replace '-', '').ToLower()
    }

    $cache   = Join-Path (Join-Path $env:LOCALAPPDATA 'office365_tools') $owner
    $current = Join-Path $cache $key
    $marker  = Join-Path $cache "$key.source"

    $stamp    = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $zip      = Join-Path $cache "download-$stamp.zip"
    $unpacked = Join-Path $cache "unpacked-$stamp"
    $retired  = Join-Path $cache "retired-$stamp"

    $from = "GitHub ($Repository, $Ref)"
    if ($env:OFFICE365TOOLS_ARCHIVE) { $from = "$url (OFFICE365TOOLS_ARCHIVE)" }

    Write-Host ''
    Write-Host "  Fetching the tools from $from..." -ForegroundColor Gray

    # Decided inside, reported after: the leftovers are cleared away before
    # anything is shown, so a window closed on the message leaves none.
    $result = $null
    $reason = $null
    $downloaded = $false

    try {
        New-Item -Path $cache -ItemType Directory -Force | Out-Null

        if (Test-Path -LiteralPath $url) {
            Copy-Item -LiteralPath $url -Destination $zip
        }
        else {
            # GitHub accepts nothing older than TLS 1.2, which Windows
            # PowerShell does not offer unless asked. A company proxy that
            # wants a sign-in gets the one the user is already signed in with.
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            try { [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials } catch { Write-Verbose $_ }

            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        }

        $downloaded = $true

        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force

        # GitHub wraps everything in one folder named after the repository and
        # the ref -- and drops a leading v from a tag -- so it is found rather
        # than predicted.
        $top = @(Get-ChildItem -LiteralPath $unpacked -Directory)
        $missing = $required
        if ($top.Count -eq 1) {
            $missing = @(Get-MissingPart -Folder $top[0].FullName -Required $required)
        }
        if ($missing.Count -gt 0) {
            throw "what was downloaded does not contain $($missing -join ' or ')"
        }

        # Renamed out of the way rather than deleted, so a copy that is in use
        # makes this fail cleanly -- and the copy is still there to fall back to.
        if (Test-Path -LiteralPath $current) {
            Move-Item -LiteralPath $current -Destination $retired
        }
        Move-Item -LiteralPath $top[0].FullName -Destination $current
        Set-Content -LiteralPath $marker -Value $source -Encoding ASCII

        $result = $current
    }
    catch {
        $reason = $_.Exception.Message

        # Failed between moving the old copy aside and moving the new one in:
        # put the old one back before deciding whether there is one.
        if (-not (Test-Path -LiteralPath $current) -and (Test-Path -LiteralPath $retired)) {
            Move-Item -LiteralPath $retired -Destination $current -ErrorAction SilentlyContinue
        }

        $cached = (Test-Path -LiteralPath $marker) -and
            ((Get-Content -LiteralPath $marker -TotalCount 1) -eq $source) -and
            (@(Get-MissingPart -Folder $current -Required $required).Count -eq 0)

        if ($cached) {
            $when = (Get-Item -LiteralPath $marker).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            Write-Host "  That did not work, so this uses the copy fetched $when." -ForegroundColor Yellow
            Write-Host "  ($reason)" -ForegroundColor DarkGray
            $result = $current
        }
    }
    finally {
        foreach ($leftover in @($zip, $unpacked, $retired)) {
            if (Test-Path -LiteralPath $leftover) {
                Remove-Item -LiteralPath $leftover -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($result) {
        return $result
    }

    # Reached GitHub and got something, just not something this launcher can
    # use: the launcher is newer than what is published there, or older.
    # Telling someone to check their internet connection would send them the
    # wrong way.
    if ($downloaded) {
        Write-Problem -Title 'What was downloaded is not something this launcher can run.' -Detail @(
            $reason,
            '',
            'It came from',
            "    $url",
            '',
            'This launcher and the version published there do not fit together.',
            'Show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    Write-Problem -Title 'The tools could not be fetched.' -Detail @(
        $reason,
        '',
        'They are downloaded from GitHub when this runs, and this computer',
        'could not get them from',
        "    $url",
        '',
        'Check that you are online and run this again. If your organisation',
        'blocks GitHub, ask whoever sent you this file for the offline',
        'package, which has everything in it.')
    exit $SETUP_PROBLEM
}

try {
    # Explorer runs a file double-clicked inside a ZIP from a temporary copy,
    # alone: no settings beside it, and reports written where nobody finds
    # them. It names that folder after the ZIP, which is what gives it away.
    if ($here -match '\\Temp\d*_[^\\]*\.zip(\\|$)') {
        Write-Problem -Title 'This was opened straight from the ZIP.' -Detail @(
            'Extract the ZIP first: right-click it, choose "Extract All...", and',
            "run $(Split-Path -Leaf $launcher) from the folder that creates.")
        exit $SETUP_PROBLEM
    }

    $root = Find-LocalCopy
    if (-not $root) {
        $root = Get-RemoteCopy
    }

    # What is passed here is what Start-Tool.ps1 has to accept from every copy
    # of this file already handed out: add, never rename or remove.
    $start = Join-Path (Join-Path $root $ToolFolder) $Handover
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
