<#
.SYNOPSIS
    Prints a SharePoint list to PDF with a fixed page layout, then verifies
    that every value reached the page.
.DESCRIPTION
    Printing a list from the browser does not produce a document you can rely
    on. The modern list is a virtualised grid: what goes to the printer is
    what was scrolled into view, laid out for the window it was in, at the zoom
    level the window happened to be at. Change the zoom and the column widths
    change, which changes which text is cut off at the right margin -- and
    nothing tells you that anything was cut off. That is the actual problem
    with printing SharePoint by hand, and it is why the same list printed twice
    comes out differently.

    So this does not print the list. It reads the items, renders its own page
    -- a plain table sized in points and millimetres, with a header row that
    repeats, rows that never split across a page, and cells that wrap instead
    of clipping -- and has a headless browser convert that to PDF with the
    device scale factor pinned to 1. Nothing in the pipeline depends on a
    window size, a zoom level, or which browser tab was in front.

    Then it checks its own work. The PDF's text is read back out and every
    printed value is looked for in it, so 'everything is on there' is something
    the command establishes rather than something you hope. The result carries
    the findings; -SkipVerification opts out, and nothing else does.

    Layout is customisable at three levels: the parameters below for the
    ordinary cases (paper, orientation, font size, column widths, grouping),
    -Css for a rule the parameters do not cover, and -CellFormatter for a value
    that should print as something other than itself. Every cell carries a
    'col-<column>' class, so -Css can address one column.

    Objects other than list items are accepted on the pipeline, so the output
    of any command in this module -- findings, a permission report, a Document
    Set register -- prints the same way.

    Needs Microsoft Edge, Chrome, or another Chromium-based browser. It is
    used headless and offline; nothing is uploaded anywhere.
.PARAMETER Library
    Title, URL name, or GUID of the list to print.
.PARAMETER InputObject
    Objects to print, instead of a list. Whatever properties they have become
    the columns.
.PARAMETER Path
    Where to write the PDF. Parent directories are created.
.PARAMETER View
    Print the columns of this list view, in its order, filtered and sorted by
    its query -- so the PDF matches what the view shows on screen.
.PARAMETER Field
    Internal names of the columns to print, in order. Overrides -View's
    columns. Omitted, the view's columns or the list's visible columns are
    used.
.PARAMETER SortBy
    Column to sort rows by before printing.
.PARAMETER Descending
    Reverse the sort.
.PARAMETER Title
    Document heading. Defaults to the list title.
.PARAMETER Subtitle
    Second line under the heading -- what the selection is, who it is for.
.PARAMETER GroupBy
    Print one sub-table per distinct value of this column, each with its own
    repeating header.
.PARAMETER Orientation
    Landscape (the default, and what a list with more than four columns needs)
    or Portrait.
.PARAMETER PaperSize
    A3, A4, A5, Letter or Legal.
.PARAMETER Margin
    Page margin as a CSS length, e.g. '12mm'.
.PARAMETER FontSize
    Body font size in points. Lower it before reaching for A3.
.PARAMETER ColumnWidth
    Column name to CSS width, e.g. @{ Title = '25%' }. A hint: a column still
    grows rather than clipping its contents.
.PARAMETER Css
    Extra CSS appended to the document's stylesheet, so it wins over the
    defaults.
.PARAMETER CellFormatter
    Script block called per cell with the value and the column name, returning
    the text to print.
.PARAMETER LinkColumn
    Column name to URL template, making that column's cells clickable in the
    PDF. '{Name}' is replaced with that column's value from the row, escaped
    for a URL; '{Name:raw}' inserts it verbatim. Only http, https, mailto and
    tel are printed as links.
.PARAMETER LinkFormatter
    Script block called per cell with the value, the column name and the row,
    returning a URL or nothing. For links the templates cannot express.
.PARAMETER ItemLink
    Name of a printed column whose cells should link back to the list item they
    came from. The display form URL is worked out from the list.
.PARAMETER NoAutoLink
    Do not turn values that are already URLs or email addresses into links.
    Hyperlink columns then print as plain text.
.PARAMETER DateFormat
    Format for date columns. Dates carrying a time also print the time.
.PARAMETER RowNumber
    Print a leading number column, which is what makes checking the paper copy
    against the row count possible by eye.
.PARAMETER PageFooter
    Keep the browser's own header and footer, which carry the title, the date
    and 'page n of m'. Off by default because it also prints the temporary
    file's path. It is the only way to get page numbers -- Chromium has no CSS
    counter for them.
.PARAMETER KeepHtml
    Keep the intermediate HTML next to the PDF. This is the file to open when
    a layout needs adjusting: reload it in a browser, print to PDF, compare.
