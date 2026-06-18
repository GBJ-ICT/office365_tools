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
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,
    [Parameter(Mandatory = $true)]
    [string]$SharePointUrl,
    [Parameter(Mandatory = $true)]
    [string]$SharePointFolder
)
if (-not $env:gbj_client_id) {
    Write-Host "uninitialized: run ./init.ps1" -ForegroundColor Red
    exit 1
}

# Connect to SharePoint
try {
    LogInfo "ClientID: '$env:gbj_client_id'"
    Connect-PnPOnline -Url $SharePointUrl -ClientId $env:gbj_client_id
    LogSuccess "✓ Connected successfully"
    LogEmptyLine
}
catch {
    LogError "✗ Failed to connect to SharePoint: $_"
    exit 1
}
if (-not (Test-Path -Path $SourceFolder)) {
    LogError "✗ Error: Source folder not found: $SourceFolder"
    exit 1
}

# Log start
LogInfo "Starting verification..."
LogInfo "Source Folder: $SourceFolder"
LogInfo "SharePoint URL: $SharePointUrl"
LogInfo "SharePoint Folder: $SharePointFolder"
LogEmptyLine

# Scan Local Files
LogInfo "Scanning local folder..."
$localFiles = Get-ChildItem -Path $SourceFolder -File -Recurse
LogSuccess "✓ Found $($localFiles.Count) files in local folder"
LogEmptyLine


# Scan SharePoint Files
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
        LogWarning "Could not access $FolderPath - $_"
    }
    return $allFiles
}

LogInfo "Retrieving files from SharePoint..."
try {
    $normalizedFolder = $SharePointFolder.TrimEnd('/')
    $spFiles = Get-AllFilesRecursive -FolderPath $normalizedFolder
}
catch {
    LogError "✗ Failed to retrieve files from SharePoint: $_"
    LogWarning "Make sure the folder path is correct (e.g., 'Shared Documents/FolderName')"
    exit 1
}
LogEmptyLine

# Build File Map
$web = Get-PnPWeb
$fullFolderPath = "$($web.ServerRelativeUrl)/$normalizedFolder".Replace("//", "/")

$spFileMap = @{}
foreach ($spFile in $spFiles) {
    $relativePath = $spFile.ServerRelativeUrl -replace [regex]::Escape($fullFolderPath), "" -replace "^/", ""
    $spFileMap[$relativePath] = $spFile
}

# Compare Files
LogInfo "Verifying files..."
$missingFiles = @()
$foundFiles = 0

foreach ($localFile in $localFiles) {
    $relativePath = $localFile.FullName.Substring($SourceFolder.Length).TrimStart('\').Replace('\', '/')
    if ($spFileMap.ContainsKey($relativePath)) {
        $foundFiles++
        LogSuccess "  ✓ $relativePath"
    }
    else {
        $missingFiles += $relativePath
        LogError "  ✗ $relativePath"
    }
}

# Log Summary
LogEmptyLine
LogInfo "========================================"
LogInfo "Verification Summary"
LogInfo "========================================"
LogInfo "Total files in source:     $($localFiles.Count)"
LogInfo "Files found in SharePoint: $foundFiles"
LogInfo "Missing files:             $($missingFiles.Count)"
LogEmptyLine

if ($missingFiles.Count -eq 0) {
    LogSuccess "✓ SUCCESS: All files are present in SharePoint!"
    exit 0
}
else {
    LogError "✗ WARNING: Some files are missing from SharePoint"
    LogEmptyLine
    LogWarning "Missing files:"
    foreach ($file in $missingFiles) {
        LogError "  - $file"
    }
    exit 1
}
