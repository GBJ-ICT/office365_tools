<#
.SYNOPSIS
    Internal: renders rows as a print-ready HTML document with a fixed,
    zoom-independent page layout.
.DESCRIPTION
    This is the half of the PDF export that decides what the page looks like.
    It exists because printing a SharePoint view from the browser does not
    produce a document: the modern list is a virtualised grid, so what reaches
    the printer is whatever happened to be scrolled into view, at whatever zoom
    the window was at, with columns cut off at the right margin and no way to
    tell which ones.

    What this emits instead is a plain table sized in points and millimetres,
    which the browser maps onto paper the same way every time, at any window
    size and any zoom level:

      * '@page' fixes the sheet and its margins, so the layout is a function of
        the paper rather than of the viewport.
      * The header row is a 'table-header-group', which repeats it on every
        page -- the thing hand-printing loses first.
      * Rows are 'break-inside: avoid', so no row is split across a page.
      * Cells wrap ('overflow-wrap: anywhere') and are never clipped. Nothing
        here uses 'table-layout: fixed', 'text-overflow', 'nowrap' or a fixed
        height, because each of those lets a cell hide its own contents, which
        is exactly what the verification pass is there to rule out.

    Every cell's text is returned alongside the HTML, so the verifier checks
    the PDF against the strings that were actually rendered rather than
    re-deriving them and possibly differing.

    The document ends with an attestation line carrying the row count and a
    digest of the data. Finding that line in the PDF is what proves the export
    reached the end rather than stopping at a page boundary.
.PARAMETER Row
    Objects to print, in the order they should appear.
.PARAMETER Column
    Property names to print, in column order.
.PARAMETER Header
    Column name to heading text. Columns absent from it keep their own name.
.PARAMETER Title
    Document heading.
.PARAMETER Subtitle
    Second line under the heading, for a filter description or a date range.
.PARAMETER Orientation
    Portrait or Landscape.
.PARAMETER PaperSize
    A3, A4, A5, Letter or Legal.
.PARAMETER Margin
    CSS length for the page margin, e.g. '12mm'.
.PARAMETER FontSize
    Body font size in points. The table scales with it.
.PARAMETER GroupBy
    Column to group rows under: one sub-table with its own repeating header per
    group.
.PARAMETER ColumnWidth
    Column name to CSS width ('18%', '30mm'). A hint -- the table still grows a
    column rather than clipping it.
.PARAMETER Css
    Extra CSS, appended last so it overrides everything above. Every cell
    carries a 'col-<column>' class, which is what this is meant to target.
.PARAMETER CellFormatter
    Script block called per cell with the value and the column name; returns
    the text to print. The return is HTML-encoded like any other value.
.PARAMETER LinkColumn
    Column name to URL template, making that column's cells clickable.
    '{Name}' is replaced with that column's value, escaped; '{Name:raw}'
    inserts it verbatim.
.PARAMETER LinkFormatter
    Script block called per cell with the value, the column name and the row;
    returns a URL, or nothing. Takes precedence over -LinkColumn.
.PARAMETER NoAutoLink
    Do not linkify values that are already URLs or email addresses.
.PARAMETER DateFormat
    Date format for cells holding a DateTime.
.PARAMETER RowNumber
    Print a leading number column, which makes 'is row 41 there' answerable by
    looking.
.OUTPUTS
    PSCustomObject with Html, Column, RowCount, Cell, Link, Digest and
    Attestation.
.EXAMPLE
    $render = ConvertTo-SpoPrintHtml -Row $items -Column Title, Datum -Title 'Duties'
    $render.Html | Set-Content out/duties.html
