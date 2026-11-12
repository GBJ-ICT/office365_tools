<#
.SYNOPSIS
    Reads list-to-pdf.xml, checks that everything needed is present, asks for
    what is missing, and hands over to the script that prints the list.
.DESCRIPTION
    The launch half of "SharePoint list to PDF". The launcher
    (packaging/Office365-Tools.cmd, handed out as List-To-Pdf.cmd) finds or
    fetches a copy of this repository and hands over to this script; the
    settings, the checks and the questions that need no sign-in are here, and
    the printing itself is Invoke-ListToPdf.ps1.

    This file is the one part of the tool that must run under **Windows
    PowerShell 5.1**, which is on every Windows machine. That is the whole
    point: it can report that PowerShell 7 is missing, which a script written
    for PowerShell 7 cannot. Keep it free of 7-only syntax -- no ternaries,
    no ??, no -Parallel -- and plain ASCII. It does as little as it can; what
    needs PowerShell 7 is in Invoke-ListToPdf.ps1.

    It asks PowerShell 7 about PnP.PowerShell rather than looking itself: the
    two PowerShells have separate module directories, so what 5.1 can see says
    nothing about what 7 can load.
.PARAMETER Folder
    Folder the PDF is written to, overriding the one in list-to-pdf.xml. This
    is what a folder dragged onto the launcher arrives as.
.PARAMETER SettingsPath
    Path to the settings file. Defaults to list-to-pdf.xml beside this script.
    The launcher passes the one beside itself, which is the one people edit.
.PARAMETER ReportFolder
    Folder the PDF goes into when neither -Folder nor <OutputFolder> names one.
    The launcher passes the one beside itself: a copy fetched from GitHub lives
    in the user's AppData and is replaced on every run, which is no place for
    something a person is meant to open. Defaults to the repository's out/.
.PARAMETER Language
    en or de, overriding the settings and the saved choice.
.PARAMETER NoPrompt
    Never ask anything: use the settings file as it stands and fail if
    something needed is missing. For scheduled runs.
.EXAMPLE
    .\Start-ListToPdf.ps1

    Asks for the list and the view, and writes the PDF.
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
# closes is not a diagnosis. Exit codes: 0 done, 1 the export failed, 2 a setup
# problem.
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

    $suffix = Get-LauncherString 'ListPdf.Prompt.YesNo.DefaultYes'
    if (-not $Default) { $suffix = Get-LauncherString 'ListPdf.Prompt.YesNo.DefaultNo' }

    while ($true) {
        Write-Host ''
        $answer = "$(Read-Host "  $Question $suffix")".Trim().ToLower()

        if (-not $answer) { return $Default }
        if ('y', 'yes', 'j', 'ja' -contains $answer) { return $true }
        if ('n', 'no', 'nein' -contains $answer) { return $false }
    }
}

# -- Locate the pieces -------------------------------------------------------
# This file lives in packaging/ListToPdf/ wherever it runs -- the repository, or
# a release fetched from GitHub, which keeps the same layout -- so the rest is
# always two levels up.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$printer = Join-Path $PSScriptRoot 'Invoke-ListToPdf.ps1'
$module = Join-Path $root 'src\Office365Tools\Office365Tools.psd1'

