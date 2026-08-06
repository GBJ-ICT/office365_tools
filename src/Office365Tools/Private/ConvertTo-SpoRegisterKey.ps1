<#
.SYNOPSIS
    Internal: reduces a field value to the text that identifies a register
    entry.
.DESCRIPTION
    Deciding "does this list already have a row for that Document Set" needs a
    key that is stable on both sides of the comparison, and the two sides do not
    hold the same shape. The register holds a read hyperlink value; the source
    holds a plain string. ConvertTo-SpoFieldValueKey is no use here because it
    keys a hyperlink on url|description together, and the source has only one
    of the two.

    A Document ID column is therefore keyed on the ID in its URL -- the
    'ID=GBJCDS-204499463-31' of a DocIdRedir.aspx link -- which is exactly the
    string the source Document Set carries in _dlc_DocId.

    **Not on the link text**, and that distinction is load-bearing rather than
    fussy. SharePoint fills the text in with the Document ID, so the two agree
    right up until someone relabels the column to show something friendlier;
    from that moment a description-keyed match finds nothing, every Document Set
    looks unregistered, and the next sync duplicates the entire register. The
    URL cannot be relabelled, so it is the half worth trusting.

    Any other hyperlink keeps the old rule -- description when it has one,
    otherwise the URL -- and anything that is not a hyperlink at all falls
    through to the normal comparison key.

    Comparison is case-insensitive, because SharePoint round-trips URLs with
    the site collection's casing rather than the one that was written.
.PARAMETER Value
    The raw value out of an item's FieldValues, or a plain string.
.OUTPUTS
    System.String. Empty means the item has no usable key.
.EXAMPLE
    ConvertTo-SpoRegisterKey -Value $item.FieldValues['Document_x0020_ID']
#>
function ConvertTo-SpoRegisterKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -isnot [string] -and $Value -isnot [ValueType]) {
        $properties = @($Value.PSObject.Properties.Name)

        if ($properties -contains 'Url') {
            $url = [string]$Value.Url

            # Anchored on DocIdRedir.aspx rather than on any 'ID=' parameter,
            # because the reference column's URL carries an 'id=' too -- the
            # folder path it points at -- and keying a back-link on half of
            # itself would be a different bug wearing the same clothes.
            if ($url -match 'DocIdRedir\.aspx\?(?:.*&)?ID=([^&]+)') {
                return [uri]::UnescapeDataString($Matches[1]).Trim().ToLowerInvariant()
            }

            $description = if ($properties -contains 'Description') { [string]$Value.Description } else { '' }

            if (-not [string]::IsNullOrWhiteSpace($description)) {
                return $description.Trim().ToLowerInvariant()
            }

            return $url.Trim().ToLowerInvariant()
        }
    }

    return (ConvertTo-SpoFieldValueKey -Value $Value).ToLowerInvariant()
}
