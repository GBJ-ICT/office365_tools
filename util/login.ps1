#
# Connect to SharePoint with an PnP context.
# Login the first time in a session the application client ID is required.
# The ID is stored in an environment variable for subsequent calls.
#
# The client ID can be found here: https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade/quickStartType~/null/sourceType/Microsoft_AAD_IAM?Microsoft_AAD_IAM_legacyAADRedirect=true
#
# Import the login module into your script with: `Import-Module ..\path\to\login.ps1`
# Note that $PSScriptRoot can be used. This variable is the folder where your script is located.
#
Function Login() {
  param(
    [Parameter(Mandatory = $true)][string]$url,
    [Parameter(Mandatory = $false)][string]$client_id
  )
  if ($client_id -eq "") {
    Connect-PnPOnline -Url $url -ClientId $env:client_id
  }
  else {
    $env:client_id = $client_id
    Connect-PnPOnline -Url $url -ClientId $client_id
  }
}
