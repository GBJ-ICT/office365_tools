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
    Joins multi-value fields. People are the exception: several of them are
    joined with a line break, one name to a line.
.PARAMETER Html
    Treat a string as the HTML of a rich text field: tags removed, paragraphs
    and list items on their own lines, entities decoded.
.PARAMETER SiteUrl
    Site address, for resolving relative links inside -Html. It does not
    change the text, which is why it is optional.
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
        [string]$Separator = '; ',

        [Parameter()]
        [switch]$Html,

        [Parameter()]
        [string]$SiteUrl
    )

    if ($null -eq $Value) { return '' }

    if ($Value -is [string]) {
        if ($Html) { return (ConvertFrom-SpoHtmlText -Html $Value -SiteUrl $SiteUrl).Text }
        return $Value
    }

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
        $members = @($Value)

        # A person column with several people reads best as one name to a line.
        $joiner = $Separator
        if ($members.Count -gt 0 -and @($members | Where-Object { -not (Test-SpoPersonValue -Value $_) }).Count -eq 0) {
            $joiner = "`n"
        }

        return (@($members | ForEach-Object { ConvertTo-SpoCellText -Value $_ -DateFormat $DateFormat -Separator $Separator -Html:$Html -SiteUrl $SiteUrl }) |
                Where-Object { $_ -ne '' }) -join $joiner
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
    # A person with no display name still prints as something: the account, or
    # failing that the address.
    foreach ($name in 'Label', 'LookupValue', 'Url', 'LoginName', 'Email', 'Title') {
        if ($null -ne $Value.PSObject.Properties[$name]) {
            $inner = $Value.PSObject.Properties[$name].Value
            if ($null -ne $inner -and "$inner" -ne '') { return "$inner" }
        }
    }

    return [string]$Value
}
