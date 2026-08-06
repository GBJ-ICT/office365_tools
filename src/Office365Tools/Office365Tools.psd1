@{
    RootModule        = 'Office365Tools.psm1'
    FormatsToProcess  = @('Office365Tools.Format.ps1xml')
    ModuleVersion     = '0.4.1'
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

        # --- Reporting ------------------------------------------------------
        'Export-SpoReport'
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
