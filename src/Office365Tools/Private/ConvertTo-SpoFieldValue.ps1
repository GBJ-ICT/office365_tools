<#
.SYNOPSIS
    Internal: reduces a SharePoint field value to a canonical comparison key.
.DESCRIPTION
    "Do these two items carry the same metadata?" is not answerable with -eq.
    A managed metadata value is an object whose ToString() varies, a lookup or
    person value is an object holding an ID and a display name, and a
    multi-value column is a collection whose order SharePoint does not
    guarantee. Comparing any of those directly produces false differences.

    This reduces a value to a string that is identical for two equivalent
    values and different otherwise:

      Managed metadata  compared by term GUID, not label -- labels differ per
                        language and get renamed in the term store while the
                        GUID stays put.
      Lookup / person   compared by lookup ID, not display name.
      Collections       elements are keyed, then sorted, so order never
                        matters.
      Dates             normalised to UTC seconds; sub-second noise from
                        round-tripping is not a metadata difference.
      Numbers           invariant culture, so 1 and 1.0 match and a German
                        locale does not turn a decimal point into a comma.

    Properties are probed through PSObject rather than by type so the CSOM
    types (which cannot be constructed in a unit test) and plain objects with
    the same shape both work. That is what makes this testable without a
    tenant.

    An empty string means "no value" -- null, empty string, and an empty
    collection all reduce to it, because SharePoint uses the three
    interchangeably depending on how the item was written.
.PARAMETER Value
    The raw value out of an item's FieldValues.
.OUTPUTS
    System.String
.EXAMPLE
    ConvertTo-SpoFieldValueKey -Value $item.FieldValues['ProjectStatus']
#>
function ConvertTo-SpoFieldValueKey {
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

    if ($Value -is [string]) {
        return $Value.Trim()
    }

    if ($Value -is [bool]) {
        return ([bool]$Value).ToString()
    }

    if ($Value -is [datetime]) {
        return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
    }

    if ($Value -is [ValueType]) {
        # Covers int, long, double, decimal, float. 'G15' then trimming keeps
        # 1 and 1.0 equal without collapsing genuinely different decimals.
        return ([double]$Value).ToString('G15', [cultureinfo]::InvariantCulture)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $keys = @(foreach ($element in $Value) { ConvertTo-SpoFieldValueKey -Value $element })
        $keys = @($keys | Where-Object { $_ -ne '' })

        if ($keys.Count -eq 0) {
            return ''
        }

        return (@($keys | Sort-Object) -join ';')
    }

    $properties = @($Value.PSObject.Properties.Name)

    if ($properties -contains 'TermGuid') {
        $guid = [string]$Value.TermGuid
        if ([string]::IsNullOrWhiteSpace($guid)) {
            return ''
        }
        return 'term:' + $guid.Trim('{', '}').ToLowerInvariant()
    }

    if ($properties -contains 'LookupId') {
        $id = $Value.LookupId
        # -1 is CSOM's "unresolved", which SharePoint also writes for a person
        # whose account was deleted. Treat it as no value rather than as a
        # difference from every other unresolved entry.
        if ($null -eq $id -or $id -le 0) {
            return ''
        }
        return "lookup:$id"
    }

    if ($properties -contains 'Url') {
        $url = [string]$Value.Url
        if ([string]::IsNullOrWhiteSpace($url)) {
            return ''
        }
        $description = if ($properties -contains 'Description') { [string]$Value.Description } else { '' }
        return "url:$($url.Trim())|$($description.Trim())"
    }

    return ([string]$Value).Trim()
}

<#
.SYNOPSIS
    Internal: renders a SharePoint field value as text a person can read.
.DESCRIPTION
    The counterpart to ConvertTo-SpoFieldValueKey. The key is built for
    correctness (GUIDs and IDs); this is built for a report column, so it
    prefers the label a user would recognise.

    Never use this for comparison: two different terms can share a label, and
    a renamed term changes its label while remaining the same term.
.PARAMETER Value
    The raw value out of an item's FieldValues.
.OUTPUTS
    System.String
