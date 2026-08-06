# Migration from the old scripts

The repository used to be a folder of standalone scripts. Everything they did is
now in the `Office365Tools` module. The old files were removed in the
restructuring commit and remain in git history if you need them:

```bash
git log --diff-filter=D --name-only -- scripts/ util/ modules/
git show <commit>:scripts/verify_upload.ps1
```

## Command mapping

| Old | New |
|---|---|
| `scripts/init.ps1` | `Connect-O365` |
| `util/login.ps1` (`Login`) | `Connect-O365` |
| `scripts/check_pnp_connection.ps1` | `Get-O365Connection` |
| `scripts/check_for_permission_mismatches.ps1` | `Get-SpoPermissionMismatch` **and** `Repair-SpoPermissionInheritance` |
| `scripts/correct_permission_mismatches.ps1` | `Repair-SpoPermissionInheritance` |
| `scripts/find_content_type_by_column.ps1` | `Find-SpoContentTypeByColumn` |
| `scripts/remove_column_from_content_types.ps1` | `Remove-SpoFieldFromContentType` |
| `scripts/verify_upload.ps1` | `Compare-SpoFolder` |
| `scripts/setup_register_pnp_application.ps1` | `scripts/Register-PnPApplication.ps1` |
| `util/logging.ps1` (`Write-LogEntry`) | `Start-O365Log` / `Stop-O365Log` |
| `modules/log.psm1` (`LogInfo`, `LogError`, …) | `Start-O365Log` / `Stop-O365Log` |
| `util/content_type_utils.ps1` | `Find-SpoContentTypeByColumn`, internal helpers |

`scripts/connect_graph.ps1` was **not** migrated. It targets Microsoft Graph
rather than PnP/CSOM, which is a separate surface. It still works standalone.

## What changed, and why

### One connection story

Before, three different mechanisms coexisted: `util/login.ps1` read
`$env:client_id`, `scripts/init.ps1` set `$env:gbj_client_id`, and
`connect_graph.ps1` used `$env:client_id` again. They did not interoperate, and
environment variables outlive the shell that set them — so a session could
silently connect to whichever tenant you last touched.

Now: `Connect-O365`, state held in module scope, tenant details in
`config/profiles.json`.

```powershell
# Before
.\scripts\init.ps1 -client_id "1234abcd-..."

# After (once)
Set-O365Profile -Name prod -SiteUrl https://contoso.sharepoint.com/sites/cds -ClientId 1234abcd-...
# After (every time)
Connect-O365
```

### One logging implementation

There were two: `util/logging.ps1` with `Write-LogEntry -LogFile $x`, and
`modules/log.psm1` with `LogInfo` reading `$env:gbj_current_log_file`. Scripts
mixed them — `verify_upload.ps1` called `LogInfo` without importing anything and
only worked if `init.ps1` had run in the same session.

Now logging is opt-in and internal. Commands narrate to the verbose stream;
`Start-O365Log` also captures that to a file.

```powershell
Start-O365Log -Name maintenance
Test-SpoLibraryHealth -Library Documents
Stop-O365Log
```

### "Check" scripts no longer modify anything

`check_for_permission_mismatches.ps1` was named "check" and its own synopsis said
"Corrects permission mismatches" — it called `ResetRoleInheritance()` as it went.
Running something called `check_*` should never change a tenant.

```powershell
# Look (changes nothing, guaranteed)
Get-SpoPermissionMismatch -Library Management -MinimumDepth 2

# Preview the fix
Get-SpoPermissionMismatch -Library Management -MinimumDepth 2 |
    Repair-SpoPermissionInheritance -WhatIf

# Apply it
Get-SpoPermissionMismatch -Library Management -MinimumDepth 2 |
    Repair-SpoPermissionInheritance
```

The comparison also changed: the old script compared each item against the
**library**, so every file inside a deliberately-restricted folder looked like a
finding. It now compares against the **immediate parent**.

### No hard-coded tenant or language

`setup_register_pnp_application.ps1` had `rebuildyourchurch.onmicrosoft.com`
baked in. `remove_column_from_content_types.ps1` defaulted to `Priorität` in the
group `Kernaufgaben- und Problemspalten`.

Both are parameters now, with no defaults where a default cannot be right:

```powershell
./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com
Find-SpoContentTypeByColumn -ColumnName 'Priorität' -ColumnGroup 'Kernaufgaben- und Problemspalten'
```

### Confirmation is standard PowerShell

`remove_column_from_content_types.ps1` prompted with
`Read-Host "Do you want to proceed? (yes/no)"` and had a `-Force` switch to skip
it. That does not compose, cannot be previewed, and behaves differently from
every other PowerShell command.

```powershell
# Before
.\scripts\remove_column_from_content_types.ps1 -ColumnName Status -Force

# After
Find-SpoContentTypeByColumn -ColumnName Status | Remove-SpoFieldFromContentType -WhatIf
Find-SpoContentTypeByColumn -ColumnName Status | Remove-SpoFieldFromContentType -Confirm:$false
```

### Output is objects

The old scripts printed with `Write-Host`, so results could not be filtered,
exported, or tested — you read the console and retyped what you saw.

```powershell
# Before: read the console
.\scripts\check_for_permission_mismatches.ps1 -LibraryName Management

# After: it is data
Get-SpoPermissionMismatch -Library Management |
    Where-Object Depth -gt 2 |
    Export-Csv out/deep-mismatches.csv -NoTypeInformation
```

### Logs are no longer in the repository

`log/` held ~900 KB of run output containing real site URLs, library names, and
local paths. It was gitignored and so never committed, but it also served no
purpose in a working tree.

Output now goes to `out/`, also gitignored. `log/` can be deleted:

```bash
rm -rf log/
```

## Related

- [Getting started](getting-started.md)
- [Authentication](authentication.md)
