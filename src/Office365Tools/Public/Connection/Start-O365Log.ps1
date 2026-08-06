<#
.SYNOPSIS
    Starts writing command narration to a log file.
.DESCRIPTION
    While a log is active, every module command records what it is doing to the
    file, whether or not you passed -Verbose. This gives you the audit trail the
    old scripts wrote by default -- but as an opt-in, so ad-hoc use does not
    litter the repository with log files.

    Logs go to out/ (gitignored) unless you pass an explicit -Path.

    Note this logs *narration*, not results. To keep results, pipe command
    output to Export-SpoReport or Export-Csv.
.PARAMETER Name
    Base name for the log file. A timestamp is appended.
.PARAMETER Path
    Full path to a specific log file, bypassing the out/ convention.
.PARAMETER PassThru
    Emit the resolved log file path.
.EXAMPLE
    Start-O365Log -Name library-audit
    Logs to out/library-audit_20260730_140322.log
.EXAMPLE
    Start-O365Log -Path C:\temp\run.log
.LINK
    Stop-O365Log
#>
function Start-O365Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates a local log file only. Prompting to confirm the start of logging would be noise on every run.')]
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([string])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name = 'office365tools',

        [Parameter(ParameterSetName = 'Path', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$PassThru
    )

    if ($PSCmdlet.ParameterSetName -eq 'Name') {
        $directory = Join-Path $script:O365RepoRoot 'out'
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $Path      = Join-Path $directory "${Name}_${timestamp}.log"
    }
    else {
        $directory = Split-Path -Parent $Path
    }

    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $script:O365State.LogPath = $Path

    $header = @(
        '=' * 72
        "office365_tools log started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Site: $($script:O365State.SiteUrl ?? '<not connected>')"
        "User: $env:USERNAME on $env:COMPUTERNAME"
        '=' * 72
    )
    Set-Content -LiteralPath $Path -Value $header -Encoding utf8

    Write-Verbose "Logging to '$Path'."

    if ($PassThru) {
        $Path
    }
}
