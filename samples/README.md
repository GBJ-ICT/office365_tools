# Samples

Example input files for the bulk commands. Copy one, edit it, point a command at it.

| File | Used by | Notes |
|---|---|---|
| `list-items.example.csv` | `Import-SpoListItem` | Column headers are **internal** field names, not display titles. |

## Finding internal field names

The single most common import failure is using the display title where the
internal name is required — they differ whenever a column was renamed, and on
any non-English site.

```powershell
Get-PnPField -List 'Tasks' | Where-Object { -not $_.Hidden } | Select-Object InternalName, Title
```

If you cannot change the CSV headers, map them instead:

```powershell
Import-SpoListItem -Path samples/list-items.example.csv -Library Tasks -Mapping @{
    'Due date' = 'DueDate'
    'Owner'    = 'AssignedTo'
}
```

## Always dry-run first

`Import-SpoListItem` validates every column and required field before it writes
anything, and `-WhatIf` shows you the result of that validation without
creating a single item:

```bash
pwsh -c "Import-SpoListItem -Path samples/list-items.example.csv -Library Tasks -WhatIf"
```

## Round-tripping

`Export-SpoListItem` produces exactly what `Import-SpoListItem` consumes, so the
quickest way to build a correct import file is to export one row from the target
list and edit it:

```powershell
Export-SpoListItem -Library Tasks | Select-Object -First 1 | Export-Csv template.csv -NoTypeInformation
```
