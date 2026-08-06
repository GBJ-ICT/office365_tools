<#
.SYNOPSIS
    Lists the connection profiles defined in config/profiles.json.
.DESCRIPTION
    Profiles hold the site URL and client ID for each tenant or site this
    checkout connects to. The file is gitignored -- see
    config/profiles.example.json for the template.
.PARAMETER Name
    Return only the named profile. Supports wildcards.
.OUTPUTS
    PSCustomObject per profile.
.EXAMPLE
    Get-O365Profile
    Lists every configured profile.
.EXAMPLE
    Get-O365Profile -Name prod
.LINK
    Set-O365Profile
.LINK
    Connect-O365
#>
function Get-O365Profile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name = '*'
    )

    $store = Get-O365ProfileStore

    if (-not $store.Exists) {
        Write-O365Log (
            "No profile store at '$($store.Path)'. " +
            'Copy config/profiles.example.json to config/profiles.json to create one.'
        ) 'Warning'
        return
    }

    foreach ($key in ($store.Profiles.Keys | Sort-Object)) {
        if ($key -notlike $Name) {
            continue
        }

        $entry = $store.Profiles[$key]

        [pscustomobject]@{
            PSTypeName  = 'Office365Tools.Profile'
            Name        = $key
            IsDefault   = ($key -eq $store.DefaultProfile)
            SiteUrl     = $entry.siteUrl
            ClientId    = $entry.clientId
            Tenant      = if ($entry.PSObject.Properties.Name -contains 'tenant') { $entry.tenant } else { $null }
            Description = if ($entry.PSObject.Properties.Name -contains 'description') { $entry.description } else { $null }
            Path        = $store.Path
        }
    }
}
