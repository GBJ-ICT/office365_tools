# Health rules

Every diagnostic command emits findings carrying a stable `RuleId`. This is the
reference for what each one means and what to do about it.

`RuleId` values are a contract — people filter and suppress on them — so they do
not get renamed casually.

## Severity

| Severity | Meaning |
|---|---|
| `Error` | Broken now, or will break opening/syncing for some user |
| `Warning` | Works today, but is a latent problem or violates convention |
| `Info` | Observation worth surfacing; no action implied |

## Filtering

```powershell
Test-SpoLibraryHealth -Library Documents -MinimumSeverity Error
Test-SpoLibraryHealth -Library Documents | Where-Object RuleId -like 'FileName.*'
Test-SpoLibraryHealth -Library Documents | Where-Object RuleId -notin 'File.Large', 'Folder.Empty'
Test-SpoLibraryHealth -Library Documents -Rule Naming, PathLength
```

---

## FileName.*

From `Test-SpoFileName` and the `Naming` rule group.

### `FileName.IllegalCharacter` — Error

The name contains one of `" * : < > ? / \ |`. SharePoint rejects these outright.
Files usually acquire them from a script or a migration tool that did not
sanitise, or from a system where the character is legal.

**Fix:** rename. Colons are the common one, from titles like `Q1: results`.

### `FileName.TrailingPeriod` — Error

Name ends with `.`. The browser accepts it; the OneDrive sync client refuses to
sync it, so the file silently never reaches anyone's desktop.

**Fix:** strip the period.

### `FileName.ReservedName` — Error

`CON`, `PRN`, `AUX`, `NUL`, `COM0`–`COM9`, `LPT0`–`LPT9`, `.lock`,
`desktop.ini`. Reserved on Windows, so a synced copy cannot be created. Matched
against the stem too — `CON.txt` is reserved.

**Fix:** rename.

### `FileName.ReservedPrefix` — Error

Starts with `~$` or `_vti_`. The first is an Office lock file, which means Word
or Excel crashed while the document was open and left the lock behind. The
second is a SharePoint internal prefix.

**Fix:** `~$` files are almost always safe to delete once nobody has the document
open. Confirm before deleting.

### `FileName.LeadingSpace` / `FileName.TrailingSpace` — Warning

Some clients strip the whitespace, others do not, so the same file ends up with
two names depending on how it was reached. Links break in ways that are very
hard to reproduce.

**Fix:** trim.

### `FileName.TooLong` — Error

Over 255 characters.

**Fix:** shorten. Also check `PathLength.*` — a long name usually comes with a
long path.

### `FileName.RiskyCharacter` — Info

Contains `#` or `%`. Legal in modern SharePoint, but still breaks some older
tools, REST URLs, and third-party integrations. **Off by default** — pass
`-IncludeRisky` to see these.

---

## PathLength.*

From `Test-SpoPathLength` and the `PathLength` rule group. SharePoint Online
allows a decoded server-relative URL of up to 400 characters.

### `PathLength.Exceeded` — Error

Over the limit. Usually the result of a migration that nested folders deeper than
the source, or of a document set inside a folder inside a folder.

**Fix:** shorten folder names near the root — that shortens every path beneath
at once. Or flatten the hierarchy.

### `PathLength.NearLimit` — Warning

Within 50 characters of the limit (tune with `-WarnAt`). Not broken, but it
breaks the moment someone renames a parent folder to something longer or moves
the branch one level deeper.

**Fix:** same as above, at your leisure. This is the rule that lets you act
before users notice.

---

## File.*

### `File.CheckedOut` — Warning

Checked out, so other users see the last checked-in version — or, if it was
never checked in, no file at all. It is invisible to everyone but the person
holding it, who has usually forgotten.

**Fix:** ask them to check it in, or discard the checkout:

```powershell
Set-PnPFileCheckedIn -Url $finding.Target -CheckinType MajorCheckIn
```

### `File.DuplicateName` — Info

The same file name appears in more than one folder. Sometimes deliberate
(`README.md` per project), sometimes a copy someone made and forgot. `Detail.Paths`
lists every location.

**Fix:** judgement call. Worth reviewing when the count is high.

### `File.Large` — Info

Over `-LargeFileThresholdMb` (250 MB by default). Slow to sync, and above 250 GB
SharePoint rejects the upload entirely.

**Fix:** consider whether it belongs in a document library at all.

### `File.VersionBloat` — Info

Version history occupies more than `-VersionBloatRatio` times the live file
(default 10×). A 50 MB file with 40 versions is 2 GB of quota for one document.

**Fix:** reduce the library's version limit, or trim history on the worst
offenders. `Detail.Ratio` ranks them:

```powershell
Test-SpoLibraryHealth -Library Documents -Rule VersionBloat |
    Sort-Object { $_.Detail.Ratio } -Descending | Select-Object -First 20
```

---

## Folder.*

### `Folder.Empty` — Info

No items. Often leftover structure from a migration or a reorganisation.

**Fix:** delete if genuinely unused. Check first — empty folders are sometimes
placeholders holding permissions for a future purpose.

---

## Item.*

### `Item.RequiredFieldEmpty` — Warning

A required column has no value. SharePoint enforces required fields on the
*form*, not on the API, so anything created by a script, a workflow, or a
migration can skip them. Views that group or filter on the column then silently
omit these items.

**Fix:** fill the values, in bulk if there are many:

```powershell
Test-SpoLibraryHealth -Library Documents -Rule RequiredField |
    ForEach-Object { Update-SpoListItem -Library Documents -Id $_.Detail.ItemId -Values @{ Status = 'Unknown' } }
```

