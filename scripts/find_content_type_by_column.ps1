<#
.SYNOPSIS
    Finds content types that contain a specific column in the current SharePoint site.
.DESCRIPTION
    This script searches for content types in the current SharePoint site that
    contain the specified column name. By default, it searches for the "Priority" column
    in the "Core Task and Issue Columns" group.
.PARAMETER ColumnName
    The internal name or display name of the column to search for. Default is "Priority".
.PARAMETER ColumnGroup
    The group that the column must belong to. Default is "Core Task and Issue Columns".
.EXAMPLE
    .\find_content_type_by_column.ps1
    Finds all content types containing the "Priority" column in the "Core Task and Issue Columns" group.
.EXAMPLE
    .\find_content_type_by_column.ps1 -ColumnName "Status"
    Finds all content types containing the "Status" column in the "Core Task and Issue Columns" group.
.EXAMPLE
    .\find_content_type_by_column.ps1 -ColumnName "Title" -ColumnGroup "Custom Columns"
    Finds all content types containing the "Title" column in the "Custom Columns" group.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ColumnName = "Priorität",

    [Parameter(Mandatory = $false)]
    [string]$ColumnGroup = "Kernaufgaben- und Problemspalten"
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
    }
    else {
        Write-Host "✓ Found $($matchingContentTypes.Count) content type(s) with column '$ColumnName':" -ForegroundColor Green
        Write-Host ""

        Show-ContentTypeInfo -ContentTypes $matchingContentTypes

        # Return the results
        return $matchingContentTypes
    }
}
catch {
    # Error already handled by utility function
}
