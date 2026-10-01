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

# Which tool this launcher runs. Empty: whatever packaging\tools.psd1 lists --
# straight into it when there is one, a menu when there are several. A ZIP
# built for one tool has that tool's name here, written in by
# build.ps1 -Task Package -Tool <name>, which looks for this exact line.
$Tool       = ''

# Where the tools come from. $Ref is a branch, a tag or a commit. A branch
# means every push reaches everyone the next time they run this -- convenient,
# and exactly as trustworthy as everyone who can push to it. A tag or a
# commit pins it.
$Repository = 'GBJ-ICT/office365_tools'
$Ref        = 'master'

$ToolList   = 'packaging\tools.psd1'
$Reports    = 'Reports'

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

        $hasList   = Test-Path -LiteralPath (Join-Path $candidate $ToolList)
        $hasModule = Test-Path -LiteralPath (Join-Path $candidate 'src\Office365Tools\Office365Tools.psd1')

        if ($hasList -and $hasModule) { return $candidate }
    }

    return $null
}

# Fetches the repository as GitHub's ZIP of $Ref and unpacks it into the
# user's AppData, one folder per ref. Fetched fresh every run -- it is a few
# hundred KB -- so a fix reaches people without anyone sending anything. The
# previous copy is kept until the new one is in place, and used when GitHub
# cannot be reached.
#
# One folder per ref, not one for everything: two launchers pinned to
# different versions would otherwise replace each other's copy on every run,
# and the one that ran second would leave the other nothing to fall back on.
function Get-RemoteCopy {
    $url    = "https://github.com/$Repository/archive/$Ref.zip"
    $source = "$Repository@$Ref"
    $key    = $Ref -replace '[^A-Za-z0-9._-]', '_'

    # For trying a build before it is pushed: a path to a ZIP laid out the way
    # GitHub lays them out, or another URL. Kept apart from every real ref.
    if ($env:OFFICE365TOOLS_ARCHIVE) {
        $url = $env:OFFICE365TOOLS_ARCHIVE
        $source = $url

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($url))
        $key = 'custom-' + ([System.BitConverter]::ToString($hash, 0, 4) -replace '-', '').ToLower()
    }

    $cache   = Join-Path $env:LOCALAPPDATA 'office365_tools'
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
        if ($top.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $top[0].FullName $ToolList))) {
            throw "what was downloaded does not contain $ToolList"
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
            (Test-Path -LiteralPath (Join-Path $current $ToolList))

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

# The list is read as data -- the way Import-PowerShellDataFile reads a .psd1,
# which a Windows PowerShell started from PowerShell 7 can fail to find. Plain
# values only; anything that would have to run to produce a value is refused.
function Read-ToolList {
    param(
        [string]$Path
    )

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "$ToolList does not parse: $($parseErrors[0].Message)"
    }

    $table = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if (-not $table) {
        throw "$ToolList holds no list of tools"
    }

    $tools = @($table.SafeGetValue().Tools | Where-Object { $_ })

    foreach ($entry in $tools) {
        foreach ($field in 'Name', 'Title', 'Entry', 'Settings') {
            if (-not $entry[$field]) {
                throw "a tool in $ToolList has no $field"
            }
        }
    }

    return $tools
}

function Select-Tool {
    param(
        [object[]]$Tools
    )

    if ($Tool) {
        foreach ($entry in $Tools) {
            if ($entry.Name -eq $Tool) { return $entry }
        }

        Write-Problem -Title "This launcher runs '$Tool', and the version it found does not have that." -Detail @(
            "Tools it does have: $(($Tools | ForEach-Object { $_.Name }) -join ', ')",
            '',
            'Show this window to whoever sent you this file.')
        exit $SETUP_PROBLEM
    }

    if ($Tools.Count -eq 0) {
        Write-Problem -Title "$ToolList lists no tools, so there is nothing to run." -Detail @(
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
        $answer = (Read-Host '  Number [1]').Trim()
        if (-not $answer) { $answer = '1' }
        $choice = 0
        [void][int]::TryParse($answer, [ref]$choice)
    }

    return $Tools[$choice - 1]
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

    $chosen = Select-Tool -Tools (Read-ToolList -Path (Join-Path $root $ToolList))

    # Read with a pattern rather than Import-PowerShellDataFile, for the same
    # reason the tool list is.
    $manifest = Join-Path $root 'src\Office365Tools\Office365Tools.psd1'
    $version = ''
    $line = Select-String -LiteralPath $manifest -Pattern "ModuleVersion\s*=\s*.([0-9.]+)" | Select-Object -First 1
    if ($line) { $version = $line.Matches[0].Groups[1].Value }

    try { $Host.UI.RawUI.WindowTitle = $chosen.Title } catch { Write-Verbose $_ }

    Write-Host ''
    Write-Host "  $($chosen.Title) $version" -ForegroundColor Cyan
    Write-Host "  from $root" -ForegroundColor DarkGray

    $entryPath = Join-Path $root $chosen.Entry

    # The settings live beside this file, where the person running it can find
    # them, and survive the code being fetched afresh. The first run puts the
    # template there.
    $settingsName = Split-Path -Leaf $chosen.Settings
    $settingsPath = Join-Path $here $settingsName
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        Copy-Item -LiteralPath (Join-Path $root $chosen.Settings) -Destination $settingsPath
        Write-Host ''
        Write-Host "  Created $settingsName beside $(Split-Path -Leaf $launcher). Your settings go in there;" -ForegroundColor Cyan
        Write-Host '  open it in Notepad to fill them in. Until then, you are asked.' -ForegroundColor Cyan
    }

    $arguments = @{
        SettingsPath = $settingsPath
        ReportFolder = (Join-Path $here $Reports)
    }

    if ($env:LAUNCHER_DROPPED) {
        $arguments.Folder = $env:LAUNCHER_DROPPED
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
