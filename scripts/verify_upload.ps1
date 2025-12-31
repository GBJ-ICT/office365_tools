<#
.SYNOPSIS
    Verify that all files from a local folder are present in a SharePoint folder or document set.

.DESCRIPTION
    This script compares files in a local folder with files in a SharePoint location (folder or document set).
    It recursively scans both locations and reports which files are found or missing.

    The script uses PnP PowerShell to connect to SharePoint and requires an app registration with
    appropriate permissions (Sites.ReadWrite.All or similar).

.PARAMETER SourceFolder
    Local folder path containing the files to verify (e.g., "C:\Documents\MyFolder").
    The script will scan this folder recursively.

.PARAMETER SharePointUrl
    SharePoint site URL where the files should be located.
    Format: https://tenant.sharepoint.com/sites/sitename

.PARAMETER SharePointFolder
    Server-relative path to the SharePoint folder or document set.
    Format: "Shared Documents/FolderName" or "LibraryName/FolderName"
    Do not include the site path (/sites/sitename).

.PARAMETER ClientId
    (Optional) Azure AD App Registration Client ID for authentication.
    If omitted, the script uses the $env:client_id environment variable.

    On first use, you'll be prompted to login interactively via browser.
    The ClientId is stored in the session for subsequent calls.

.EXAMPLE
    .\verify_upload.ps1 -SourceFolder "C:\Documents\MyFolder" `
                        -SharePointUrl "https://contoso.sharepoint.com/sites/projects" `
                        -SharePointFolder "Shared Documents/MyFolder" `
                        -ClientId "12345678-1234-1234-1234-123456789abc"

    Verifies all files from C:\Documents\MyFolder are present in the SharePoint location.

.EXAMPLE
    .\verify_upload.ps1 -SourceFolder "C:\Reports" `
                        -SharePointUrl "https://contoso.sharepoint.com/sites/hr" `
                        -SharePointFolder "Documents/Reports"

    Uses the stored ClientId from environment variable for authentication.

.OUTPUTS
    Exit code 0: All files found in SharePoint
    Exit code 1: Some files missing or error occurred

.NOTES
    Requirements:
    - PnP.PowerShell module must be installed
    - Azure AD App Registration with SharePoint permissions
    - login.ps1 module in the same directory

    The script works with both regular folders and SharePoint document sets.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [string]$SharePointUrl,

    [Parameter(Mandatory = $true)]
    [string]$SharePointFolder,

    [Parameter(Mandatory = $false)]
    [string]$ClientId = ""
)

# ==================== Initialization ====================

# Get the parent directory of the script's folder
$parentPath = Split-Path -Path $PSScriptRoot -Parent
Import-Module "$parentPath\util\login.ps1"

if (-not (Test-Path -Path $SourceFolder)) {
    Write-Host "✗ Error: Source folder not found: $SourceFolder" -ForegroundColor Red
    exit 1
}

Write-Host "Starting verification..." -ForegroundColor Cyan
Write-Host "Source Folder: $SourceFolder" -ForegroundColor Gray
Write-Host "SharePoint URL: $SharePointUrl" -ForegroundColor Gray
Write-Host "SharePoint Folder: $SharePointFolder" -ForegroundColor Gray
Write-Host ""

# ==================== SharePoint Connection ====================

Write-Host "Connecting to SharePoint..." -ForegroundColor Yellow
try {
    Login -url $SharePointUrl -client_id $ClientId
    Write-Host "✓ Connected successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to connect to SharePoint: $_" -ForegroundColor Red
    exit 1
}

# ==================== Scan Local Files ====================

Write-Host "Scanning local folder..." -ForegroundColor Yellow
$localFiles = Get-ChildItem -Path $SourceFolder -File -Recurse
Write-Host "✓ Found $($localFiles.Count) files in local folder" -ForegroundColor Green
Write-Host ""

# ==================== Helper Function ====================

Function Get-AllFilesRecursive {
    param([string]$FolderPath)

    $allFiles = @()
    try {
        $items = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderPath -ErrorAction Stop

        foreach ($item in $items) {
            if ($item.GetType().Name -eq "File") {
                $allFiles += $item
            }
            elseif ($item.GetType().Name -eq "Folder") {
                $subPath = "$FolderPath/$($item.Name)".Replace("//", "/")
                $allFiles += Get-AllFilesRecursive -FolderPath $subPath
            }
        }
    }
    catch {
        Write-Host "  Warning: Could not access $FolderPath - $_" -ForegroundColor Yellow
    }
    return $allFiles
}

# ==================== Scan SharePoint Files ====================

Write-Host "Retrieving files from SharePoint..." -ForegroundColor Yellow
try {
    $normalizedFolder = $SharePointFolder.TrimEnd('/')
    $spFiles = Get-AllFilesRecursive -FolderPath $normalizedFolder
    Write-Host "✓ Found $($spFiles.Count) files in SharePoint folder" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to retrieve files from SharePoint: $_" -ForegroundColor Red
    Write-Host "Make sure the folder path is correct (e.g., 'Shared Documents/FolderName')" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# ==================== Build File Map ====================

$web = Get-PnPWeb
$fullFolderPath = "$($web.ServerRelativeUrl)/$normalizedFolder".Replace("//", "/")

$spFileMap = @{}
foreach ($spFile in $spFiles) {
    $relativePath = $spFile.ServerRelativeUrl -replace [regex]::Escape($fullFolderPath), "" -replace "^/", ""
    $spFileMap[$relativePath] = $spFile
}

# ==================== Compare Files ====================

Write-Host "Verifying files..." -ForegroundColor Yellow
$missingFiles = @()
$foundFiles = 0

foreach ($localFile in $localFiles) {
    $relativePath = $localFile.FullName.Substring($SourceFolder.Length).TrimStart('\').Replace('\', '/')

    if ($spFileMap.ContainsKey($relativePath)) {
        $foundFiles++
        Write-Host "  ✓ $relativePath" -ForegroundColor Green
    }
    else {
        $missingFiles += $relativePath
        Write-Host "  ✗ $relativePath" -ForegroundColor Red
    }
}


# ==================== Summary ====================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total files in source:     $($localFiles.Count)" -ForegroundColor Gray
Write-Host "Files found in SharePoint: $foundFiles" -ForegroundColor Green
Write-Host "Missing files:             $($missingFiles.Count)" -ForegroundColor $(if ($missingFiles.Count -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($missingFiles.Count -eq 0) {
    Write-Host "✓ SUCCESS: All files are present in SharePoint!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ WARNING: Some files are missing from SharePoint" -ForegroundColor Red
    Write-Host ""
    Write-Host "Missing files:" -ForegroundColor Yellow
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    exit 1
}
