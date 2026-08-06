# Document Sets

A Document Set holds metadata that its contents are supposed to carry too. When
that stops happening, the library still looks fine — the Document Set has the
right values, and the drift is only visible if you open a document or group a
view by the column. This is how to find it, fix it, and stop it recurring.

## How the sync actually works

SharePoint copies a column's value from a Document Set down to its contents
**only if that column is registered as a shared column** on the Document Set
content type. Shared columns are pushed:

- when a document is **uploaded into** the Document Set, and
- when the Document Set's **properties are saved**.

That is the whole mechanism. It has four consequences that account for almost
every out-of-sync library:

| What happened | Why it drifted |
|---|---|
| A column was added to the Document Set content type later | It is on the content type but was never registered as *shared*, so it has never been pushed anywhere |
| Files were **moved or copied in** rather than uploaded | Copy preserves the source's metadata; no push runs |
| The Document Set was updated by a script using `SystemUpdate` | `SystemUpdate` writes the item without running the push-down |
| The Document Set contains **folders** | The push targets documents; subfolders keep whatever they were created with |

Two more worth knowing: registering a column as shared does **not** backfill
what is already there — SharePoint pushes on the next save, so existing
contents stay as they are until something writes them; and a push over a large
Document Set can fail part-way and is never retried.

## Check

```powershell
pwsh ./scripts/Test-DocumentSetSync.ps1
```

Read-only. With no `-Library` it examines every visible document library and
skips the ones without Document Sets, so libraries do not have to be listed and
a newly added one is picked up automatically. Name them to go faster:

```powershell
pwsh ./scripts/Test-DocumentSetSync.ps1 -Library Projekte, Management, Produkte
```

It writes to `out/documentset-sync-<timestamp>/`:

| File | What is in it |
|---|---|
| `metadata-drift.csv` | One row per column difference: Document Set, item, column, the Document Set's value, the item's value, and why they differ |
| `metadata-drift.html` | The same, as a report you can send to someone |
| `configuration.html` | Columns that cannot sync at all, with the command to fix each |
| `check.log` | What the run did |

The same thing as commands, when you want to slice it yourself:

```powershell
Get-SpoDocumentSet -Library Projekte                    # what is in there, and what it shares
Get-SpoDocumentSetMismatch -Library Projekte            # contents that have drifted
Test-SpoDocumentSetSharedColumn -Library Projekte       # why they drifted
```

Where the drift is:

```powershell
$drift = Get-SpoDocumentSetMismatch -Library Projekte

$drift | Select-Object -ExpandProperty Difference |
    Group-Object Field | Sort-Object Count -Descending    # worst columns
$drift | Group-Object Kind                                 # files vs folders
$drift | Group-Object DocumentSet | Sort-Object Count -Descending
```

`Reason` on each difference says what kind of problem it is:

| Reason | Meaning |
|---|---|
| `EmptyOnItem` | The Document Set has a value, the item has none. The ordinary "never got pushed" case |
| `ValueDiffers` | Both have values and they disagree. Usually a copied-in file carrying its old metadata |
| `EmptyOnDocumentSet` | The item has a value the Document Set does not. **Not repaired by default** — see below |
| `ColumnMissingFromLibrary` | A shared column that does not exist on the library. Cannot be repaired by writing a value; add the column first |

## Fix the data

```powershell
pwsh ./scripts/Repair-DocumentSetSync.ps1 -WhatIf    # every write it would make
pwsh ./scripts/Repair-DocumentSetSync.ps1            # do it
```

A `before.csv` is written either way — including under `-WhatIf` — so there is
always a record of the previous values.

Or as commands, which is the same thing with the steps visible:

```powershell
$drift = Get-SpoDocumentSetMismatch -Library Projekte
$drift | Export-Csv out/before.csv -NoTypeInformation
$drift | Repair-SpoDocumentSetMetadata -WhatIf
$drift | Repair-SpoDocumentSetMetadata
```

Three things about the repair:

**The Document Set wins.** Metadata lives on the Document Set; contents carry a
copy. If a document is genuinely supposed to differ, the column should not be a
shared column.

**Empty values are not pushed.** If the Document Set's column is empty and the
item's is not (`EmptyOnDocumentSet`), the item keeps its value — writing would
delete the only copy of it. `-ClearEmpty` overrides that when the Document Set
really is the authority.

**Version history is the undo.** By default each change creates a version, so
the previous metadata stays recoverable. `-SystemUpdate` skips versioning and
leaves `Modified`/`Editor` alone — tidier, and genuinely irreversible.

Folders only, which is the part SharePoint never does for you:

```powershell
Get-SpoDocumentSetMismatch -Library Projekte |
    Where-Object Kind -eq 'Folder' |
    Repair-SpoDocumentSetMetadata
```

## Fix the cause

Repairing the data without this means repairing it again next month.

```powershell
Test-SpoDocumentSetSharedColumn -Library Projekte |
    Where-Object RuleId -eq 'DocumentSet.ColumnNotShared'
```

Each finding carries the exact command in `Detail.Remedy`:

```powershell
Set-PnPDocumentSetField -DocumentSet 'Projekt' -Field ProjectStatus -SetSharedField
```

Then repair the existing contents once, because registering the column does not
backfill them. After that SharePoint keeps them in step on its own — for
documents. Folders will drift again, so a scheduled
`Test-DocumentSetSync.ps1` is worth having.

