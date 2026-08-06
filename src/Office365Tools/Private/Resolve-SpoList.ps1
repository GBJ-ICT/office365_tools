<#
.SYNOPSIS
    Internal: resolves a list or library identifier to a PnP list object.
.DESCRIPTION
    Accepts a display title, an internal URL name, or a GUID, and fails with a
    message listing what actually exists on the site -- which is far more
    useful than PnP's default "List does not exist" when the caller has a typo
    or is on the wrong site.
.PARAMETER Identity
    Title, URL name, or GUID of the list or library.
.OUTPUTS
    Microsoft.SharePoint.Client.List
.EXAMPLE
    $list = Resolve-SpoList -Identity 'Documents'
#>
function Resolve-SpoList {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    $list = Get-PnPList -Identity $Identity -ErrorAction SilentlyContinue

    if (-not $list) {
        $available = @(Get-PnPList -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Hidden } |
                Select-Object -ExpandProperty Title |
                Sort-Object)

        $hint = if ($available.Count -gt 0) {
            "Available lists on $($script:O365State.SiteUrl): $($available -join ', ')"
        }
        else {
            'No visible lists were found on the connected site. Check that you connected to the right site.'
        }

        throw [System.InvalidOperationException]::new(
            "List or library '$Identity' was not found. $hint"
        )
    }

    return $list
}
