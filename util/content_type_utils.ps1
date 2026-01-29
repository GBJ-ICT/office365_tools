#
# Utility functions for working with SharePoint content types
#

<#
.SYNOPSIS
    Finds content types that contain a specific column.
.DESCRIPTION
    Searches all content types in the current SharePoint site for ones that
    contain the specified column name and are in the specified group.
.PARAMETER ColumnName
    The internal name or display name of the column to search for.
.PARAMETER ColumnGroup
    The group that the column must belong to.
.OUTPUTS
    Array of PSCustomObjects containing content type information and matching field details.
#>
Function Find-ContentTypesByColumn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColumnName,

        [Parameter(Mandatory = $true)]
        [string]$ColumnGroup
    )

    $contentTypes = Get-PnPContentType
    $matchingContentTypes = @()

    foreach ($contentType in $contentTypes) {
        # Get the fields/columns for this content type
        $fields = Get-PnPProperty -ClientObject $contentType -Property Fields

        # Check if the column exists in this content type and is in the specified group
        $matchingField = $fields | Where-Object {
            ($_.InternalName -eq $ColumnName -or $_.Title -eq $ColumnName) -and
            $_.Group -eq $ColumnGroup
        }

        if ($matchingField) {
            $matchingContentTypes += [PSCustomObject]@{
                Name = $contentType.Name
                Id = $contentType.Id
                Group = $contentType.Group
                Description = $contentType.Description
                ContentTypeObject = $contentType
                FieldInternalName = $matchingField.InternalName
                FieldDisplayName = $matchingField.Title
                FieldGroup = $matchingField.Group
            }
        }
    }

    return $matchingContentTypes
}

<#
.SYNOPSIS
    Displays content type information in a formatted manner.
.DESCRIPTION
    Outputs content type details including name, ID, group, and field information.
.PARAMETER ContentTypes
    Array of content type objects to display.
#>
Function Show-ContentTypeInfo {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ContentTypes
    )

    foreach ($ct in $ContentTypes) {
        Write-Host "Content Type: $($ct.Name)" -ForegroundColor White
        Write-Host "  ID: $($ct.Id)" -ForegroundColor Gray
        Write-Host "  Group: $($ct.Group)" -ForegroundColor Gray
        Write-Host "  Field Internal Name: $($ct.FieldInternalName)" -ForegroundColor Gray
        Write-Host "  Field Display Name: $($ct.FieldDisplayName)" -ForegroundColor Gray
        Write-Host "  Field Group: $($ct.FieldGroup)" -ForegroundColor Gray
        if ($ct.Description) {
            Write-Host "  Description: $($ct.Description)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

<#
.SYNOPSIS
    Checks if a PnP connection is active.
.DESCRIPTION
    Verifies that there is an active PnP connection to SharePoint and displays
    the connection URL.
.OUTPUTS
    Returns the connection object if successful, throws an error otherwise.
#>
Function Test-PnPConnectionActive {
    try {
        $connection = Get-PnPConnection -ErrorAction Stop
        Write-Host "✓ Connected to: $($connection.Url)" -ForegroundColor Green
        Write-Host ""
        return $connection
    }
    catch {
        Write-Host "✗ Error occurred: $_" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please establish a PnP connection first using:" -ForegroundColor Cyan
        Write-Host "  Connect-PnPOnline -Url <site-url> -Interactive" -ForegroundColor White
        Write-Host "Or run one of the setup scripts in the setup folder." -ForegroundColor White
        throw
    }
}
