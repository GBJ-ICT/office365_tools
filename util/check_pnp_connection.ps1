
try {
  $connection = Get-PnPConnection -ErrorAction Stop
  Write-Host "✓ PnP connection is active" -ForegroundColor Green
  Write-Host "Connected to: $($connection.Url)" -ForegroundColor Cyan
} catch {
  Write-Host "✗ No active PnP connection" -ForegroundColor Red
  Write-Host "Error: $_" -ForegroundColor Yellow
}