See [health-rules.md](health-rules.md#documentset) for what each `DocumentSet.*`
finding means.

## Register them in a list

A separate problem from metadata sync: keeping a flat list — a *register* —
that indexes the Document Sets spread across several libraries, one row each,
carrying their metadata plus a link back to the folder.

```bash
pwsh ./scripts/Sync-DocumentSetRegister.ps1                       # plan only
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path> -WhatIf  # preview
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path>          # write
pwsh ./scripts/Sync-DocumentSetRegister.ps1 -RelabelExisting      # pass two only
```

The plan is a CSV. Editing it before applying is the intended workflow, not an
escape hatch: `Title` is copied verbatim from the Document Set, and verbatim is
rarely right for every one of them.

Scripted, the same thing:

```powershell
Get-SpoDocumentSetRegisterEntry -Library Management, Projekte -RegisterList Index `
    -ReferenceField Link -DocumentIdField DocId -ContentTypeMap @{
        Management = 'Management Entry'
        Projekte   = 'Project Entry'
    } | Add-SpoListItem -Library Index

Update-SpoListItemLinkText -Library Index -Field Link -TextField Name_x0020_ID
```

### One content type per library

A register usually classifies its rows by where they came from, so
`-ContentTypeMap` says which of its content types goes with which library.
Without it every row lands in the list's default content type, which is only
right if there is one.

The mapping has to be given because it cannot be worked out. Content types are
named for the kind of thing (`Project Entry`), libraries for the collection
(`Projekte`), and a rule that gets that correspondence right most of the time is
worse than no rule — it misfiles the exceptions silently. The map is validated
against the register before anything is read, so a typo names the content types
that do exist rather than failing once per row.

### Why it is two passes

The register's link text usually comes from a **calculated** column, and a
calculated column has no value until the item exists. It therefore cannot be
part of the write that creates the item. Pass one writes the rows and their
link URLs; pass two reads back what SharePoint calculated and sets the link text
from it.

`-RelabelExisting` with no `-Plan` runs pass two alone, over every row. That is
what to run after editing Titles by hand: the calculated column follows the
Title immediately, and the link text does not follow it until this is re-run.

Which hyperlink gets labelled is `-LinkField`, and where its text comes from is
`-LinkTextField`. Labelling the Document ID column is the usual choice — the
link then reads `HG4425-ÄB` rather than `GBJCDS-204499463-31` while still
pointing at the same `DocIdRedir.aspx` URL, which is the one link to a Document
Set that a rename or a move cannot break.

Relabelling that column is safe **because matching reads the ID out of the URL,
never out of the link text.** The two agree until someone relabels; keying on the
text would mean a friendlier register matches nothing at all, and the next sync
duplicates every row in it.

### Which columns are copied

Columns are matched by **internal name**: a column on both the register and the
Document Set is copied across, with person, lookup, managed metadata and
hyperlink values translated to their writable form. That overlap is the whole
mapping — there is no table of column names in the module. `-ColumnMap` handles
names that differ, `-ExcludeColumn` drops one.

Two columns are built rather than matched, because the Document Set has no
equivalent to copy: `-ReferenceField` (the library's default view plus `?id=`
pointing at the folder — the link that opens it *in* its library rather than as
a bare folder listing) and `-DocumentIdField` (mirroring `_dlc_DocIdUrl`).

`-ReferenceField` is optional, and a register with a Document ID column has
little use for it. Both links open the Document Set; only one of them is a path,
and paths go stale when a folder is renamed or moved.

### What counts as "already registered"

The Document ID, not the name. A Document ID is assigned once and survives a
rename and a move to another library, so renaming a Document Set updates nothing
and creates no duplicate.

### What happens when a Document Set moves library

Surviving a move is what makes the Document ID the right key, and it is also
what creates the one case where an existing row is wrong rather than missing.
The row is found — correctly — but it is filed under the content type of the
library the Document Set used to be in, and a reference column, if the register
has one, still links there.

That row is planned as an **Update**, and the write pass changes exactly those:
its content type, and its reference URL. A register keyed on the Document ID
link alone has nothing but the content type to repair, since a `DocIdRedir` URL
follows the Document Set wherever it goes.

```powershell
Get-SpoDocumentSetRegisterEntry -Library Management, Projekte -RegisterList Index `
    -ReferenceField Link -ContentTypeMap $map |
    Where-Object Action -eq 'Update' |
    Select-Object Name, SourceList, CurrentContentType, ContentType
```

**Nothing else is touched.** The metadata columns are not rewritten from the
source, on an Update or ever. A register is edited by hand — Titles get
shortened, entries annotated — and re-copying every column on each run would
undo that work. If you do want a column refreshed, put the value in the plan
CSV; the write pass writes whatever cells the plan has filled in.

Two comparisons are deliberately skipped. A library with no `-ContentTypeMap`
entry is never reclassified, because no mapping means no opinion about where
its rows belong, not an opinion that they belong nowhere. And references that
differ only in casing are not drift — SharePoint rewrites URL casing on its
own, and treating that as a change would rewrite every row every run.

It has one failure mode worth knowing. **Copying a Document Set copies its
Document ID.** The Document ID service assigns an ID on creation and does not
re-issue one for a copy, so two folders can carry the same ID indefinitely. When
that happens they are indistinguishable to the matcher: the first is matched and
the rest are treated as already registered. `Get-SpoDocumentSetRegisterEntry`
warns about duplicate keys it finds in the register; for the source side, look
for repeated `DocumentId` values in the plan CSV. Use `-KeyField` with the
reference column instead if a library has copies that must each get a row.

## Cost

Each library is read once, in pages, and the hierarchy is worked out from the
URLs rather than with a request per Document Set. Document Set templates are
resolved once per content type, not once per Document Set. A library of a few
thousand items is a minute or two; lower `-PageSize` if you hit throttling.

## Related

- [Health rules](health-rules.md) — every `RuleId` and what to do about it
- [Getting started](getting-started.md)
