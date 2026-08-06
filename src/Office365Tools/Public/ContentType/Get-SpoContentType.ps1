<#
.SYNOPSIS
    Lists content types on the site or on a list.
.DESCRIPTION
    The plain listing command: what content types exist, which group they are
    in, and what they descend from.

    By default it reports the *site* content types -- the global ones, the
    templates that lists copy from. Pass -Library to see a specific list's
    copies instead.

    Built-in content types (Item, Document, Folder and friends) are excluded by
    default because on most sites they are noise; -IncludeBuiltIn brings them
    back.
.PARAMETER Name
    Filter by content type name. Supports wildcards.
.PARAMETER Group
    Filter by content type group, e.g. 'Custom Content Types'. Supports
    wildcards. Group names are language-dependent on non-English sites.
.PARAMETER Library
    List a specific library's content types rather than the site's.
.PARAMETER IncludeFields
    Populate the Fields property with the content type's columns. Costs one
    request per content type, so it is off by default.
.PARAMETER IncludeBuiltIn
    Include SharePoint's built-in content types.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.ContentType'.
.EXAMPLE
    Get-SpoContentType
    Lists every custom site content type.
.EXAMPLE
    Get-SpoContentType -Group 'Custom Content Types'
.EXAMPLE
    Get-SpoContentType -Name 'Contract' -IncludeFields |
        Select-Object -ExpandProperty Fields
    Shows the columns on the Contract content type.
.EXAMPLE
    Get-SpoContentType -Library Documents
    Shows which content types the Documents library uses.
.LINK
    New-SpoContentType
.LINK
    Add-SpoFieldToContentType
.LINK
    Test-SpoContentTypeLink
#>
function Get-SpoContentType {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [Alias('ContentTypeName')]
        [string]$Name = '*',

        [Parameter()]
        [SupportsWildcards()]
        [string]$Group = '*',

        [Parameter()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeFields,

        [Parameter()]
        [switch]$IncludeBuiltIn
    )

    begin {
        Assert-SpoConnection | Out-Null

        # Groups SharePoint ships with. Filtering by group rather than by ID
        # catches the whole family without listing every built-in ID.
        $builtInGroups = @(
            '_Hidden'
            'List Content Types'
            'Document Content Types'
            'Folder Content Types'
            'Special Content Types'
            'Business Intelligence'
            'Digital Asset Content Types'
            'Display Template Content Types'
            'Group Work Content Types'
            'Page Layout Content Types'
            'Publishing Content Types'
        )
    }

    process {
        $contentTypes = if ($Library) {
            $list = Resolve-SpoList -Identity $Library
            Get-PnPContentType -List $list
        }
        else {
            Get-PnPContentType
        }

        $scope = if ($Library) { 'List' } else { 'Site' }

        foreach ($contentType in $contentTypes) {
            if ($contentType.Name -notlike $Name) { continue }
            if ($contentType.Group -notlike $Group) { continue }

            if (-not $IncludeBuiltIn -and $contentType.Group -in $builtInGroups) {
                continue
            }

            $fields = $null
            $fieldCount = $null

            if ($IncludeFields) {
                $allFields = Get-PnPProperty -ClientObject $contentType -Property Fields
                $visible = $allFields | Where-Object { -not $_.Hidden }

                $fields = @($visible | ForEach-Object {
                        [pscustomobject]@{
                            PSTypeName   = 'Office365Tools.Field'
                            InternalName = $_.InternalName
                            DisplayName  = $_.Title
                            Type         = "$($_.TypeAsString)"
                            Group        = $_.Group
                            Required     = $_.Required
                            ReadOnly     = $_.ReadOnlyField
                            Hidden       = $_.Hidden
                            Id           = $_.Id
                        }
                    })
                $fieldCount = $fields.Count
            }

            [pscustomobject]@{
                PSTypeName  = 'Office365Tools.ContentType'
                Name        = $contentType.Name
                Id          = $contentType.Id.StringValue
                Group       = $contentType.Group
                Description = $contentType.Description
                Scope       = $scope
                List        = $Library
                Hidden      = $contentType.Hidden
                Sealed      = $contentType.Sealed
                ReadOnly    = $contentType.ReadOnly
                FieldCount  = $fieldCount
                Fields      = $fields
                SiteUrl     = $script:O365State.SiteUrl
            }
        }
    }
}
