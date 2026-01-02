<#
.SYNOPSIS
    Corrects permission mismatches in a SharePoint library.
.DESCRIPTION
    This script compares the permissions of items in a SharePoint document library
    against their parent folders. For nested items with unique permissions that differ
    from their parent, the script resets them to inherit from the parent.
    Top-level items are logged but not modified.
.PARAMETER LibraryName
    The name of the SharePoint document library to check and correct.
.EXAMPLE
    .\correct_permission_mismatches.ps1 -LibraryName "Documents"
    Checks and corrects permission mismatches in the "Documents" library.
.NOTES
    Requires: Active PnP PowerShell connection to SharePoint
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the SharePoint library to check")]
    [ValidateNotNullOrEmpty()]
    [string]$LibraryName
)

# Import logging utilities
$parentPath = Split-Path -Path $PSScriptRoot -Parent
. "$parentPath\util\logging.ps1"

# Initialize logging
$logFolder = Join-Path -Path $parentPath -ChildPath "log"
$logFile = Initialize-Logging -LogFileName "correct_permission_mismatches" -LogFolder $logFolder

# Helper function to get permission signature for comparison
function Get-PermissionSignature {
    param($roleAssignments)

    $signatures = @()
    foreach ($roleAssignment in $roleAssignments) {
        $member = Get-PnPProperty -ClientObject $roleAssignment -Property Member
        $roleDefinitions = Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings

        # Create a signature using LoginName and role IDs (most stable identifiers)
        $roleIds = ($roleDefinitions | ForEach-Object { $_.Id }) | Sort-Object
        $signature = "$($member.LoginName)|$($roleIds -join ',')"
        $signatures += $signature
    }

    return ($signatures | Sort-Object) -join ";"
}

# Start processing
Write-LogEntry "=== SharePoint Permission Mismatch Correction Started ===" "INFO" $logFile
Write-LogEntry "Library: $LibraryName" "INFO" $logFile
Write-LogEntry "Log file: $logFile" "INFO" $logFile
Write-LogEntry "" "INFO" $logFile

