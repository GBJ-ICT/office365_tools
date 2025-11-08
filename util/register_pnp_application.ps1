
$application_name = "GBJ-ICT Office365 Tools PnP Login"
$tenant = "rebuildyourchurch.onmicrosoft.com"

Uninstall-Module SharePointPnPPowerShellOnline -Force -AllVersions
Install-Module PnP.PowerShell
Get-Module -ListAvailable -Name PnP.PowerShell | Select-String Name, Version
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName $application_name -SharePointDelegatePermissions "AllSites.FullControl" -Tenant $tenant
