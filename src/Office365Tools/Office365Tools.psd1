@{
    RootModule        = 'Office365Tools.psm1'
    FormatsToProcess  = @('Office365Tools.Format.ps1xml')
    ModuleVersion     = '0.2.0'
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
