<#
.SYNOPSIS
    Signs in, asks which list and which view, and writes the list as a PDF.
.DESCRIPTION
    The PowerShell 7 half of "SharePoint list to PDF". Start-ListToPdf.ps1,
    which runs under Windows PowerShell 5.1, reads the settings, checks that
    PowerShell 7 and PnP.PowerShell are there and hands over to this script
    with everything it knows.

    What is not given is asked: the list from the lists of the site, the view
    from the stored views of that list (Enter takes the default view), and the
    reason for the export. The PDF is Export-SpoListPdf's, so every value on it
    has been looked for in the finished file.

    The folder the PDF is in opens only when the export worked. A list with no
    rows writes no PDF, and a PDF that failed its own check is not announced as
    finished.

    Exit codes: 0 done, 1 the export did not work, 2 the setup is wrong.
.PARAMETER SiteUrl
    Address of the SharePoint site.
.PARAMETER ClientId
    Entra application ID to sign in with.
.PARAMETER List
    Title or URL name of the list. Omitted: asked, from the lists of the site.
.PARAMETER View
    Title or GUID of a stored view. Omitted: asked, from the views of the list.
.PARAMETER OutputFolder
    Folder the PDF is written to. Created when it is not there.
.PARAMETER Orientation
    Landscape (the default) or Portrait.
.PARAMETER PaperSize
    A4 (the default), A3, A5, Letter or Legal.
.PARAMETER Reason
    Why the list is exported; printed on the first page. Omitted: asked.
.PARAMETER NoReason
    Print no reason, and do not ask for one.
.PARAMETER Language
    en, de or auto, for this run only.
.PARAMETER NoPrompt
    Never ask: take the default view, no reason, and fail where an answer is
    missing.
.EXAMPLE
    .\Invoke-ListToPdf.ps1 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId $id -OutputFolder C:\Reports
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter()]
    [string]$List,

    [Parameter()]
    [string]$View,

    [Parameter(Mandatory)]
    [string]$OutputFolder,

    [Parameter()]
    [ValidateSet('Portrait', 'Landscape')]
    [string]$Orientation = 'Landscape',

    [Parameter()]
    [ValidateSet('A3', 'A4', 'A5', 'Letter', 'Legal')]
    [string]$PaperSize = 'A4',

    [Parameter()]
    [string]$Reason,

    [Parameter()]
    [switch]$NoReason,

    [Parameter()]
    [ValidateSet('en', 'de', 'auto')]
    [string]$Language,

    [Parameter()]
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'

# Run from the launcher this is a fresh process and the module is not loaded;
# under a test it already is, and is left as it is.
if (-not (Get-Module -Name Office365Tools)) {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'Office365Tools' 'Office365Tools.psd1')
}

if ($Language) {
    Set-O365Language -Language $Language -SessionOnly -WhatIf:$false
}

function Get-LauncherString {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    return (Get-O365String -ResourcePath (Join-Path $PSScriptRoot 'Resources') $Key @FormatArguments)
}

function Write-Problem {
    param(
        [string]$Title,
        [string[]]$Detail = @()
    )

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Red
    foreach ($line in $Detail) {
        Write-Host "  $line" -ForegroundColor Gray
    }
    Write-Host ''
}

# A numbered question. Enter takes the default; -NoPrompt takes it without
# asking. Returns the zero-based index chosen.
function Read-Choice {
    param(
        [string]$Question,
        [string[]]$Option,
        [int]$Default = 0
    )

    if ($NoPrompt) { return $Default }

    Write-Host ''
    Write-Host "  $Question" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Option.Count; $i++) {
        Write-Host ('    {0,3}) {1}' -f ($i + 1), $Option[$i])
    }

    while ($true) {
        Write-Host ''
        $answer = "$(Read-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Choice.Prompt' ($Default + 1))))".Trim()

        if (-not $answer) { return $Default }

        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Option.Count) {
            return ($number - 1)
        }

        Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Choice.Invalid' $Option.Count)) -ForegroundColor Yellow
    }
}

