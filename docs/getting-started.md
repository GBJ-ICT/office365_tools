# Getting started

Assumes you have connected — see [authentication.md](authentication.md) if not.

```powershell
Import-Module ./src/Office365Tools
Connect-O365
```

## Finding your way around

```powershell
Get-Command -Module Office365Tools
Get-Command -Module Office365Tools -Noun *Permission*
Get-Help Test-SpoLibraryHealth -Full
Get-Help Get-SpoPermissionMismatch -Examples
```

## Workflow: audit a library

```powershell
Test-SpoLibraryHealth -Library Documents
```

Output is finding objects, so ordinary PowerShell works on it:

```powershell
# What kinds of problem, and how many of each?
Test-SpoLibraryHealth -Library Documents | Group-Object RuleId | Sort-Object Count -Descending

# Only the things that are actually broken
Test-SpoLibraryHealth -Library Documents -MinimumSeverity Error

# Only naming, which is the cheapest check
Test-SpoLibraryHealth -Library Documents -Rule Naming

# Something to send to a colleague
Test-SpoLibraryHealth -Library Documents |
    Export-SpoReport -Path out/health.html -Title 'Documents health'
```

Every `RuleId` is explained in [health-rules.md](health-rules.md).

To audit the whole site at once:

```bash
pwsh ./scripts/Invoke-LibraryAudit.ps1
```

## Workflow: fix permission drift

Someone breaks inheritance on a file to share it, and years later nobody knows
which of a thousand items have special permissions or why.

**Look first.**

```powershell
Get-SpoPermissionMismatch -Library Documents
```

`-MinimumDepth 2` skips top-level folders, which are usually restricted
deliberately:

```powershell
$mismatches = Get-SpoPermissionMismatch -Library Documents -MinimumDepth 2
$mismatches | Format-Table Depth, Kind, Name, RelativePath
```

**Keep a record.** SharePoint does not retain discarded permissions, so this file
is your only undo:

```powershell
$mismatches | Export-Csv out/permissions-before.csv -NoTypeInformation
```

**Preview.**

```powershell
$mismatches | Repair-SpoPermissionInheritance -WhatIf
```

**Act.**

```powershell
$mismatches | Repair-SpoPermissionInheritance
```

You will be prompted per item, because `ConfirmImpact` is `High`. To run it
unattended after reviewing the `-WhatIf` output:

```powershell
$mismatches | Repair-SpoPermissionInheritance -Confirm:$false
```

### Who can see what?

```powershell
Get-SpoPermissionReport -Library Documents | Export-Csv out/permissions.csv -NoTypeInformation

# What can one person reach?
Get-SpoPermissionReport -Library Documents -ExpandGroups |
    Where-Object PrincipalLogin -like '*anna*'
```

### Leftovers from deleted accounts

```powershell
Find-SpoOrphanedPermission -Library Documents
Find-SpoOrphanedPermission -Library Documents -IncludeEmptyGroups
```

## Workflow: content types

### Interactively

```bash
pwsh ./scripts/Manage-ContentType.ps1
pwsh ./scripts/Manage-ContentType.ps1 -ProfileName cds -Group 'Custom Content Types'
```

A menu-driven front end over the commands below:

```
  [1] List content types
  [2] Inspect a content type
  [3] Create a content type
  [4] Add columns to a content type
  [5] Remove columns from a content type
  [6] Create a site column
  [Q] Quit
```

Pickers accept `1,3,5`, ranges like `2-6`, `all`, and `/text` to filter a long
list. Nothing is written until you confirm a summary, removals additionally
require typing the content type name, and every action prints the equivalent
command so you can automate it next time.

### Listing and inspecting

```powershell
Get-SpoContentType
Get-SpoContentType -Group 'Custom Content Types'
Get-SpoContentType -Name Contract -IncludeFields | Select-Object -ExpandProperty Fields
Get-SpoContentType -Library Documents          # which types a library uses
```

Built-in content types are hidden by default; `-IncludeBuiltIn` shows them.

### Creating a content type

The parent decides where it can be used — `Document` for libraries, `Item` for
plain lists. This is the mistake people hit most often: a content type inheriting
from `Item` simply will not appear in a document library.

```powershell
New-SpoContentType -Name Contract -Parent Document -Group 'Custom Content Types'
```

### Creating and attaching columns

```powershell
# Find what already exists — matches internal name or display title
Get-SpoField -Group 'Custom Columns'
Get-SpoField -Name '*priorit*'

# Create new ones
New-SpoField -DisplayName 'Contract Value' -Type Currency -Group 'Contract Columns'
New-SpoField -DisplayName 'Status' -Type Choice -Group 'Contract Columns' `
    -Choice 'Draft', 'Signed', 'Expired' -DefaultValue 'Draft'