.PARAMETER SkipVerification
    Do not read the PDF back and check it. Faster, and blind.
.PARAMETER Sample
    Verify this many rows, chosen at random, rather than all of them.
.PARAMETER BrowserPath
    Full path to msedge.exe or chrome.exe, when it is somewhere unusual.
.PARAMETER TimeoutSecond
    How long to give the browser before giving up on it.
.PARAMETER PageSize
    Items fetched per request when reading the list.
.OUTPUTS
    PSCustomObject with Path, RowCount, ColumnCount, PageCount, Digest,
    LinkCount, Verified and Finding.
.EXAMPLE
    Export-SpoListPdf -Library 'Aufgaben und Dienste' -Path out/dienste.pdf
    Prints every visible column of the list, A4 landscape, and verifies it.
.EXAMPLE
    Export-SpoListPdf -Library Duties -View 'Aktuelle Saison' -Path out/saison.pdf `
        -GroupBy Gefaess -RowNumber -Subtitle 'Saison 2026/27'
    Prints what the view shows, grouped, with numbered rows.
.EXAMPLE
    $export = Export-SpoListPdf -Library Duties -Path out/duties.pdf
    $export.Finding | Export-SpoReport -Path out/duties-check.html
    Keeps the verification result as a report of its own.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte |
        Export-SpoListPdf -Path out/drift.pdf -Field Target, Message -Orientation Portrait
    Prints another command's output rather than a list.
.EXAMPLE
    Export-SpoListPdf -Library 'ICT Support Ticket' -View 'Ungeschlossene Tickets' `
        -Path out/tickets.pdf -ItemLink Title
    Every title in the PDF is a live link back to its item in SharePoint.