function Open-OutputFolder {
    param(
        [string]$Path
    )

    try {
        Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$Path`""
    }
    catch {
        Write-Verbose "Could not open the folder: $($_.Exception.Message)"
    }
}

$pdfPath = $null

# What the run was doing, so a failure can say where it was.
$step = ''

try {
    # -- Can the PDF be written at all? Found out before signing in. ----------
    try {
        $null = New-Item -ItemType Directory -Path $OutputFolder -Force
        $probe = Join-Path $OutputFolder ".write-test-$([guid]::NewGuid().ToString('N'))"
        [System.IO.File]::WriteAllText($probe, 'x')
        Remove-Item -LiteralPath $probe -Force
    }
    catch {
        Write-Problem -Title (Get-LauncherString 'ListPdf.Run.Folder.Title' $OutputFolder) `
            -Detail @($_.Exception.Message, '', (Get-LauncherString 'ListPdf.Run.Folder.Hint'))
        exit 2
    }

    # -- The address ---------------------------------------------------------
    # What people paste is whatever their browser shows: a list, a view, a page
    # inside the site. The site is what to sign in to; and a list the address
    # names is the list to print, so it need not be asked. An address that
    # cannot be read as one is used as it is, and the sign-in says what is wrong.
    $parsed = $null
    try { $parsed = ConvertFrom-SpoAddress -Address $SiteUrl } catch { Write-Verbose $_.Exception.Message }

    # A sharing link (the "Copy link" button) is refused by that reader, because
    # it is an opaque token and says nothing of the list. Its first part does
    # name the site -- /:x:/s/team/... is the site /sites/team -- and the site is
    # all that is needed here: the list is then asked for.
    if (-not $parsed) {
        $sharing = [regex]::Match($SiteUrl.Trim().Trim('"'), '^(?<origin>https://[^/\s]+)/:[a-z]:/(?<kind>[a-z])/(?<rest>[^?#\s]+)')
        if ($sharing.Success) {
            $first = @($sharing.Groups['rest'].Value -split '/')[0]
            $siteFromLink = switch ($sharing.Groups['kind'].Value) {
                's' { "$($sharing.Groups['origin'].Value)/sites/$first" }
                't' { "$($sharing.Groups['origin'].Value)/teams/$first" }
                default { $null }
            }

            if ($siteFromLink) {
                Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Address.Sharing' $siteFromLink)) -ForegroundColor Yellow
                $parsed = [pscustomobject]@{ SiteUrl = $siteFromLink; Library = $null; RemoteFolder = '' }
            }
        }
    }

    if ($parsed) {
        if ($parsed.SiteUrl.TrimEnd('/') -ne $SiteUrl.Trim().TrimEnd('/')) {
            Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Address.Site' $parsed.SiteUrl)) -ForegroundColor Gray
        }
        $SiteUrl = $parsed.SiteUrl

        if (-not $List) {
            $named = $null
            if ($parsed.Library -eq 'Lists' -and $parsed.RemoteFolder) { $named = @($parsed.RemoteFolder -split '/')[0] }
            elseif ($parsed.Library -and $parsed.Library -ne 'Lists') { $named = $parsed.Library }

            if ($named) {
                $List = $named
                Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Address.List' $List)) -ForegroundColor Gray
            }
        }
    }

    # -- Sign in ---------------------------------------------------------------
    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Connecting' $SiteUrl)) -ForegroundColor Cyan

    $step = Get-LauncherString 'ListPdf.Run.Step.Connect'
    Connect-O365 -SiteUrl $SiteUrl -ClientId $ClientId -Interactive:(-not $NoPrompt)

    # -- Which list ------------------------------------------------------------
    if (-not $List) {
        $step = Get-LauncherString 'ListPdf.Run.Step.Lists'
        $lists = @(Get-PnPList | Where-Object { -not $_.Hidden } | Sort-Object Title)

        if ($lists.Count -eq 0) {
            Write-Problem -Title (Get-LauncherString 'ListPdf.Run.List.None.Title' $SiteUrl)
            exit 1
        }

        if ($NoPrompt) {
            Write-Problem -Title (Get-LauncherString 'ListPdf.Run.List.Missing.Title')
            exit 2
        }

        $picked = Read-Choice -Question (Get-LauncherString 'ListPdf.Run.List.Question') -Option @($lists | ForEach-Object { $_.Title })
        $List = $lists[$picked].Title
    }

    # -- Which view ------------------------------------------------------------
    $step = Get-LauncherString 'ListPdf.Run.Step.Views' $List
    $chosenView = $null
    if ($View) {
        $chosenView = Get-SpoListView -Library $List -View $View
    }
    else {
        $views = @(Get-SpoListView -Library $List)

        if ($views.Count -gt 0) {
            $labels = @($views | ForEach-Object {
                    if ($_.DefaultView) { "$($_.Title)  $(Get-LauncherString 'ListPdf.Run.View.Default')" } else { $_.Title }
                })
            $default = [Math]::Max(0, @($views | ForEach-Object { $_.DefaultView }).IndexOf($true))

            $picked = Read-Choice -Question (Get-LauncherString 'ListPdf.Run.View.Question' $List) -Option $labels -Default $default
            $chosenView = $views[$picked]
        }
        else {
            Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.View.None')) -ForegroundColor Gray
        }
    }

    # -- Why ---------------------------------------------------------------------
    $why = $Reason
    if (-not $why -and -not $NoReason -and -not $NoPrompt) {
        Write-Host ''
        $why = "$(Read-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Reason.Prompt')))".Trim()
    }

    # -- Print -------------------------------------------------------------------
    $name = $List
    if ($chosenView) { $name = "$List $($chosenView.Title)" }
    $safeName = [regex]::Replace($name, '[^\w\-]+', '-').Trim('-')
    $pdfPath = Join-Path $OutputFolder "$safeName-$(Get-Date -Format 'yyyyMMdd_HHmm').pdf"

    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Printing' $name)) -ForegroundColor Cyan

    $arguments = @{
        Library     = $List
        Path        = $pdfPath
        Orientation = $Orientation
        PaperSize   = $PaperSize
    }
    if ($chosenView) { $arguments['View'] = $chosenView.Id.ToString() }
    if ($why) { $arguments['Reason'] = $why }

    $step = Get-LauncherString 'ListPdf.Run.Step.Print' $List
    $export = Export-SpoListPdf @arguments

    # A list or a view with no rows has nothing to hand over, and a PDF that
    # says "0 rows" would only look like a result.
    if ($export.RowCount -eq 0) {
        if (Test-Path -LiteralPath $pdfPath) { Remove-Item -LiteralPath $pdfPath -Force }
        Write-Problem -Title (Get-LauncherString 'ListPdf.Run.Empty.Title' $name) `
            -Detail @((Get-LauncherString 'ListPdf.Run.Empty.Hint'))
        exit 1
    }

    $errors = @($export.Finding | Where-Object { $_.Severity -eq 'Error' })
    if ($errors.Count -gt 0) {
        # Each finding with what it is about, the start of the value that is
        # missing or the address of the link, so it can be looked up in the list.
        $lines = @($errors | Select-Object -First 8 | ForEach-Object {
                # A finding's Detail is an object (or missing), not a hashtable.
                $about = ''
                $detail = $_.PSObject.Properties['Detail']
                if ($detail -and $detail.Value -and $detail.Value.PSObject.Properties['Value']) {
                    $value = ("$($detail.Value.Value)" -replace '\s+', ' ').Trim()
                    if ($value.Length -gt 60) { $value = $value.Substring(0, 60) + '...' }
                    $about = "  [$value]"
                }
                elseif ($detail -and $detail.Value -and $detail.Value.PSObject.Properties['Href']) {
                    $about = "  [$($detail.Value.Href)]"
                }
                "$($_.Message)$about"
            })
        if ($errors.Count -gt 8) { $lines += (Get-LauncherString 'ListPdf.Run.Unverified.More' ($errors.Count - 8)) }
        $lines += ''
        $lines += (Get-LauncherString 'ListPdf.Run.Unverified.File' $pdfPath)

        Write-Problem -Title (Get-LauncherString 'ListPdf.Run.Unverified.Title' $errors.Count) -Detail $lines
        exit 1
    }

    Write-Host ''
    Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.Done' $export.RowCount $export.ColumnCount $export.PageCount)) -ForegroundColor Green
    Write-Host ('  ' + $pdfPath) -ForegroundColor Green
    if (-not $export.Verified) {
        Write-Host ('  ' + (Get-LauncherString 'ListPdf.Run.NotFullyVerified')) -ForegroundColor Yellow
    }

    Open-OutputFolder -Path $pdfPath
    exit 0
}
catch {
    # No half-written PDF is left to be mistaken for a result.
    if ($pdfPath -and (Test-Path -LiteralPath $pdfPath)) {
        Remove-Item -LiteralPath $pdfPath -Force -ErrorAction SilentlyContinue
    }

    # The message, where it happened and the stack, because "NotFound" alone
    # does not say which request it was.
    $detail = @($_.Exception.Message, '')
    if ($step) { $detail += (Get-LauncherString 'ListPdf.Run.Failed.Step' $step) }
    $detail += (Get-LauncherString 'ListPdf.Run.Failed.Where' $_.Exception.GetType().Name)
    $detail += @($_.ScriptStackTrace -split "`r?`n" | Select-Object -First 6 | ForEach-Object { "    $_" })

    Write-Problem -Title (Get-LauncherString 'ListPdf.Run.Failed.Title') -Detail $detail
    exit 1
}
