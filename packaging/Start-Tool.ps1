<#
.SYNOPSIS
    The repository's half of the double-click launcher: finds the tools, asks
    which one, and hands over to it.
.DESCRIPTION
    packaging/Office365-Tools.cmd is handed out, and a copy on someone's
    machine never changes. So it does as little as it can: it fetches the
    newest release of this repository -- the newest tag named vX.Y -- and
    hands over to this script in it. Whatever happens after that -- the menu,
    the settings file, how a tool is started -- can change with a release and
    reaches everyone who already has a launcher.

    The launcher never runs the code of a checkout. To try a change before it
    is tagged, start this script from the checkout, with no parameters.

    The parameters below are what every launcher handed out passes. They are
    the contract: a launcher from before a parameter was added does not pass
    it, so a new one needs a default that does what that launcher expects, and
    none of them can be renamed or removed. tests/Unit/Launcher.Tests.ps1
    checks that what the launcher passes is accepted here.

    Runs under Windows PowerShell 5.1 -- no ternaries, no ??, no -Parallel --
    and stays plain ASCII.
.PARAMETER Root
    The release the launcher fetched. Defaults to the repository this script
    is in.
.PARAMETER LauncherPath
    The launcher itself. The settings files and the Reports folder live beside
    it, where the person running it can find them. Defaults to the launcher
    beside this script.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File packaging\Start-Tool.ps1

    Runs the tools of this checkout, as the launcher would run a release.
.PARAMETER Tool
    The tool a launcher is pinned to, the name of its folder under packaging\.
    Empty: every tool there.
.PARAMETER Dropped
    A folder dragged onto the launcher, if there was one.
#>
[CmdletBinding()]
param(
    [string]$Root = '',

    [string]$LauncherPath = '',

    [string]$Tool = '',

    [string]$Dropped = ''
)

$ErrorActionPreference = 'Stop'

# Started by hand from a checkout: the repository this script is in, and the
# launcher beside it. Here rather than as parameter defaults, where Windows
# PowerShell does not know $PSScriptRoot yet.
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $LauncherPath) { $LauncherPath = Join-Path $PSScriptRoot 'Office365-Tools.cmd' }

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

$script:DpiAware = $false
$script:UiScale = 1.0

