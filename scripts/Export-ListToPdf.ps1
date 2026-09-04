<#
.SYNOPSIS
    Prints a SharePoint list to PDF and reports whether all of it arrived.
.DESCRIPTION
    Connect, print, verify, in one command, with the verification report
    written next to the PDF.

    The reason not to do this from the browser is that the browser's print of a
    SharePoint list is not reproducible. The modern list virtualises its rows,
    so only what is scrolled into view is in the DOM to print, and the layout
    is computed for the window at its current zoom -- change the zoom and the
    columns change width, which changes what gets cut off at the right edge.
    Nothing warns you when that happens.

    This renders its own page instead: a table sized in points and millimetres,
    header row repeating on every page, rows that never split, cells that wrap
    rather than clip. A headless browser converts it with the device scale
    factor pinned to 1, so the output depends on the paper and the data and on
    nothing else.

    Then it reads the PDF back and looks for every printed value in it. A
    missing value is an error and is listed with its row and column. This is
    the part that is worth having: 'is everything on there' becomes something
    the run answers rather than something you check by hand.

    Three files go into the output directory: the PDF, verification.html, and
    the run log. -KeepHtml adds the intermediate HTML, which is the file to
    edit when a layout needs adjusting -- open it in a browser, print it, look,
    change the CSS, repeat, and only then put the rule into -Css.
.PARAMETER ProfileName
    Connection profile naming the site.
.PARAMETER SiteUrl
    Site URL, instead of -ProfileName.
.PARAMETER ClientId
    Entra application ID, when connecting by URL.
.PARAMETER List
    Title or URL name of the list to print.
.PARAMETER View
    Print what this view shows: its columns, in its order, filtered and sorted
    by its query.
.PARAMETER Field
    Internal names of the columns to print, in order. Overrides the view's.
.PARAMETER SortBy
    Column to sort by before printing.
.PARAMETER Descending
    Reverse the sort.
.PARAMETER GroupBy
    Print one sub-table per value of this column.
.PARAMETER Title
    Document heading. Defaults to the list title.
.PARAMETER Subtitle
    Second line under the heading.
.PARAMETER Orientation
    Landscape (default) or Portrait.
.PARAMETER PaperSize
    A3, A4, A5, Letter or Legal.
.PARAMETER FontSize
    Body font size in points. Lower this before reaching for A3.
.PARAMETER Margin
    Page margin as a CSS length, e.g. '12mm'.
.PARAMETER ColumnWidth
    Column name to CSS width, e.g. @{ Title = '25%' }. From a shell, JSON:
    '{"Title":"25%"}'.
.PARAMETER Css
    Extra CSS. Cells carry a 'col-<column>' class, so a rule can address one
    column.
.PARAMETER ItemLink
    Name of a printed column whose cells link back to the item in SharePoint.
    'Title' is the usual choice.
.PARAMETER LinkColumn
    Column name to URL template, e.g. @{ Ticket = 'https://.../DispForm.aspx?ID={ID}' }.
    From a shell, JSON: '{"Ticket":"https://.../DispForm.aspx?ID={ID}"}'.
.PARAMETER NoAutoLink
    Print hyperlink columns as plain text rather than clickable links.
.PARAMETER RowNumber
    Print a leading number column.
.PARAMETER PageFooter
    Keep the browser's own header and footer, which is the only way to get page
    numbers.
.PARAMETER SkipVerification
    Print without checking the result.
.PARAMETER Sample
    Verify this many rows, chosen at random, rather than all of them.
.PARAMETER KeepHtml
    Keep the intermediate HTML next to the PDF.
.PARAMETER BrowserPath
    Full path to msedge.exe or chrome.exe, when it is somewhere unusual.
.PARAMETER Interactive
    Force a browser sign-in rather than relying on a cached token. Worth
    reaching for first when a connection hangs instead of failing.
.PARAMETER OutputPath
    Directory for the PDF, the verification report and the log. Defaults to
    out/list-pdf-<timestamp>.
