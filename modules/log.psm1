Function LogImpl {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Message,
    [Parameter(Mandatory = $true)]
    [ValidateSet("info", "success", "warning", "error")]
    [string]$Level
  )
  $log_entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
  Add-Content -Path $env:gbj_current_log_file -Value $log_entry
  switch ($Level) {
    "error" { Write-Host $Message -ForegroundColor Red }
    "warning" { Write-Host $Message -ForegroundColor Yellow }
    "success" { Write-Host $Message -ForegroundColor Green }
    default { Write-Host $Message }
  }
}

Function LogError {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Message
  )
  LogImpl $Message "error"
}

Function LogWarning {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Message
  )
  LogImpl $Message "warning"
}

Function LogInfo {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Message
  )
  LogImpl $Message "info"
}

Function LogSuccess {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Message
  )
  LogImpl $Message "success"
}

Function LogEmptyLine {
  Add-Content -Path $env:gbj_current_log_file -Value ""
  Write-Host ""
}
