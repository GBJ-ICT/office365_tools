<#
.SYNOPSIS
    Closes the current SharePoint connection.
.DESCRIPTION
    Disconnects the PnP session and clears the module's cached connection
    state. Safe to call when nothing is connected.
.EXAMPLE
    Disconnect-O365
.LINK
    Connect-O365
#>
function Disconnect-O365 {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $script:O365State.Connection) {
        Write-O365Log 'No active connection to disconnect.' 'Info'
        return
    }

    $target = $script:O365State.SiteUrl

    if ($PSCmdlet.ShouldProcess($target, 'Disconnect')) {
        try {
            Disconnect-PnPOnline -ErrorAction Stop
        }
        catch {
            Write-O365Log "PnP reported an error while disconnecting: $($_.Exception.Message)" 'Warning'
        }

        $script:O365State.Connection  = $null
        $script:O365State.SiteUrl     = $null
        $script:O365State.ClientId    = $null
        $script:O365State.ProfileName = $null
        $script:O365State.ConnectedAt = $null

        $script:O365DocumentSetTemplateCache.Clear()

        Write-O365Log "Disconnected from '$target'." 'Success'
    }
}
