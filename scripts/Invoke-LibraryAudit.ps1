<#
.SYNOPSIS
    Runs a full read-only audit of one or more libraries and writes reports.
.DESCRIPTION
    A task runner for people who do not want to learn the module: connect, run
    every diagnostic, write an HTML report per library plus a combined CSV.

    Nothing here changes the tenant. Every command it calls is a Get/Test/Find.
    Read the reports, decide what to fix, then use the Repair/Remove/Sync
    commands deliberately.

    This is also the worked example of composing the module: each step is one
    command, and the whole thing is about thirty lines of actual logic.
.PARAMETER Library
    Libraries to audit. Omit to audit every visible library on the site.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile.
.PARAMETER OutputPath
    Directory for the reports. Defaults to out/audit-<timestamp>.
.PARAMETER MinimumSeverity
    Suppress findings below this severity.
.PARAMETER SkipPermissions
    Skip the permission checks, which are the slowest part on a large library
    because each item costs a request.
.EXAMPLE
    ./scripts/Invoke-LibraryAudit.ps1 -Library Documents

.EXAMPLE
    ./scripts/Invoke-LibraryAudit.ps1 -ProfileName prod -MinimumSeverity Warning

    Audits every library on the prod site, ignoring informational findings.
.EXAMPLE
    ./scripts/Invoke-LibraryAudit.ps1 -Library Documents, Contracts -SkipPermissions
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Library,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('Info', 'Warning', 'Error')]
    [string]$MinimumSeverity = 'Info',

    [Parameter()]
    [switch]$SkipPermissions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

# -- Connect ----------------------------------------------------------------
if ($ProfileName) {
    Connect-O365 -ProfileName $ProfileName
}
else {
    Connect-O365
}

$connection = Get-O365Connection
Write-Host "Connected to $($connection.SiteUrl)" -ForegroundColor Green

# -- Prepare output ---------------------------------------------------------
if (-not $OutputPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = Join-Path $PSScriptRoot "../out/audit-$timestamp"
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Start-O365Log -Path (Join-Path $OutputPath 'audit.log') | Out-Null

# -- Decide what to audit ---------------------------------------------------
if (-not $Library) {
    $Library = @(Get-PnPList | Where-Object { -not $_.Hidden } | ForEach-Object { $_.Title })
    Write-Host "Auditing all $($Library.Count) visible libraries." -ForegroundColor Cyan
}

$rules = if ($SkipPermissions) {
    @('Naming', 'PathLength', 'CheckedOut', 'EmptyFolder', 'Duplicate', 'LargeFile', 'VersionBloat', 'RequiredField', 'ContentType')
}
else {
    @('Naming', 'PathLength', 'CheckedOut', 'EmptyFolder', 'Duplicate', 'LargeFile', 'VersionBloat', 'RequiredField', 'ContentType', 'Permission')
}

# -- Audit ------------------------------------------------------------------
$allFindings = [System.Collections.Generic.List[object]]::new()

foreach ($name in $Library) {
    Write-Host ''
    Write-Host "=== $name ===" -ForegroundColor Cyan

    try {
        $findings = @(Test-SpoLibraryHealth -Library $name -Rule $rules -MinimumSeverity $MinimumSeverity)

        if (-not $SkipPermissions) {
            $findings += @(Get-SpoPermissionMismatch -Library $name -MinimumDepth 2 | ForEach-Object {
                    [pscustomobject]@{
                        PSTypeName = 'Office365Tools.Finding'
                        RuleId     = 'Permission.MismatchWithParent'
                        Severity   = 'Warning'
                        Scope      = $_.Kind
                        List       = $_.List
                        Target     = $_.ServerRelativeUrl
                        Message    = "Unique permissions at depth $($_.Depth) differ from the parent folder."
                        Detail     = [pscustomobject]@{ Depth = $_.Depth; ItemSignature = $_.ItemSignature; ParentSignature = $_.ParentSignature }
                        SiteUrl    = $_.SiteUrl
                        DetectedAt = Get-Date
                    }
                })
        }

        foreach ($finding in $findings) {
            $allFindings.Add($finding)
        }

        $bySeverity = $findings | Group-Object Severity | ForEach-Object { "$($_.Name): $($_.Count)" }
        $summary = if ($bySeverity) { $bySeverity -join ', ' } else { 'clean' }
        Write-Host "  $($findings.Count) finding(s) -- $summary" -ForegroundColor $(if ($findings.Count -eq 0) { 'Green' } else { 'Yellow' })

        if ($findings.Count -gt 0) {
            $safeName = ($name -replace '[^\w\-]', '_')
            $findings | Export-SpoReport -Path (Join-Path $OutputPath "$safeName.html") -Title "$name -- health report"
        }
    }
    catch {
        Write-Warning "Audit of '$name' failed: $($_.Exception.Message)"
    }
}

# -- Content types are a site-level concern, checked once --------------------
Write-Host ''
Write-Host '=== Content type links (site-wide) ===' -ForegroundColor Cyan
try {
    $contentTypeFindings = @(Test-SpoContentTypeLink)
    foreach ($finding in $contentTypeFindings) {
        $allFindings.Add($finding)
    }
    Write-Host "  $($contentTypeFindings.Count) finding(s)" -ForegroundColor $(if ($contentTypeFindings.Count -eq 0) { 'Green' } else { 'Yellow' })
}
catch {
    Write-Warning "Content type check failed: $($_.Exception.Message)"
}

# -- Combined output --------------------------------------------------------
if ($allFindings.Count -gt 0) {
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'all-findings.csv')
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'summary.html') -Title 'Site audit summary'
}

Stop-O365Log | Out-Null

Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan
$allFindings | Group-Object Severity | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)"
}
Write-Host ''
Write-Host "Reports written to: $((Resolve-Path $OutputPath).Path)" -ForegroundColor Green
Write-Host ''
Write-Host 'Nothing was changed. To act on these findings, see docs/getting-started.md.' -ForegroundColor Gray
