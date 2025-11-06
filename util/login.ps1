# Note that the Microsoft.Online.SharePoint.PowerShell module must be installed
# If not installed, run the following command as Administrator: `Install-Module -Name Microsoft.Online.SharePoint.PowerShell`

# Connect to SharePoint Online Admin Center
Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell | Select-String Name, Version

# Importing the module creates compatibility issues and throws a warning in PowerShell 7+.
# The suggested way to suppress this warning using `-SkipEditionCheck` instead of `-UseWindowsPowerShell` does not work.
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell -DisableNameChecking

Connect-SPOService -Url https://rebuildyourchurch-admin.sharepoint.com
