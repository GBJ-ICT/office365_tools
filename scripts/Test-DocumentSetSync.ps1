<#
.SYNOPSIS
    Reports Document Sets whose contents no longer carry their metadata, and
    the configuration that let it happen.
.DESCRIPTION
    A read-only task runner for the question "are the Document Sets still in
    sync?". For every library it checks two different things, because they have
    two different fixes:

      Configuration -- are the columns actually registered as shared columns,
                       so SharePoint pushes them down at all? A column that is
                       not shared has never synced and never will, however many
                       times you repair the data.

      Data          -- do the documents and folders inside each Document Set
                       currently carry the Document Set's values?

    Nothing is changed. Read the reports, then use Repair-DocumentSetSync.ps1
    for the data and Set-PnPDocumentSetField for the configuration.

    With no -Library, every visible document library on the site is examined
    and the ones without Document Sets are skipped, so the CDS libraries do not
    have to be named here and stay correct when a new one is added.
.PARAMETER Library
    Libraries to check. Omit to check every visible document library.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile.
.PARAMETER OutputPath
    Directory for the reports. Defaults to out/documentset-sync-<timestamp>.
.PARAMETER IncludeUnsharedColumn
    Also compare columns that are on the Document Set content type but are not
    registered as shared. Shows the drift that the configuration problem has
    already caused.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling.
.EXAMPLE
    ./scripts/Test-DocumentSetSync.ps1

.EXAMPLE
    ./scripts/Test-DocumentSetSync.ps1 -Library Projekte, Management, Produkte

.EXAMPLE
    ./scripts/Test-DocumentSetSync.ps1 -IncludeUnsharedColumn -ProfileName CDS

    Includes columns that were never wired up to sync, which is usually where
    the surprises are.
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
    [switch]$IncludeUnsharedColumn,

    [Parameter()]
    [ValidateRange(1, 5000)]
    [int]$PageSize = 500
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
    $OutputPath = Join-Path $PSScriptRoot "../out/documentset-sync-$timestamp"
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Start-O365Log -Path (Join-Path $OutputPath 'check.log') | Out-Null

# -- Decide what to check ---------------------------------------------------
if (-not $Library) {
    $Library = @(Get-PnPList | Where-Object { -not $_.Hidden -and $_.BaseTemplate -eq 101 } | ForEach-Object { $_.Title })
    Write-Host "Examining all $($Library.Count) visible document libraries." -ForegroundColor Cyan
}

$allFindings = [System.Collections.Generic.List[object]]::new()
$allDrift    = [System.Collections.Generic.List[object]]::new()
$rows        = [System.Collections.Generic.List[object]]::new()

