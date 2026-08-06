<#
.SYNOPSIS
    Shows the current connection state.
.DESCRIPTION
    Reports which site the module is connected to, which profile was used, and
    whether PnP still considers the connection live. Useful as a first
    diagnostic when a command reports "not connected".
.OUTPUTS
    PSCustomObject describing the connection, or nothing if not connected.
.EXAMPLE
    Get-O365Connection
.LINK
    Connect-O365
#>
function Get-O365Connection {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $live = $null
    try {
        $live = Get-PnPConnection -ErrorAction Stop
    }
    catch {
        $live = $null
    }

    if (-not $live -and -not $script:O365State.Connection) {
        Write-O365Log "Not connected. Run 'Connect-O365' to connect." 'Info'
        return
    }

    [pscustomobject]@{
        PSTypeName  = 'Office365Tools.Connection'
        SiteUrl     = if ($live) { $live.Url } else { $script:O365State.SiteUrl }
        ProfileName = $script:O365State.ProfileName
        ClientId    = $script:O365State.ClientId
        ConnectedAt = $script:O365State.ConnectedAt
        IsLive      = [bool]$live
        LogPath     = $script:O365State.LogPath
    }
}
