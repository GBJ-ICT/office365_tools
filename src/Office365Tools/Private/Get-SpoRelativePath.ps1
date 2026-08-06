<#
.SYNOPSIS
    Internal: expresses a server-relative URL as a path relative to a library
    root, plus its folder depth.
.DESCRIPTION
    Several commands need to know "how deep inside the library is this item",
    for example to distinguish a top-level folder with intentional unique
    permissions from a deeply nested item that has drifted.

    Depth 1 means the item sits directly in the library root.
.PARAMETER ServerRelativeUrl
    The item's full server-relative URL, e.g.
    /sites/team/Shared Documents/Projects/2026/plan.docx
.PARAMETER RootUrl
    The library root folder's server-relative URL, e.g.
    /sites/team/Shared Documents
.OUTPUTS
    PSCustomObject with RelativePath, Depth, ParentUrl, and Name.
#>
function Get-SpoRelativePath {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRelativeUrl,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$RootUrl
    )

    $normalizedRoot = $RootUrl.TrimEnd('/')

    $relative = if ($ServerRelativeUrl.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $ServerRelativeUrl.Substring($normalizedRoot.Length).TrimStart('/')
    }
    else {
        # Item is not under the given root. Return it whole rather than
        # silently producing a nonsense substring.
        $ServerRelativeUrl.TrimStart('/')
    }

    $segments  = @($relative -split '/' | Where-Object { $_ -ne '' })
    $lastSlash = $ServerRelativeUrl.LastIndexOf('/')

    [pscustomobject]@{
        RelativePath = $relative
        Depth        = $segments.Count
        Name         = if ($segments.Count -gt 0) { $segments[-1] } else { '' }
        ParentUrl    = if ($lastSlash -gt 0) { $ServerRelativeUrl.Substring(0, $lastSlash) } else { $normalizedRoot }
    }
}
