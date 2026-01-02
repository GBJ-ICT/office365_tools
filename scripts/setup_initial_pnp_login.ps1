<#
.SYNOPSIS
    Connects to SharePoint using a Client ID and URL.
.DESCRIPTION
    This script accepts a Client ID and SharePoint URL as mandatory parameters,
    registers the Client ID as an environment variable, and establishes a
    connection to SharePoint using the Login utility function.
.PARAMETER client_id
    The Azure AD Client ID to use for authentication.
.PARAMETER url
    The SharePoint URL to connect to.
.EXAMPLE
    .\login.ps1 -client_id "12345678-1234-1234-1234-123456789abc" -url "https://yourtenant.sharepoint.com"
    Connects to the specified SharePoint site using the provided Client ID.
#>
param(
    [Parameter(Mandatory = $true, HelpMessage = "The Client ID to register as a local environment variable.")]
    [ValidateNotNullOrEmpty()]
    [string]$client_id,
    [Parameter(Mandatory = $true, HelpMessage = "The URL to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$url
)

$parentPath = Split-Path -Path $PSScriptRoot -Parent
Import-Module "$parentPath\util\login.ps1"

$env:client_id = $client_id

Write-Host "Connecting to SharePoint..." -ForegroundColor Yellow
try {
    Login -url $url -client_id $client_id
    Write-Host "✓ Connected successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to connect to SharePoint: $_" -ForegroundColor Red
    exit 1
}
