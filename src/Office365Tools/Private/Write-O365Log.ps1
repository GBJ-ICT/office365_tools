<#
.SYNOPSIS
    Internal: writes a narration message to the active log file and the
    appropriate PowerShell stream.
.DESCRIPTION
    This is the module's single logging path. It replaces the two competing
    implementations the old script collection had (util/logging.ps1 with an
    explicit -LogFile parameter, and modules/log.psm1 reading
    $env:gbj_current_log_file).

    Narration goes to the verbose or warning stream, never to the host, so
    command output stays clean and pipeable. If Start-O365Log has been called,
    every message is also appended to the log file regardless of whether the
    user passed -Verbose.

    Call sites that need to emit a real, catchable error record should call
    Write-Error or throw directly; this helper only narrates.
.PARAMETER Message
    The text to log.
.PARAMETER Level
    Info and Success go to the verbose stream. Warning and Error go to the
    warning stream. All four are recorded in the log file with their level.
.EXAMPLE
    Write-O365Log -Message "Scanned $count items" -Level Success
#>
function Write-O365Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if ($script:O365State.LogPath) {
        $line = '[{0}] [{1,-7}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpperInvariant(), $Message
        try {
            Add-Content -LiteralPath $script:O365State.LogPath -Value $line -Encoding utf8
        }
        catch {
            # A failing log file must never take down the operation being
            # logged. Surface it once and carry on.
            Write-Warning "Could not write to log file '$($script:O365State.LogPath)': $($_.Exception.Message)"
            $script:O365State.LogPath = $null
        }
    }

    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Warning $Message }
        default { Write-Verbose $Message }
    }
}