foreach ($name in $Library) {
    Write-Host ''
    Write-Host "=== $name ===" -ForegroundColor Cyan

    try {
        $documentSets = @(Get-SpoDocumentSet -Library $name -PageSize $PageSize)

        if ($documentSets.Count -eq 0) {
            Write-Host '  no Document Sets -- skipped' -ForegroundColor Gray
            continue
        }

        $contained = ($documentSets | Measure-Object -Property ItemCount -Sum).Sum
        Write-Host "  $($documentSets.Count) Document Set(s), $contained contained item(s)" -ForegroundColor Gray

        $unshared = @($documentSets | Where-Object { $_.SharedColumnCount -eq 0 })
        if ($unshared.Count -gt 0) {
            Write-Host "  $($unshared.Count) of them share no columns at all" -ForegroundColor Yellow
        }

        # -- Configuration --------------------------------------------------
        $findings = @(Test-SpoDocumentSetSharedColumn -Library $name -PageSize $PageSize)
        foreach ($finding in $findings) {
            $allFindings.Add($finding)
        }

        $notShared = @($findings | Where-Object { $_.RuleId -eq 'DocumentSet.ColumnNotShared' })
        Write-Host "  configuration: $($findings.Count) finding(s), $($notShared.Count) column(s) not registered as shared" `
            -ForegroundColor $(if ($findings.Count -eq 0) { 'Green' } else { 'Yellow' })

        # -- Data -------------------------------------------------------------
        $parameters = @{ Library = $name; PageSize = $PageSize }
        if ($IncludeUnsharedColumn) {
            $parameters['IncludeUnsharedColumn'] = $true
        }

        $drift = @(Get-SpoDocumentSetMismatch @parameters)

        foreach ($mismatch in $drift) {
            $allDrift.Add($mismatch)

            foreach ($difference in $mismatch.Difference) {
                $rows.Add([pscustomobject]@{
                        List              = $mismatch.List
                        DocumentSet       = $mismatch.DocumentSet
                        Kind              = $mismatch.Kind
                        Item              = $mismatch.RelativePath
                        Column            = $difference.Field
                        DisplayName       = $difference.DisplayName
                        Reason            = $difference.Reason
                        IsShared          = $difference.IsShared
                        DocumentSetValue  = $difference.DocumentSetValue
                        ItemValue         = $difference.ItemValue
                        ServerRelativeUrl = $mismatch.ServerRelativeUrl
                        ItemId            = $mismatch.ItemId
                    })
            }
        }

        $percentage = if ($contained -gt 0) { [math]::Round(($drift.Count / $contained) * 100, 1) } else { 0 }
        Write-Host "  data: $($drift.Count) of $contained item(s) out of sync ($percentage%)" `
            -ForegroundColor $(if ($drift.Count -eq 0) { 'Green' } else { 'Yellow' })

        if ($findings.Count -gt 0) {
            $safeName = ($name -replace '[^\w\-]', '_')
            $findings | Export-SpoReport -Path (Join-Path $OutputPath "$safeName-configuration.html") `
                -Title "$name -- Document Set configuration"
        }
    }
    catch {
        Write-Warning "Check of '$name' failed: $($_.Exception.Message)"
    }
}

# -- Combined output --------------------------------------------------------
if ($rows.Count -gt 0) {
    # One row per column difference: the shape you want in a spreadsheet when
    # deciding what to repair.
    $rows | Export-Csv -Path (Join-Path $OutputPath 'metadata-drift.csv') -NoTypeInformation -Encoding utf8
    $rows | Export-SpoReport -Path (Join-Path $OutputPath 'metadata-drift.html') -Title 'Document Set metadata drift'
}

if ($allFindings.Count -gt 0) {
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'configuration.html') -Title 'Document Set configuration'
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'configuration.csv')
}

Stop-O365Log | Out-Null

# -- Summary ----------------------------------------------------------------
Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan
Write-Host "  items out of sync : $($allDrift.Count)"
Write-Host "  column differences: $($rows.Count)"

if ($rows.Count -gt 0) {
    Write-Host ''
    Write-Host '  Worst columns:' -ForegroundColor Gray
    $rows | Group-Object Column | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "    $($_.Name): $($_.Count) item(s)"
    }

    Write-Host ''
    Write-Host '  Reasons:' -ForegroundColor Gray
    $rows | Group-Object Reason | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "    $($_.Name): $($_.Count)"
    }
}

if ($allFindings.Count -gt 0) {
    Write-Host ''
    Write-Host '  Configuration findings:' -ForegroundColor Gray
    $allFindings | Group-Object RuleId | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "    $($_.Name): $($_.Count)"
    }
}

Write-Host ''
Write-Host "Reports written to: $((Resolve-Path $OutputPath).Path)" -ForegroundColor Green
Write-Host ''
Write-Host 'Nothing was changed.' -ForegroundColor Gray

if ($allDrift.Count -gt 0) {
    Write-Host 'To push the Document Set values down:' -ForegroundColor Gray
    Write-Host '    ./scripts/Repair-DocumentSetSync.ps1 -WhatIf' -ForegroundColor Gray
}

if ($allFindings.Count -gt 0) {
    Write-Host 'Fix the configuration too, or the drift comes back. See docs/document-sets.md.' -ForegroundColor Gray
}
