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
    [string]$SiteUrl,

    [Parameter()]
    [ValidateSet('en', 'de', 'auto')]
    [string]$Language
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The module is imported first, whatever else happens, so that everything this
# script says can be said in the language in use. -Language applies to this
# session only, and the texts of this script live in scripts\Resources.
Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

if ($Language) {
    Set-O365Language -Language $Language -SessionOnly -WhatIf:$false
}

. (Join-Path $PSScriptRoot 'Shared/ScriptLanguage.ps1')

if ($ProfileName -and -not $SiteUrl) {
    throw (Get-ScriptString 'Register.NeedsSiteUrl')
}

if (-not (Get-Module -ListAvailable PnP.PowerShell)) {
    Write-Host (Get-ScriptString 'Register.Installing') -ForegroundColor Yellow
    Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
}

Import-Module PnP.PowerShell

$version = (Get-Module -ListAvailable PnP.PowerShell | Sort-Object Version -Descending | Select-Object -First 1).Version
Write-Host "PnP.PowerShell $version" -ForegroundColor Gray

if (-not $PSCmdlet.ShouldProcess($Tenant, (Get-ScriptString 'Register.Action' $ApplicationName ($Permission -join ', ')))) {
    return
}

Write-Host ''
Write-Host (Get-ScriptString 'Register.Registering' $ApplicationName $Tenant) -ForegroundColor Cyan
Write-Host (Get-ScriptString 'Register.BrowserWillOpen') -ForegroundColor Gray
Write-Host ''

$result = Register-PnPEntraIDAppForInteractiveLogin `
    -ApplicationName $ApplicationName `
    -SharePointDelegatePermissions $Permission `
    -Tenant $Tenant

Write-Host ''
Write-Host (Get-ScriptString 'Register.Complete') -ForegroundColor Green
Write-Host (Get-ScriptString 'Register.ClientId' $result.'AzureAppId/ClientId') -ForegroundColor White
Write-Host ''
Write-Host (Get-ScriptString 'Register.Consent1') -ForegroundColor Gray
Write-Host (Get-ScriptString 'Register.Consent2') -ForegroundColor Gray

if ($ProfileName) {
    Set-O365Profile -Name $ProfileName `
        -SiteUrl $SiteUrl `
        -ClientId $result.'AzureAppId/ClientId' `
        -Tenant $Tenant `
        -Description (Get-ScriptString 'Register.ProfileDescription' $(Get-Date -Format 'yyyy-MM-dd'))

    Write-Host ''
    Write-Host (Get-ScriptString 'Register.ProfileSaved' $ProfileName) -ForegroundColor Green
}
else {
    Write-Host ''
    Write-Host (Get-ScriptString 'Register.SaveAsProfile') -ForegroundColor Cyan
    Write-Host "  Set-O365Profile -Name prod -SiteUrl <your-site> -ClientId $($result.'AzureAppId/ClientId') -Tenant $Tenant" -ForegroundColor White
}
