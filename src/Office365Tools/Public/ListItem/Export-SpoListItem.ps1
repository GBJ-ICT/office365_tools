<#
.SYNOPSIS
    Exports list items as flat objects.
.DESCRIPTION
    Flattens SharePoint's field values into plain properties so the result
    drops straight into Export-Csv, Compare-Object, or a spreadsheet.

    SharePoint returns lookups, users, taxonomy terms and URLs as structured
    objects. Left as-is they serialise to type names in a CSV, which is useless.
    This resolves each to its display value.

    The output is round-trippable: what this exports, Import-SpoListItem can
    import.
.PARAMETER Library
    Title, URL name, or GUID of the list.
.PARAMETER Field
    Internal names of the fields to export. Omit for all non-hidden fields.
.PARAMETER IncludeSystemField
    Also include SharePoint's system fields (GUID, owshiddenversion, and so
    on). Off by default because they dominate the output and are rarely wanted.
.PARAMETER Query
    CAML query, as a complete <View>...</View>, so a view's own filter and
    sort can be reproduced. -PageSize does not apply with it: PnP puts the two
    in different parameter sets, and a row limit belongs in the CAML.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject per item.
.EXAMPLE
    Export-SpoListItem -Library Tasks | Export-Csv out/tasks.csv -NoTypeInformation
.EXAMPLE
    Export-SpoListItem -Library Tasks -Field Title, Status, AssignedTo
.EXAMPLE
    $view = Get-PnPView -List Tasks -Identity 'Open'
    Export-SpoListItem -Library Tasks -Query "<View><Query>$($view.ViewQuery)</Query></View>"
    Exports what a view shows rather than the whole list.
.LINK
    Import-SpoListItem
.LINK
    Add-SpoListItem
#>
function Export-SpoListItem {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 1)]
        [string[]]$Field,

        [Parameter()]
        [switch]$IncludeSystemField,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null

        # Flattens one SharePoint field value to something a CSV can hold.
        function ConvertTo-FlatValue {
            param($Value)

            if ($null -eq $Value) { return $null }

            # Lookup and user fields arrive as FieldLookupValue objects.
            if ($Value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                return $Value.LookupValue
            }
            if ($Value -is [Microsoft.SharePoint.Client.FieldUrlValue]) {
                return $Value.Url
            }

            # Multi-value lookups and user pickers arrive as arrays.
            if ($Value -is [System.Array]) {
                return (@($Value | ForEach-Object { ConvertTo-FlatValue $_ }) -join '; ')
            }

            # Taxonomy terms expose Label; everything else stringifies fine.
            # Indexed rather than -contains against .Properties.Name: member
            # enumeration over an empty property collection is an error under
            # Set-StrictMode -Version Latest, and a value with no properties at
            # all is exactly what several system columns hold.
            if ($null -ne $Value.PSObject.Properties['Label']) {
                return $Value.Label
            }

            return $Value
        }
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        $selected = if ($Field) {
            $Field
        }
        elseif ($IncludeSystemField) {
            @(Get-PnPField -List $list | ForEach-Object { $_.InternalName })
        }
        else {
            # Non-hidden fields, plus the handful of system fields that are
            # genuinely useful in an export and would otherwise be filtered.
            $alwaysInclude = 'Title', 'Created', 'Modified', 'Author', 'Editor', 'FileLeafRef'
            @(Get-PnPField -List $list |
                    Where-Object { -not $_.Hidden -or $_.InternalName -in $alwaysInclude } |
                    ForEach-Object { $_.InternalName })
        }

        Write-O365Log "Exporting $(@($selected).Count) field(s) from '$($list.Title)'." 'Info'

        # PnP puts -Query and -PageSize in different parameter sets, so
        # passing both fails rather than paging the query.
        $itemArguments = @{ List = $list }
        if ($Query) { $itemArguments['Query'] = $Query } else { $itemArguments['PageSize'] = $PageSize }

        foreach ($item in (Get-PnPListItem @itemArguments)) {
            $record = [ordered]@{ ID = $item.Id }

            foreach ($fieldName in $selected) {
                if ($fieldName -eq 'ID') { continue }
                $record[$fieldName] = ConvertTo-FlatValue $item.FieldValues[$fieldName]
            }

            [pscustomobject]$record
        }

        Write-O365Log "Export of '$($list.Title)' complete." 'Success'
    }
}
