<#
.SYNOPSIS
    Internal: guarantees there is a usable SharePoint connection, or throws
    with a message that tells the caller exactly what to do next.
.DESCRIPTION
    Every command that talks to SharePoint calls this first. It checks the
    module's own state and then confirms PnP still has a live connection --
    the two can diverge if the user called Disconnect-PnPOnline directly or
    the token expired.
.OUTPUTS
    The PnP connection object.
.EXAMPLE
    $connection = Assert-SpoConnection
#>
function Assert-SpoConnection {
    [CmdletBinding()]
    [OutputType([object])]
    param()

    try {
        $connection = Get-PnPConnection -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Not connected to SharePoint. Run 'Connect-O365' first " +
            "(for example: Connect-O365 -Profile prod, or " +
            "Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId <guid>)."
        )
    }

    if (-not $connection) {
        throw [System.InvalidOperationException]::new(
            "Not connected to SharePoint. Run 'Connect-O365' first."
        )
    }

    # Keep module state honest if the connection was made outside this module.
    if (-not $script:O365State.Connection) {
        $script:O365State.Connection  = $connection
        $script:O365State.SiteUrl     = $connection.Url
        $script:O365State.ConnectedAt = Get-Date
    }

    return $connection
}