.EXAMPLE
    ./scripts/Export-ListToPdf.ps1 -ProfileName HGTitterten -List 'Aufgaben und Dienste'
    Prints every visible column, A4 landscape, and verifies the result.
.EXAMPLE
    ./scripts/Export-ListToPdf.ps1 -ProfileName HGTitterten -List 'Aufgaben und Dienste' `
        -View 'Saison 2026/27' -GroupBy 'Gefaess' -RowNumber -FontSize 7.5
    Prints what a view shows, grouped, with numbered rows and smaller type.
.EXAMPLE
    ./scripts/Export-ListToPdf.ps1 -ProfileName HGTitterten -List Mappen -KeepHtml `
        -ColumnWidth '{"Bemerkungen":"35%"}' -Css 'td.col-datum { white-space: nowrap; }'
    Adjusts the layout and keeps the HTML so the next adjustment is quicker.
.LINK
    Export-SpoListPdf
.LINK
    Test-SpoPdfContent
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Profile')]
param(
    [Parameter(ParameterSetName = 'Profile')]
    [string]$ProfileName,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$SiteUrl,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$List,

    [Parameter()]
    [string]$View,

    [Parameter()]
    [string[]]$Field,

    [Parameter()]
    [string]$SortBy,

    [Parameter()]
    [switch]$Descending,

    [Parameter()]
    [string]$GroupBy,

    [Parameter()]
    [string]$Title,

    [Parameter()]
    [string]$Subtitle,

    [Parameter()]
    [ValidateSet('Portrait', 'Landscape')]
    [string]$Orientation = 'Landscape',

    [Parameter()]
    [ValidateSet('A3', 'A4', 'A5', 'Letter', 'Legal')]
    [string]$PaperSize = 'A4',

    [Parameter()]
    [double]$FontSize = 8.5,

    [Parameter()]
    [string]$Margin = '12mm',

    [Parameter()]
    [object]$ColumnWidth,

    [Parameter()]
    [string]$Css,

    [Parameter()]
    [string]$ItemLink,

    [Parameter()]
    [object]$LinkColumn,

    [Parameter()]
    [switch]$NoAutoLink,

    [Parameter()]
    [switch]$RowNumber,

    [Parameter()]
    [switch]$PageFooter,

    [Parameter()]
    [switch]$SkipVerification,

    [Parameter()]
    [int]$Sample,

    [Parameter()]
    [switch]$KeepHtml,

    [Parameter()]
    [string]$BrowserPath,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'Office365Tools') -Force

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot '..' 'out' "list-pdf-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
# -WhatIf:$false: this directory holds the log and the report rather than
# anything on the tenant, and Resolve-Path below would fail without it.
$null = New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false
$OutputPath = (Resolve-Path $OutputPath).Path

Start-O365Log -Path (Join-Path $OutputPath 'export-pdf.log') | Out-Null

