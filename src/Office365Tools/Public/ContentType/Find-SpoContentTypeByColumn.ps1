<#
.SYNOPSIS
    Finds content types containing a given column.
.DESCRIPTION
    Answers "what breaks if I delete this column?" before you delete it.
    Searches site content types by default, or a specific list's content types
    with -Library.

    Both the internal name and the display title are matched, because on a
    non-English site those differ and people usually know only the one they see
    in the UI.
.PARAMETER ColumnName
    Internal name or display title of the column. Supports wildcards.
.PARAMETER ColumnGroup
    Restrict to columns in this group. Group names are language-dependent
    (for example 'Core Task and Issue Columns' is 'Kernaufgaben- und
    Problemspalten' on a German site), so leave it off unless you are sure.
.PARAMETER Library
    Search this list's content types instead of the site's.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.ContentTypeMatch'.
.EXAMPLE
    Find-SpoContentTypeByColumn -ColumnName Priority
.EXAMPLE
    Find-SpoContentTypeByColumn -ColumnName 'Priorität' -ColumnGroup 'Kernaufgaben- und Problemspalten'
.EXAMPLE
    Find-SpoContentTypeByColumn -ColumnName Status -Library Documents
.LINK
    Remove-SpoFieldFromContentType
#>
function Find-SpoContentTypeByColumn {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$ColumnName,

        [Parameter()]
        [string]$ColumnGroup,

        [Parameter()]
        [Alias('List', 'LibraryName')]
        [string]$Library
    )

    Assert-SpoConnection | Out-Null

    $contentTypes = if ($Library) {
        $list = Resolve-SpoList -Identity $Library
        Get-PnPContentType -List $list
    }
    else {
        Get-PnPContentType
    }

    $scopeLabel = if ($Library) { "list '$Library'" } else { 'the site' }
    Write-O365Log "Searching $(@($contentTypes).Count) content type(s) in $scopeLabel for column '$ColumnName'." 'Info'

    foreach ($contentType in $contentTypes) {
        $fields = Get-PnPProperty -ClientObject $contentType -Property Fields

        $matchingFields = $fields | Where-Object {
            ($_.InternalName -like $ColumnName -or $_.Title -like $ColumnName) -and
            (-not $ColumnGroup -or $_.Group -eq $ColumnGroup)
        }

        foreach ($field in $matchingFields) {
            [pscustomobject]@{
                PSTypeName        = 'Office365Tools.ContentTypeMatch'
                ContentTypeName   = $contentType.Name
                ContentTypeId     = $contentType.Id.StringValue
                ContentTypeGroup  = $contentType.Group
                Description       = $contentType.Description
                FieldInternalName = $field.InternalName
                FieldDisplayName  = $field.Title
                FieldGroup        = $field.Group
                FieldRequired     = $field.Required
                FieldReadOnly     = $field.ReadOnlyField
                Sealed            = $contentType.Sealed
                ReadOnly          = $contentType.ReadOnly
                List              = $Library
                SiteUrl           = $script:O365State.SiteUrl
            }
        }
    }
}
