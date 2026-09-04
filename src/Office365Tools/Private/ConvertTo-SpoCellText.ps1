<#
.SYNOPSIS
    Internal: renders one field value as the text a printed cell shows.
.DESCRIPTION
    The renderer and the verifier must agree on what a value looks like, or
    verification checks the PDF against a string that was never printed. So
    both call this, and there is exactly one place where a date becomes
    '2026-09-06' and a multi-value lookup becomes 'a; b'.

    Left alone, a DateTime stringifies with the current culture's format and a
    lookup with its type name -- neither of which is what the cell shows.
.PARAMETER Value
    The raw field value.
.PARAMETER DateFormat
    Format string for dates that fall on midnight. Dates carrying a time get
    this plus ' HH:mm', because dropping the time from a duty roster loses the
    part people are reading.
.PARAMETER Separator
    Joins multi-value fields.
.OUTPUTS
    System.String. Never null -- an absent value is an empty string.
.EXAMPLE
    ConvertTo-SpoCellText -Value (Get-Date) -DateFormat 'dd.MM.yyyy'
#>
function ConvertTo-SpoCellText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$DateFormat = 'yyyy-MM-dd',

        [Parameter(Position = 2)]
        [AllowEmptyString()]
        [string]$Separator = '; '
    )

    if ($null -eq $Value) { return '' }

    if ($Value -is [string]) { return $Value }

    if ($Value -is [datetime]) {
        return $(if ($Value.TimeOfDay -eq [timespan]::Zero) {
                $Value.ToString($DateFormat)
            }
            else {
                $Value.ToString("$DateFormat HH:mm")
            })
    }

    if ($Value -is [bool]) { return $(if ($Value) { 'Yes' } else { 'No' }) }

    # Strings are IEnumerable too, which is why they are handled above.
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [hashtable]) {
        return (@($Value | ForEach-Object { ConvertTo-SpoCellText -Value $_ -DateFormat $DateFormat -Separator $Separator }) |
                Where-Object { $_ -ne '' }) -join $Separator
    }

    # A Hyperlink or Picture column carries both halves of a link. The
    # description is the caption the list shows; the URL is what to print when
    # nobody gave it one. Checked before the probe below, which would return
    # the URL and lose the caption.
    if ($null -ne $Value.PSObject.Properties['Url'] -and $null -ne $Value.PSObject.Properties['Description']) {
        $description = "$($Value.PSObject.Properties['Description'].Value)"
        if ($description) { return $description }
        return "$($Value.PSObject.Properties['Url'].Value)"
    }

    # Indexed rather than -contains against .Properties.Name: member
    # enumeration over an empty property collection throws under
    # Set-StrictMode -Version Latest, and several system columns hold exactly
    # that.
    foreach ($name in 'Label', 'LookupValue', 'Url', 'Email', 'Title') {
        if ($null -ne $Value.PSObject.Properties[$name]) {
            $inner = $Value.PSObject.Properties[$name].Value
            if ($null -ne $inner -and "$inner" -ne '') { return "$inner" }
        }
    }

    return [string]$Value
}
