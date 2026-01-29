<#
.SYNOPSIS
    Removes a specific column from content types in the current SharePoint site.
.DESCRIPTION
    This script finds content types that contain a specified column and removes
    that column from each content type. By default, it searches for the "Priority"
    column in the "Core Task and Issue Columns" group and prompts for confirmation
    before deletion.
.PARAMETER ColumnName
    The internal name or display name of the column to remove. Default is "Priority".
.PARAMETER ColumnGroup
    The group that the column must belong to. Default is "Core Task and Issue Columns".
.PARAMETER Force
    If specified, skips the confirmation prompt and immediately removes the column.
.EXAMPLE
    .\remove_column_from_content_types.ps1
    Finds and removes the "Priority" column from content types (with confirmation).
.EXAMPLE
    .\remove_column_from_content_types.ps1 -ColumnName "Status" -Force
    Removes the "Status" column from content types without confirmation.
.EXAMPLE
    .\remove_column_from_content_types.ps1 -ColumnName "CustomField" -ColumnGroup "Custom Columns"
    Removes the "CustomField" column from the "Custom Columns" group.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ColumnName = "Priorität",

    [Parameter(Mandatory = $false)]
    [string]$ColumnGroup = "Kernaufgaben- und Problemspalten",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Import utilities
$loggingPath = Join-Path $PSScriptRoot "..\util\logging.ps1"
if (Test-Path $loggingPath) {
    . $loggingPath
}

$contentTypeUtilsPath = Join-Path $PSScriptRoot "..\util\content_type_utils.ps1"
. $contentTypeUtilsPath

try {
    # Check if PnP connection exists
    Test-PnPConnectionActive | Out-Null

    # Get all content types from the site
    Write-Host "Searching for content types with column '$ColumnName' in group '$ColumnGroup'..." -ForegroundColor Cyan
    Write-Host ""

    $matchingContentTypes = Find-ContentTypesByColumn -ColumnName $ColumnName -ColumnGroup $ColumnGroup

    # Display results
    if ($matchingContentTypes.Count -eq 0) {
        Write-Host "✗ No content types found with column '$ColumnName'" -ForegroundColor Yellow
        return
    }

    Write-Host "✓ Found $($matchingContentTypes.Count) content type(s) with column '$ColumnName':" -ForegroundColor Green
    Write-Host ""

    Show-ContentTypeInfo -ContentTypes $matchingContentTypes

    # Confirm deletion unless -Force is specified
    if (-not $Force) {
        Write-Host "⚠️  WARNING: This will remove the column '$ColumnName' from $($matchingContentTypes.Count) content type(s)." -ForegroundColor Yellow
        Write-Host "This action cannot be undone!" -ForegroundColor Yellow
        Write-Host ""
        $confirmation = Read-Host "Do you want to proceed? (yes/no)"

        if ($confirmation -ne "yes") {
            Write-Host "✗ Operation cancelled by user" -ForegroundColor Yellow
            return
        }
    }

    Write-Host ""
    Write-Host "Starting removal process..." -ForegroundColor Cyan
    Write-Host ""

    # Remove the column from each content type
    $successCount = 0
    $failureCount = 0

    foreach ($ct in $matchingContentTypes) {
        try {
            Write-Host "Removing '$($ct.FieldInternalName)' from '$($ct.Name)'..." -ForegroundColor White

            # Remove the field from the content type using the internal name
            Remove-PnPFieldFromContentType -Field $ct.FieldInternalName -ContentType $ct.Id -ErrorAction Stop

            Write-Host "  ✓ Successfully removed" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed to remove: $_" -ForegroundColor Red
            $failureCount++
        }
        Write-Host ""
    }

    # Summary
    Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
    Write-Host "Total content types processed: $($matchingContentTypes.Count)" -ForegroundColor White
    Write-Host "Successfully removed: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" })
    Write-Host "=================================================" -ForegroundColor Cyan
}
catch {
    # Error already handled by utility function
}
