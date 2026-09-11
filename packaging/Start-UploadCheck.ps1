<#
.SYNOPSIS
    Reads upload-check.xml, checks that everything needed is present, asks for
    what is missing, and runs the upload checker.
.DESCRIPTION
    The double-click entry point's brain. Check-Upload.cmd is deliberately a
    dozen lines; everything that could go wrong is diagnosed here, where a
    message can be a sentence instead of a batch-file echo.

    This file is the one part of the package that must run under **Windows
    PowerShell 5.1**, which is on every Windows machine. That is the whole
    point: it can report that PowerShell 7 is missing, which a script written
    for PowerShell 7 cannot. Keep it free of 7-only syntax -- no ternaries,
    no ??, no -Parallel.

    Note that it asks PowerShell 7 about PnP.PowerShell rather than looking
    itself: the two PowerShells have separate module directories, so what 5.1
    can see says nothing about what 7 can load.
.PARAMETER Folder
    Folder to check, overriding the one in upload-check.xml. This is what a
    folder dragged onto Check-Upload.cmd arrives as.
.PARAMETER SettingsPath
    Path to the settings file. Defaults to upload-check.xml beside this script.
.PARAMETER NoPrompt
    Never ask anything: use the settings file as it stands and fail if
    something needed is missing. For scheduled runs.
.EXAMPLE
    .\Start-UploadCheck.ps1

    Asks for the folder, asks what to do, and runs it.
