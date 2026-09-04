@{
    RootModule        = 'Office365Tools.psm1'
    FormatsToProcess  = @('Office365Tools.Format.ps1xml')
    ModuleVersion     = '0.6.0'
    GUID              = 'b7f3c9a2-4d18-4e6b-9c53-8a1f2e7d4b60'
    Author            = 'office365_tools contributors'
    CompanyName       = 'Unknown'
    Copyright         = '(c) 2026 office365_tools contributors. MIT licensed.'
    Description       = 'Tools for administering SharePoint Online libraries, lists, content types and permissions via PnP PowerShell.'

    PowerShellVersion = '7.2'

    RequiredModules   = @(
        @{ ModuleName = 'PnP.PowerShell'; ModuleVersion = '3.0.0' }
    )

    # Every exported command is listed explicitly. Wildcards here defeat
    # command discovery performance and hide accidental exports.
    FunctionsToExport = @(
        # --- Connection & profiles -----------------------------------------
        'Connect-O365'
        'Disconnect-O365'
        'Get-O365Connection'
        'Get-O365Profile'
        'Set-O365Profile'
        'Remove-O365Profile'
        'Start-O365Log'
        'Stop-O365Log'

        # --- Permissions ----------------------------------------------------
        'Get-SpoPermissionMismatch'
        'Repair-SpoPermissionInheritance'
        'Get-SpoPermissionReport'
        'Find-SpoOrphanedPermission'
        'Grant-SpoPermission'
        'Revoke-SpoPermission'

        # --- Content types --------------------------------------------------
        'Get-SpoContentType'
        'New-SpoContentType'
        'Get-SpoField'
        'New-SpoField'
        'Get-SpoListFieldSchema'
        'Add-SpoListField'
        'Add-SpoFieldToContentType'
        'Find-SpoContentTypeByColumn'
        'Add-SpoContentTypeToList'
        'Remove-SpoContentTypeFromList'
        'Remove-SpoFieldFromContentType'
        'Test-SpoContentTypeLink'
        'Sync-SpoContentType'

        # --- Document Sets ---------------------------------------------------
        'Get-SpoDocumentSet'
        'Get-SpoDocumentSetMismatch'
        'Get-SpoDocumentSetRegisterEntry'
        'Repair-SpoDocumentSetMetadata'
        'Test-SpoDocumentSetSharedColumn'

        # --- Library health & naming ----------------------------------------
        'Test-SpoLibraryHealth'
        'Test-SpoFileName'
        'Test-SpoPathLength'
        'Compare-SpoFolder'
        'Get-SpoFileDraft'
        'Publish-SpoFileDraft'

        # --- List items -----------------------------------------------------
        'Add-SpoListItem'
        'Update-SpoListItem'
        'Update-SpoListItemLinkText'
        'Export-SpoListItem'
        'Import-SpoListItem'

        # --- Scheduling -----------------------------------------------------
        'Get-SpoRecurringDate'

        # --- Reporting ------------------------------------------------------
        'Export-SpoReport'
        'Export-SpoListPdf'
        'Test-SpoPdfContent'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList          = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('SharePoint', 'SharePointOnline', 'PnP', 'Microsoft365', 'Office365', 'Administration')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = @'
0.6.0
- Export-SpoListPdf: prints a list to PDF with a page layout that does not
  depend on a window size or a zoom level, which is what makes printing a
  SharePoint view by hand unreproducible. The command renders its own table --
  repeating header row, rows that never split across a page, cells that wrap
  instead of clipping -- and a headless Edge or Chrome converts it with the
  device scale factor pinned to 1.
- It then reads the PDF back and checks that every printed value is in it, so
  'everything is on there' is established rather than assumed. -Css,
  -CellFormatter, -ColumnWidth, -GroupBy and the paper parameters cover the
  layout; -View prints what a list view shows.
- Links are live in the PDF: a Hyperlink column or any cell holding a URL
  becomes clickable on its own, -ItemLink links a column back to the item it
  came from, and -LinkColumn takes a URL template per column. They are
  verified against the document's link annotations, which the text pass cannot
  see -- a PDF whose text reads back perfectly can still have lost every link.
- Export-SpoListPdf reads a PDF back in drawing order rather than visual
  layout order. A row where two columns both wrapped used to report every
  value in it as missing: the reader was interleaving the two cells' lines,
  not the printer dropping them.
- Test-SpoPdfContent does that verification on its own, against any PDF and
  any set of rows -- including a file from months ago and a CSV of what it
  should have said. A value that merely wrapped across lines is reported as
  Info; one that is absent is an Error; a PDF whose text cannot be read is
  reported as unverifiable rather than as passing.
- Export-SpoListItem: -Query takes a CAML view query, which is what lets a
  view's filter and sort be reproduced.
- scripts/Export-ListToPdf.ps1 connects, prints, verifies, and writes the
  verification report next to the PDF.

0.5.0
- Get-SpoListFieldSchema / Add-SpoListField: copy a list's columns to another
  list, as columns local to it rather than site columns. Internal names are
  preserved, so anything written against the original -- a view, a flow, a
  script -- addresses the copy unchanged. Choices, defaults, rich-text settings
  and the JSON column formatter come across; the source list's provenance
  (SourceID, ColName, RowOrdinal, Version) does not, and the stale Title
  attribute a renamed column carries is corrected from DisplayName.
- Lookup, taxonomy and calculated columns are reported as unportable rather
  than copied. SharePoint accepts all three and produces a column that renders
  empty forever, which is worse than refusing.
- Get-SpoRecurringDate: the dates of a recurring series -- every second Sunday,
  Sundays of odd calendar weeks, the first Sunday of the month. Needs no
  connection, so a schedule is checkable before a tenant is involved.
- scripts/Copy-ListSchema.ps1 reads one list and writes another, plan first.
- scripts/New-ListItemDateSeries.ps1 creates a run of empty entries on a
  schedule, with per-column defaults, via an editable plan CSV. Columns may be
  named by display name or internal name; the two are reconciled against the
  list when the plan is written. Re-runnable: entries the list already has are
  skipped on a key that defaults to the date plus the two columns that tell one
  of a day's entries from another.

0.4.1
- Get-SpoDocumentSetRegisterEntry: a Document ID column is now matched on the
  ID in its URL rather than on its link text. The two agree until the link is
  relabelled to show something friendlier -- at which point the old rule
  matched nothing, made every Document Set look unregistered, and would have
  duplicated the whole register on the next run.
- Get-SpoDocumentSetRegisterEntry: -ReferenceField is genuinely optional. A
  register keyed on the Document ID link needs no second link back to the
  folder, and a DocIdRedir URL survives a move where a path does not.

0.4.0
- Get-SpoDocumentSetRegisterEntry: -ContentTypeMap registers each library's
  Document Sets as their own content type. The two sets of names rarely
  correspond, so the mapping is given rather than guessed at.
- Get-SpoDocumentSetRegisterEntry: entries now carry an Action -- Create,
  Update or Current. Update is a Document Set that has moved to another
  library: the Document ID still matches, so the row is found, but its content
  type and reference link are both stale. Only those two are rewritten; the
  metadata columns are left alone because a register is edited by hand.
- Update-SpoListItem: -ContentType reclassifies an item, and -Values is no
  longer mandatory, since a reclassification changes no field.

0.3.0
- Get-SpoDocumentSetRegisterEntry: compares the Document Sets in one or more
  libraries against a list that registers them, and describes the rows that
  are missing. Columns are matched by internal name, so the mapping is the two
  schemas' overlap rather than a table baked into the module.
- Update-SpoListItemLinkText: sets a hyperlink column's display text from
  another column on the same item -- the second pass a register needs when its
  link text comes from a calculated column.
- scripts/Sync-DocumentSetRegister.ps1 runs both, plan first.

0.2.0
- Document Set commands: Get-SpoDocumentSet, Get-SpoDocumentSetMismatch,
  Repair-SpoDocumentSetMetadata, Test-SpoDocumentSetSharedColumn.
- Finds contents whose metadata has drifted from the Document Set that holds
  them, pushes the Document Set's values back down, and reports the shared
  column configuration that let the drift happen.

0.1.0
- Initial module release. Replaces the loose script collection.
- Unified connection handling via named profiles (config/profiles.json).
- Read and write operations are separate commands; every mutating command
  supports -WhatIf and -Confirm.
- All commands emit objects rather than writing to the console.
'@
        }
    }
}
