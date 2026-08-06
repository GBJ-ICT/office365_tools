<#
.SYNOPSIS
    Stops writing command narration to a log file.
.DESCRIPTION
    Closes the log started by Start-O365Log. Safe to call when no log is
    active.
.PARAMETER PassThru
    Emit the path of the log that was closed.
.EXAMPLE
    Stop-O365Log
.LINK
    Start-O365Log
#>
function Stop-O365Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Closes a local log file. Nothing on the tenant changes.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [switch]$PassThru
    )

    $path = $script:O365State.LogPath

    if (-not $path) {
        Write-Verbose 'No log is active.'
        return
    }

    try {
        Add-Content -LiteralPath $path -Value @(
            '=' * 72
            "office365_tools log stopped $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        ) -Encoding utf8
    }
    catch {
        Write-Warning "Could not write log footer: $($_.Exception.Message)"
    }

    $script:O365State.LogPath = $null
    Write-Verbose "Stopped logging to '$path'."

    if ($PassThru) {
        $path
    }
}