---

## Permission.*

### `Permission.DeepUniqueAssignment` — Warning

Unique permissions at depth `-MaxPermissionDepth` or deeper (default 2). Not
wrong in itself, but permissions set deep inside a hierarchy are the ones nobody
remembers and nobody reviews.

**Fix:** investigate with `Get-SpoPermissionMismatch`, then decide.

### `Permission.MismatchWithParent` — Warning

From `Get-SpoPermissionMismatch` (and surfaced by `Invoke-LibraryAudit.ps1`).
Unique permissions that genuinely differ from what would be inherited. Items
whose unique permissions happen to match the parent are *not* reported — they
are harmless and would bury the real findings.

**Fix:**

```powershell
Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2 |
    Repair-SpoPermissionInheritance -WhatIf
```

Export the mismatches before repairing. SharePoint does not keep a copy of the
permissions you discard.

### `Permission.OrphanedPrincipal` — Warning

A role assignment names an account that no longer resolves — deleted from Entra
ID, but the assignment lingers. Clutters every permission report and makes access
reviews harder each year.

**Fix:**

```powershell
Revoke-SpoPermission -Library Documents -Identity $finding.Detail.LoginName
```

### `Permission.EmptyGroup` — Info

A SharePoint group holds permissions but has no members. Not broken — often a
leftover from a reorganisation. Only reported with `-IncludeEmptyGroups`.

---

## ContentType.*

From `Test-SpoContentTypeLink`. Adding a site content type to a list creates a
*copy*; the copy does not track later changes to the parent.

### `ContentType.OrphanedListCopy` — Error

A list content type with no matching site content type — the parent was deleted.
The list copy still works, but it can never be updated centrally again, and
nobody can tell what it was supposed to be.

**Fix:** recreate the site content type, or migrate items to a different one and
remove the copy with `Remove-SpoContentTypeFromList`.

### `ContentType.FieldMissingOnListCopy` — Warning

The parent gained fields the list copy never received. The usual cause: someone
added a column to the site content type and did not push the change down. Items
in that list are missing metadata everyone assumes is there.

**Fix:**

```powershell
Sync-SpoContentType -ContentType 'Contract' -WhatIf
Sync-SpoContentType -ContentType 'Contract'
```

### `ContentType.FieldOnlyOnListCopy` — Info

The list copy has fields the parent does not — either added directly to the list,
or removed from the parent afterwards. May hold data that exists nowhere else,
which is why `Sync-SpoContentType` never removes fields.

**Fix:** if genuinely obsolete, `Remove-SpoFieldFromContentType`. Check for data
first.

### `ContentType.NameDrift` — Info

The list copy was renamed and no longer matches its parent. Harmless, but it
makes the relationship invisible to anyone reading the list settings.

**Fix:** rename to match, or leave it if the local name is more meaningful.

---

## DocumentSet.*

From `Test-SpoDocumentSetSharedColumn`. A Document Set pushes a column's value
down to its contents only if that column is registered as a *shared* column, so
these findings are about columns that cannot sync at all — as opposed to
`Get-SpoDocumentSetMismatch`, which reports contents that have actually drifted.

See [document-sets.md](document-sets.md) for the whole workflow.

### `DocumentSet.ColumnNotShared` — Warning

The column is on the Document Set content type but is not a shared column.
People fill it in on the Document Set and reasonably expect the documents inside
to carry it; nothing is ever copied anywhere. The usual history is a column
added to the content type some time after it was created.

**Fix:** register it, then repair what already exists — registering does not
backfill.

```powershell
Set-PnPDocumentSetField -DocumentSet 'Projekt' -Field ProjectStatus -SetSharedField
Get-SpoDocumentSetMismatch -Library Projekte | Repair-SpoDocumentSetMetadata
```

`Detail.Remedy` carries the exact first command for each finding.

### `DocumentSet.SharedColumnMissingFromLibrary` — Error

A shared column does not exist on the library at all, so its value cannot be
stored on any item there and the push has nowhere to land. Usually a content
type that was added to the library without its columns, or a column removed
from the library afterwards.

**Fix:** add the column to the library — `Sync-SpoContentType` pushes the
content type's columns down to its list copies.

### `DocumentSet.NoSharedColumn` — Warning

The Document Set content type shares nothing. None of its metadata reaches the
documents inside it, whatever is filled in.

**Fix:** decide which columns should be carried down and register them. If the
answer is genuinely none, the Document Set is being used as a folder and this
finding can be ignored.

### `DocumentSet.SharedColumnMissingFromChildContentType` — Info

A *custom* content type allowed inside the Document Set does not have one of the
shared columns. Base content types (`Document`, `Folder` and friends) are not
reported — every Document Set allows `Document`, and nobody adds custom columns
to it, so reporting it would bury the case worth seeing. The value is still stored on the item — columns are list-scoped — but
it does not appear on that document's form, so users conclude the metadata is
missing and re-enter it, which is how contradictory values appear.

**Fix:** add the column to the child content type, or accept it if the column is
only ever read from views and reports.

### `DocumentSet.TemplateUnreadable` — Error

The Document Set template could not be read, so its shared columns cannot be
verified. Normally a permissions problem: reading the template needs access to
the site content type, which may live in the content type hub.

**Fix:** check the connection has access to the site the content type is defined
on.

---

## Related

- [Getting started](getting-started.md)
- [Document Sets](document-sets.md)
- [Authentication](authentication.md)
