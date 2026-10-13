<#
.SYNOPSIS
    Internal: finds the application (client) ID to sign in with.
.DESCRIPTION
    Shared with the double-click launcher for the same reason as Language.ps1:
    one implementation, dot-sourced by both, so it follows the same two rules --
    Windows PowerShell 5.1 syntax only, and ASCII only. tests/Unit enforces both.

    The launcher used to take the ID from its settings file alone, so a machine
    that had it elsewhere -- the environment variable the old scripts set, or a
    connection profile -- was asked for it again.
#>

function Get-O365EnvironmentValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    # The process first, then what Windows has stored for the user and the
    # machine. A variable set with setx or in System Properties is not in an
    # already-open window's environment, and a launcher started from Explorer
    # may not have inherited it either.
    foreach ($scope in 'Process', 'User', 'Machine') {
        $value = [Environment]::GetEnvironmentVariable($Name, $scope)
        if ($value) {
            return $value
        }
    }

    return $null
}

function Read-O365ProfileClientId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # The default profile's clientId, or nothing. A missing or unreadable file
    # is not an error here: it only means this source has nothing to say.
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $store = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    if ($null -eq $store -or -not $store.PSObject.Properties['defaultProfile'] -or -not $store.PSObject.Properties['profiles']) {
        return $null
    }

    $entry = $store.profiles.PSObject.Properties[[string]$store.defaultProfile]
    if ($null -eq $entry -or -not $entry.Value.PSObject.Properties['clientId']) {
        return $null
    }

    return [string]$entry.Value.clientId
}

function Resolve-O365ClientId {
    <#
    .SYNOPSIS
        Internal: the client ID to sign in with, and where it came from.
    .DESCRIPTION
        The first of these that has a value wins:

          1. Settings     the value in the launcher's settings file, if one was given
          2. Environment  the environment variable gbj_client_id, which the old
                          init script set
          3. Profile      the default profile in config/profiles.json

        Returns $null when none has one. Source says which it was, so the
        launcher can tell the person instead of leaving them to wonder.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Configured,

        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Environment = (Get-O365EnvironmentValue -Name 'gbj_client_id'),

        [Parameter()]
        [string]$ProfilePath
    )

    if ($Configured) {
        return [pscustomobject]@{ ClientId = $Configured.Trim(); Source = 'Settings' }
    }

    if ($Environment) {
        return [pscustomobject]@{ ClientId = $Environment.Trim(); Source = 'Environment' }
    }

    if ($ProfilePath) {
        $fromProfile = Read-O365ProfileClientId -Path $ProfilePath
        if ($fromProfile) {
            return [pscustomobject]@{ ClientId = $fromProfile.Trim(); Source = 'Profile' }
        }
    }

    return $null
}