#>
function ConvertTo-SpoPrintHtml {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Row,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Column,

        [Parameter()]
        [hashtable]$Header = @{},

        [Parameter()]
        [string]$Title = 'SharePoint list',

        [Parameter()]
        [string]$Subtitle,

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
        [string]$GroupBy,

        [Parameter()]
        [hashtable]$ColumnWidth = @{},

        [Parameter()]
        [string]$Css,

        [Parameter()]
        [scriptblock]$CellFormatter,

        [Parameter()]
        [hashtable]$LinkColumn = @{},

        [Parameter()]
        [scriptblock]$LinkFormatter,

        [Parameter()]
        [switch]$NoAutoLink,

        [Parameter()]
        [string]$DateFormat = 'yyyy-MM-dd',

        [Parameter()]
        [switch]$RowNumber
    )

    $encode = { param($Value) [System.Net.WebUtility]::HtmlEncode([string]$Value) }

    # A CSS class per column, so -Css can target one without the caller having
    # to know how the table is built. Anything not a letter or digit becomes a
    # dash: SharePoint internal names carry _x00e4_ style escapes.
    $classOf = { param([string]$Name) 'col-' + ([regex]::Replace($Name, '[^A-Za-z0-9]', '-')).ToLowerInvariant() }

    $rows = @($Row)

    # ---------------------------------------------------------------------
    # Render every cell once, up front. The HTML and the verification list are
    # then two views of the same strings rather than two renderings that can
    # disagree.
    # ---------------------------------------------------------------------
    $cells = [System.Collections.Generic.List[object]]::new()
    $text  = [System.Collections.Generic.List[object]]::new()
    $links = [System.Collections.Generic.List[object]]::new()
    $href  = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $rows.Count; $index++) {
        $record = [ordered]@{}
        $target = [ordered]@{}

        foreach ($name in $Column) {
            $value = if ($null -ne $rows[$index].PSObject.Properties[$name]) {
                $rows[$index].PSObject.Properties[$name].Value
            }
            else {
                $null
            }

            $rendered = if ($CellFormatter) {
                [string](& $CellFormatter $value $name)
            }
            else {
                ConvertTo-SpoCellText -Value $value -DateFormat $DateFormat
            }

            $record[$name] = $rendered

            # From the raw value, not the rendered text: a -CellFormatter that
            # shortens a URL to 'Ticket 42' should not also shorten where the
            # link goes.
            $target[$name] = Get-SpoCellLink -Value $value -Column $name -Row $rows[$index] `
                -LinkColumn $LinkColumn -LinkFormatter $LinkFormatter -NoAutoLink:$NoAutoLink

            if (-not [string]::IsNullOrWhiteSpace($rendered)) {
                $cells.Add([pscustomobject]@{
                        Row    = $index + 1
                        Column = $name
                        Text   = $rendered
                    })

                if ($target[$name]) {
                    $links.Add([pscustomobject]@{
                            Row    = $index + 1
                            Column = $name
                            Text   = $rendered
                            Href   = $target[$name]
                        })
                }
            }
        }

        $text.Add($record)
        $href.Add($target)
    }

    # ---------------------------------------------------------------------
    # Digest over the rendered data, printed on the document. Two exports of
    # the same rows carry the same eight characters; one row different, and
    # they differ.
    # ---------------------------------------------------------------------
    $flat = (@($text | ForEach-Object {
                $record = $_
                (@($Column | ForEach-Object { $record[$_] }) -join "`u{001F}")
            }) -join "`u{001E}")

    $digest = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($flat))
    ).Replace('-', '').Substring(0, 8)

    $attestation = "Rows $($rows.Count) / Columns $($Column.Count) / Digest $digest / End of report"

    # ---------------------------------------------------------------------
    # Style. Sizes are in pt and mm on purpose: a length in px is a length in
    # CSS pixels, and a zoom level is precisely a change to how big one of
    # those is.
    # ---------------------------------------------------------------------
    $pageSize = "$PaperSize $($Orientation.ToLowerInvariant())"

    $style = @"
@page { size: $pageSize; margin: $Margin; }
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: #ffffff; color: #000000; }
body { font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif;
       font-size: $($FontSize)pt; line-height: 1.3;
       -webkit-print-color-adjust: exact; print-color-adjust: exact; }
