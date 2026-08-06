<#
.SYNOPSIS
    Internal: tells whether a column is a candidate for being shared down from
    a Document Set to its contents.
.DESCRIPTION
    Used when looking for columns that *should* probably be shared but are not.
    Three kinds of column are never candidates:

      Read-only and hidden columns  -- nothing can be written to them, and
                                       SharePoint maintains them itself.
      SharePoint's own plumbing     -- anything starting with '_', the taxonomy
                                       catch-all columns, view and icon
                                       pseudo-columns.
      Identity columns              -- Title, Name, Created, Author and
                                       friends. Copying a Document Set's name
                                       or author onto every document inside it
                                       would be actively wrong.

    This governs *discovery* only. A column the administrator has deliberately
    registered as shared is always compared, whatever this says -- their
    decision beats the heuristic.

    Pure: it takes a plain descriptor rather than a CSOM field, so it is unit
    testable and works for both list fields and content type fields.
.PARAMETER Field
    Object with InternalName, and optionally Hidden and ReadOnly.
.OUTPUTS
    System.Boolean
.EXAMPLE
    Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = 'ProjectStatus' })
#>
function Test-SpoSyncableColumn {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        $Field
    )

    if ($null -eq $Field) {
        return $false
    }

    $properties = @($Field.PSObject.Properties.Name)

    if ($properties -notcontains 'InternalName') {
        return $false
    }

    $name = [string]$Field.InternalName

    if ([string]::IsNullOrWhiteSpace($name)) {
        return $false
    }

    if ($properties -contains 'Hidden' -and $Field.Hidden) {
        return $false
    }

    if ($properties -contains 'ReadOnly' -and $Field.ReadOnly) {
        return $false
    }

    if ($name.StartsWith('_') -or $name.StartsWith('ows', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $systemColumns = @(
        'Title', 'Name', 'FileLeafRef', 'FileRef', 'FileDirRef', 'FSObjType'
        'ContentType', 'ContentTypeId', 'DocumentSetDescription'
        'Created', 'Modified', 'Author', 'Editor', 'ID', 'GUID', 'UniqueId'
        'Attachments', 'Edit', 'DocIcon', 'LinkTitle', 'LinkTitleNoMenu'
        'LinkFilename', 'LinkFilenameNoMenu', 'ItemChildCount', 'FolderChildCount'
        'AppAuthor', 'AppEditor', 'CheckoutUser', 'SyncClientId'
        'TaxCatchAll', 'TaxCatchAllLabel', 'MetaInfo', 'Order', 'SortBehavior'
        'PermMask', 'ProgId', 'ScopeId', 'SelectTitle', 'InstanceID', 'WorkflowVersion'
    )

    return $name -notin $systemColumns
}