try {
    if ($PSCmdlet.ParameterSetName -eq 'Url') {
        Connect-O365 -SiteUrl $SiteUrl -ClientId $ClientId -Interactive:$Interactive
    }
    elseif ($ProfileName) {
        Connect-O365 -ProfileName $ProfileName -Interactive:$Interactive
    }
    else {
        Connect-O365 -Interactive:$Interactive
    }

    # A hashtable from a PowerShell prompt, JSON from a shell: pwsh runs a
    # script under -File semantics, where every argument arrives as a string
    # and a hashtable literal does not survive the trip.
    $widths = @{}
    if ($ColumnWidth -is [hashtable]) {
        $widths = $ColumnWidth
    }
    elseif ($ColumnWidth -is [string] -and $ColumnWidth.Trim()) {
        $parsed = $ColumnWidth | ConvertFrom-Json
        foreach ($property in $parsed.PSObject.Properties) { $widths[$property.Name] = [string]$property.Value }
    }

    $links = @{}
    if ($LinkColumn -is [hashtable]) {
        $links = $LinkColumn
    }
    elseif ($LinkColumn -is [string] -and $LinkColumn.Trim()) {
        $parsedLinks = $LinkColumn | ConvertFrom-Json
        foreach ($property in $parsedLinks.PSObject.Properties) { $links[$property.Name] = [string]$property.Value }
    }

    $safeName = [regex]::Replace($List, '[^\w\-]+', '-').Trim('-')
    $pdfPath = Join-Path $OutputPath "$safeName.pdf"

    $arguments = @{
        Library          = $List
        Path             = $pdfPath
        Orientation      = $Orientation
        PaperSize        = $PaperSize
        FontSize         = $FontSize
        Margin           = $Margin
        ColumnWidth      = $widths
        RowNumber        = $RowNumber
        NoAutoLink       = $NoAutoLink
        PageFooter       = $PageFooter
        KeepHtml         = $KeepHtml
        SkipVerification = $SkipVerification
        Descending       = $Descending
        WhatIf           = $WhatIfPreference
    }

    # Spelled out rather than looped over: an omitted parameter must not reach
    # the command at all, since an empty -GroupBy or -Title is not the same as
    # no grouping and no title.
    if ($View) { $arguments['View'] = $View }
    if ($Field) { $arguments['Field'] = $Field }
    if ($SortBy) { $arguments['SortBy'] = $SortBy }
    if ($GroupBy) { $arguments['GroupBy'] = $GroupBy }
    if ($Title) { $arguments['Title'] = $Title }
    if ($Subtitle) { $arguments['Subtitle'] = $Subtitle }
    if ($Css) { $arguments['Css'] = $Css }
    if ($BrowserPath) { $arguments['BrowserPath'] = $BrowserPath }
    if ($Sample) { $arguments['Sample'] = $Sample }
    if ($ItemLink) { $arguments['ItemLink'] = $ItemLink }
    if ($links.Count -gt 0) { $arguments['LinkColumn'] = $links }

    Write-Host "Printing '$List' ..." -ForegroundColor Cyan

    $export = Export-SpoListPdf @arguments

    if (-not $export.Printed) {
        Write-Host "Would print $($export.RowCount) row(s) and $($export.ColumnCount) column(s) to $pdfPath" -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host "  $($export.Path)" -ForegroundColor Green
    Write-Host "  $($export.RowCount) row(s), $($export.ColumnCount) column(s), $($export.PageCount) page(s), digest $($export.Digest)"
    if ($export.LinkCount -gt 0) { Write-Host "  $($export.LinkCount) clickable link(s)" }
    Write-Host "  columns: $($export.Column -join ', ')"

    if ($SkipVerification) {
        Write-Host '  not verified (-SkipVerification)' -ForegroundColor Yellow
        return
    }

    $findings = @($export.Finding)
    $errors = @($findings | Where-Object Severity -eq 'Error')

    $reportPath = Join-Path $OutputPath 'verification.html'
    $findings | Export-SpoReport -Path $reportPath -Title "Verification of $($export.RowCount) row(s) in $List" -WhatIf:$false

    Write-Host ''
    if ($errors.Count -eq 0 -and $export.Verified) {
        Write-Host '  Verified: every printed value was found in the PDF.' -ForegroundColor Green
    }
    elseif ($errors.Count -eq 0) {
        Write-Host '  Not fully verified. See verification.html -- the PDF may still be correct.' -ForegroundColor Yellow
        $findings | Where-Object Severity -ne 'Info' | ForEach-Object { Write-Host "    $($_.RuleId): $($_.Message)" -ForegroundColor Yellow }
    }
    else {
        Write-Host "  $($errors.Count) value(s) or check(s) failed. The PDF is missing data:" -ForegroundColor Red
        $errors | Select-Object -First 10 | ForEach-Object { Write-Host "    $($_.Message)" -ForegroundColor Red }
        if ($errors.Count -gt 10) { Write-Host "    ... and $($errors.Count - 10) more" -ForegroundColor Red }
        Write-Host '  Usual cause: too many columns for the paper. Lower -FontSize, use -PaperSize A3, or print fewer columns.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host "  Report and log in $OutputPath"
}
finally {
    Stop-O365Log | Out-Null
}