if (-not $SettingsPath) {
    $SettingsPath = Join-Path $PSScriptRoot 'list-to-pdf.xml'
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
    Write-Problem -Title 'Part of the tool is missing.' -Detail @(
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
# language. Throws for a language it does not know.
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
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Language.Title') -Detail (Get-LauncherLines 'ListPdf.Settings.Language.Argument' $badLanguage)
    exit $SETUP_PROBLEM
}

$missing = @()
if (-not (Test-Path -LiteralPath $printer)) { $missing += 'packaging\ListToPdf\Invoke-ListToPdf.ps1' }
if (-not (Test-Path -LiteralPath $module)) { $missing += 'src\Office365Tools\' }
if (-not (Test-Path -LiteralPath $SettingsPath)) { $missing += (Split-Path -Leaf $SettingsPath) }

if ($missing.Count -gt 0) {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Setup.Missing.Title') -Detail (Get-LauncherLines 'ListPdf.Setup.Missing.Body' ($missing -join ', '))
    exit $SETUP_PROBLEM
}

# -- Read the settings -------------------------------------------------------
$known = @(
    'SiteUrl', 'ClientId', 'List', 'View', 'Orientation', 'PaperSize',
    'Reason', 'OutputFolder', 'Language')

# A SharePoint address can hold a bare & -- which is not legal XML, so a file
# that was filled in by pasting exactly what was asked for would not parse.
# Escaping them repairs the one mistake this file invites; an & that is already
# part of an entity is left alone.
try {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsPath
    $text = [regex]::Replace($text, '&(?!(?:[A-Za-z][A-Za-z0-9]*|#[0-9]+|#[xX][0-9A-Fa-f]+);)', '&amp;')

    $document = New-Object System.Xml.XmlDocument
    $document.LoadXml($text)
}
catch {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Unreadable.Title' (Split-Path -Leaf $SettingsPath)) `
        -Detail (Get-LauncherLines 'ListPdf.Settings.Unreadable.Body' $_.Exception.Message)
    exit $SETUP_PROBLEM
}

$rootNode = $document.DocumentElement

if (-not $rootNode -or $rootNode.Name -ne 'ListToPdf') {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.WrongFile.Title' (Split-Path -Leaf $SettingsPath)) `
        -Detail (Get-LauncherLines 'ListPdf.Settings.WrongFile.Body')
    exit $SETUP_PROBLEM
}

# Reading the child nodes, rather than asking for properties by name, means a
# typo shows up as an unknown setting instead of being silently ignored.
$settings = @{}
$unknown = @()

foreach ($node in $rootNode.ChildNodes) {
    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

    if ($known -notcontains $node.Name) {
        $unknown += $node.Name
        continue
    }

    $settings[$node.Name] = $node.InnerText.Trim()
}

if ($unknown.Count -gt 0) {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Unknown.Title') `
        -Detail (Get-LauncherLines 'ListPdf.Settings.Unknown.Body' ($unknown -join ', ') ($known -join ', '))
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

# -- Language, once the settings are read ------------------------------------
# <Language> in this file can name one for the file. -Language still wins, as it
# does everywhere.
$fromFile = Get-Setting -Name 'Language'
if (-not $Language -and $fromFile) {
    try {
        Select-LauncherLanguage -Requested $fromFile
    }
    catch {
        Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Language.Title') -Detail (Get-LauncherLines 'ListPdf.Settings.Language.File' $fromFile)
        exit $SETUP_PROBLEM
    }
}

# -- The page ----------------------------------------------------------------
$orientation = Get-Setting -Name 'Orientation'
if (-not $orientation) { $orientation = 'Landscape' }

$orientations = @('Landscape', 'Portrait')
$match = @($orientations | Where-Object { $_ -eq $orientation })
if ($match.Count -eq 0) {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Choice.Title' 'Orientation' ($orientations -join ', ')) `
        -Detail (Get-LauncherLines 'ListPdf.Settings.CurrentValue' $orientation)
    exit $SETUP_PROBLEM
}
$orientation = $match[0]

$paperSize = Get-Setting -Name 'PaperSize'
if (-not $paperSize) { $paperSize = 'A4' }

$papers = @('A4', 'A3', 'A5', 'Letter', 'Legal')
$match = @($papers | Where-Object { $_ -eq $paperSize })
if ($match.Count -eq 0) {
    Write-Problem -Title (Get-LauncherString 'ListPdf.Settings.Choice.Title' 'PaperSize' ($papers -join ', ')) `
        -Detail (Get-LauncherLines 'ListPdf.Settings.CurrentValue' $paperSize)
    exit $SETUP_PROBLEM
}
$paperSize = $match[0]

# -- Where the PDF goes ------------------------------------------------------
$outputFolder = $Folder
if (-not $outputFolder) { $outputFolder = Get-Setting -Name 'OutputFolder' }
if (-not $outputFolder) { $outputFolder = $ReportFolder }
if (-not $outputFolder) { $outputFolder = Join-Path $root 'out' }

# A path pasted from Explorer arrives wrapped in quotes, and a trailing
# backslash confuses the command line further down.
$outputFolder = $outputFolder.Trim().Trim('"').TrimEnd('\')

# -- Which site --------------------------------------------------------------
$siteUrl = (Get-Setting -Name 'SiteUrl').Trim('"')

if (-not $siteUrl -and -not $NoPrompt) {
    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Site.Question')) -ForegroundColor Cyan
    foreach ($line in (Get-LauncherLines 'ListPdf.Site.Help')) {
        Write-Host "  $line" -ForegroundColor Gray
    }
    $siteUrl = "$(Read-Host ('  ' + (Get-LauncherString 'ListPdf.Site.Prompt')))".Trim().Trim('"')
}

$clientInfo = Resolve-O365ClientId -Configured (Get-Setting -Name 'ClientId') `
    -ProfilePath (Join-Path $root 'config\profiles.json')
$clientId = $null
if ($clientInfo) { $clientId = $clientInfo.ClientId }

if ($siteUrl -notmatch '^https://[^/\s]+') { $siteUrl = '' }

if (-not $siteUrl -or -not $clientId) {
    $detail = @()
    $detail += Get-LauncherLines 'ListPdf.SignIn.Missing.Needed'
    if (-not $siteUrl) { $detail += Get-LauncherLines 'ListPdf.SignIn.Missing.SiteUrl' }
    if (-not $clientId) { $detail += Get-LauncherLines 'ListPdf.SignIn.Missing.ClientId' }
    $detail += Get-LauncherLines 'ListPdf.SignIn.Missing.Footer'

    Write-Problem -Title (Get-LauncherString 'ListPdf.SignIn.Missing.Title') -Detail $detail
    exit $SETUP_PROBLEM
}

# Said out loud, so nobody has to wonder which of the three was used.
$from = Get-LauncherString 'ListPdf.ClientId.From.Settings'
if ($clientInfo.Source -eq 'Environment') { $from = Get-LauncherString 'ListPdf.ClientId.From.Environment' }
if ($clientInfo.Source -eq 'Profile') { $from = Get-LauncherString 'ListPdf.ClientId.From.Profile' }

Write-Host ''
Write-Host ('  ' + (Get-LauncherString 'ListPdf.Site.Shown' $siteUrl)) -ForegroundColor Green
Write-Host ('  ' + (Get-LauncherString 'ListPdf.ClientId.Found' $from)) -ForegroundColor Gray

# -- Find PowerShell 7 -------------------------------------------------------
# This script runs under whatever PowerShell the .cmd could find, which on a
# fresh machine is Windows PowerShell 5.1. Everything after this needs 7.
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
    Write-Problem -Title (Get-LauncherString 'ListPdf.Pwsh.Missing.Title') -Detail (Get-LauncherLines 'ListPdf.Pwsh.Missing.Body')
    exit $SETUP_PROBLEM
}

# -- Signing in needs PnP.PowerShell -----------------------------------------
# Ask PowerShell 7, do not look here: 5.1 and 7 read different module folders,
# so what this process can see is not what the tool will be able to load.
$installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

if ($installed -ne 'yes') {
    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Pnp.Title')) -ForegroundColor Yellow
    foreach ($line in (Get-LauncherLines 'ListPdf.Pnp.Body')) {
        Write-Host "  $line" -ForegroundColor Gray
    }

    $install = $false
    if (-not $NoPrompt) {
        $install = Read-YesNo -Question (Get-LauncherString 'ListPdf.Pnp.Question') -Default $true
    }

    if (-not $install) {
        Write-Problem -Title (Get-LauncherString 'ListPdf.Pnp.Declined.Title') -Detail (Get-LauncherLines 'ListPdf.Pnp.Declined.Body')
        exit $SETUP_PROBLEM
    }

    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Pnp.Installing')) -ForegroundColor Gray

    & $pwsh -NoProfile -Command "Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber"

    $installed = & $pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name PnP.PowerShell) { 'yes' } else { 'no' }"

    if ($installed -ne 'yes') {
        Write-Problem -Title (Get-LauncherString 'ListPdf.Pnp.Failed.Title') -Detail (Get-LauncherLines 'ListPdf.Pnp.Failed.Body')
        exit $SETUP_PROBLEM
    }

    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Pnp.Installed')) -ForegroundColor Green
}

# -- Build the command -------------------------------------------------------
$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', $printer
    '-SiteUrl', $siteUrl
    '-ClientId', $clientId
    '-OutputFolder', $outputFolder
    '-Orientation', $orientation
    '-PaperSize', $paperSize
    '-Language', $script:Chosen.Language)

# Only what the settings name. An empty -List or -View would not be the same as
# none: the printer asks for what it was not given.
$list = Get-Setting -Name 'List'
if ($list) { $arguments += @('-List', $list) }

$view = Get-Setting -Name 'View'
if ($view) { $arguments += @('-View', $view) }

# "none" leaves the reason out; nothing, or "ask", has the printer ask.
if ($settings.ContainsKey('Reason') -and $settings['Reason'].ToLower() -eq 'none') {
    $arguments += '-NoReason'
}
else {
    $reason = Get-Setting -Name 'Reason'
    if ($reason) { $arguments += @('-Reason', $reason) }
}

if ($NoPrompt) {
    $arguments += '-NoPrompt'
}

# -- Run it ------------------------------------------------------------------
& $pwsh $arguments

exit $LASTEXITCODE
