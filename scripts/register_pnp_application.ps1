<#
.SYNOPSIS
    Registers a PnP Entra ID application for interactive SharePoint login.

.DESCRIPTION
    This script uninstalls legacy SharePointPnPPowerShellOnline module, installs
    the modern PnP.PowerShell module, and registers a new Entra ID application
    with SharePoint delegated permissions for interactive authentication. The
    application is configured with AllSites.FullControl permissions.

.EXAMPLE
    .\register_pnp_application.ps1
    Registers the PnP application for the configured tenant.
#>

$application_name = "GBJ-ICT Office365 Tools PnP Login"
$tenant = "rebuildyourchurch.onmicrosoft.com"

Uninstall-Module SharePointPnPPowerShellOnline -Force -AllVersions
Install-Module PnP.PowerShell
Get-Module -ListAvailable -Name PnP.PowerShell | Select-String Name, Version
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName $application_name -SharePointDelegatePermissions "AllSites.FullControl" -Tenant $tenant