.EXAMPLE
    Export-SpoListPdf -Library Duties -Path out/duties.pdf -FontSize 7 `
        -ColumnWidth @{ Bemerkungen = '30%' } -Css 'td.col-datum { white-space: nowrap; }'
    Custom layout: smaller type, a wider notes column, dates kept on one line.
.LINK
    Test-SpoPdfContent
.LINK
    Export-SpoReport
.LINK
    Export-SpoListItem
#>
function Export-SpoListPdf {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low', DefaultParameterSetName = 'List')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'List')]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Object')]
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(ParameterSetName = 'List')]
        [string]$View,

        [Parameter()]
        [Alias('Column')]
        [string[]]$Field,

        [Parameter()]
        [string]$SortBy,

        [Parameter()]
        [switch]$Descending,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Subtitle,

        [Parameter()]
        [string]$GroupBy,

        [Parameter()]
        [ValidateSet('Portrait', 'Landscape')]
        [string]$Orientation = 'Landscape',

        [Parameter()]
        [ValidateSet('A3', 'A4', 'A5', 'Letter', 'Legal')]
        [string]$PaperSize = 'A4',

        [Parameter()]
        [ValidatePattern('^\d+(\.\d+)?(mm|cm|in|pt|px)$')]
        [string]$Margin = '12mm',

        [Parameter()]
        [ValidateRange(4.0, 24.0)]
        [double]$FontSize = 8.5,

        [Parameter()]
        [hashtable]$ColumnWidth = @{},

        [Parameter()]
        [string]$Css,

        [Parameter()]
        [scriptblock]$CellFormatter,

        [Parameter()]
        [string]$DateFormat = 'yyyy-MM-dd',

        [Parameter()]
        [hashtable]$LinkColumn = @{},

        [Parameter()]
        [scriptblock]$LinkFormatter,

        [Parameter(ParameterSetName = 'List')]
        [string]$ItemLink,

        [Parameter()]
        [switch]$NoAutoLink,

        [Parameter()]
        [switch]$RowNumber,

        [Parameter()]
        [switch]$PageFooter,

        [Parameter()]
        [switch]$KeepHtml,

        [Parameter()]
        [switch]$SkipVerification,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Sample,

        [Parameter()]
        [string]$BrowserPath,

        [Parameter()]
        [ValidateRange(5, 3600)]
        [int]$TimeoutSecond = 180,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Object' -and $null -ne $InputObject) {
            $collected.Add($InputObject)
        }
    }

    end {
        $started = Get-Date

        # -------------------------------------------------------------------
        # Rows, columns, and the headings to print above them.
        # -------------------------------------------------------------------
        $header = @{}
        $documentTitle = $Title

        if ($PSCmdlet.ParameterSetName -eq 'List') {
            Assert-SpoConnection | Out-Null
            $list = Resolve-SpoList -Identity $Library

            if (-not $documentTitle) { $documentTitle = $list.Title }

            $viewFields = @()
            $viewQuery = $null
            if ($View) {
                $listView = Get-PnPView -List $list -Identity $View -ErrorAction SilentlyContinue
                if (-not $listView) {
                    $available = @(Get-PnPView -List $list | Select-Object -ExpandProperty Title)
                    throw [System.InvalidOperationException]::new(
                        "View '$View' was not found on '$($list.Title)'. Views on this list: $($available -join ', ')"
                    )
                }
                $viewFields = @($listView.ViewFields)
                $viewQuery = $listView.ViewQuery
                if (-not $Title) { $documentTitle = "$($list.Title) - $($listView.Title)" }
            }

            # Display names, so the page reads the way the list does. Internal
            # names are what everything else here works in, because that is
            # what a value can be looked up by.
            $listFields = @(Get-PnPField -List $list)
            foreach ($listField in $listFields) {
                $header[$listField.InternalName] = $listField.Title
            }

            $columns = if ($Field) {
                $Field
            }
            elseif ($viewFields.Count -gt 0) {
                @($viewFields | Where-Object { $_ -notin 'LinkTitleNoMenu', 'LinkTitle2', 'Edit', 'DocIcon', 'LinkFilename' })
            }
            else {
                @($listFields |
                        Where-Object { -not $_.Hidden -and $_.InternalName -notin 'ContentType', 'Attachments', '_UIVersionString' } |
                        ForEach-Object { $_.InternalName })
            }

            # LinkTitle is the view's clickable title column; the value lives
            # in Title, and asking for LinkTitle gets an empty cell.
            $columns = @($columns | ForEach-Object { if ($_ -eq 'LinkTitle') { 'Title' } else { $_ } } | Select-Object -Unique)

            # -ItemLink: the column that should take the reader back to the
            # item it came from. Built here rather than by the caller, because
            # the display form URL is the part nobody wants to hand-write.
            if ($ItemLink) {
                if ($ItemLink -notin $columns) {
                    throw [System.InvalidOperationException]::new(
                        "-ItemLink names '$ItemLink', which is not one of the printed columns: $($columns -join ', ')"
                    )
                }

                $displayForm = ''
                try {
                    $displayForm = [string](Get-PnPProperty -ClientObject $list -Property DefaultDisplayFormUrl -ErrorAction Stop)
                }
                catch {
                    Write-O365Log "Could not read the display form URL of '$($list.Title)': $($_.Exception.Message)" 'Verbose'
                }

                $site = [string]$script:O365State.SiteUrl
                $origin = if ($site) { ([uri]$site).GetLeftPart([System.UriPartial]::Authority) } else { '' }

                $template = if ($displayForm -and $origin) {
                    "$origin$displayForm`?ID={ID}"
                }
                elseif ($site) {
                    # Every list has this route whether or not it has a form of
                    # its own, so it is the fallback rather than the default.
                    "$($site.TrimEnd('/'))/_layouts/15/listform.aspx?PageType=4&ListId=$($list.Id)&ID={ID}"
                }
                else {
                    ''
                }

                # A caller's own -LinkColumn for the same column wins: it was
                # asked for explicitly, this was inferred.
                if ($template -and -not $LinkColumn.ContainsKey($ItemLink)) {
                    $LinkColumn = $LinkColumn.Clone()
                    $LinkColumn[$ItemLink] = $template
                }
            }

            $itemArguments = @{ Library = $list.Title; Field = $columns }
            if ($viewQuery) {
                # The view's own filter and sort, so the PDF is the view rather
                # than the list. RowLimit is left out on purpose: a view that
                # pages on screen still prints whole.
                $itemArguments['Query'] = "<View><Query>$viewQuery</Query></View>"
            }
            else {
                $itemArguments['PageSize'] = $PageSize
            }

            $rows = @(Export-SpoListItem @itemArguments)
        }
        else {
            $rows = @($collected)
            if (-not $documentTitle) { $documentTitle = 'Report' }

            $columns = if ($Field) {
                $Field
            }
            elseif ($rows.Count -gt 0) {
                @($rows[0].PSObject.Properties |
                        Where-Object { $_.Name -notlike 'PS*' -and $_.Name -ne 'Detail' } |
                        ForEach-Object { $_.Name })
            }
            else {
                @('Value')
            }
        }

        if ($SortBy) {
            $rows = @($rows | Sort-Object -Property $SortBy -Descending:$Descending)
        }

        if ($GroupBy -and $GroupBy -notin $columns) {
            Write-O365Log "Grouping column '$GroupBy' is not among the printed columns; it will head each group but not appear as a column." 'Info'
        }

        # -------------------------------------------------------------------
        # Render.
        # -------------------------------------------------------------------
        $render = ConvertTo-SpoPrintHtml -Row $rows -Column $columns -Header $header `
            -Title $documentTitle -Subtitle $Subtitle -Orientation $Orientation -PaperSize $PaperSize `
            -Margin $Margin -FontSize $FontSize -GroupBy $GroupBy -ColumnWidth $ColumnWidth `
            -Css $Css -CellFormatter $CellFormatter -DateFormat $DateFormat -RowNumber:$RowNumber `
            -LinkColumn $LinkColumn -LinkFormatter $LinkFormatter -NoAutoLink:$NoAutoLink

        $directory = Split-Path -Parent $Path
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            $null = New-Item -Path $directory -ItemType Directory -Force -WhatIf:$false
        }

        $pdfPath = [System.IO.Path]::GetFullPath($Path)

        $htmlPath = if ($KeepHtml) {
            [System.IO.Path]::ChangeExtension($pdfPath, '.html')
        }
        else {
            Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-print-$([guid]::NewGuid()).html"
        }

        # -WhatIf:$false, because this is the input to the print rather than
        # the output of the command. Under -WhatIf it is written, read once,
        # and removed.
        Set-Content -LiteralPath $htmlPath -Value $render.Html -Encoding utf8 -WhatIf:$false

        try {
            if (-not $PSCmdlet.ShouldProcess($pdfPath, "Print $($render.RowCount) row(s) and $($columns.Count) column(s) to PDF")) {
                return [pscustomobject]@{
                    PSTypeName  = 'Office365Tools.PdfExport'
                    Path        = $pdfPath
                    HtmlPath    = $(if ($KeepHtml) { $htmlPath } else { $null })
                    Printed     = $false
                    RowCount    = $render.RowCount
                    ColumnCount = $columns.Count
                    Column      = $columns
                    PageCount   = 0
                    Digest      = $render.Digest
                    LinkCount   = @($render.Link).Count
                    Verified    = $false
                    Finding     = @()
                    Browser     = $null
                    Duration    = (Get-Date) - $started
                }
            }

            $print = Invoke-SpoBrowserPrint -HtmlPath $htmlPath -Path $pdfPath `
                -BrowserPath $BrowserPath -TimeoutSecond $TimeoutSecond -PageFooter:$PageFooter
        }
        finally {
            if (-not $KeepHtml) {
                # -WhatIf:$false to match the write above: this is our own
                # temporary file, and a preview that declines to delete it
                # both narrates a file the user never asked about and leaves
                # it behind.
                Remove-Item -LiteralPath $htmlPath -Force -ErrorAction SilentlyContinue -WhatIf:$false
            }
        }

        # -------------------------------------------------------------------
        # Check it.
        # -------------------------------------------------------------------
        $findings = @()
        $pageCount = 0

        if ($SkipVerification) {
            Write-O365Log "Wrote '$pdfPath' without verifying it." 'Warning'
        }
        else {
            $verifyArguments = @{
                Path             = $pdfPath
                Cell             = $render.Cell
                Attestation      = $render.Attestation
                ExpectedRowCount = $render.RowCount
            }
            if (@($render.Link).Count -gt 0) { $verifyArguments['Link'] = $render.Link }
            if ($Sample) { $verifyArguments['Sample'] = $Sample }

            $findings = @(Test-SpoPdfContent @verifyArguments)
            $pageCount = (ConvertFrom-SpoPdfText -Path $pdfPath).PageCount
        }

        $errors = @($findings | Where-Object Severity -eq 'Error')
        $inconclusive = @($findings | Where-Object RuleId -in 'Pdf.NoTextLayer', 'Pdf.ExtractionSuspect')

        $verified = -not $SkipVerification -and $errors.Count -eq 0 -and $inconclusive.Count -eq 0

        Write-O365Log (
            "Wrote '$pdfPath': $($render.RowCount) row(s), $($columns.Count) column(s), $pageCount page(s), " +
            "$($errors.Count) verification error(s)."
        ) $(if ($errors.Count -gt 0) { 'Warning' } else { 'Success' })

        [pscustomobject]@{
            PSTypeName  = 'Office365Tools.PdfExport'
            Path        = $pdfPath
            HtmlPath    = $(if ($KeepHtml) { $htmlPath } else { $null })
            Printed     = $true
            RowCount    = $render.RowCount
            ColumnCount = $columns.Count
            Column      = $columns
            PageCount   = $pageCount
            Digest      = $render.Digest
            LinkCount   = @($render.Link).Count
            Verified    = $verified
            Finding     = $findings
            Browser     = $print.Browser
            Duration    = (Get-Date) - $started
        }
    }
}
