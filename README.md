# office365_tools

PowerShell tools for administering SharePoint Online: libraries, lists, content
types and permissions. Built on [PnP.PowerShell](https://pnp.github.io/powershell/).

Everything ships as one module with 41 verb-noun commands, so `Get-Help` and tab
completion work the way you already expect.

```powershell
Import-Module ./src/Office365Tools
Connect-O365 -ProfileName prod

Test-SpoLibraryHealth -Library Documents | Export-SpoReport -Path out/health.html
```

## Quick start

**1. Prerequisites**

PowerShell 7.2+ and PnP.PowerShell 3.0+.

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

**2. Register an application** (once per tenant, needs an admin)

```powershell
./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com
```

This prints a client ID. See [docs/authentication.md](docs/authentication.md) if
you already have one, or cannot register applications yourself.

**3. Save a profile**

```powershell
Import-Module ./src/Office365Tools

Set-O365Profile -Name prod `
    -SiteUrl https://contoso.sharepoint.com/sites/team `
    -ClientId <the-client-id> `
    -Tenant contoso.onmicrosoft.com
```

Profiles live in `config/profiles.json`, which is gitignored — your tenant
details never get committed.

**4. Connect and go**

```powershell
Connect-O365
Get-Command -Module Office365Tools
```

## What it does

### Check a library is healthy

```powershell
Test-SpoLibraryHealth -Library Documents
```

Runs ten rule groups in a single pass: illegal file names, paths approaching the
400-character limit, files checked out and invisible to everyone else, empty
folders, duplicate names, oversized files, version-history bloat, empty required
columns, deeply nested unique permissions, and broken content type links.

Everything it finds is a *finding object* with a stable `RuleId`, so you can
filter, group, and diff between runs:

```powershell
Test-SpoLibraryHealth -Library Documents | Group-Object RuleId | Sort-Object Count -Descending
Test-SpoLibraryHealth -Library Documents -MinimumSeverity Error | Export-SpoReport -Path out/errors.html
```

### Fix permission drift

Reading and writing are separate commands, always:

```powershell
# 1. Look
Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2

# 2. Keep a record of what it was
Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2 |
    Export-Csv out/before.csv -NoTypeInformation

# 3. Preview the change
Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2 |
    Repair-SpoPermissionInheritance -WhatIf

# 4. Do it
Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2 |
    Repair-SpoPermissionInheritance
```

### Keep Document Set metadata in sync

Documents and folders inside a Document Set are supposed to carry its metadata.
SharePoint only pushes columns registered as *shared*, only on upload and on
save, and never to subfolders — so libraries drift.

```bash
pwsh ./scripts/Test-DocumentSetSync.ps1        # read-only; reports drift and its cause
pwsh ./scripts/Repair-DocumentSetSync.ps1 -WhatIf
```

Scripted, the same two questions separately — what has drifted, and why:

```powershell
Get-SpoDocumentSetMismatch -Library Projekte | Repair-SpoDocumentSetMetadata -WhatIf
Test-SpoDocumentSetSharedColumn -Library Projekte
```

Comparison is by term GUID and lookup ID, so a renamed term is not reported as a
difference. See [docs/document-sets.md](docs/document-sets.md).

### Index Document Sets in a list

Keeps a flat list — a register — in step with the Document Sets spread across
several libraries: one row each, carrying their metadata and a link back to the
folder.

```bash
pwsh ./scripts/Sync-DocumentSetRegister.ps1                       # plan only
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path> -WhatIf  # preview
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path>          # write
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -RelabelExisting      # pass two only
```

It runs in two passes, and the split is not optional: the register's link text
comes from a calculated column, which has no value until the item exists. Each
library's Document Sets are registered as their own content type.

Matching is on the Document ID — read from the link's URL, not its text, so the
link can be relabelled to read `HG4425-ÄB` instead of `GBJCDS-204499463-31` and
still match. Renaming a Document Set therefore produces no second row, and
*moving* one to another library updates the row it already has, since that is the
case where the register is not missing an entry but filing an existing one under
the wrong library. See [docs/document-sets.md](docs/document-sets.md).

### Stand a test list up against a real one

```bash
pwsh ./scripts/Copy-ListSchema.ps1 -SourceProfile prod -SourceList Tasks \
    -TargetProfile test -TargetList TestTasks                    # read and report
pwsh ./scripts/Copy-ListSchema.ps1 ... -Apply -WhatIf            # preview
pwsh ./scripts/Copy-ListSchema.ps1 ... -Apply -CopyDefaultView   # write
```

Recreates one list's columns on another with the same *internal* names, so a
view, a flow, or a script written against the original addresses the copy
unchanged — which is what makes testing against it mean anything. Choices,
defaults, rich-text settings and the JSON column formatter come across too.

Columns are created local to the target list rather than as site columns: a
local column exists only on the list named and goes away with it, where a site
column is permanent and visible to every list on the site.

Lookup, managed metadata and calculated columns are reported and skipped. Each
carries a reference that does not survive the move — a list GUID, a term set
binding, a formula naming columns that may not be there — and SharePoint accepts
all three without complaint, leaving a column that looks right and never works.

Re-running copies only what is missing; columns the target already has are left
alone, never duplicated and never overwritten.

### Schedule a run of list items

For a list whose rows are a calendar — one entry per service, per duty, per
shift:

```bash
pwsh ./scripts/New-ListItemDateSeries.ps1 -List Duties -DateField Datum \
    -Start 2026-09-06 -Until 2026-12-31 -DayOfWeek Sunday -Interval 2 \
    -Default '{"Status":"planned"}'                              # plan
pwsh ./scripts/New-ListItemDateSeries.ps1 -Plan <path> -WhatIf   # preview
pwsh ./scripts/New-ListItemDateSeries.ps1 -Plan <path>           # write
```

`-Default` takes a hashtable from a PowerShell prompt and JSON from a shell —
`pwsh script.ps1` runs under `-File` semantics, where every argument arrives as
a string and a hashtable literal does not survive the trip.

The entries are created empty on purpose. Scheduling them is the part a script
does well; deciding who is doing what is the part it does not.

Columns may be named the way they read on the list — `Gefäss`, `Inhalt &
Bemerkungen` — or by their internal names — `Gef_x00e4_ss`, `Bemerkungen`.
Either works for `-DateField`, for the keys of `-Default`, for `-DuplicateKey`
and for the headers of a plan CSV. The translation happens when the plan is
written, against the list itself, so a misspelled column fails there with every
column the list has named in the error.

The plan is a CSV and editing it is the intended workflow: any column whose name
does not start with an underscore is written to the list, so changing a date
moves an entry, deleting a row drops it, and adding a column sets it.

Re-running skips entries the list already has. The key defaults to the date
column plus `Bezeichnung` and `Gefäss` — a roster holds several entries per day,
one per duty per vessel, and those three together are what makes one distinct.
`-DuplicateKey` overrides it; whichever of the three the list does not have is
dropped from the key with a note.

The date arithmetic is its own command, and needs no connection:

```powershell
Get-SpoRecurringDate -Start 2026-09-06 -Until 2026-12-31 -DayOfWeek Sunday -Interval 2
Get-SpoRecurringDate -Start 2026-09-01 -Until 2027-06-30 -DayOfWeek Sunday -WeekParity Odd
Get-SpoRecurringDate -Start 2026-09-01 -Count 12 -Frequency Monthly -DayOfWeek Sunday -WeekOfMonth First
```

Note that the first two are different questions. `-Interval 2` counts weeks from
`-Start`, so moving `-Start` by a week shifts the whole series; `-WeekParity Odd`
reads the ISO 8601 week number, so it means the odd weeks on the calendar
whatever `-Start` happens to be. The second is usually what "every other week"
means out loud.

### Bulk-load a list from CSV

```powershell
Import-SpoListItem -Path data/tasks.csv -Library Tasks -WhatIf   # validates first
Import-SpoListItem -Path data/tasks.csv -Library Tasks
```

Column names and required fields are checked against the list *before* the first
item is written, so a bad header fails at row zero rather than row 400.

### Print a list to PDF, and know it is all there

```bash
pwsh ./scripts/Export-ListToPdf.ps1 -ProfileName prod -List 'Aufgaben und Dienste'
pwsh ./scripts/Export-ListToPdf.ps1 -ProfileName prod -List Dienste -View 'Saison 26/27' -GroupBy Gefaess
```

Printing a SharePoint view from the browser is not reproducible, and the reason
is worth knowing: the modern list virtualises its rows, so only what is
scrolled into view is in the page to print, and the layout is computed for the
window at its **current zoom**. Change the zoom and the columns change width,
which changes what gets cut off at the right margin — and nothing tells you
anything was cut off.

So this does not print the list. It reads the items, renders its own page, and
has a headless Edge or Chrome convert that with the device scale factor pinned
to 1. Nothing in the chain depends on a window size or a zoom level: `@page`
fixes the sheet, the header row repeats on every page, rows never split across
a page, and cells wrap instead of clipping.

Then it reads the PDF back and looks for every printed value in it, so
*everything is on there* is established rather than hoped:

```powershell
$export = Export-SpoListPdf -Library Dienste -Path out/dienste.pdf
$export.Verified          # $true only if every printed value was found again
$export.Finding | Export-SpoReport -Path out/check.html
```

A missing value is an `Error` naming its row and column — which is what catches
a cell clipped by a column boundary, since a browser does not draw glyphs it
clips. The document also ends with a line carrying the row count and a digest
of the data; finding that line proves the PDF runs to the end.

Links stay live. A Hyperlink column, or any cell holding a URL, is clickable
in the PDF without asking; `-ItemLink` makes a column lead back to the item it
came from:

```powershell
Export-SpoListPdf -Library 'ICT Support Ticket' -View 'Offene Tickets' `
    -Path out/tickets.pdf -ItemLink Title
```

Links are checked separately from the text, because a link in a PDF is an
annotation rather than a string — a document whose text reads back perfectly
can still have lost every one of them.

Layout is customisable in three steps: parameters for the ordinary cases, `-Css`
for a rule they do not cover, and `-CellFormatter` for a value that should print
as something other than itself. Every cell carries a `col-<column>` class:

```powershell
Export-SpoListPdf -Library Dienste -Path out/dienste.pdf -FontSize 7 -RowNumber `
    -ColumnWidth @{ Bemerkungen = '30%' } -Css 'td.col-datum { white-space: nowrap; }'
```

Anything else in this module prints the same way:

```powershell
Test-SpoLibraryHealth -Library Documents | Export-SpoListPdf -Path out/health.pdf
```

See [Printing](docs/printing.md).

### Audit everything at once

```bash
pwsh ./scripts/Invoke-LibraryAudit.ps1 -Library Documents
```

Read-only. Writes an HTML report per library plus a combined CSV to `out/`.

### Edit content types interactively

```bash
pwsh ./scripts/Manage-ContentType.ps1
```

A menu for listing global content types, inspecting their columns, creating new
ones, and adding or removing columns — with multi-select, a confirmation summary
before every write, and the equivalent command printed each time so the session
doubles as a way to learn the scripted form.

The same thing scripted:

```powershell
Get-SpoContentType
New-SpoField -DisplayName 'Contract Value' -Type Currency -Group 'Contract Columns'
Add-SpoFieldToContentType -ContentType Contract -Field ContractValue -UpdateChildren
```

### Check names before you upload

```powershell
Test-SpoFileName -Name 'Q1 report: draft.docx'
```

Works offline, with no connection — useful in scripts that generate file names.

## Command reference

| Area | Commands |
|---|---|
| **Connection** | `Connect-O365` `Disconnect-O365` `Get-O365Connection` |
| **Profiles** | `Get-O365Profile` `Set-O365Profile` `Remove-O365Profile` |
| **Logging** | `Start-O365Log` `Stop-O365Log` |
| **Permissions** | `Get-SpoPermissionMismatch` `Repair-SpoPermissionInheritance` `Get-SpoPermissionReport` `Find-SpoOrphanedPermission` `Grant-SpoPermission` `Revoke-SpoPermission` |
| **Content types** | `Get-SpoContentType` `New-SpoContentType` `Add-SpoContentTypeToList` `Remove-SpoContentTypeFromList` `Test-SpoContentTypeLink` `Sync-SpoContentType` |
| **Site columns** | `Get-SpoField` `New-SpoField` `Add-SpoFieldToContentType` `Remove-SpoFieldFromContentType` `Find-SpoContentTypeByColumn` |
| **List columns** | `Get-SpoListFieldSchema` `Add-SpoListField` |
| **Scheduling** | `Get-SpoRecurringDate` |
| **Document Sets** | `Get-SpoDocumentSet` `Get-SpoDocumentSetMismatch` `Get-SpoDocumentSetRegisterEntry` `Repair-SpoDocumentSetMetadata` `Test-SpoDocumentSetSharedColumn` |
| **Library health** | `Test-SpoLibraryHealth` `Test-SpoFileName` `Test-SpoPathLength` `Compare-SpoFolder` |
| **List items** | `Add-SpoListItem` `Update-SpoListItem` `Update-SpoListItemLinkText` `Export-SpoListItem` `Import-SpoListItem` |
| **Reporting** | `Export-SpoReport` `Export-SpoListPdf` `Test-SpoPdfContent` |

Full help for any of them:

```powershell
Get-Help Test-SpoLibraryHealth -Full
Get-Help Get-SpoPermissionMismatch -Examples
```

## Design rules

Four rules, applied everywhere. They are what makes the module predictable
enough to hand to someone else.

**Commands emit objects, never console text.** `Export-Csv`, `Where-Object`,
`Group-Object`, `Sort-Object` all work on every command's output without any
special support.

**Reading and writing are different commands.** `Get-SpoPermissionMismatch`
cannot change anything. `Repair-SpoPermissionInheritance` takes its output on
the pipeline. Dry-run is simply not running the second one.

**Every mutating command supports `-WhatIf` and `-Confirm`.** Standard
PowerShell machinery, not a hand-rolled `-Force` switch or a `Read-Host` prompt.

**Nothing tenant-specific is committed.** Site URLs and client IDs live in
`config/profiles.json`; reports and logs go to `out/`. Both are gitignored.

## Repository layout

```
src/Office365Tools/     The module. Public/ is the command surface, Private/ is helpers.
scripts/                Task runners for people who do not want to learn the module.
config/                 profiles.example.json is tracked; profiles.json is not.
samples/                Example CSVs for the bulk commands.
tests/Unit/             Pester tests. No tenant required.
docs/                   Guides beyond what Get-Help covers.
out/                    Reports and logs. Gitignored.
```

## Development

```bash
pwsh ./build.ps1            # lint + test
pwsh ./build.ps1 -Task Test
pwsh ./build.ps1 -Task Import
```

Needs `Pester` 5+ and `PSScriptAnalyzer`:

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
```

Adding a command is one file — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Docs

- [Getting started](docs/getting-started.md) — the common workflows end to end
- [Authentication](docs/authentication.md) — app registration, permissions, troubleshooting
- [Document Sets](docs/document-sets.md) — why the metadata sync breaks, and the two fixes
- [Printing](docs/printing.md) — why a browser print of a list is unreliable, and what this does instead
- [Health rules](docs/health-rules.md) — what every `RuleId` means and what to do about it
- [Migration](docs/migration.md) — mapping from the old loose scripts

## Licence

MIT. See [LICENSE](LICENSE).
