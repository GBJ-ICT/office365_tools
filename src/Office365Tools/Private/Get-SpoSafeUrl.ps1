<#
.SYNOPSIS
    Internal: returns a URL only when it is one a printed page may link to.
.DESCRIPTION
    Only http, https, mailto and tel are allowed through. List content is
    someone else's text, the print runs from a local file, and a 'javascript:'
    href in a cell would be that text deciding what the browser executes.

    One place decides this, so a link typed into a cell, a link inside a rich
    text field and a link built from a template all follow the same rule.
.PARAMETER Url
    The candidate.
.OUTPUTS
    System.String. The trimmed URL, or an empty string when it may not be a
    link.
.EXAMPLE
    Get-SpoSafeUrl -Url 'https://contoso.sharepoint.com/sites/x'
.EXAMPLE
    Get-SpoSafeUrl -Url 'javascript:alert(1)'
    Returns an empty string.
#>
function Get-SpoSafeUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $trimmed = $Url.Trim()

    if ($trimmed -notmatch '^(?<scheme>[A-Za-z][A-Za-z0-9+.\-]*):') { return '' }
    if ($Matches['scheme'].ToLowerInvariant() -notin 'http', 'https', 'mailto', 'tel') { return '' }

    return $trimmed
}
