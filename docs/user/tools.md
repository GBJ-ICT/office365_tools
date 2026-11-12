# Tools at a glance

What is in the box, and how to start each tool. Details for each one are in the
[detailed guides](../sandbox/README.md).

## Three ways to use the tools

**Double-click a single tool.** For people who do not use PowerShell. You get a
launcher file for one tool, for example `Check-Upload.cmd`, double-click it, and
answer a few questions. The tool starts straight away.

**Double-click `Office365-Tools.cmd`.** Also for people who do not use PowerShell.
You get this file when you receive several tools. A window opens with every
available tool, each with a short description. Click the tool you want to start.
Today these are **SharePoint list to PDF** and the **Upload checker**; new tools appear in this window by themselves.
At the bottom left, the **Language / Sprache** box changes the language.

**PowerShell.** For everything else. Open PowerShell 7 in the repository folder
and start a script, or use the commands directly.

## SharePoint list to PDF (double-click)

Prints a SharePoint list, or one of its views, to a PDF you can keep, send or
print. It only reads; it never changes anything in SharePoint.

1. Double-click `List-To-Pdf.cmd`. With `Office365-Tools.cmd`, click
   **SharePoint list to PDF** in the window instead.
2. The first time it asks for an address. Copy it out of your browser and paste it.
   It can be the address of the site, or of a page in it: if you copy the address
   of the list you want, the site is taken from it, and the list too, so you are not
   asked which one. Put the address in `list-to-pdf.xml` beside the launcher and it
   stops asking.
3. Sign in with your work account, then pick the **list** and the **view** from
   numbered lists. The views are the stored selections of that list, named as the
   view picker in SharePoint names them; Enter takes the default view. In
   `list-to-pdf.xml` you can name a view instead, and it is not asked.
4. Type why you are exporting it, or press Enter to leave that out. The reason goes
   on the first page.
5. The PDF is in the `Reports` folder next to the launcher, and the folder opens
   with it selected.

The first page says what was exported, when, by whom (your name, from the
sign-in) and why. The paper is A4 landscape; `list-to-pdf.xml` also offers A3, A5,
Letter, Legal and portrait. A list with many text columns reads better on A3.

How each kind of column is printed:

| Column in SharePoint | On the page |
|---|---|
| Single line of text, Choice, Number, Currency, Calculated | The text as the list shows it. Several choices are separated by `;`. |
| Multiple lines of text, plain | The full text, with its line breaks. |
| Multiple lines of text, enhanced rich text | The text with its paragraphs, bullets and numbers. Links inside it are clickable. Emoji are printed. |
| Date and time | The date, and the time when there is one. |
| Yes/No | Yes or No. |
| Person or Group | The display name. Several people are one name to a line. The name opens an email to that person; a group has no address. |
| Lookup, Managed metadata | The value, or the values separated by `;`. |
| Hyperlink, Picture | The description, or the address when there is none. It is a clickable link. |
| Attachments, Content type | Not printed. |

Colours from SharePoint (conditional formatting, coloured choices) are not carried
over: the table has a grey header row and every second row is shaded.

Every column is as wide as its content needs, up to 70 mm for a short one; the
long text columns share the rest of the page. All the text is on the page: long
texts wrap and may continue on the next page, nothing is cut off. After printing,
the tool reads the PDF back and checks that every value is in it. If one is
missing it says so and tells you not to rely on the file. A view with no rows
writes no PDF.

Needs PowerShell 7 (the launcher says how to get it) and, for the sign-in, the
application ID of your organisation. A list a person cannot read in SharePoint
cannot be printed.

## The Upload checker (double-click)

Checks a folder **before** you upload it to SharePoint, and checks **afterwards**
that everything arrived. It only looks; it never changes anything.

1. Double-click `Check-Upload.cmd`, or drag the folder you want checked onto it.
   With `Office365-Tools.cmd`, click **Upload checker** in the window instead.
2. Pick the folder, then choose what to do: check before uploading, check that
   it arrived, or both.
3. Read the report in the `Reports` folder next to the launcher. Red means fix it before uploading.

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
