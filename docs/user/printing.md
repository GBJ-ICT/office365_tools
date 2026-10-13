# Printing a list to PDF

Two commands and one script:

| | |
|---|---|
| `Export-SpoListPdf` | Reads a list, renders a page, prints it, verifies it |
| `Test-SpoPdfContent` | The verification on its own, against any PDF and any rows |
| `scripts/Export-ListToPdf.ps1` | Connect, print, verify, write the report |

## Why not just print from the browser

Because the result is not reproducible, and the way it fails is silent.

A modern SharePoint list is a **virtualised grid**. The rows you can see are in
the page; the rest are not there at all until you scroll to them. Printing takes
what is in the page, so a 200-row list prints the 30 rows that happened to be
rendered. What comes out looks like a document.

The layout is computed for the **window, at its current zoom**. Column widths
are a function of the viewport width divided by the zoom factor, so the same
list printed at 100% and at 125% has different column widths — and therefore
cuts off different text at the right margin. Nothing marks a truncated cell:
the text is simply not on the paper. This is why the same list printed twice
comes out differently, and why checking the result by eye never quite settles
the question.

## What this does instead

It does not print the list. It reads the items and renders its own page:

- `@page { size: A4 landscape; margin: 12mm; }` — the sheet is fixed in the
  document, so the layout is a function of the paper, not of a viewport.
- Sizes are in **pt and mm**, never px. A CSS pixel is exactly the unit a zoom
  level changes.
- `thead { display: table-header-group; }` — the header row repeats on every
  page. This is the first thing a hand-print loses.
- `break-inside: avoid` on rows — no row is ever split across a page.
- `overflow-wrap: anywhere`, no `table-layout: fixed`, no `text-overflow`, no
  `white-space: nowrap`, no fixed heights. A cell grows and wraps; it never
  clips. Every one of those four properties is a way for a cell to hide its own
  contents.

A headless Edge or Chrome then converts that to PDF with
`--force-device-scale-factor=1` and a scratch `--user-data-dir`, so no browser
profile, print setting, extension or zoom level can reach the output.

Nothing is uploaded anywhere. The browser is used offline, on a local file.

## Verification

The exported PDF's text is read back out and every printed value is looked for
in it. This is the part worth having, and it is on by default:

```powershell
$export = Export-SpoListPdf -Library Dienste -Path out/dienste.pdf
$export.Verified      # $true only when every printed value was found again
$export.Finding       # what was not
```

Matching is forgiving about shape and unforgiving about substance. A value that
wrapped across two lines, was drawn with a ligature, or came back with a
non-breaking space still counts as present. A value that was clipped by a
column boundary, dropped at a page break, or truncated does not — a browser
does not draw glyphs it clips, so a clipped cell really is absent from the file.

The document ends with a line reading

```
Rows 86 / Columns 7 / Digest A1B2C3D4 / End of report
```

Finding it in the PDF proves the document runs to the end of the data rather
than stopping at a page boundary — the failure a page count cannot see. The
digest is over the rendered values: two exports of the same rows carry the same
eight characters, and one row different makes them differ. It is the quickest
way to answer "is this printout the current one".

### Rule IDs

| `RuleId` | Severity | Meaning |
|---|---|---|
| `Pdf.Missing` | Error | The PDF is not there |
| `Pdf.NotAPdf` | Error | The file does not start with `%PDF-` |
| `Pdf.NoPages` | Error | No pages in the document |
| `Pdf.MissingValue` | Error | A printed value is not in the PDF. Row and column are in `Detail` |
| `Pdf.MoreMissingValues` | Error | How many further values were missing beyond `-MaxFinding` |
| `Pdf.TruncatedDocument` | Error | The closing attestation line is absent |
| `Pdf.RowCountMismatch` | Error | The PDF attests to a different row count than was exported |
| `Pdf.NoTextLayer` | Warning | The text could not be read, so nothing was verified |
| `Pdf.ExtractionSuspect` | Warning | Over 40% of values missing — usually a reader problem, not a data one |
| `Pdf.NothingToCheck` | Warning | No rows were supplied to check against |
| `Pdf.WrappedValues` | Info | How many values were printed across a line break |
| `Pdf.MissingLink` | Error | A cell was printed but carries no clickable link |
| `Pdf.MoreMissingLinks` | Error | How many further links were missing beyond `-MaxFinding` |
| `Pdf.NoLinks` | Error | Links were rendered and the PDF has no link annotations at all |

`Pdf.MissingValue` in bulk almost always means **too many columns for the
paper**. Lower `-FontSize`, use `-PaperSize A3`, or print fewer columns.

A `Warning` never means "verified". `Export-SpoListPdf` sets `Verified` to
`$false` when the check could not be carried out, and says so, rather than
reporting a pass it did not establish.

### Verifying a PDF you did not just make

`Test-SpoPdfContent` needs no connection and no export. Give it the file and
what should be in it:

```powershell
Import-Csv out/expected.csv | Test-SpoPdfContent -Path archive/2026-06-dienste.pdf |
    Export-SpoReport -Path out/check.html
```

## Clickable links

Links survive into the PDF as real annotations, so a printed ticket list is
still a way back into SharePoint. Three sources, and the first two need no
parameter at all:

**A value that is already a link.** A Hyperlink column, or any cell holding a
URL, becomes clickable on its own. `-NoAutoLink` turns that off and prints
them as plain text. A value has to carry a scheme to count: `name@site` on its
own stays text, because a list column of those is more often an account or a
reference than a mailbox.

