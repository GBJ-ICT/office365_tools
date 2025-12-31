<#
.SYNOPSIS
    Logging utility functions for Office365 tools.

.DESCRIPTION
    Provides functions to initialize logging and write log entries to both
    console and file. Automatically creates log folder if it doesn't exist.

.NOTES
    Author: Office365 Tools
    Date: December 31, 2025
#>

<#
.SYNOPSIS
    Initializes logging by creating log folder and file.

.DESCRIPTION
    Creates a log folder if it doesn't exist and returns the path to a
    timestamped log file.

.PARAMETER LogFileName
    The base name for the log file (without timestamp or extension).

.PARAMETER LogFolder
    The path to the log folder where the log file will be created.

.EXAMPLE
    $logFolder = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "log"
    $logFile = Initialize-Logging -LogFileName "library_permissions" -LogFolder $logFolder
    Returns path like: C:\path\to\log\library_permissions_20251231_163840.log
#>
Function Initialize-Logging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFileName,
        [Parameter(Mandatory = $true)]
        [string]$LogFolder
    )

    # Create log folder if it doesn't exist
    if (-not (Test-Path -Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created log folder: $logFolder" -ForegroundColor Green
    }

    # Create log file with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path -Path $logFolder -ChildPath "${LogFileName}_${timestamp}.log"

    return $logFile
}

<#
.SYNOPSIS
    Writes a message to both console and log file.

.DESCRIPTION
    Appends a timestamped log entry to the specified log file and displays
    it in the console with appropriate color formatting based on log level.

.PARAMETER Message
    The message to log.

.PARAMETER Level
    The log level (INFO, SUCCESS, WARNING, ERROR). Default is INFO.

.PARAMETER LogFile
    The path to the log file.

.EXAMPLE
    Write-LogEntry -Message "Processing complete" -Level "SUCCESS" -LogFile $logFile
#>
Function Write-LogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}
