<#
.SYNOPSIS
    Internal: writes a profile store back to config/profiles.json.
.DESCRIPTION
    Creates the config directory if needed and writes stable, indented JSON so
    that hand-editing and diffing stay pleasant. The file is gitignored; this
    helper does not check that, but CONTRIBUTING.md and .gitignore do.
.PARAMETER Store
    The store object returned by Get-O365ProfileStore, with modifications.
#>
function Save-O365ProfileStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Store
    )

    $directory = Split-Path -Parent $Store.Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    # Rebuild an ordered object so key order in the file is predictable.
    $profiles = [ordered]@{}
    foreach ($name in ($Store.Profiles.Keys | Sort-Object)) {
        $profiles[$name] = $Store.Profiles[$name]
    }

    $document = [ordered]@{
        '$schema'      = './profiles.schema.json'
        defaultProfile = $Store.DefaultProfile
        profiles       = $profiles
    }

    $json = $document | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $Store.Path -Value $json -Encoding utf8

    Write-O365Log "Saved profile store to '$($Store.Path)'." 'Success'
}
