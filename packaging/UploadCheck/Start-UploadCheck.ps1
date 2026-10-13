<#
.SYNOPSIS
    Reads upload-check.xml, checks that everything needed is present, asks for
    what is missing, and runs the upload checker.
.DESCRIPTION
    The upload checker's half of the double-click entry point. The launcher
    (packaging/Office365-Tools.cmd, handed out as Check-Upload.cmd) finds or
    fetches a copy of this repository and hands over to this script;
    everything about the upload check itself -- its settings, its questions,
    what it needs installed -- is decided here.

    This file is the one part of the checker that must run under **Windows
    PowerShell 5.1**, which is on every Windows machine. That is the whole
    point: it can report that PowerShell 7 is missing, which a script written
    for PowerShell 7 cannot. Keep it free of 7-only syntax -- no ternaries,
    no ??, no -Parallel.

    Note that it asks PowerShell 7 about PnP.PowerShell rather than looking
    itself: the two PowerShells have separate module directories, so what 5.1
    can see says nothing about what 7 can load.
.PARAMETER Folder
    Folder to check, overriding the one in upload-check.xml. This is what a
    folder dragged onto the launcher arrives as.
.PARAMETER SettingsPath
    Path to the settings file. Defaults to upload-check.xml beside this script.
    The launcher passes the one beside itself, which is the one people edit.
.PARAMETER ReportFolder
    Folder the reports go into, each run in its own subfolder. The launcher
    passes the one beside itself: a copy fetched from GitHub lives in the
    user's AppData and is replaced on every run, which is no place for
    something a person is meant to open. Defaults to the repository's out/.
.PARAMETER NoPrompt
    Never ask anything: use the settings file as it stands and fail if
    something needed is missing. For scheduled runs.
.EXAMPLE
    .\Start-UploadCheck.ps1

    Asks for the folder, asks what to do, and runs it.
.EXAMPLE
    .\Start-UploadCheck.ps1 -Folder C:\ToUpload

    What dragging a folder onto the launcher does.
.EXAMPLE
    .\Start-UploadCheck.ps1 -Folder C:\ToUpload -NoPrompt

    Unattended. Exit code 1 means something needs fixing, 2 a setup problem.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Folder,

    [Parameter()]
    [string]$SettingsPath,

    [Parameter()]
    [string]$ReportFolder,

    [Parameter()]
    [string]$Language,

    [Parameter()]
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'

# Everything below reports rather than throws: a stack trace in a window that
# closes is not a diagnosis. Exit codes: 0 clean, 1 findings, 2 setup problem.
$SETUP_PROBLEM = 2

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

function Read-YesNo {
    param(
        [string]$Question,
        [bool]$Default = $true
    )

    $suffix = Get-LauncherString 'Prompt.YesNo.DefaultYes'
    if (-not $Default) { $suffix = Get-LauncherString 'Prompt.YesNo.DefaultNo' }

    while ($true) {
        Write-Host ''
        $answer = "$(Read-Host "  $Question $suffix")".Trim().ToLower()

        if (-not $answer) { return $Default }
        if ('y', 'yes', 'j', 'ja' -contains $answer) { return $true }
        if ('n', 'no', 'nein' -contains $answer) { return $false }
    }
}

$script:DpiAware = $false
$script:UiScale = 1.0

function Enable-HighDpi {
    <#
        Windows scales the windows of a process that has not said it
        understands DPI, and it scales them as bitmaps -- which is why every
        dialog comes out fuzzy on a modern laptop screen. Saying so once, here,
        makes the folder dialog and the ones below draw at the real resolution.

        It has to happen before the process owns its first window, and it only
        counts once. $UiScale is what is left to do by hand: this process is
        now told the true pixel count, so a size written as 620 has to become
        930 at 150%.
    #>
    if ($script:DpiAware) { return }
    $script:DpiAware = $true

    try {
        Add-Type -Namespace UploadCheck -Name Display -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
'@ -ErrorAction Stop

        [UploadCheck.Display]::SetProcessDPIAware() | Out-Null
    }
    catch {
        # Windows too old to have it, a host that has already drawn something,
        # or a machine where compiling is not allowed. Fuzzy is not worth
        # abandoning the run over.
        Write-Verbose "Could not ask for DPI awareness: $($_.Exception.Message)"
    }

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $graphics = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        $script:UiScale = $graphics.DpiX / 96.0
        $graphics.Dispose()
    }
    catch {
        Write-Verbose "Could not read the screen DPI: $($_.Exception.Message)"
    }
}