try {
    # Verify PnP connection
    $connection = Get-PnPConnection -ErrorAction Stop
    Write-LogEntry "✓ Connected to: $($connection.Url)" "SUCCESS" $logFile

    # Get the library object
    Write-LogEntry "Retrieving library '$LibraryName'..." "INFO" $logFile
    $list = Get-PnPList -Identity $LibraryName

    # Get library-level permissions
    Write-LogEntry "Reading library permissions..." "INFO" $logFile
    $listRoleAssignments = Get-PnPProperty -ClientObject $list -Property RoleAssignments
    $listPermissionSignature = Get-PermissionSignature -roleAssignments $listRoleAssignments

    Write-LogEntry "Library permission signature established" "SUCCESS" $logFile
    Write-LogEntry "" "INFO" $logFile

    # Get all items from the library
    Write-LogEntry "Retrieving items from library..." "INFO" $logFile
    $items = Get-PnPListItem -List $LibraryName -PageSize 500

    if ($null -eq $items -or $items.Count -eq 0) {
        Write-LogEntry "No items found in library '$LibraryName'" "WARNING" $logFile
        exit 0
    }

    Write-LogEntry "Found $($items.Count) items to check" "SUCCESS" $logFile
    Write-LogEntry "" "INFO" $logFile

    # Get the library root folder path for level detection
    $listRootFolder = Get-PnPProperty -ClientObject $list -Property RootFolder
    $listRootPath = $listRootFolder.ServerRelativeUrl

    $processedCount = 0
    $topLevelMismatchCount = 0
    $nestedMismatchCount = 0
    $inheritedCount = 0

    # Loop through each item
    foreach ($item in $items) {
        $processedCount++
        $fileName = $item.FieldValues["FileLeafRef"]
        $fileUrl = $item.FieldValues["FileRef"]

        try {
            # Check if item has unique permissions
            $hasUniqueRoleAssignments = Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments

            if (-not $hasUniqueRoleAssignments) {
                # Item is inheriting permissions - this is correct, no mismatch
                $inheritedCount++
            }
            else {
                # Item has unique permissions - check if they match the library
                $itemRoleAssignments = Get-PnPProperty -ClientObject $item -Property RoleAssignments
                $itemPermissionSignature = Get-PermissionSignature -roleAssignments $itemRoleAssignments

                if ($itemPermissionSignature -ne $listPermissionSignature) {
                    # Determine if this is a top-level item or nested
                    $relativePath = $fileUrl.Substring($listRootPath.Length).TrimStart('/')
                    $pathDepth = ($relativePath -split '/').Count
                    $isTopLevel = $pathDepth -eq 1

                    if ($isTopLevel) {
                        # Top-level mismatch - log as INFO (not an error)
                        $topLevelMismatchCount++
                        Write-LogEntry "⚠ TOP-LEVEL MISMATCH: $fileName" "WARNING" $logFile
                        Write-LogEntry "  Path: $fileUrl" "INFO" $logFile
                        Write-LogEntry "  Top-level item has unique permissions that differ from library" "INFO" $logFile
                        Write-LogEntry "  Library signature: $listPermissionSignature" "INFO" $logFile
                        Write-LogEntry "  Item signature: $itemPermissionSignature" "INFO" $logFile
                        Write-LogEntry "" "INFO" $logFile
                    }
                    else {
                        # Nested mismatch - log as ERROR
                        $nestedMismatchCount++

                        # Get parent folder signature
                        try {
                            $parentPath = $fileUrl.Substring(0, $fileUrl.LastIndexOf('/'))
                            $parentFolder = Get-PnPFolder -Url $parentPath -ErrorAction Stop
                            $parentRoleAssignments = Get-PnPProperty -ClientObject $parentFolder.ListItemAllFields -Property RoleAssignments
                            $parentPermissionSignature = Get-PermissionSignature -roleAssignments $parentRoleAssignments

                            Write-LogEntry "✗ NESTED MISMATCH: $fileName" "ERROR" $logFile
                            Write-LogEntry "  Path: $fileUrl" "ERROR" $logFile
                            Write-LogEntry "  Nested item has unique permissions that differ from parent" "ERROR" $logFile
                            Write-LogEntry "  Parent signature: $parentPermissionSignature" "ERROR" $logFile
                            Write-LogEntry "  Item signature: $itemPermissionSignature" "ERROR" $logFile
                            
                            # Reset permissions to inherit from parent
                            Write-LogEntry "  Resetting permissions to inherit from parent..." "INFO" $logFile
                            $item.ResetRoleInheritance()
                            Invoke-PnPQuery
                            Write-LogEntry "  ✓ Permissions reset successfully" "SUCCESS" $logFile
                        }
                        catch {
                            Write-LogEntry "✗ NESTED MISMATCH: $fileName" "ERROR" $logFile
                            Write-LogEntry "  Path: $fileUrl" "ERROR" $logFile
                            Write-LogEntry "  Nested item has unique permissions (could not retrieve parent signature)" "ERROR" $logFile
                            Write-LogEntry "  Item signature: $itemPermissionSignature" "ERROR" $logFile
                            Write-LogEntry "  Failed to reset permissions: $_" "ERROR" $logFile
                        }
                        Write-LogEntry "" "INFO" $logFile
                    }
                }
            }
        }
        catch {
            Write-LogEntry "✗ Error checking item: $fileName - $_" "ERROR" $logFile
            Write-LogEntry "" "INFO" $logFile
        }
    }

    Write-LogEntry "=== Correction Complete ===" "SUCCESS" $logFile
    Write-LogEntry "Total items checked: $processedCount" "SUCCESS" $logFile
    Write-LogEntry "Items inheriting permissions: $inheritedCount" "SUCCESS" $logFile
    Write-LogEntry "Top-level items with different permissions: $topLevelMismatchCount" "INFO" $logFile
    Write-LogEntry "Nested items corrected: $nestedMismatchCount" $(if ($nestedMismatchCount -gt 0) { "SUCCESS" } else { "INFO" }) $logFile
    Write-LogEntry "Log file saved: $logFile" "SUCCESS" $logFile
}
catch {
    Write-LogEntry "✗ Fatal error: $_" "ERROR" $logFile
    Write-LogEntry $_.ScriptStackTrace "ERROR" $logFile
    exit 1
}
