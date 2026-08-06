<#
.SYNOPSIS
    Connects to a SharePoint Online site.
.DESCRIPTION
    The single entry point for authentication. Every other command in this
    module expects a connection made here (or at least a live PnP connection).

    Two ways to call it:

      By profile  - reads site URL and client ID from config/profiles.json.
                    This is what you want day to day, and what makes the repo
                    usable by someone else without editing any script.

      By value    - pass -SiteUrl and -ClientId explicitly. Useful for one-off
                    sites and for CI.

    The connection is stored in module state, not in an environment variable.
    Environment variables outlive the session that set them and leak between
    unrelated shells, which is how the old scripts ended up connecting to the
    wrong tenant.
.PARAMETER ProfileName
    Name of a profile in config/profiles.json. If omitted and no -SiteUrl is
    given, the store's defaultProfile is used. Aliased to -Profile.
.PARAMETER SiteUrl
    Full site collection URL, e.g. https://contoso.sharepoint.com/sites/team.
.PARAMETER ClientId
    Entra ID application (client) ID registered for interactive login. See
    docs/authentication.md for how to create one.
.PARAMETER Interactive
    Force an interactive browser sign-in even if a cached token exists.
.PARAMETER PassThru
    Emit the connection object. By default the command is quiet on success.
.EXAMPLE
    Connect-O365
    Connects using the default profile from config/profiles.json.
.EXAMPLE
    Connect-O365 -ProfileName test
    Connects using the 'test' profile.
.EXAMPLE
    Connect-O365 -SiteUrl 'https://contoso.sharepoint.com/sites/hr' -ClientId '1234abcd-...'
    Connects to a site not present in the profile store.
.OUTPUTS
    None by default. With -PassThru, the PnP connection object.
.LINK
    Get-O365Profile
.LINK
    Disconnect-O365
#>
function Connect-O365 {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'commandName and parameterName are required by the ArgumentCompleter signature even when unused.')]
    [CmdletBinding(DefaultParameterSetName = 'Profile')]
    [OutputType([object])]
    param(
        [Parameter(ParameterSetName = 'Profile', Position = 0)]
        [Alias('Profile')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete)
                $store = Get-O365ProfileStore
                @($store.Profiles.Keys) |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
            })]
        [string]$ProfileName,

        [Parameter(ParameterSetName = 'Explicit', Mandatory, Position = 0)]
        [ValidatePattern('^https://')]
        [string]$SiteUrl,

        [Parameter(ParameterSetName = 'Explicit', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,

        [Parameter()]
        [switch]$Interactive,

        [Parameter()]
        [switch]$PassThru
    )

    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        $store = Get-O365ProfileStore

        if (-not $store.Exists) {
            throw [System.InvalidOperationException]::new(
                "No profile store found at '$($store.Path)'. " +
                "Copy config/profiles.example.json to config/profiles.json and fill in your tenant, " +
                "or connect explicitly: Connect-O365 -SiteUrl <url> -ClientId <guid>."
            )
        }

        $resolvedProfile = if ($ProfileName) { $ProfileName } else { $store.DefaultProfile }

        if (-not $resolvedProfile) {
            throw [System.InvalidOperationException]::new(
                "No profile specified and no 'defaultProfile' set in '$($store.Path)'. " +
                "Available profiles: $(@($store.Profiles.Keys) -join ', ')."
            )
        }

        if (-not $store.Profiles.ContainsKey($resolvedProfile)) {
            throw [System.InvalidOperationException]::new(
                "Profile '$resolvedProfile' is not defined in '$($store.Path)'. " +
                "Available profiles: $(@($store.Profiles.Keys) -join ', ')."
            )
        }

        $entry    = $store.Profiles[$resolvedProfile]
        $SiteUrl  = $entry.siteUrl
        $ClientId = $entry.clientId
    }
    else {
        $resolvedProfile = $null
    }

    Write-O365Log "Connecting to '$SiteUrl' with client ID '$ClientId'." 'Info'

    $connectParams = @{
        Url      = $SiteUrl
        ClientId = $ClientId
    }
    if ($Interactive) {
        $connectParams['Interactive'] = $true
    }

    try {
        Connect-PnPOnline @connectParams -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Failed to connect to '$SiteUrl': $($_.Exception.Message) " +
            "Check that the client ID is registered in this tenant and that you have access to the site. " +
            "See docs/authentication.md.",
            $_.Exception
        )
    }

    $connection = Get-PnPConnection

    $script:O365State.Connection  = $connection
    $script:O365State.SiteUrl     = $SiteUrl
    $script:O365State.ClientId    = $ClientId
    $script:O365State.ProfileName = $resolvedProfile
    $script:O365State.ConnectedAt = Get-Date

    # Content type configuration read in a previous session may have been
    # changed since; a fresh connection starts with a fresh view of it.
    $script:O365DocumentSetTemplateCache.Clear()

    Write-O365Log "Connected to '$SiteUrl'." 'Success'

    if ($PassThru) {
        $connection
    }
}