h1 { font-size: $([math]::Round($FontSize * 1.7, 2))pt; margin: 0 0 1mm; }
p.subtitle { font-size: $([math]::Round($FontSize * 1.1, 2))pt; margin: 0 0 1mm; }
p.meta { font-size: $([math]::Round($FontSize * 0.85, 2))pt; color: #444444; margin: 0 0 3mm; }
h2 { font-size: $([math]::Round($FontSize * 1.2, 2))pt; margin: 4mm 0 1.5mm;
     padding-bottom: 0.8mm; border-bottom: 0.6pt solid #666666;
     break-after: avoid; page-break-after: avoid; }
h2 .count { font-weight: normal; color: #444444; }
table { width: 100%; border-collapse: collapse; table-layout: auto; }
thead { display: table-header-group; }
tbody tr { break-inside: avoid; page-break-inside: avoid; }
th, td { border: 0.5pt solid #999999; padding: 1.2mm 1.4mm;
         text-align: left; vertical-align: top;
         white-space: normal; overflow-wrap: anywhere; word-break: normal;
         overflow: visible; }
th { background: #ececec; font-weight: 600; }
tbody tr:nth-child(even) td { background: #f7f7f7; }
td.rownum, th.rownum { width: 8mm; text-align: right; color: #444444; }
td.empty-cell { color: #999999; }
/* A long URL is one unbreakable word, and a cell that cannot break it widens
   the column until something else clips. anywhere is what keeps the promise
   that a cell wraps rather than hides. */
a { color: #0b57d0; text-decoration: underline; overflow-wrap: anywhere; }
p.attest { margin: 3mm 0 0; font-size: $([math]::Round($FontSize * 0.85, 2))pt;
           color: #444444; border-top: 0.6pt solid #999999; padding-top: 1mm;
           break-before: avoid; page-break-before: avoid; }
div.nothing { padding: 8mm; text-align: center; border: 0.6pt dashed #999999; }
$Css
"@

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine('<!DOCTYPE html>')
    [void]$builder.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    [void]$builder.AppendLine("<title>$(& $encode $Title)</title>")
    [void]$builder.AppendLine("<style>$style</style>")
    [void]$builder.AppendLine('</head><body>')
    [void]$builder.AppendLine("<h1>$(& $encode $Title)</h1>")

    if ($Subtitle) {
        [void]$builder.AppendLine("<p class=""subtitle"">$(& $encode $Subtitle)</p>")
    }

    $site = if ($script:O365State.SiteUrl) { $script:O365State.SiteUrl } else { '' }
    [void]$builder.AppendLine(
        "<p class=""meta"">$(& $encode $site) &middot; " +
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm') &middot; " +
        "$($rows.Count) row(s), $($Column.Count) column(s)</p>"
    )

    if ($rows.Count -eq 0) {
        [void]$builder.AppendLine('<div class="nothing">No rows matched. Nothing to print.</div>')
    }
    else {
        # Group membership by row index, so the numbering stays continuous
        # across groups and the last number can be checked against the count.
        $groups = if ($GroupBy) {
            $keyed = for ($index = 0; $index -lt $rows.Count; $index++) {
                [pscustomobject]@{
                    Index = $index
                    Key   = $(if ($text[$index].Contains($GroupBy)) { $text[$index][$GroupBy] } else { '' })
                }
            }
            @($keyed | Group-Object Key | Sort-Object Name)
        }
        else {
            @([pscustomobject]@{
                    Name  = $null
                    Group = @(0..($rows.Count - 1) | ForEach-Object { [pscustomobject]@{ Index = $_ } })
                })
        }

        foreach ($group in $groups) {
            if ($GroupBy) {
                $label = if ($group.Name) { $group.Name } else { '(empty)' }
                [void]$builder.AppendLine(
                    "<h2>$(& $encode $GroupBy): $(& $encode $label) " +
                    "<span class=""count"">($($group.Group.Count))</span></h2>"
                )
            }

            [void]$builder.AppendLine('<table>')
            [void]$builder.AppendLine('<colgroup>')
            if ($RowNumber) {
                [void]$builder.AppendLine('<col class="rownum">')
            }
            foreach ($name in $Column) {
                $width = if ($ColumnWidth.ContainsKey($name)) { " style=""width: $($ColumnWidth[$name])""" } else { '' }
                [void]$builder.AppendLine("<col class=""$(& $classOf $name)""$width>")
            }
            [void]$builder.AppendLine('</colgroup>')

            [void]$builder.Append('<thead><tr>')
            if ($RowNumber) {
                [void]$builder.Append('<th class="rownum">#</th>')
            }
            foreach ($name in $Column) {
                $caption = if ($Header.ContainsKey($name)) { $Header[$name] } else { $name }
                [void]$builder.Append("<th class=""$(& $classOf $name)"">$(& $encode $caption)</th>")
            }
            [void]$builder.AppendLine('</tr></thead>')

            [void]$builder.AppendLine('<tbody>')
            foreach ($member in $group.Group) {
                $index = $member.Index
                [void]$builder.Append('<tr>')

                if ($RowNumber) {
                    [void]$builder.Append("<td class=""rownum"">$($index + 1)</td>")
                }

                foreach ($name in $Column) {
                    $value = $text[$index][$name]
                    $class = & $classOf $name
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        [void]$builder.Append("<td class=""$class empty-cell"">&ndash;</td>")
                    }
                    else {
                        # Line breaks in a multi-line text column are content;
                        # everything else is encoded and left to wrap.
                        $html = (& $encode $value) -replace '\r?\n', '<br>'

                        # Chromium turns an <a href> into a /Link annotation
                        # with a /URI action, so the link is live in the PDF
                        # rather than printed text that looks like one.
                        $to = $href[$index][$name]
                        if ($to) {
                            $html = "<a href=""$(& $encode $to)"">$html</a>"
                        }

                        [void]$builder.Append("<td class=""$class"">$html</td>")
                    }
                }

                [void]$builder.AppendLine('</tr>')
            }
            [void]$builder.AppendLine('</tbody></table>')
        }
    }

    [void]$builder.AppendLine("<p class=""attest"">$(& $encode $attestation)</p>")
    [void]$builder.AppendLine('</body></html>')

    return [pscustomobject]@{
        Html        = $builder.ToString()
        Column      = $Column
        RowCount    = $rows.Count
        Cell        = $cells.ToArray()
        Link        = $links.ToArray()
        Digest      = $digest
        Attestation = $attestation
    }
}