# Attach them
Add-SpoFieldToContentType -ContentType Contract `
    -Field ContractValue, Status -UpdateChildren

# Or attach a whole group at once
Get-SpoField -Group 'Contract Columns' |
    Add-SpoFieldToContentType -ContentType Contract -UpdateChildren
```

**`-UpdateChildren` is the one to remember.** A site content type already added
to lists exists as independent copies on each of them. Without it, the new column
reaches the site definition only and every list keeps the old shape — which is
exactly the `ContentType.FieldMissingOnListCopy` drift that
`Test-SpoContentTypeLink` reports later.

Internal names are permanent. `Priorität` created through the German UI is
internally `Priorit_x00e4_t` forever, no matter how it is renamed afterwards.
`New-SpoField` derives an ASCII internal name from the display name unless you
pass `-InternalName`.

### Everything else

**What breaks if I delete this column?**

```powershell
Find-SpoContentTypeByColumn -ColumnName Priority
```

**Remove it, having seen the blast radius:**

```powershell
Find-SpoContentTypeByColumn -ColumnName Priority | Remove-SpoFieldFromContentType -WhatIf
Find-SpoContentTypeByColumn -ColumnName Priority | Remove-SpoFieldFromContentType
```

**Find broken and drifted links.** When a site content type is added to a list,
SharePoint copies it. The copy does not follow later changes to the parent:

```powershell
Test-SpoContentTypeLink
Test-SpoContentTypeLink -Library Contracts
```

**Push parent changes down:**

```powershell
Sync-SpoContentType -ContentType 'Contract' -WhatIf
Sync-SpoContentType -ContentType 'Contract'
```

`Sync-SpoContentType` only adds fields. It never removes them, because a field
on a list copy but not on the parent may hold data that exists nowhere else.

**Attach a content type to a library:**

```powershell
Add-SpoContentTypeToList -Library Contracts -ContentType 'Contract' -SetDefault
```

Content type management is enabled on the list automatically if it is off — a
step that is easy to forget and produces a confusing "nothing happened".

## Workflow: bulk list items

**Discover the internal field names.** This is the step people skip, and it is
the cause of most import failures — internal names differ from display titles
whenever a column was renamed, and on any non-English site:

```powershell
Get-PnPField -List Tasks | Where-Object { -not $_.Hidden } | Select-Object InternalName, Title
```

**Validate, then import:**

```powershell
Import-SpoListItem -Path data/tasks.csv -Library Tasks -WhatIf
Import-SpoListItem -Path data/tasks.csv -Library Tasks
```

Columns and required fields are checked before anything is written.

**Excel in a German or French locale exports semicolon-delimited CSV:**

```powershell
Import-SpoListItem -Path data/tasks.csv -Library Tasks -Delimiter ';'
```

**Headers that do not match field names:**

```powershell
Import-SpoListItem -Path data/tasks.csv -Library Tasks -Mapping @{
    'Task name' = 'Title'
    'Owner'     = 'AssignedTo'
}
```

**Single items:**

```powershell
Add-SpoListItem -Library Tasks -Values @{ Title = 'Review budget'; Status = 'Open' }
Update-SpoListItem -Library Tasks -Id 42 -Values @{ Status = 'Done' }
```

`-SystemUpdate` changes values without bumping Modified, creating a version, or
firing workflows — right for bulk corrections that are bookkeeping rather than
real content changes:

```powershell
Update-SpoListItem -Library Tasks -Id 42 -Values @{ Reviewed = $true } -SystemUpdate
```

**Export:**

```powershell
Export-SpoListItem -Library Tasks | Export-Csv out/tasks.csv -NoTypeInformation
```

Export output is exactly what import consumes, so exporting one row is the
fastest way to build a correct import template.

## Workflow: verify an upload

```powershell
Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports
Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports -DifferencesOnly
Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports -CompareSize
```

Every file is emitted with a `Status` of `Match`, `MissingRemote`,
`MissingLocal`, or `SizeDiffers`:

```powershell
$result = Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports
$result | Group-Object Status | Select-Object Name, Count
```

## Checking names offline

No connection needed, so this works in a script that generates file names:

```powershell
Test-SpoFileName -Name 'Q1 report: draft.docx'
Get-ChildItem C:\ToUpload -Recurse -File | ForEach-Object { $_.Name } | Test-SpoFileName
```

## Logging a session

```powershell
Start-O365Log -Name maintenance
# ... commands ...
Stop-O365Log
```

Writes narration to `out/maintenance_<timestamp>.log`. This logs *what happened*,
not results — for results, use `Export-SpoReport` or `Export-Csv`.

## Related

- [Authentication](authentication.md)
- [Health rules](health-rules.md)
- [Migration from the old scripts](migration.md)