function ConvertTo-Pixel {
    param(
        [int]$Length
    )

    return [int][Math]::Round($Length * $script:UiScale)
}

function Read-Address {
    <#
        A window with a box to paste into, because the answer is a hundred
        characters of URL and a console is a poor place to put one: Ctrl+V does
        nothing there, the line wraps into something unreadable, and a typo is
        invisible until the run fails.

        The box starts out holding whatever is on the clipboard when that looks
        like a SharePoint address -- which it usually is, since copying it is
        the step before this one.

        Returns '' for cancelled, and falls back to the console where there is
        no desktop to draw on.
    #>
    param(
        [string]$Title = 'Where in SharePoint did the files go?'
    )

    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()

    if ($apartment -eq [System.Threading.ApartmentState]::STA) {
        try {
            Enable-HighDpi

            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            [System.Windows.Forms.Application]::EnableVisualStyles()

            $form = New-Object System.Windows.Forms.Form
            $form.Text = 'Upload checker'
            $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
            $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            $form.MaximizeBox = $false
            $form.MinimizeBox = $false
            $form.TopMost = $true
            $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
            $form.ClientSize = New-Object System.Drawing.Size((ConvertTo-Pixel 640), (ConvertTo-Pixel 200))

            $heading = New-Object System.Windows.Forms.Label
            $heading.Text = $Title
            $heading.Font = New-Object System.Drawing.Font('Segoe UI', 12)
            $heading.AutoSize = $true
            $heading.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 16), (ConvertTo-Pixel 16))

            $explain = New-Object System.Windows.Forms.Label
            $explain.Text = "Open that folder in SharePoint, copy the address out of your browser's" + [Environment]::NewLine +
            'address bar, and paste it here. Not the "Copy link" button: that link' + [Environment]::NewLine +
            'names no folder.'
            $explain.AutoSize = $true
            $explain.ForeColor = [System.Drawing.SystemColors]::GrayText
            $explain.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 18), (ConvertTo-Pixel 48))

            $box = New-Object System.Windows.Forms.TextBox
            $box.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 18), (ConvertTo-Pixel 110))
            $box.Size = New-Object System.Drawing.Size((ConvertTo-Pixel 604), (ConvertTo-Pixel 24))

            $problem = New-Object System.Windows.Forms.Label
            $problem.AutoSize = $true
            $problem.ForeColor = [System.Drawing.Color]::Firebrick
            $problem.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 18), (ConvertTo-Pixel 142))

            $ok = New-Object System.Windows.Forms.Button
            $ok.Text = 'OK'
            $ok.Size = New-Object System.Drawing.Size((ConvertTo-Pixel 90), (ConvertTo-Pixel 28))
            $ok.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 428), (ConvertTo-Pixel 160))

            $cancel = New-Object System.Windows.Forms.Button
            $cancel.Text = 'Cancel'
            $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $cancel.Size = New-Object System.Drawing.Size((ConvertTo-Pixel 90), (ConvertTo-Pixel 28))
            $cancel.Location = New-Object System.Drawing.Point((ConvertTo-Pixel 532), (ConvertTo-Pixel 160))

            # Closing over $box and $problem: the button decides whether the
            # window may close, so an address that obviously cannot work is
            # said so here rather than three minutes later after a sign-in.
            # This is a courtesy, not the rule -- the checker is what really
            # reads the address, and it knows far more cases than these two.
            $ok.Add_Click({
                    $value = $box.Text.Trim().Trim('"')

                    if (-not $value) {
                        $problem.Text = 'Paste the address first. Cancel stops the run; nothing is checked and nothing is changed.'
                        return
                    }

                    if ($value -notmatch '^https?://') {
                        $problem.Text = 'That does not look like a web address. It has to start with https://'
                        return
                    }

                    if ($value -match '^https?://[^/]+/:[a-z]:/') {
                        $problem.Text = 'That is a sharing link, and it names no folder. Use the browser address bar.'
                        return
                    }

                    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $form.Close()
                })

            $form.Controls.AddRange(@($heading, $explain, $box, $problem, $ok, $cancel))
            $form.AcceptButton = $ok
            $form.CancelButton = $cancel

            # Whatever they copied a moment ago is almost certainly the answer.
            try {
                $clip = [System.Windows.Forms.Clipboard]::GetText()
                if ($clip -and $clip.Trim() -match '^https?://\S+$') {
                    $box.Text = $clip.Trim()
                    $box.SelectAll()
                }
            }
            catch {
                Write-Verbose "Could not read the clipboard: $($_.Exception.Message)"
            }

            $form.Add_Shown({ $form.Activate(); $box.Focus() | Out-Null })

            $result = $form.ShowDialog()
            $value = $box.Text.Trim().Trim('"')
            $form.Dispose()

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                return $value
            }

            return ''
        }
        catch {
            Write-Host "  (Could not open a window: $($_.Exception.Message))" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host '  Copy the address out of your browser and paste it here.' -ForegroundColor Gray
    Write-Host '  Right-click pastes into this window.' -ForegroundColor Gray
    return (Read-Host '  Address')
}

