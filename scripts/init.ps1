<#
.SYNOPSIS
    Initializes SharePoint connection and URL and other utilities.
.PARAMETER url
    The SharePoint URL to connect to.
.PARAMETER client_id
    (Optional) Azure AD App Registration Client ID for authentication.
    If omitted, the script uses the $env:client_id environment variable.
    On first use, you'll be prompted to login interactively via browser.
    The ClientId is stored in the session for subsequent calls.
.EXAMPLE
    .\login.ps1 -client_id "12345678-1234-1234-1234-123456789abc" -url "https://yourtenant.sharepoint.com"
    Connects to the specified SharePoint site using the provided Client ID.
#>
param(
  [Parameter(Mandatory = $true, HelpMessage = "The Client ID to register as a local environment variable.")]
  [ValidateNotNullOrEmpty()]
  [string]$client_id
)

# returns $true if available on disk (any version)
function Test-ModuleInstalled {
  param([string]$Name)
  return [bool](Get-Module -ListAvailable -Name $Name)
}

try {
  if (-not (Test-ModuleInstalled -Name 'PnP.PowerShell')) {
    Write-Host "PnP.PowerShell not found. Installing..."
    Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
  }
  else {
    Write-Host "PnP.PowerShell is installed."
  }
  # Init logging
  $parent_path = Split-Path -Path $PSScriptRoot -Parent
  $log_folder = Join-Path -Path $parent_path -ChildPath "log"
  if (-not (Test-Path -Path $log_folder)) {
    New-Item -Path $log_folder -ItemType Directory -Force | Out-Null
    Write-Host "✓ Created log folder: $log_folder" -ForegroundColor Green
  }
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $log_file = Join-Path -Path $log_folder -ChildPath "${timestamp}.log"

  $env:gbj_client_id = $client_id
  $env:gbj_current_log_file = $log_file

  $log_module_path = Join-Path -Path $parent_path -ChildPath "modules/log.psm1"
  Import-Module $log_module_path

  Write-Host "✓ Initialization successful" -ForegroundColor Green
}
catch {
  Write-Host " ✗ Initialization failed" -ForegroundColor Red
}

