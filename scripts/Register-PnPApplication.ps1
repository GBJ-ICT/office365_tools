<#
.SYNOPSIS
    Registers an Entra ID application for interactive SharePoint sign-in.
.DESCRIPTION
    One-time setup, run once per tenant by someone with permission to register
    applications. It produces the client ID that everyone else puts in their
    config/profiles.json.

    The predecessor script had the tenant name hard-coded, which meant nobody
    else could run it. Tenant and application name are parameters now.

    Requires: an account that may register applications and grant admin consent
    (Application Administrator or Global Administrator).
.PARAMETER Tenant
    Tenant name, e.g. contoso.onmicrosoft.com.
.PARAMETER ApplicationName
    Display name for the registered application, as it will appear in Entra ID.
.PARAMETER Permission
    SharePoint delegated permission scopes to request. The default grants full
    control of all site collections, which is what the administrative commands
    in this module need. Narrow it if your use case is read-only.
.PARAMETER ProfileName
    After registration, save the result as a connection profile under this
    name. Requires -SiteUrl.
.PARAMETER SiteUrl
    Site URL to store in the profile. Only used with -ProfileName.
.EXAMPLE
    ./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com

    Registers 'office365_tools PnP Login' and prints the client ID.
.EXAMPLE
    ./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com `
        -ProfileName prod -SiteUrl https://contoso.sharepoint.com/sites/team

    Registers the application and writes a ready-to-use profile.
.EXAMPLE
    ./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com `
        -Permission 'AllSites.Read'

    Registers a read-only application, enough for the Get/Test/Find commands.
.NOTES
    A browser window opens for consent. The client ID is written to the
    console; store it in config/profiles.json (or use -ProfileName).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Tenant,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName = 'office365_tools PnP Login',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$Permission = @('AllSites.FullControl'),

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [ValidatePattern('^https://')]
    [string]$SiteUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ProfileName -and -not $SiteUrl) {
    throw '-ProfileName requires -SiteUrl so the profile knows which site to connect to.'
}

if (-not (Get-Module -ListAvailable PnP.PowerShell)) {
    Write-Host 'Installing PnP.PowerShell...' -ForegroundColor Yellow
    Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
}

Import-Module PnP.PowerShell

$version = (Get-Module -ListAvailable PnP.PowerShell | Sort-Object Version -Descending | Select-Object -First 1).Version
Write-Host "PnP.PowerShell $version" -ForegroundColor Gray

if (-not $PSCmdlet.ShouldProcess($Tenant, "Register Entra ID application '$ApplicationName' with $($Permission -join ', ')")) {
    return
}

Write-Host ''
Write-Host "Registering '$ApplicationName' in $Tenant..." -ForegroundColor Cyan
Write-Host 'A browser window will open for sign-in and consent.' -ForegroundColor Gray
Write-Host ''

$result = Register-PnPEntraIDAppForInteractiveLogin `
    -ApplicationName $ApplicationName `
    -SharePointDelegatePermissions $Permission `
    -Tenant $Tenant

Write-Host ''
Write-Host 'Registration complete.' -ForegroundColor Green
Write-Host "  Client ID: $($result.'AzureAppId/ClientId')" -ForegroundColor White
Write-Host ''
Write-Host 'Consent can take a few minutes to propagate. If the first connection' -ForegroundColor Gray
Write-Host 'fails with an authorisation error, wait and retry.' -ForegroundColor Gray

if ($ProfileName) {
    Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

    Set-O365Profile -Name $ProfileName `
        -SiteUrl $SiteUrl `
        -ClientId $result.'AzureAppId/ClientId' `
        -Tenant $Tenant `
        -Description "Registered by Register-PnPApplication.ps1 on $(Get-Date -Format 'yyyy-MM-dd')"

    Write-Host ''
    Write-Host "Saved profile '$ProfileName'. Connect with: Connect-O365 -ProfileName $ProfileName" -ForegroundColor Green
}
else {
    Write-Host ''
    Write-Host 'Save it as a profile with:' -ForegroundColor Cyan
    Write-Host "  Set-O365Profile -Name prod -SiteUrl <your-site> -ClientId $($result.'AzureAppId/ClientId') -Tenant $Tenant" -ForegroundColor White
}
