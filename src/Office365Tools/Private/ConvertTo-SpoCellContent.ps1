<#
.SYNOPSIS
    Internal: renders one field value as the text a printed cell shows, in
    pieces, each with the link it carries.
.DESCRIPTION
    ConvertTo-SpoCellText answers 'what does this cell say'. This answers the
    same and also 'which parts of it are links', which a plain string cannot:

      * a rich text field has links inside its text;
      * a person column links each name to the person's address, one name to a
        line.

    The Text it returns is exactly what ConvertTo-SpoCellText returns for the
    same value, because the PDF check looks for that text and nothing else.
    Everything that is not rich text or a person is one piece without a link;
    the cell as a whole may still be linked by Get-SpoCellLink.
.PARAMETER Value
    The raw field value.
.PARAMETER DateFormat
    Format for dates.
.PARAMETER Html
    Read a string as the HTML of a rich text field.
.PARAMETER SiteUrl
    Site address, for relative links inside rich text.
.OUTPUTS
    PSCustomObject with Text, and Segment: objects with Text and Href. Href is
    empty for a piece that is not a link.
.EXAMPLE
    ConvertTo-SpoCellContent -Value $item.Melder
#>
function ConvertTo-SpoCellContent {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DateFormat = 'yyyy-MM-dd',

        [Parameter()]
        [switch]$Html,

        [Parameter()]
        [string]$SiteUrl
    )

    if ($null -eq $Value) {
        return [pscustomobject]@{ Text = ''; Segment = @() }
    }

    if ($Html -and $Value -is [string]) {
        return (ConvertFrom-SpoHtmlText -Html $Value -SiteUrl $SiteUrl)
    }

    $members = @($Value)

    $allPeople = $members.Count -gt 0 -and @($members | Where-Object { -not (Test-SpoPersonValue -Value $_) }).Count -eq 0

    if ($allPeople) {
        $segments = [System.Collections.Generic.List[object]]::new()

        foreach ($person in $members) {
            $name = ConvertTo-SpoCellText -Value $person -DateFormat $DateFormat
            if ([string]::IsNullOrEmpty($name)) { continue }

            if ($segments.Count -gt 0) {
                $segments.Add([pscustomobject]@{ Text = "`n"; Href = '' })
            }

            # Only an address makes a link: a group has none, and a bare
            # address elsewhere is left as text on purpose.
            $address = "$($person.PSObject.Properties['Email'].Value)".Trim()
            $target = if ($address) { Get-SpoSafeUrl -Url "mailto:$address" } else { '' }

            $segments.Add([pscustomobject]@{ Text = $name; Href = $target })
        }

        return [pscustomobject]@{
            Text    = (@($segments | ForEach-Object { $_.Text }) -join '')
            Segment = $segments.ToArray()
        }
    }

    $text = ConvertTo-SpoCellText -Value $Value -DateFormat $DateFormat -Html:$Html -SiteUrl $SiteUrl

    return [pscustomobject]@{
        Text    = $text
        Segment = $(if ($text -ne '') { @([pscustomobject]@{ Text = $text; Href = '' }) } else { @() })
    }
}