.EXAMPLE
    .\Start-UploadCheck.ps1 -Folder C:\ToUpload

    What dragging a folder onto Check-Upload.cmd does.
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

    $suffix = '[Y/n]'
    if (-not $Default) { $suffix = '[y/N]' }

    while ($true) {
        Write-Host ''
        $answer = (Read-Host "  $Question $suffix").Trim().ToLower()

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
# Beside this script is the packaged layout; one level up is the repository,
# where this file lives in packaging/ and the rest does not.
$root = $PSScriptRoot
$checker = Join-Path $root 'scripts\Test-Upload.ps1'

if (-not (Test-Path -LiteralPath $checker)) {
    $parent = Split-Path -Parent $root
    if ($parent) {
        $candidate = Join-Path $parent 'scripts\Test-Upload.ps1'
        if (Test-Path -LiteralPath $candidate) {
            $root = $parent
            $checker = $candidate
        }
    }
}

$module = Join-Path $root 'src\Office365Tools\Office365Tools.psd1'

if (-not $SettingsPath) {
    $SettingsPath = Join-Path $PSScriptRoot 'upload-check.xml'
}

$missing = @()
if (-not (Test-Path -LiteralPath $checker)) { $missing += 'scripts\Test-Upload.ps1' }
if (-not (Test-Path -LiteralPath $module)) { $missing += 'src\Office365Tools\' }
if (-not (Test-Path -LiteralPath $SettingsPath)) { $missing += (Split-Path -Leaf $SettingsPath) }

if ($missing.Count -gt 0) {
    Write-Problem -Title 'Part of the upload checker is missing.' -Detail @(
        "Not found: $($missing -join ', ')",
        '',
        'This usually means the ZIP was opened rather than extracted, or only',
        'Check-Upload.cmd was copied out of it. Extract the whole folder, keep',
        'the files together, and run Check-Upload.cmd from there.')
    exit $SETUP_PROBLEM
}

# -- Read the settings -------------------------------------------------------
$known = @(
    'Folder', 'Mode', 'Destination', 'ClientId',
    'TargetPathPrefix', 'LargeFileMb', 'PathLimit', 'WarnAt',
    'BlockedExtension', 'CompareSize', 'IncludeRisky')

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
    Write-Problem -Title "$(Split-Path -Leaf $SettingsPath) could not be read." -Detail @(
        $_.Exception.Message,
        '',
        'Something in the file is malformed - usually a missing angle bracket,',
        'or a setting whose closing tag does not match its opening tag.',
        'Open it in Notepad and compare it with the copy in the ZIP.')
    exit $SETUP_PROBLEM
}

$rootNode = $document.DocumentElement

if (-not $rootNode -or $rootNode.Name -ne 'UploadCheck') {
    Write-Problem -Title "$(Split-Path -Leaf $SettingsPath) is not an upload checker settings file." -Detail @(
        'It has to start with <UploadCheck> and end with </UploadCheck>.')
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
        Write-Host "  $($node.Name) in $(Split-Path -Leaf $SettingsPath) does nothing any more; you can delete that line." -ForegroundColor DarkGray
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
    Write-Problem -Title 'This settings file names the target the old way.' -Detail @(
        "No longer used: $($obsolete -join ', ')",
        '',
        'All three have been replaced by one setting, which you fill in by',
        'copying rather than by typing:',
        '',
        '    <Destination>  open the folder in SharePoint, copy the whole',
        '                   address out of your browser, paste it in',
        '',
        'The address says the site, the library and the folder together, so',
        'they cannot disagree with each other -- and it carries the channel',
        'folder a Teams site hides, which is what typing gets wrong.',
        '',
        'Delete those lines, add a <Destination> line, and run this again.',
        'The copy of upload-check.xml in the ZIP shows the shape of it.')
    exit $SETUP_PROBLEM
}

if ($unknown.Count -gt 0) {
    Write-Problem -Title 'There is a setting in the file that I do not recognise.' -Detail @(
        "Unknown: $($unknown -join ', ')",
        '',
        "Known settings: $($known -join ', ')",
        'Check the spelling - the names are case-sensitive.')
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
        Write-Problem -Title "The setting <$Name> has to be a whole number." -Detail @(
            "It currently says: $raw")
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

    Write-Problem -Title "The setting <$Name> has to be true or false." -Detail @(
        "It currently says: $raw")
    exit $SETUP_PROBLEM
}

# -- Source: which folder ----------------------------------------------------
if (-not $Folder) {
    $Folder = Get-Setting -Name 'Folder'
}

if (-not $Folder -and -not $NoPrompt) {
    Write-Host ''
    Write-Host '  Upload checker' -ForegroundColor Cyan
    Write-Host '  A window will open. Pick the folder you are uploading.' -ForegroundColor Gray
    $Folder = Select-Folder -Description 'Which folder are you uploading to SharePoint?'
}

# A path pasted from Explorer arrives wrapped in quotes, and a trailing
# backslash confuses the command line further down.
$Folder = $Folder.Trim().Trim('"').TrimEnd('\')

if (-not $Folder) {
    Write-Problem -Title 'No folder was chosen, so there is nothing to check.' -Detail @(
        'Run Check-Upload.cmd again and pick a folder, or drag a folder onto it.')
    exit $SETUP_PROBLEM
}

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Problem -Title 'That folder does not exist.' -Detail @(
        "Looked for: $Folder",
        '',
        'If you typed it, check for a typo. If you pasted it, make sure the',
        'whole path came along.')
    exit $SETUP_PROBLEM
}

Write-Host ''
Write-Host "  Folder:  $Folder" -ForegroundColor Green

# -- What to do --------------------------------------------------------------
$mode = Get-Setting -Name 'Mode'

if (-not $mode -and -not $NoPrompt) {
    Write-Host ''
    Write-Host '  What would you like to do?' -ForegroundColor Cyan
    Write-Host '    1) Check this folder before I upload it        (no sign-in)'
    Write-Host '    2) I uploaded it already - did everything arrive?  (sign-in)'
    Write-Host '    3) Both'

    $answer = ''
    while ('1', '2', '3' -notcontains $answer) {
        Write-Host ''
        $answer = (Read-Host '  Number [1]').Trim()
        if (-not $answer) { $answer = '1' }
    }

    $mode = @{ '1' = 'PreFlight'; '2' = 'Verify'; '3' = 'Both' }[$answer]
}

if (-not $mode) { $mode = 'PreFlight' }

if ('PreFlight', 'Verify', 'Both' -notcontains $mode) {
    Write-Problem -Title "The setting <Mode> has to be PreFlight, Verify, Both or ask." -Detail @(
        "It currently says: $mode")
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
    Write-Problem -Title 'PowerShell 7 is not installed on this computer.' -Detail @(
        'It is a free Microsoft download, and it is the only thing missing.',
        '',
        'Install it once: open the Start menu, type cmd, press Enter, and paste',
        '',
        '    winget install --id Microsoft.PowerShell',
        '',
        'or download it from https://aka.ms/powershell-release',
        'Then run Check-Upload.cmd again.')
    exit $SETUP_PROBLEM
}

# -- Signing in needs PnP.PowerShell -----------------------------------------
# Ask PowerShell 7, do not look here: 5.1 and 7 read different module folders,
# so what this process can see is not what the checker will be able to load.
if ($needsSignIn) {
    $clientId = Get-Setting -Name 'ClientId'

    if (-not $destination -and -not $NoPrompt) {
        $destination = (Read-Address).Trim()

        if ($destination) {
            Write-Host ''
            Write-Host "  Destination: $destination" -ForegroundColor Gray
        }
    }

    if (-not $destination -or -not $clientId) {
        Write-Problem -Title 'Checking what arrived means signing in, and I am missing the details for that.' -Detail @(
            'Needed in upload-check.xml:',
            '',
            '    <Destination>  the address of the folder in SharePoint, copied',
            '                   from your browser',
            '    <ClientId>     the application ID your organisation uses to sign in',
            '',
            'The address you can fetch yourself: open the folder in SharePoint',
            'and copy what is in the address bar. The ClientId is one line that',
            'whoever sent you this package has. Until then, option 1 (checking',
            'the folder before uploading) works without any of it.')
        exit $SETUP_PROBLEM
    }

    $installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

    if ($installed -ne 'yes') {
        Write-Host ''
        Write-Host '  Signing in needs one more component: PnP.PowerShell.' -ForegroundColor Yellow
        Write-Host '  It is a Microsoft-published PowerShell module, about 100 MB,' -ForegroundColor Gray
        Write-Host '  installed once for your account only. It needs internet access.' -ForegroundColor Gray

        $install = $false
        if (-not $NoPrompt) {
            $install = Read-YesNo -Question 'Install it now? (takes a few minutes)' -Default $true
        }

        if (-not $install) {
            Write-Problem -Title 'Cannot check what arrived without signing in.' -Detail @(
                'Option 1 - checking the folder before you upload - still works,',
                'and needs nothing extra. Run Check-Upload.cmd again and pick it.',
                '',
                'To install the component later, from PowerShell 7:',
                '',
                '    Install-Module PnP.PowerShell -Scope CurrentUser')
            exit $SETUP_PROBLEM
        }

        Write-Host ''
        Write-Host '  Installing. This takes a few minutes and says nothing while it works...' -ForegroundColor Gray

        & $pwsh -NoProfile -Command "Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber"

        $installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

        if ($installed -ne 'yes') {
            Write-Problem -Title 'The component could not be installed.' -Detail @(
                'This is usually no internet access, or a company policy that',
                'blocks installing PowerShell modules. Show this to whoever sent',
                'you the package.',
                '',
                'Option 1 - checking the folder before you upload - still works.')
            exit $SETUP_PROBLEM
        }

        Write-Host '  Installed.' -ForegroundColor Green
    }
}

# -- Build the command -------------------------------------------------------
$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', $checker
    '-LocalPath', $Folder
    '-Mode', $mode)

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
