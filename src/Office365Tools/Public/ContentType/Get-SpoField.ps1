<#
.SYNOPSIS
    Lists site columns, or the columns on a list.
.DESCRIPTION
    Finds available columns and, importantly, their *internal* names -- which is
    what every other command needs and what the UI never shows you.

    Hidden and read-only system columns are excluded by default; on a typical
    site they outnumber the useful ones several times over.
.PARAMETER Name
    Filter by internal name or display title. Supports wildcards, and matches
    either, so you can search for what you see in the UI.
.PARAMETER Group
    Filter by column group. Supports wildcards.
.PARAMETER Library
    List a library's columns rather than the site's.
.PARAMETER Type
    Filter by field type, e.g. Text, Choice, DateTime.
.PARAMETER IncludeHidden
    Include hidden columns.
.PARAMETER IncludeReadOnly
    Include read-only columns, which cannot be added to a content type.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Field'.
.EXAMPLE
    Get-SpoField -Group 'Custom Columns'

.EXAMPLE
    Get-SpoField -Name '*priorit*'
    Finds a column whether it is titled 'Priority' or 'Priorität'.
.EXAMPLE
    Get-SpoField -Type Choice | Select-Object InternalName, DisplayName, Group

.EXAMPLE
    Get-SpoField -Group 'Contract Columns' |
        Add-SpoFieldToContentType -ContentType 'Contract' -UpdateChildren
.LINK
    New-SpoField
.LINK
    Add-SpoFieldToContentType
.LINK
    Find-SpoContentTypeByColumn
#>
function Get-SpoField {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [Alias('InternalName', 'ColumnName')]
        [string]$Name = '*',

        [Parameter()]
        [SupportsWildcards()]
        [Alias('ColumnGroup')]
        [string]$Group = '*',

        [Parameter()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [string]$Type,

        [Parameter()]
        [switch]$IncludeHidden,

        [Parameter()]
        [switch]$IncludeReadOnly
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $fields = if ($Library) {
            $list = Resolve-SpoList -Identity $Library
            Get-PnPField -List $list
        }
        else {
            Get-PnPField
        }

        foreach ($field in $fields) {
            if (-not $IncludeHidden -and $field.Hidden) { continue }
            if (-not $IncludeReadOnly -and $field.ReadOnlyField) { continue }

            # Match either name, so searching for what the UI shows works.
            if ($field.InternalName -notlike $Name -and $field.Title -notlike $Name) { continue }
            if ($field.Group -notlike $Group) { continue }
            if ($Type -and "$($field.TypeAsString)" -ne $Type) { continue }

            [pscustomobject]@{
                PSTypeName   = 'Office365Tools.Field'
                InternalName = $field.InternalName
                DisplayName  = $field.Title
                Type         = "$($field.TypeAsString)"
                Group        = $field.Group
                Required     = $field.Required
                ReadOnly     = $field.ReadOnlyField
                Hidden       = $field.Hidden
                Description  = $field.Description
                Id           = $field.Id
                List         = $Library
                SiteUrl      = $script:O365State.SiteUrl
            }
        }
    }
}
