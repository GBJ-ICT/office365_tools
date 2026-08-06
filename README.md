# office365_tools

PowerShell tools for administering SharePoint Online: libraries, lists, content
types and permissions. Built on [PnP.PowerShell](https://pnp.github.io/powershell/).

Everything ships as one module with 38 verb-noun commands, so `Get-Help` and tab
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

### Bulk-load a list from CSV

```powershell
Import-SpoListItem -Path data/tasks.csv -Library Tasks -WhatIf   # validates first
Import-SpoListItem -Path data/tasks.csv -Library Tasks
```

Column names and required fields are checked against the list *before* the first
item is written, so a bad header fails at row zero rather than row 400.

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
| **Document Sets** | `Get-SpoDocumentSet` `Get-SpoDocumentSetMismatch` `Get-SpoDocumentSetRegisterEntry` `Repair-SpoDocumentSetMetadata` `Test-SpoDocumentSetSharedColumn` |
| **Library health** | `Test-SpoLibraryHealth` `Test-SpoFileName` `Test-SpoPathLength` `Compare-SpoFolder` |
| **List items** | `Add-SpoListItem` `Update-SpoListItem` `Update-SpoListItemLinkText` `Export-SpoListItem` `Import-SpoListItem` |
| **Reporting** | `Export-SpoReport` |

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
- [Health rules](docs/health-rules.md) — what every `RuleId` means and what to do about it
- [Migration](docs/migration.md) — mapping from the old loose scripts

## Licence

MIT. See [LICENSE](LICENSE).
