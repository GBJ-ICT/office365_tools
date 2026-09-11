<#
.SYNOPSIS
    Internal: guarantees PnP.PowerShell is available, or throws with the
    command that installs it.
.DESCRIPTION
    The manifest does not declare PnP.PowerShell in RequiredModules, because
    that is enforced at import time and would make the offline commands
    unusable without a 100 MB dependency nobody needs to check a file name.

    The cost of that choice is this helper: every path that reaches a tenant
    has to say so itself. Without it the failure is a bare
    "Connect-PnPOnline is not recognised", which tells a non-PowerShell user
    nothing at all.
.OUTPUTS
    None. Throws when PnP.PowerShell cannot be found.
.EXAMPLE
    Assert-SpoPnPModule
#>
function Assert-SpoPnPModule {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (Get-Command -Name 'Connect-PnPOnline' -ErrorAction SilentlyContinue) {
        return
    }

    if (Get-Module -ListAvailable -Name 'PnP.PowerShell' -ErrorAction SilentlyContinue) {
        # Installed but not loaded: importing it here is friendlier than
        # telling someone to import a module they already have.
        Import-Module -Name 'PnP.PowerShell' -ErrorAction Stop
        return
    }

    throw [System.InvalidOperationException]::new(
        "This command talks to SharePoint, which needs the PnP.PowerShell module. " +
        "Install it once with: Install-Module PnP.PowerShell -Scope CurrentUser " +
        "-- or use only the offline commands (Test-SpoFileName, Get-SpoRecurringDate, " +
        "Export-SpoReport, and scripts/Test-Upload.ps1 without -Library), which need nothing extra."
    )
}
