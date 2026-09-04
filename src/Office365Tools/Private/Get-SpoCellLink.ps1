<#
.SYNOPSIS
    Internal: works out the URL one printed cell should link to, if any.
.DESCRIPTION
    Three sources, in this order, first one wins:

      1. -LinkFormatter, a scriptblock given the raw value, the column name and
         the whole row. Full control, for when the URL is computed.
      2. -LinkColumn, a column-to-template map. '{Name}' in the template is
         replaced with that column's value from the row, escaped for a URL;
         '{Name:raw}' inserts it verbatim, for when the value is itself a URL
         or a path that must keep its slashes.
      3. The value itself, when it already carries a scheme. A Hyperlink
         column reaches here as its URL string, so this is what makes one
         clickable without any parameter at all. A value with no scheme is
         text, whatever shape it has: a list column full of 'name@site' is far
         more often an account, a reference or an import key than a mailbox,
         and guessing turns those into links nobody can follow.

    The href comes from the *raw* value while the text comes from the renderer,
    so -CellFormatter can shorten a URL to 'Ticket 42' and the link still
    points where the data says.

    Only http, https, mailto and tel are allowed through. List content is
    someone else's text, the print runs from a local file, and a 'javascript:'
    href in a cell would be that text deciding what the browser executes.
.PARAMETER Value
    The raw field value for the cell.
.PARAMETER Column
    Internal name of the column.
.PARAMETER Row
    The whole row, for template substitution and for -LinkFormatter.
.PARAMETER LinkColumn
    Column name to URL template.
.PARAMETER LinkFormatter
    Scriptblock returning a URL, or nothing.
.PARAMETER NoAutoLink
    Do not linkify values that merely look like URLs.
.OUTPUTS
    System.String. Empty when the cell should not be a link.
.EXAMPLE
    Get-SpoCellLink -Value 'https://contoso.sharepoint.com' -Column 'Link' -Row $item
.EXAMPLE
    Get-SpoCellLink -Value 'Printer broken' -Column 'Title' -Row $item `
        -LinkColumn @{ Title = 'https://contoso.sharepoint.com/sites/CDS/Lists/t/DispForm.aspx?ID={ID}' }
#>
function Get-SpoCellLink {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory, Position = 1)]
        [string]$Column,

        [Parameter(Position = 2)]
        [AllowNull()]
        $Row,

        [Parameter()]
        [hashtable]$LinkColumn = @{},

        [Parameter()]
        [scriptblock]$LinkFormatter,

        [Parameter()]
        [switch]$NoAutoLink
    )

    # Everything below produces a candidate; this decides whether it may be
    # printed as a link at all.
    $accept = {
        param([string]$Candidate)

        if ([string]::IsNullOrWhiteSpace($Candidate)) { return '' }
        $trimmed = $Candidate.Trim()

        if ($trimmed -notmatch '^(?<scheme>[A-Za-z][A-Za-z0-9+.\-]*):') { return '' }
        if ($Matches['scheme'].ToLowerInvariant() -notin 'http', 'https', 'mailto', 'tel') { return '' }

        return $trimmed
    }

    if ($LinkFormatter) {
        $computed = & $accept ([string](& $LinkFormatter $Value $Column $Row))
        if ($computed) { return $computed }
    }

    if ($LinkColumn.ContainsKey($Column)) {
        $template = [string]$LinkColumn[$Column]

        $expanded = [regex]::Replace($template, '\{([^{}:]+)(:raw)?\}', {
                param($Match)

                $name = $Match.Groups[1].Value
                $field = if ($null -ne $Row -and $null -ne $Row.PSObject.Properties[$name]) {
                    [string]$Row.PSObject.Properties[$name].Value
                }
                else {
                    ''
                }

                if ($Match.Groups[2].Success) { $field } else { [uri]::EscapeDataString($field) }
            })

        # A template whose placeholders all came back empty produces a URL
        # pointing at the form with no item -- worse than no link.
        if ($expanded -notmatch '(\?|&|/)$' -and $expanded -notmatch '=$') {
            $candidate = & $accept $expanded
            if ($candidate) { return $candidate }
        }
    }

    if ($NoAutoLink) { return '' }

    if ($Value -is [string] -or $null -eq $Value) {
        return (& $accept ([string]$Value))
    }

    # A Hyperlink or Picture column, when it has not already been flattened to
    # its URL further up the pipeline.
    if ($null -ne $Value.PSObject.Properties['Url']) {
        return (& $accept ([string]$Value.PSObject.Properties['Url'].Value))
    }

    if ($null -ne $Value.PSObject.Properties['Email']) {
        return (& $accept ([string]$Value.PSObject.Properties['Email'].Value))
    }

    return (& $accept ([string]$Value))
}