.EXAMPLE
    ConvertTo-SpoFieldValueText -Value $item.FieldValues['ProjectStatus']
#>
function ConvertTo-SpoFieldValueText {
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

    if ($Value -is [string]) {
        return $Value.Trim()
    }

    if ($Value -is [datetime]) {
        return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
    }

    if ($Value -is [ValueType]) {
        return [string]$Value
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = @(foreach ($element in $Value) { ConvertTo-SpoFieldValueText -Value $element })
        return (@($parts | Where-Object { $_ -ne '' }) -join '; ')
    }

    $properties = @($Value.PSObject.Properties.Name)

    if ($properties -contains 'Label') {
        return [string]$Value.Label
    }

    if ($properties -contains 'LookupValue') {
        return [string]$Value.LookupValue
    }

    if ($properties -contains 'Url') {
        return [string]$Value.Url
    }

    return [string]$Value
}

<#
.SYNOPSIS
    Internal: converts a read field value into the form Set-PnPListItem wants.
.DESCRIPTION
    SharePoint hands back rich objects on read but insists on primitives on
    write, and the shape differs per column type. Copying a value from one item
    to another therefore means translating it:

      Managed metadata  'Label|TermGuid' (a list of them for a multi-value
                        column). PnP resolves the hidden taxonomy list entry.
      Person or group   the e-mail address, falling back to the display name.
                        *Not* the ID: Set-PnPListItem rejects a numeric user
                        ID with "the specified user was not found", because it
                        resolves user fields by calling EnsureUser with the
                        value as a login. Lookup fields are the opposite --
                        they want the ID -- and the two are told apart by the
                        Email property, which only a user value carries.
      Lookup            the numeric lookup ID.
      Hyperlink         'url, description'.
      Everything else   passes through unchanged.

    Returns $null for an empty value, which Set-PnPListItem writes as "clear
    this column".
.PARAMETER Value
    The raw value read from the source item's FieldValues.
.OUTPUTS
    The value to hand to Set-PnPListItem -Values.
.EXAMPLE
    $writable = ConvertTo-SpoFieldUpdateValue -Value $documentSet.FieldValues['ProjectStatus']
#>
function ConvertTo-SpoFieldUpdateValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
        return $Value
    }

    if ($Value -is [ValueType]) {
        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $converted = @(foreach ($element in $Value) { ConvertTo-SpoFieldUpdateValue -Value $element })
        $converted = @($converted | Where-Object { $null -ne $_ })

        if ($converted.Count -eq 0) {
            return $null
        }

        return $converted
    }

    $properties = @($Value.PSObject.Properties.Name)

    if ($properties -contains 'TermGuid') {
        $guid = [string]$Value.TermGuid
        if ([string]::IsNullOrWhiteSpace($guid)) { return $null }
        $label = if ($properties -contains 'Label') { [string]$Value.Label } else { '' }
        return "$label|$($guid.Trim('{', '}'))"
    }

    # A person or group value. Only these carry Email, which is what
    # distinguishes them from a plain lookup -- and they need a login rather
    # than an ID on write.
    if ($properties -contains 'Email') {
        $email = [string]$Value.Email
        if (-not [string]::IsNullOrWhiteSpace($email)) {
            return $email.Trim()
        }

        # A SharePoint group, or a principal with no mailbox: the display name
        # is all that is left, and EnsureUser does resolve group names.
        $display = if ($properties -contains 'LookupValue') { [string]$Value.LookupValue } else { '' }
        if (-not [string]::IsNullOrWhiteSpace($display)) {
            return $display.Trim()
        }

        return $null
    }

    if ($properties -contains 'LookupId') {
        $id = $Value.LookupId
        if ($null -eq $id -or $id -le 0) { return $null }
        return [int]$id
    }

    if ($properties -contains 'Url') {
        $url = [string]$Value.Url
        if ([string]::IsNullOrWhiteSpace($url)) { return $null }
        $description = if ($properties -contains 'Description') { [string]$Value.Description } else { '' }
        if ([string]::IsNullOrWhiteSpace($description)) { return $url }
        return "$url, $description"
    }

    return $Value
}