function Select-Folder {
    param(
        [string]$Description
    )

    # Windows PowerShell runs STA, which is what the folder dialog needs. If
    # this ever runs somewhere else, fall back to typing rather than crashing.
    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()

    if ($apartment -eq [System.Threading.ApartmentState]::STA) {
        try {
            Enable-HighDpi

            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            [System.Windows.Forms.Application]::EnableVisualStyles()

            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = $Description
            $dialog.ShowNewFolderButton = $false

            # Without an owner the dialog can open behind the console window,
            # which looks exactly like nothing happening.
            $owner = New-Object System.Windows.Forms.Form
            $owner.TopMost = $true

            $result = $dialog.ShowDialog($owner)
            $owner.Dispose()

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dialog.SelectedPath
            }

            return ''
        }
        catch {
            Write-Host "  (Could not open a folder window: $($_.Exception.Message))" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host "  $Description" -ForegroundColor Cyan
    return (Read-Host '  Folder')
}

# -- Locate the pieces -------------------------------------------------------
# This file lives in packaging/UploadCheck/ wherever it runs -- the
# repository, or a release fetched from GitHub, which keeps the same layout
# -- so the rest is always two levels up.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$checker = Join-Path $root 'scripts\Test-Upload.ps1'

$module = Join-Path $root 'src\Office365Tools\Office365Tools.psd1'

if (-not $SettingsPath) {
    $SettingsPath = Join-Path $PSScriptRoot 'upload-check.xml'
}

$shared = Join-Path $root 'src\Office365Tools\Private\Shared'
$resources = @(
    (Join-Path $root 'src\Office365Tools\Resources'),
    (Join-Path $PSScriptRoot 'Resources'))

# Nothing can be said in a language until the shared files and the English
# texts are there, so this one message is English only.
$needed = @('Language.ps1', 'ClientId.ps1') | ForEach-Object { Join-Path $shared $_ }
$needed += $resources | ForEach-Object { Join-Path $_ 'en\Strings.psd1' }
$absent = @($needed | Where-Object { -not (Test-Path -LiteralPath $_) })

if ($absent.Count -gt 0) {
    $names = $absent | ForEach-Object { $_.Substring($root.Length).TrimStart('\') }
    Write-Problem -Title 'Part of the upload checker is missing.' -Detail @(
        "Not found: $($names -join ', ')",
        '',
        'If you were sent a ZIP with everything in it, it was probably opened',
        'rather than extracted: extract the whole folder and start it from',
        'there. Otherwise just start it again; it fetches a fresh copy.')
    exit $SETUP_PROBLEM
}

# The language and application ID lookups are shared with the module: the very
# same files, so the two cannot drift. They need no module and no PowerShell 7.
. (Join-Path $shared 'Language.ps1')
. (Join-Path $shared 'ClientId.ps1')

function Get-LauncherString {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    return (Format-O365String -Table $script:Strings -Key $Key -FormatArguments $FormatArguments)
}

# A text of several lines, for Write-Problem: one line per line of the text.
function Get-LauncherLines {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    $text = Format-O365String -Table $script:Strings -Key $Key -FormatArguments $FormatArguments

    return @($text -split "`r?`n")
}

# One language per run, chosen the same way for every tool: -Language, then the
# environment, the language saved for the user, and the Windows display
# language. The texts live in Resources\, one table per language, with English
# underneath. Throws for a language it does not know.
function Select-LauncherLanguage {
    param(
        [string]$Requested
    )

    $script:Chosen = Resolve-O365Language -Language $Requested
    $script:Strings = Import-O365StringTable -Language $script:Chosen.Language -Path $resources
}

$badLanguage = $null
try {
    Select-LauncherLanguage -Requested $Language
}
catch {
    $badLanguage = $Language
    Select-LauncherLanguage -Requested ''
}

# German umlauts need a console that decodes UTF-8. The .cmd launcher already
# switched the code page; this covers a start from anywhere else.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Verbose $_ }

if ($badLanguage) {
    Write-Problem -Title (Get-LauncherString 'Settings.Language.Title') -Detail (Get-LauncherLines 'Settings.Language.Argument' $badLanguage)
    exit $SETUP_PROBLEM
}

$missing = @()
if (-not (Test-Path -LiteralPath $checker)) { $missing += 'scripts\Test-Upload.ps1' }
if (-not (Test-Path -LiteralPath $module)) { $missing += 'src\Office365Tools\' }
if (-not (Test-Path -LiteralPath $SettingsPath)) { $missing += (Split-Path -Leaf $SettingsPath) }

if ($missing.Count -gt 0) {
    Write-Problem -Title (Get-LauncherString 'Setup.Missing.Title') -Detail (Get-LauncherLines 'Setup.Missing.Body' ($missing -join ', '))
    exit $SETUP_PROBLEM
}

# -- Read the settings -------------------------------------------------------
$known = @(
    'Folder', 'Mode', 'Language', 'Destination', 'ClientId', 'Subfolders',
    'IgnoreDates', 'CompareSize', 'TargetPathPrefix', 'LargeFileMb',
    'PathLimit', 'WarnAt', 'BlockedExtension', 'IncludeRisky')

# Settings that used to exist and no longer matter. Accepted and ignored, with
# a word about it: refusing to run over a line that was correct last week is a
# poor way to announce that a feature went away.
$retired = @('OpenReport')

# Settings that used to exist and did matter. Ignoring one of these silently
# would mean checking a different folder than the file asks for, so they stop
# the run instead -- and say what replaced them.
$replaced = @('SiteUrl', 'Library', 'RemoteFolder')

# A SharePoint address is full of & -- and a bare & is not legal XML, so the
# file someone has just filled in correctly, by pasting exactly what they were
# asked to paste, would fail to parse. Escaping them here repairs the one
# mistake this settings file invites. An & that is already part of an entity
# (&amp;, &#39;) is left alone, so a file that was written properly is
# unaffected.
try {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsPath
    $text = [regex]::Replace($text, '&(?!(?:[A-Za-z][A-Za-z0-9]*|#[0-9]+|#[xX][0-9A-Fa-f]+);)', '&amp;')

    $document = New-Object System.Xml.XmlDocument
    $document.LoadXml($text)
}
catch {
    Write-Problem -Title (Get-LauncherString 'Settings.Unreadable.Title' (Split-Path -Leaf $SettingsPath)) `
        -Detail (Get-LauncherLines 'Settings.Unreadable.Body' $_.Exception.Message)
    exit $SETUP_PROBLEM
}

$rootNode = $document.DocumentElement

if (-not $rootNode -or $rootNode.Name -ne 'UploadCheck') {
    Write-Problem -Title (Get-LauncherString 'Settings.WrongFile.Title' (Split-Path -Leaf $SettingsPath)) `
        -Detail (Get-LauncherLines 'Settings.WrongFile.Body')
    exit $SETUP_PROBLEM
}

# Reading the child nodes, rather than asking for properties by name, means a
# typo shows up as an unknown setting instead of being silently ignored.
$settings = @{}
$unknown = @()
$obsolete = @()

foreach ($node in $rootNode.ChildNodes) {
    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

    if ($retired -contains $node.Name) {
        Write-Host ('  ' + (Get-LauncherString 'Settings.Retired' $node.Name (Split-Path -Leaf $SettingsPath))) -ForegroundColor DarkGray
        continue
    }

    if ($replaced -contains $node.Name) {
        $obsolete += $node.Name
        continue
    }

    if ($known -notcontains $node.Name) {
        $unknown += $node.Name
        continue
    }

    $settings[$node.Name] = $node.InnerText.Trim()
}

if ($obsolete.Count -gt 0) {
    Write-Problem -Title (Get-LauncherString 'Settings.Obsolete.Title') `
        -Detail (Get-LauncherLines 'Settings.Obsolete.Body' ($obsolete -join ', '))
    exit $SETUP_PROBLEM
}

if ($unknown.Count -gt 0) {
    Write-Problem -Title (Get-LauncherString 'Settings.Unknown.Title') `
        -Detail (Get-LauncherLines 'Settings.Unknown.Body' ($unknown -join ', ') ($known -join ', '))
    exit $SETUP_PROBLEM
}

function Get-Setting {
    param(
        [string]$Name
    )

    if (-not $settings.ContainsKey($Name)) { return '' }

    $value = $settings[$Name]

    # "ask" is how the settings file says "prompt me every time".
    if ($value.ToLower() -eq 'ask') { return '' }

    return $value
}

function Read-Number {
    param(
        [string]$Name
    )

    $raw = Get-Setting -Name $Name
    if ($raw -eq '') { return $null }

    $value = 0
    if (-not [int]::TryParse($raw, [ref]$value)) {
        Write-Problem -Title (Get-LauncherString 'Settings.NotNumber.Title' $Name) `
            -Detail (Get-LauncherLines 'Settings.CurrentValue' $raw)
        exit $SETUP_PROBLEM
    }

    return $value
}

function Read-Boolean {
    param(
        [string]$Name,
        [bool]$Default
    )

    $raw = Get-Setting -Name $Name
    if ($raw -eq '') { return $Default }

    if ('true', 'yes', '1' -contains $raw.ToLower()) { return $true }
    if ('false', 'no', '0' -contains $raw.ToLower()) { return $false }

    Write-Problem -Title (Get-LauncherString 'Settings.NotBoolean.Title' $Name) `
        -Detail (Get-LauncherLines 'Settings.CurrentValue' $raw)
    exit $SETUP_PROBLEM
}

# -- Language, once the settings are read ------------------------------------
# <Language> in this file can name one for the file. -Language still wins, as it
# does everywhere.
$fromFile = Get-Setting -Name 'Language'
if (-not $Language -and $fromFile) {
    try {
        Select-LauncherLanguage -Requested $fromFile
    }
    catch {
        Write-Problem -Title (Get-LauncherString 'Settings.Language.Title') -Detail (Get-LauncherLines 'Settings.Language.File' $fromFile)
        exit $SETUP_PROBLEM
    }
}
# -- Source: which folder ----------------------------------------------------
if (-not $Folder) {
    $Folder = Get-Setting -Name 'Folder'
}

if (-not $Folder -and -not $NoPrompt) {
    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'Upload.Heading')) -ForegroundColor Cyan
    Write-Host ('  ' + (Get-LauncherString 'Upload.Folder.Intro')) -ForegroundColor Gray
    $Folder = Select-Folder -Description (Get-LauncherString 'Upload.Folder.Question')
}

# A path pasted from Explorer arrives wrapped in quotes, and a trailing
# backslash confuses the command line further down.
$Folder = $Folder.Trim().Trim('"').TrimEnd('\')

if (-not $Folder) {
    Write-Problem -Title (Get-LauncherString 'Upload.Folder.None.Title') -Detail (Get-LauncherLines 'Upload.Folder.None.Body')
    exit $SETUP_PROBLEM
}

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Problem -Title (Get-LauncherString 'Upload.Folder.Missing.Title') -Detail (Get-LauncherLines 'Upload.Folder.Missing.Body' $Folder)
    exit $SETUP_PROBLEM
}

Write-Host ''
Write-Host ('  ' + (Get-LauncherString 'Upload.Folder.Shown' $Folder)) -ForegroundColor Green

# -- What to do --------------------------------------------------------------
$mode = Get-Setting -Name 'Mode'

# How to check the upload later depends on whether this run asked.
if ($mode) {
    $nextStep = Get-LauncherString 'Upload.NextStep.FromFile'
}
else {
    $nextStep = Get-LauncherString 'Upload.NextStep.FromMenu'
}

if (-not $mode -and -not $NoPrompt) {
    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'Upload.Menu.Title')) -ForegroundColor Cyan
    Write-Host (Get-LauncherString 'Upload.Menu.Option1')
    Write-Host (Get-LauncherString 'Upload.Menu.Option2')
    Write-Host (Get-LauncherString 'Upload.Menu.Option3')

    $answer = ''
    while ('1', '2', '3' -notcontains $answer) {
        Write-Host ''
        $answer = "$(Read-Host ('  ' + (Get-LauncherString 'Upload.Menu.Prompt')))".Trim()
        if (-not $answer) { $answer = '1' }
    }

    $mode = @{ '1' = 'PreFlight'; '2' = 'Verify'; '3' = 'Both' }[$answer]
}

if (-not $mode) { $mode = 'PreFlight' }

if ('PreFlight', 'Verify', 'Both' -notcontains $mode) {
    Write-Problem -Title (Get-LauncherString 'Settings.Mode.Title') `
        -Detail (Get-LauncherLines 'Settings.CurrentValue' $mode)
    exit $SETUP_PROBLEM
}

$needsSignIn = ($mode -ne 'PreFlight')

# Read here rather than inside the sign-in branch: a pre-flight check wants the
# address too. It says where the files are headed, which is what the path
# length check measures against -- and reading it costs no connection.
$destination = Get-Setting -Name 'Destination'

# -- Find PowerShell 7 -------------------------------------------------------
# This script runs under whatever PowerShell the .cmd could find, which on a
# fresh machine is Windows PowerShell 5.1. The checker itself needs 7.
$pwsh = $null

$onPath = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue
if ($onPath) {
    $pwsh = $onPath.Source
}

if (-not $pwsh) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'))

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $pwsh = $candidate
            break
        }
    }
}

if (-not $pwsh) {
    Write-Problem -Title (Get-LauncherString 'Upload.Pwsh.Missing.Title') -Detail (Get-LauncherLines 'Upload.Pwsh.Missing.Body')
    exit $SETUP_PROBLEM
}

# -- Signing in needs PnP.PowerShell -----------------------------------------
# Ask PowerShell 7, do not look here: 5.1 and 7 read different module folders,
# so what this process can see is not what the checker will be able to load.
if ($needsSignIn) {
    # The settings file first; failing that, where an earlier setup left it: the
    # environment variable the old scripts used, then the default profile.
    $clientInfo = Resolve-O365ClientId -Configured (Get-Setting -Name 'ClientId') `
        -ProfilePath (Join-Path $root 'config\profiles.json')
    $clientId = $null
    if ($clientInfo) { $clientId = $clientInfo.ClientId }

    if (-not $destination -and -not $NoPrompt) {
        $destination = (Read-Address).Trim()

        if ($destination) {
            Write-Host ''
            Write-Host ('  ' + (Get-LauncherString 'Upload.Destination.Shown' $destination)) -ForegroundColor Gray
        }
    }

    if (-not $destination -or -not $clientId) {
        $detail = @()
        $detail += Get-LauncherLines 'Upload.SignIn.Missing.Needed'
        if (-not $destination) { $detail += Get-LauncherLines 'Upload.SignIn.Missing.Destination' }
        if (-not $clientId) { $detail += Get-LauncherLines 'Upload.SignIn.Missing.ClientId' }
        $detail += Get-LauncherLines 'Upload.SignIn.Missing.Footer'

        Write-Problem -Title (Get-LauncherString 'Upload.SignIn.Missing.Title') -Detail $detail
        exit $SETUP_PROBLEM
    }

    # Said out loud, so nobody has to wonder which of the three was used.
    $from = Get-LauncherString 'Upload.ClientId.From.Settings'
    if ($clientInfo.Source -eq 'Environment') { $from = Get-LauncherString 'Upload.ClientId.From.Environment' }
    if ($clientInfo.Source -eq 'Profile') { $from = Get-LauncherString 'Upload.ClientId.From.Profile' }

    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'Upload.ClientId.Found' $from)) -ForegroundColor Gray

    $installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

    if ($installed -ne 'yes') {
        Write-Host ''
        Write-Host ('  ' + (Get-LauncherString 'Upload.Pnp.Title')) -ForegroundColor Yellow
        foreach ($line in (Get-LauncherLines 'Upload.Pnp.Body')) {
            Write-Host "  $line" -ForegroundColor Gray
        }

        $install = $false
        if (-not $NoPrompt) {
            $install = Read-YesNo -Question (Get-LauncherString 'Upload.Pnp.Question') -Default $true
        }

        if (-not $install) {
            Write-Problem -Title (Get-LauncherString 'Upload.Pnp.Declined.Title') -Detail (Get-LauncherLines 'Upload.Pnp.Declined.Body')
            exit $SETUP_PROBLEM
        }

        Write-Host ''
        Write-Host ('  ' + (Get-LauncherString 'Upload.Pnp.Installing')) -ForegroundColor Gray

        & $pwsh -NoProfile -Command "Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber"

        $installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

        if ($installed -ne 'yes') {
            Write-Problem -Title (Get-LauncherString 'Upload.Pnp.Failed.Title') -Detail (Get-LauncherLines 'Upload.Pnp.Failed.Body')
            exit $SETUP_PROBLEM
        }

        Write-Host ('  ' + (Get-LauncherString 'Upload.Pnp.Installed')) -ForegroundColor Green
    }
}

