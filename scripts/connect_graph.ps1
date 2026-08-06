<#
.SYNOPSIS
    Connect to Microsoft Graph API for SharePoint operations.

.DESCRIPTION
    This script establishes a connection to Microsoft Graph API using device code flow or
    client credentials flow. It can be used to access SharePoint sites, lists, and files
    through the Graph API instead of PnP PowerShell.

    The script supports two authentication methods:
    1. Interactive (Device Code Flow) - User signs in via browser
    2. Client Credentials (App-Only) - Uses client secret for automated scenarios

.PARAMETER TenantId
    Azure AD Tenant ID (e.g., "contoso.onmicrosoft.com" or "12345678-1234-1234-1234-123456789abc").

.PARAMETER ClientId
    Azure AD App Registration Client ID.
    If omitted, the script uses the $env:client_id environment variable.

.PARAMETER ClientSecret
    (Optional) Client Secret for app-only authentication, as a SecureString.
    If provided, uses client credentials flow instead of interactive login.

    This is a SecureString rather than a plain string on purpose: a plain
    string parameter ends up in the shell history, in the process command
    line, and in any transcript that happens to be running. Supply it with
    Read-Host -AsSecureString, or from a secret store:

        $secret = Read-Host 'Client secret' -AsSecureString
        ./connect_graph.ps1 -TenantId contoso.onmicrosoft.com -ClientSecret $secret

.PARAMETER Scopes
    (Optional) Array of permission scopes to request.
    Default: Sites.ReadWrite.All, Files.ReadWrite.All
    Common scopes:
    - Sites.Read.All / Sites.ReadWrite.All
    - Files.Read.All / Files.ReadWrite.All
    - User.Read

.EXAMPLE
    .\connect_graph.ps1 -TenantId "contoso.onmicrosoft.com" -ClientId "12345678-1234-1234-1234-123456789abc"

    Connects interactively using device code flow.

.EXAMPLE
    $secret = Read-Host 'Client secret' -AsSecureString
    .\connect_graph.ps1 -TenantId "contoso.onmicrosoft.com" -ClientId "12345678-1234-1234-1234-123456789abc" -ClientSecret $secret

    Connects using app-only authentication with a client secret.

.EXAMPLE
    .\connect_graph.ps1 -TenantId "contoso.onmicrosoft.com" -Scopes "Sites.Read.All","Files.Read.All"

    Connects with read-only permissions using stored ClientId from environment variable.

.OUTPUTS
    Access token and connection details for Microsoft Graph API.

.NOTES
    Requirements:
    - Microsoft.Graph PowerShell SDK (Install-Module Microsoft.Graph)
    - Azure AD App Registration with appropriate permissions
    - For app-only: Client secret configured in Azure AD
    - For interactive: Public client flow enabled in Azure AD

    Permission scopes must be granted admin consent in Azure AD for app-only scenarios.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$ClientId = "",

    [Parameter(Mandatory = $false)]
    [securestring]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [string[]]$Scopes = @("Sites.ReadWrite.All", "Files.ReadWrite.All")
)

# ==================== Initialization ====================

Write-Host "Microsoft Graph API Connection Tool" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Tenant ID: $TenantId" -ForegroundColor Gray

# Use environment variable if ClientId not provided
if ($ClientId -eq "" -and $env:client_id) {
    $ClientId = $env:client_id
    Write-Host "Client ID: $ClientId (from environment)" -ForegroundColor Gray
}
elseif ($ClientId -ne "") {
    Write-Host "Client ID: $ClientId" -ForegroundColor Gray
    # Store in environment variable for future use
    $env:client_id = $ClientId
}
else {
    Write-Host "✗ Error: Client ID is required. Provide -ClientId or set `$env:client_id" -ForegroundColor Red
    exit 1
}

Write-Host "Scopes: $($Scopes -join ', ')" -ForegroundColor Gray
Write-Host ""

# ==================== Check Microsoft.Graph Module ====================

Write-Host "Checking for Microsoft.Graph module..." -ForegroundColor Yellow
$graphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication

if (-not $graphModule) {
    Write-Host "✗ Microsoft.Graph module not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ Microsoft.Graph module found (v$($graphModule[0].Version))" -ForegroundColor Green
Write-Host ""

# ==================== Connect to Graph API ====================

try {
    if ($ClientSecret) {
        # App-only authentication using client credentials
        Write-Host "Connecting with client credentials (app-only)..." -ForegroundColor Yellow

        $credential = New-Object System.Management.Automation.PSCredential($ClientId, $ClientSecret)

        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $credential -NoWelcome

        Write-Host "✓ Connected successfully (app-only)" -ForegroundColor Green
    }
    else {
        # Interactive authentication using device code flow
        Write-Host "Connecting interactively..." -ForegroundColor Yellow
        Write-Host "You will be prompted to sign in via browser." -ForegroundColor Gray
        Write-Host ""

        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Scopes $Scopes -NoWelcome

        Write-Host "✓ Connected successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "- Verify Client ID and Tenant ID are correct" -ForegroundColor Gray
    Write-Host "- Check app permissions in Azure AD" -ForegroundColor Gray
    Write-Host "- For app-only: Ensure client secret is valid" -ForegroundColor Gray
    Write-Host "- For interactive: Enable public client flow in Azure AD" -ForegroundColor Gray
    exit 1
}

# ==================== Display Connection Details ====================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connection Details" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $context = Get-MgContext

    Write-Host "Tenant ID:     $($context.TenantId)" -ForegroundColor Gray
    Write-Host "Client ID:     $($context.ClientId)" -ForegroundColor Gray
    Write-Host "Account:       $($context.Account)" -ForegroundColor Gray
    Write-Host "Auth Type:     $($context.AuthType)" -ForegroundColor Gray
    Write-Host "Scopes:        $($context.Scopes -join ', ')" -ForegroundColor Gray
    Write-Host ""

    Write-Host "✓ You are now connected to Microsoft Graph API" -ForegroundColor Green
    Write-Host ""
    Write-Host "Example commands:" -ForegroundColor Cyan
    Write-Host "  Get-MgSite -Search 'sitename'                    # Find SharePoint sites" -ForegroundColor Gray
    Write-Host "  Get-MgSite -SiteId 'site-id'                     # Get specific site" -ForegroundColor Gray
    Write-Host "  Get-MgSiteList -SiteId 'site-id'                 # List libraries" -ForegroundColor Gray
    Write-Host "  Get-MgSiteDrive -SiteId 'site-id'                # Get document libraries" -ForegroundColor Gray
    Write-Host "  Disconnect-MgGraph                               # Disconnect when done" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "✓ Connected, but unable to retrieve context details" -ForegroundColor Yellow
    Write-Host ""
}

exit 0
