<#
.SYNOPSIS
    Checks the status of the current PnP PowerShell connection.

.DESCRIPTION
    This script verifies whether there is an active PnP (Patterns and Practices)
    PowerShell connection to SharePoint. It displays the connection status and
    the URL of the connected site if a connection exists.

.EXAMPLE
    .\check_pnp_connection.ps1
    Checks if there is an active PnP connection and displays the connection details.
#>

try {
  $connection = Get-PnPConnection -ErrorAction Stop
  Write-Host "✓ PnP connection is active" -ForegroundColor Green
  Write-Host "Connected to: $($connection.Url)" -ForegroundColor Cyan
}
catch {
  Write-Host "✗ No active PnP connection" -ForegroundColor Red
  Write-Host "Error: $_" -ForegroundColor Yellow
}
