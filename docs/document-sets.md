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

## Cost

Each library is read once, in pages, and the hierarchy is worked out from the
URLs rather than with a request per Document Set. Document Set templates are
resolved once per content type, not once per Document Set. A library of a few
thousand items is a minute or two; lower `-PageSize` if you hit throttling.

## Related

- [Health rules](health-rules.md) — every `RuleId` and what to do about it
- [Getting started](getting-started.md)
