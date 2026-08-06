<#
.SYNOPSIS
    Internal: reads config/profiles.json, or returns an empty store.
.DESCRIPTION
    The profile file holds tenant-specific data (site URLs, client IDs) and is
    gitignored. config/profiles.example.json is the tracked template a new
    contributor copies.

    A missing file is not an error -- callers can still connect by passing
    -SiteUrl and -ClientId explicitly.
.PARAMETER Path
    Override the store location. Defaults to <repo>/config/profiles.json.
    Mainly here so tests can point at a temporary file.
.OUTPUTS
    PSCustomObject with DefaultProfile, Profiles, and Path members.
#>
function Get-O365ProfileStore {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string]$Path
    )

    if (-not $Path) {
        $Path = $script:O365ProfilePathOverride
    }
    if (-not $Path) {
        $Path = Join-Path $script:O365RepoRoot 'config/profiles.json'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            DefaultProfile = $null
            Profiles       = @{}
            Path           = $Path
            Exists         = $false
        }
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Profile file '$Path' is not valid JSON: $($_.Exception.Message). " +
            "Compare it against config/profiles.example.json."
        )
    }

    # Normalise the PSCustomObject the JSON parser produced into a hashtable,
    # so callers can do a simple ContainsKey lookup.
    $profiles = @{}
    if ($raw.PSObject.Properties.Name -contains 'profiles' -and $raw.profiles) {
        foreach ($property in $raw.profiles.PSObject.Properties) {
            $profiles[$property.Name] = $property.Value
        }
    }

    [pscustomobject]@{
        DefaultProfile = if ($raw.PSObject.Properties.Name -contains 'defaultProfile') { $raw.defaultProfile } else { $null }
        Profiles       = $profiles
        Path           = $Path
        Exists         = $true
    }
}
