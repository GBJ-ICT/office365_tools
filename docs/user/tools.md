# Tools at a glance

What is in the box, and how to start each tool. Details for each one are in the
[detailed guides](../sandbox/README.md).

## Two ways to use the tools

**Double-click.** For people who do not use PowerShell. You get a launcher file,
double-click it, and answer a few questions. Today this is the
**Upload checker**.

**PowerShell.** For everything else. Open PowerShell 7 in the repository folder
and start a script, or use the commands directly.

## The Upload checker (double-click)

Checks a folder **before** you upload it to SharePoint, and checks **afterwards**
that everything arrived. It only looks; it never changes anything.

1. Double-click `Check-Upload.cmd`, or drag the folder you want checked onto it.
2. Pick the folder, then choose what to do: check before uploading, check that
   it arrived, or both.
3. Read the report in the `out` folder. Red means fix it before uploading.

Checking before uploading needs no sign-in. Checking afterwards asks you to sign
in with your work account.

## The PowerShell tools

Start every script like this, from the repository folder:

```powershell
pwsh ./scripts/<name>.ps1
```

Scripts that talk to SharePoint need a connection to your tenant (see "Before
the first run" below). Some need a few details, such as which library or list;
run `Get-Help ./scripts/<name>.ps1 -Full` to see them. Scripts that change data
say so in their help, and the ones that can preview a change accept `-WhatIf`.

| I want to... | Start | Changes data? |
|---|---|---|
| Check one or all libraries for problems and get reports | `Invoke-LibraryAudit.ps1` | No, read-only |
| Check a folder before uploading it, or that an upload arrived | `Test-Upload.ps1` | No |
| Find Document Sets whose files no longer carry their metadata | `Test-DocumentSetSync.ps1` | No, read-only |
| Push each Document Set's metadata down onto its files and folders | `Repair-DocumentSetSync.ps1` | Yes, try `-WhatIf` first |
| Add every Document Set that is missing to an overview list | `Sync-DocumentSetRegister.ps1` | Only after you approve a plan file |
| Print a list to PDF and check that every value made it into the file | `Export-ListToPdf.ps1` | No, writes a PDF and a report |
| Create list items on a recurring date, such as every second Sunday | `New-ListItemDateSeries.ps1` | Only after you approve a plan file |
| Rename a choice value in every item that still holds the old one | `Update-SpoFieldValue.ps1` | Yes, try `-WhatIf` first |
| Copy a list's columns to another list (not lookup, managed metadata or calculated columns) | `Copy-ListSchema.ps1` | Only with `-Apply` |
| Browse and edit content types and columns from a menu | `Manage-ContentType.ps1` | Yes, after you confirm each change |
| Set up the sign-in for your organisation (administrator, once) | `Register-PnPApplication.ps1` | Registers an application in your tenant |

Every script explains itself: `Get-Help ./scripts/Test-Upload.ps1 -Full`.

## Before the first run

You need PowerShell 7 and, for anything that talks to SharePoint, an application
ID for your organisation. Whoever administers your tenant registers it once and
gives you the ID. See [Authentication](../sandbox/authentication.md) for how.

## Language

The tools speak English or German. See [Language](language.md).
