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
    [switch]$SkipPermissions,

    [Parameter()]
    [ValidateSet('en', 'de', 'auto')]
    [string]$Language
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

# One language for this run: -Language if given, otherwise what the person chose
# or Windows says. Applied to this session only, so the saved choice is left
# alone. The texts of this script live in scripts\Resources, over the module's own.
if ($Language) {
    Set-O365Language -Language $Language -SessionOnly
}

. (Join-Path $PSScriptRoot 'Shared/ScriptLanguage.ps1')

# -- Connect ----------------------------------------------------------------
if ($ProfileName) {
    Connect-O365 -ProfileName $ProfileName
}
else {
    Connect-O365
}

$connection = Get-O365Connection
Write-Host (Get-ScriptString 'LibraryAudit.Connected' $connection.SiteUrl) -ForegroundColor Green

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
    Write-Host (Get-ScriptString 'LibraryAudit.All' $Library.Count) -ForegroundColor Cyan
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
                        Message    = (Get-ScriptString 'LibraryAudit.Finding.Mismatch' $_.Depth)
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
        $summary = if ($bySeverity) { $bySeverity -join ', ' } else { (Get-ScriptString 'LibraryAudit.Clean') }
        Write-Host (Get-ScriptString 'LibraryAudit.Findings' $findings.Count $summary) -ForegroundColor $(if ($findings.Count -eq 0) { 'Green' } else { 'Yellow' })

        if ($findings.Count -gt 0) {
            $safeName = ($name -replace '[^\w\-]', '_')
            $findings | Export-SpoReport -Path (Join-Path $OutputPath "$safeName.html") -Title (Get-ScriptString 'LibraryAudit.ReportTitle' $name)
        }
    }
    catch {
        Write-Warning (Get-ScriptString 'LibraryAudit.Failed' $name $_.Exception.Message)
    }
}

# -- Content types are a site-level concern, checked once --------------------
Write-Host ''
Write-Host (Get-ScriptString 'LibraryAudit.ContentTypeHeading') -ForegroundColor Cyan
try {
    $contentTypeFindings = @(Test-SpoContentTypeLink)
    foreach ($finding in $contentTypeFindings) {
        $allFindings.Add($finding)
    }
    Write-Host (Get-ScriptString 'LibraryAudit.ContentTypeFindings' $contentTypeFindings.Count) -ForegroundColor $(if ($contentTypeFindings.Count -eq 0) { 'Green' } else { 'Yellow' })
}
catch {
    Write-Warning (Get-ScriptString 'LibraryAudit.ContentTypeFailed' $_.Exception.Message)
}

# -- Combined output --------------------------------------------------------
if ($allFindings.Count -gt 0) {
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'all-findings.csv')
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'summary.html') -Title (Get-ScriptString 'LibraryAudit.SummaryTitle')
}

Stop-O365Log | Out-Null

Write-Host ''
Write-Host (Get-ScriptString 'LibraryAudit.SummaryHeading') -ForegroundColor Cyan
$allFindings | Group-Object Severity | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)"
}
Write-Host ''
Write-Host (Get-ScriptString 'LibraryAudit.ReportsWritten' (Resolve-Path $OutputPath).Path) -ForegroundColor Green
Write-Host ''
Write-Host (Get-ScriptString 'LibraryAudit.NothingChanged') -ForegroundColor Gray