**`-ItemLink`**, naming a printed column whose cells should lead back to the
item they came from. The display form URL is worked out from the list:

```powershell
Export-SpoListPdf -Library 'ICT Support Ticket' -View 'Ungeschlossene Tickets' `
    -Path out/tickets.pdf -ItemLink Title
```

**`-LinkColumn`**, a column-to-template map for anything else. `{Name}` is
replaced with that column's value from the row and escaped for a URL;
`{Name:raw}` inserts it verbatim, for a value that is itself a path:

```powershell
Export-SpoListPdf -Library Projekte -Path out/projekte.pdf -LinkColumn @{
    Nummer = 'https://contoso.sharepoint.com/sites/CDS/Lists/p/DispForm.aspx?ID={ID}'
    Akte   = 'https://contoso.sharepoint.com/{Pfad:raw}'
}
```

`-LinkFormatter` takes a script block (value, column, row) for a URL a template
cannot express, and wins over `-LinkColumn`.

The href comes from the **raw** value while the text comes from the renderer,
so a `-CellFormatter` that shortens a 200-character URL to `Ticket 42` leaves
the link pointing where the data says.

Only `http`, `https`, `mailto` and `tel` are printed as links. List content is
someone else's text and the print runs from a local file, so a `javascript:`
value in a cell would otherwise be list data choosing what the browser
executes.

### Links are checked too

A link in a PDF is not text — it is an annotation over a rectangle, carrying a
`/URI` action. Reading the page back therefore proves nothing about the links,
and a document whose text verifies perfectly can have lost every one of them.
So they are verified separately, against the annotations themselves:
`Pdf.MissingLink` names the row and column of a cell that printed without its
link, and `LinkCount` on the result says how many the document carries.

## Layout

Three levels, in the order to reach for them.

**1. Parameters.**

```powershell
Export-SpoListPdf -Library Dienste -Path out/dienste.pdf `
    -PaperSize A3 -Orientation Landscape -FontSize 7.5 -Margin '10mm' `
    -GroupBy Gefaess -SortBy Datum -RowNumber -Subtitle 'Saison 2026/27'
```

**2. `-ColumnWidth` and `-Css`.** Every cell carries a `col-<column>` class
built from the column's internal name, lower-cased, with anything that is not a
letter or digit turned into a dash:

```powershell
Export-SpoListPdf -Library Dienste -Path out/dienste.pdf `
    -ColumnWidth @{ Bemerkungen = '30%'; Titel = '20%' } `
    -Css @'
td.col-datum { white-space: nowrap; }
td.col-bemerkungen { font-size: 7pt; }
tbody tr:nth-child(even) td { background: #ffffff; }
'@
```

`-ColumnWidth` is a hint, not a cap: a column still grows rather than clipping.

**3. `-CellFormatter`** for a value that should print as something other than
itself:

```powershell
Export-SpoListPdf -Library Dienste -Path out/dienste.pdf -CellFormatter {
    param($Value, $Column)
    if ($Column -eq 'Datum' -and $Value) { ([datetime]$Value).ToString('ddd dd.MM.') } else { $Value }
}
```

What the formatter returns is HTML-encoded like any other value, and it is what
verification then looks for — the check always runs against the strings that
were actually printed.

### Working on a layout

`-KeepHtml` leaves the intermediate HTML next to the PDF. That is the file to
iterate on: open it in a browser, Ctrl+P, look, change the CSS, reload. Once it
is right, move the rule into `-Css`.

## Printing something other than a list

Anything with properties prints:

```powershell
Test-SpoLibraryHealth -Library Documents | Export-SpoListPdf -Path out/health.pdf
Get-SpoDocumentSetRegisterEntry -Library Projekte -Register Mappen |
    Export-SpoListPdf -Path out/register.pdf -Field Title, Action, DocumentId
Import-Csv data/rows.csv | Export-SpoListPdf -Path out/rows.pdf
```

## Requirements and limits

**A Chromium-based browser.** Edge, Chrome, Chromium or Brave. Edge is on every
Windows install and is tried first; `-BrowserPath` points at a specific one.

**A link's text still has to fit.** A link is verified as an annotation and its
caption as text, so a URL clipped at a column boundary is reported as a missing
*value* even though the link itself is intact. Shorten the caption with
`-CellFormatter` rather than the URL.

**Page numbers need `-PageFooter`.** Chromium implements no CSS counter for the
page number, so the only source of "page 3 of 8" is the browser's own header and
footer — which also prints the temporary file's path. It is off by default.

**`pdftotext` is used if present.** Poppler's `pdftotext` on `PATH` is a more
complete implementation of the text extraction than the built-in reader, and is
preferred automatically. The built-in one handles what a browser produces
(Flate-compressed content streams, subset fonts with `/ToUnicode` maps) and is
what the tests run against; `-NoExternalReader` forces it.

**Verification proves presence, not position.** It establishes that every value
is somewhere in the document. It does not check that a value is in the right
column on the page, and it cannot see a value printed white-on-white. The
layout is what makes those unlikely; the check is what makes an absent value
impossible to miss.

**Very wide lists.** Twenty columns do not fit on A4 landscape at a readable
size whatever the tool does. The honest options are fewer columns, A3, or a
smaller font — and the verification pass is what tells you which of those you
still need.