function Enable-HighDpi {
    <#
        Windows scales the windows of a process that has not said it
        understands DPI, and scales them as bitmaps -- which is why they come
        out fuzzy on a laptop screen. Saying so has to happen before the
        process owns its first window, and the tool started after the menu
        runs in this same process, so this is where it happens. Entry scripts
        may ask again; a second time changes nothing.

        $UiScale is what is left to do by hand: this process is now told the
        true pixel count, so a size written as 560 has to become 840 at 150%.
    #>
    if ($script:DpiAware) { return }
    $script:DpiAware = $true

    try {
        Add-Type -Namespace Office365ToolsLauncher -Name Display -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
'@ -ErrorAction Stop

        [Office365ToolsLauncher.Display]::SetProcessDPIAware() | Out-Null
    }
    catch {
        # Windows too old to have it, or a machine where compiling is not
        # allowed. Fuzzy is not worth giving up the window over.
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

# Windows Forms needs a single-threaded apartment, which Windows PowerShell
# runs in and PowerShell 7 does not. OFFICE365TOOLS_CONSOLE, set to anything,
# asks for the numbered list instead: for a session with no desktop to draw
# on, and for trying the launcher with its input piped in.
function Test-WindowPossible {
    if ($env:OFFICE365TOOLS_CONSOLE) { return $false }
    if (-not [Environment]::UserInteractive) { return $false }

    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    return ($apartment -eq [System.Threading.ApartmentState]::STA)
}

# The menu as a window: one button per tool, its title over its description.
# Built and returned unshown. A click closes it with DialogResult OK and the
# tool's index in the form's Tag; Close and Esc close it with Cancel.
function New-ToolWindow {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds a window in memory and does not show it. Nothing outside this process is changed, so -WhatIf would be meaningless.')]
    param(
        [object[]]$Tools
    )

    Enable-HighDpi

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $margin = ConvertTo-Pixel 16
    $gap = ConvertTo-Pixel 8
    $width = ConvertTo-Pixel 560

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'office365_tools'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true

    # Without this it can open behind the console window, which looks exactly
    # like nothing happening.
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $heading = New-Object System.Windows.Forms.Label
    $heading.Text = 'What would you like to do?'
    $heading.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $heading.AutoSize = $true
    $heading.Location = New-Object System.Drawing.Point($margin, $margin)

    $explain = New-Object System.Windows.Forms.Label
    $explain.Text = 'Click one to start it. It runs in the window behind this one.'
    $explain.AutoSize = $true
    $explain.ForeColor = [System.Drawing.SystemColors]::GrayText
    $explain.Location = New-Object System.Drawing.Point(($margin + 2), ($margin + (ConvertTo-Pixel 32)))

    $listTop = $margin + (ConvertTo-Pixel 60)

    # The buttons, top to bottom. Scrolls once there are more than fit on
    # most of the screen, so the Close button never ends up below its edge.
    $list = New-Object System.Windows.Forms.FlowLayoutPanel
    $list.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $list.WrapContents = $false
    $list.AutoScroll = $true
    $list.Location = New-Object System.Drawing.Point($margin, $listTop)

    $padding = ConvertTo-Pixel 10
    $titleFont = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $wrap = [System.Windows.Forms.TextFormatFlags]::WordBreak
    $maxHeight = [int]([System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height * 0.6)

    # How tall each tool's two lines are at a given button width.
    $measure = {
        param([int]$ButtonWidth)

        $textWidth = $ButtonWidth - 2 * $padding
        foreach ($entry in $Tools) {
            $titleHeight = [System.Windows.Forms.TextRenderer]::MeasureText([string]$entry['Title'], $titleFont,
                (New-Object System.Drawing.Size($textWidth, 0)), $wrap).Height
            $descriptionHeight = 0
            if ($entry['Description']) {
                $descriptionHeight = [System.Windows.Forms.TextRenderer]::MeasureText([string]$entry['Description'], $form.Font,
                    (New-Object System.Drawing.Size($textWidth, 0)), $wrap).Height
            }
            , @($titleHeight, ($titleHeight + $descriptionHeight + 2 * $padding + (ConvertTo-Pixel 2)))
        }
    }

    # Full width unless that is too tall to fit, in which case the list
    # scrolls and the buttons make room for the scroll bar.
    $buttonWidth = $width
    $heights = @(& $measure $buttonWidth)
    $total = 0
    foreach ($pair in $heights) { $total += $pair[1] + $gap }
    if ($total -gt $maxHeight) {
        $buttonWidth = $width - [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth - $gap
        $heights = @(& $measure $buttonWidth)
    }

    $listHeight = 0
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        $title = [string]$Tools[$i]['Title']
        $description = [string]$Tools[$i]['Description']
        $titleHeight = $heights[$i][0]

        # A button has one font and one colour for its text, and this wants a
        # bold title over a grey description. So the button gets no text: it
        # draws its own background, border, hover and focus, and the Paint
        # handler draws the two lines on top. Screen readers get them from
        # the accessible name and description.
        $button = New-Object System.Windows.Forms.Button
        $button.Text = ''
        $button.AccessibleName = $title
        $button.AccessibleDescription = $description
        $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, $gap)
        $button.Cursor = [System.Windows.Forms.Cursors]::Hand
        $button.Size = New-Object System.Drawing.Size($buttonWidth, $heights[$i][1])
        $button.Tag = @{
            Index       = $i
            Title       = $title
            Description = $description
            TitleFont   = $titleFont
            Padding     = $padding
            TitleHeight = $titleHeight
        }

        $button.Add_Paint({
                param($source, $paint)

                $info = $source.Tag
                $area = $source.ClientRectangle
                $left = $area.Left + $info.Padding
                $top = $area.Top + $info.Padding
                $inner = $area.Width - 2 * $info.Padding

                [System.Windows.Forms.TextRenderer]::DrawText($paint.Graphics, $info.Title, $info.TitleFont,
                    (New-Object System.Drawing.Rectangle($left, $top, $inner, $info.TitleHeight)),
                    [System.Drawing.SystemColors]::ControlText, [System.Windows.Forms.TextFormatFlags]::WordBreak)

                if ($info.Description) {
                    $below = $top + $info.TitleHeight + 2
                    [System.Windows.Forms.TextRenderer]::DrawText($paint.Graphics, $info.Description, $source.Font,
                        (New-Object System.Drawing.Rectangle($left, $below, $inner, ($area.Bottom - $below))),
                        [System.Drawing.SystemColors]::GrayText, [System.Windows.Forms.TextFormatFlags]::WordBreak)
                }
            })

        # FindForm rather than $form: the handler runs when the button is
        # clicked, long after this function has returned.
        $button.Add_Click({
                param($source)

                $owner = $source.FindForm()
                $owner.Tag = $source.Tag.Index
                $owner.DialogResult = [System.Windows.Forms.DialogResult]::OK
            })

        $list.Controls.Add($button)
        $listHeight += $button.Height + $gap
    }

    # The last button's gap is not needed below it, and would make a list
    # that just fits scroll by that much.
    $list.Controls[$list.Controls.Count - 1].Margin = New-Object System.Windows.Forms.Padding(0)
    $list.Size = New-Object System.Drawing.Size($width, ([Math]::Min($listHeight - $gap, $maxHeight)))

    $close = New-Object System.Windows.Forms.Button
    $close.Text = 'Close'
    $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $close.Size = New-Object System.Drawing.Size((ConvertTo-Pixel 90), (ConvertTo-Pixel 28))
    $closeTop = $listTop + $list.Height + $gap
    $close.Location = New-Object System.Drawing.Point(($margin + $width - $close.Width), $closeTop)

    $form.Controls.AddRange(@($heading, $explain, $list, $close))
    $form.CancelButton = $close
    $form.ClientSize = New-Object System.Drawing.Size(($width + 2 * $margin), ($closeTop + $close.Height + $margin))

    $form.Add_Shown({
            param($source)

            $source.Activate()
            $first = $source.Controls | Where-Object { $_ -is [System.Windows.Forms.FlowLayoutPanel] } | Select-Object -First 1
            if ($first -and $first.Controls.Count -gt 0) { $first.Controls[0].Focus() | Out-Null }
        })

    return $form
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

    # Asked even when there is only one tool: a launcher that is not pinned to
    # a tool is the one that shows what there is. A window if one can be had;
    # the numbered list below if not, or if it fails to open. Closed without a
    # choice is an answer, not a failure.
    if (Test-WindowPossible) {
        $form = $null
        $opened = $false
        $picked = -1
        try {
            $form = New-ToolWindow -Tools $Tools
            $result = $form.ShowDialog()
            $opened = $true
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $picked = [int]$form.Tag
            }
        }
        catch {
            Write-Host "  (Could not open a window: $($_.Exception.Message))" -ForegroundColor DarkGray
        }
        finally {
            if ($form) { $form.Dispose() }
        }

        if ($picked -ge 0) {
            return $Tools[$picked]
        }

        if ($opened) {
            Write-Host ''
            Write-Host '  Nothing chosen, so nothing was run.' -ForegroundColor Gray
            exit 0
        }
    }

    Write-Host ''
    Write-Host '  What would you like to do?' -ForegroundColor Cyan
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        Write-Host ('    {0}) {1}' -f ($i + 1), $Tools[$i].Title)
        if ($Tools[$i]['Description']) {
            Write-Host "       $($Tools[$i]['Description'])" -ForegroundColor Gray
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

    # The launcher keeps each release in a folder named for its tag, so that
    # name is the version. A checkout is not a release and has none.
    $version = Split-Path -Leaf $Root
    if ($version -cnotmatch '^v\d+\.\d+$') { $version = '(not a release)' }

    try { $Host.UI.RawUI.WindowTitle = "$($chosen.Title) $version" } catch { Write-Verbose $_ }

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
