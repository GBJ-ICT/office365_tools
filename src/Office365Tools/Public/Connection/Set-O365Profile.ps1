<#
.SYNOPSIS
    Creates or updates a connection profile.
.DESCRIPTION
    Writes an entry into config/profiles.json, creating the file if it does not
    exist. This is the friendly alternative to hand-editing JSON, and it means
    a new user can go from clone to connected without opening an editor.

    The file is gitignored: it contains your tenant's site URLs and client IDs.
.PARAMETER Name
    Profile name, e.g. 'prod' or 'sandbox'.
.PARAMETER SiteUrl
    Full site collection URL.
.PARAMETER ClientId
    Entra ID application (client) ID used for interactive login.
.PARAMETER Tenant
    Tenant name, e.g. contoso.onmicrosoft.com. Optional; used by setup docs.
.PARAMETER Description
    Free-text note shown by Get-O365Profile.
.PARAMETER SetDefault
    Make this the profile Connect-O365 uses when called with no arguments.
.EXAMPLE
    Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/cds' `
        -ClientId '1234abcd-...' -Tenant 'contoso.onmicrosoft.com' -SetDefault
.LINK
    Get-O365Profile
.LINK
    Remove-O365Profile
#>
function Set-O365Profile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidatePattern('^https://')]
        [string]$SiteUrl,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$ClientId,

        [Parameter()]
        [string]$Tenant,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$SetDefault
    )

    $store = Get-O365ProfileStore

    $entry = [ordered]@{
        siteUrl  = $SiteUrl
        clientId = $ClientId
    }
    if ($Tenant) { $entry['tenant'] = $Tenant }
    if ($Description) { $entry['description'] = $Description }

    $action = if ($store.Profiles.ContainsKey($Name)) { 'Update profile' } else { 'Create profile' }

    if ($PSCmdlet.ShouldProcess("$Name -> $SiteUrl", $action)) {
        $store.Profiles[$Name] = [pscustomobject]$entry

        # First profile written becomes the default automatically, otherwise
        # the user would have to remember -SetDefault on their very first call.
        if ($SetDefault -or -not $store.DefaultProfile -or $store.Profiles.Count -eq 1) {
            $store.DefaultProfile = $Name
        }

        Save-O365ProfileStore -Store $store
        Get-O365Profile -Name $Name
    }
}
