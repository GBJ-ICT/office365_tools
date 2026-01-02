<#
.SYNOPSIS
    Changes the SharePoint URL for an existing PnP connection.
.DESCRIPTION
    This script connects to a different SharePoint URL using the client ID
    stored in the environment variable. Requires an existing env:client_id
    from a previous login session.
.PARAMETER url
    The new SharePoint URL to connect to.
.EXAMPLE
    .\change_pnp_url.ps1 -url "https://yourtenant.sharepoint.com/sites/NewSite"
    Connects to the new SharePoint site using the stored Client ID.
.NOTES
    Requires: env:client_id must be set from a previous login
#>
param(
  [Parameter(Mandatory = $true, HelpMessage = "The new SharePoint URL to connect to.")]
  [ValidateNotNullOrEmpty()]
  [string]$url
)

# Import login utilities
$parentPath = Split-Path -Path $PSScriptRoot -Parent
. "$parentPath\util\login.ps1"

# Check if client_id is available in environment
if ([string]::IsNullOrEmpty($env:client_id)) {
  Write-Host "✗ No client_id found in environment variable" -ForegroundColor Red
  Write-Host "Please run initial_pnp_login.ps1 first to set up the client ID" -ForegroundColor Yellow
  exit 1
}

Write-Host "Using stored client ID: $env:client_id" -ForegroundColor Cyan
Write-Host "Connecting to new URL..." -ForegroundColor Yellow

try {
  Login -url $url -client_id $env:client_id
  Write-Host "✓ Connected successfully to: $url" -ForegroundColor Green
  Write-Host ""
}
catch {
  Write-Host "✗ Failed to connect to SharePoint: $_" -ForegroundColor Red
  exit 1
}