# -- Build the command -------------------------------------------------------
$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', $checker
    '-LocalPath', $Folder
    '-Mode', $mode
    '-NextStep', $nextStep)

if ($ReportFolder) {
    $arguments += @('-OutputPath', (Join-Path $ReportFolder "upload-check-$(Get-Date -Format 'yyyyMMdd_HHmmss')"))
}

# Both phases: which files count is the same question before and after.
if (-not (Read-Boolean -Name 'Subfolders' -Default $true)) {
    $arguments += '-TopLevelOnly'
}

if (-not $NoPrompt) {
    # Lets the checker ask for the library, which it can only do once it is
    # connected and knows which libraries exist.
    $arguments += '-Interactive'
}

# One argument for the site, the library and the folder together. The checker
# is what pulls the three apart -- it runs on PowerShell 7, where the module
# that knows how to read an address lives.
if ($destination) {
    $arguments += @('-Destination', $destination)
}

if ($needsSignIn) {
    $arguments += @('-ClientId', $clientId)

    if (Read-Boolean -Name 'CompareSize' -Default $false) {
        $arguments += '-CompareSize'
    }

    if (-not (Read-Boolean -Name 'IgnoreDates' -Default $true)) {
        $arguments += '-CompareDate'
    }
}

$prefix = Get-Setting -Name 'TargetPathPrefix'
if ($prefix) {
    $arguments += @('-TargetPathPrefix', $prefix)
}

$largeFileMb = Read-Number -Name 'LargeFileMb'
if ($null -ne $largeFileMb) {
    $arguments += @('-LargeFileMb', $largeFileMb)
}

$pathLimit = Read-Number -Name 'PathLimit'
if ($null -ne $pathLimit) {
    $arguments += @('-PathLimit', $pathLimit)
}

$warnAt = Read-Number -Name 'WarnAt'
if ($null -ne $warnAt) {
    $arguments += @('-WarnAt', $warnAt)
}

$blocked = Get-Setting -Name 'BlockedExtension'
if ($blocked) {
    # "-BlockedExtension .exe,.js" is the only array form that survives
    # pwsh -File, and the checker splits it back apart.
    $cleaned = ($blocked -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ','
    $arguments += @('-BlockedExtension', $cleaned)
}

if (Read-Boolean -Name 'IncludeRisky' -Default $false) {
    $arguments += '-IncludeRisky'
}

# Someone who double-clicked wants a page to look at even when the answer is
# "nothing to fix" -- an empty out folder reads as a run that failed silently.
$arguments += '-AlwaysReport'

# -- Run it ------------------------------------------------------------------
& $pwsh $arguments

exit $LASTEXITCODE
