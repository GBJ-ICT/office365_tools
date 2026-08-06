<#
    Module loader.

    Dot-sources Private/ first (helpers the public commands depend on), then
    Public/. Only Public/ is exported, and the export list is derived from the
    file names -- so adding a command is exactly: drop Verb-Noun.ps1 into
    Public/<Area>/ and add the name to the manifest's FunctionsToExport.

    Files are dot-sourced into the module scope rather than the caller's, so
    private helpers stay genuinely private.
#>

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module-scoped state.
#
# Everything the module remembers between commands lives here. This replaces
# the $env:client_id / $env:gbj_client_id variables the old scripts used --
# environment variables leak across unrelated sessions and survive process
# restarts in ways that surprise people.
# ---------------------------------------------------------------------------
$script:O365State = [pscustomobject]@{
    Connection  = $null   # PnP connection object returned by Connect-PnPOnline
    SiteUrl     = $null   # URL we are connected to
    ProfileName = $null   # Name of the profile used, if any
    ClientId    = $null
    LogPath     = $null   # Active transcript-style log file, if Start-O365Log ran
    ConnectedAt = $null
}

# Document Set templates are read once per site and content type. Resolving one
# costs a round trip, and a library with hundreds of Document Sets shares a
# handful of templates between all of them.
$script:O365DocumentSetTemplateCache = @{}

# Repository root, resolved once. Used to locate config/ and out/.
$script:O365ModuleRoot = $PSScriptRoot
$script:O365RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

# Set by tests (and advanced users) to point the profile store somewhere other
# than <repo>/config/profiles.json. Null means "use the default location".
$script:O365ProfilePathOverride = $null

# ---------------------------------------------------------------------------
# Load implementation files.
# ---------------------------------------------------------------------------
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
$public  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

foreach ($file in @($private) + @($public)) {
    try {
        . $file.FullName
    }
    catch {
        throw "Failed to load '$($file.FullName)': $_"
    }
}

Export-ModuleMember -Function $public.BaseName

# ---------------------------------------------------------------------------
# Clean up the connection when the module is removed, so `Remove-Module` does
# not leave a dangling PnP session behind.
# ---------------------------------------------------------------------------
$ExecutionContext.SessionState.Module.OnRemove = {
    if ($script:O365State.Connection) {
        try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
        }
        catch {
            # Module teardown must not throw: PowerShell is already unloading
            # us, and a failure here would surface as a confusing error on an
            # unrelated Remove-Module or session exit.
            Write-Verbose "Ignoring disconnect error during module removal: $($_.Exception.Message)"
        }
    }
}
