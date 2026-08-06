<#
.SYNOPSIS
    Pushes each Document Set's metadata down onto the documents and folders it
    contains.
.DESCRIPTION
    The write half of Test-DocumentSetSync.ps1: it finds the drift again, keeps
    a record of the current state, and then writes the Document Set's values
    onto the items that have drifted -- including folders, which SharePoint's
    own push-down does not touch.

    Run it with -WhatIf first. That prints every item and every column that
    would be written, and changes nothing:

        ./scripts/Repair-DocumentSetSync.ps1 -WhatIf
        ./scripts/Repair-DocumentSetSync.ps1

    A CSV of the state *before* the repair is written either way, including
    under -WhatIf, so there is always a record to compare against or to restore
    from by hand.

    The Document Set wins every difference. Where the Document Set's own column
    is empty, the item keeps its value -- pushing an empty value would delete
    the only copy of it. Pass -ClearEmpty when the Document Set really is the
    authority and those item values are wrong.

    This repairs the data. It does not repair the configuration that let the
    data drift: if Test-DocumentSetSync.ps1 reported columns that are not
    registered as shared columns, register them, or you will be running this
    again next month.
.PARAMETER Library
    Libraries to repair. Omit to repair every visible document library.
.PARAMETER DocumentSet
    Wildcard pattern restricting which Document Sets are repaired.
.PARAMETER Column
    Repair only these columns (internal names).
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile.
.PARAMETER OutputPath
    Directory for the before/after records. Defaults to
    out/documentset-repair-<timestamp>.
.PARAMETER IncludeUnsharedColumn
    Also push columns that are on the Document Set content type but are not
    registered as shared. Off by default: SharePoint has never synced those, so
    a difference there may well be deliberate.
.PARAMETER ClearEmpty
    Also push empty values, clearing item columns the Document Set leaves
    blank. Destroys data that exists nowhere else -- read the before CSV first.
.PARAMETER SystemUpdate
    Write without creating a version or changing Modified/Editor. Leaves the
    audit trail alone, and removes version history as a way back.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling.
.EXAMPLE
    ./scripts/Repair-DocumentSetSync.ps1 -WhatIf

.EXAMPLE
    ./scripts/Repair-DocumentSetSync.ps1 -Library Projekte

.EXAMPLE
    ./scripts/Repair-DocumentSetSync.ps1 -Library Projekte -DocumentSet 'P-2026-*' -SystemUpdate

    Repairs one year's Document Sets without touching Modified or creating
    versions.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)]
    [string[]]$Library,

    [Parameter()]
    [string]$DocumentSet,

    [Parameter()]
    [string[]]$Column,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$IncludeUnsharedColumn,

    [Parameter()]
    [switch]$ClearEmpty,

    [Parameter()]
    [switch]$SystemUpdate,

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
    $OutputPath = Join-Path $PSScriptRoot "../out/documentset-repair-$timestamp"
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Start-O365Log -Path (Join-Path $OutputPath 'repair.log') | Out-Null

if (-not $Library) {
    $Library = @(Get-PnPList | Where-Object { -not $_.Hidden -and $_.BaseTemplate -eq 101 } | ForEach-Object { $_.Title })
    Write-Host "Examining all $($Library.Count) visible document libraries." -ForegroundColor Cyan
}

$before  = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()

foreach ($name in $Library) {
    Write-Host ''
    Write-Host "=== $name ===" -ForegroundColor Cyan

    try {
        $findParameters = @{ Library = $name; PageSize = $PageSize }
        if ($DocumentSet) {
            $findParameters['DocumentSet'] = $DocumentSet
        }
        if ($Column) {
            $findParameters['Column'] = $Column
        }
        if ($IncludeUnsharedColumn) {
            $findParameters['IncludeUnsharedColumn'] = $true
        }

        $drift = @(Get-SpoDocumentSetMismatch @findParameters)

        if ($drift.Count -eq 0) {
            Write-Host '  in sync -- nothing to do' -ForegroundColor Green
            continue
        }

        Write-Host "  $($drift.Count) item(s) out of sync" -ForegroundColor Yellow

        # The record of what it was. Written before anything is touched, and
        # written under -WhatIf too: the point is to have it, not to have run.
        foreach ($mismatch in $drift) {
            foreach ($difference in $mismatch.Difference) {
                $before.Add([pscustomobject]@{
                        List              = $mismatch.List
                        DocumentSet       = $mismatch.DocumentSet
                        Kind              = $mismatch.Kind
                        Item              = $mismatch.RelativePath
                        Column            = $difference.Field
                        Reason            = $difference.Reason
                        DocumentSetValue  = $difference.DocumentSetValue
                        ItemValue         = $difference.ItemValue
                        ServerRelativeUrl = $mismatch.ServerRelativeUrl
                        ItemId            = $mismatch.ItemId
                    })
            }
        }

        $repairParameters = @{ Confirm = $false; PassThru = $true }
        if ($Column) {
            $repairParameters['Column'] = $Column
        }
        if ($ClearEmpty) {
            $repairParameters['ClearEmpty'] = $true
        }
        if ($SystemUpdate) {
            $repairParameters['SystemUpdate'] = $true
        }

        $target = "$($drift.Count) item(s) in '$name'"
        $action = "Push Document Set metadata down$(if ($SystemUpdate) { ' (SystemUpdate: no version created)' })"

        if ($PSCmdlet.ShouldProcess($target, $action)) {
            $outcome = @($drift | Repair-SpoDocumentSetMetadata @repairParameters)

            foreach ($item in $outcome) {
                $results.Add($item)
            }

            $repaired = @($outcome | Where-Object { $_.Status -eq 'Repaired' }).Count
            $skipped  = @($outcome | Where-Object { $_.Status -eq 'SkippedEmptySource' }).Count
            $failed   = @($outcome | Where-Object { $_.Status -eq 'Failed' }).Count

            Write-Host "  repaired $repaired, skipped $skipped, failed $failed" `
                -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
        }
        elseif ($WhatIfPreference) {
            # ShouldProcess above announced the batch; this prints the columns
            # and values of every individual write it stands for.
            $drift | Repair-SpoDocumentSetMetadata @repairParameters -WhatIf | Out-Null
        }
    }
    catch {
        Write-Warning "Repair of '$name' failed: $($_.Exception.Message)"
    }
}

# -- Records ----------------------------------------------------------------
if ($before.Count -gt 0) {
    $beforePath = Join-Path $OutputPath 'before.csv'
    $before | Export-Csv -Path $beforePath -NoTypeInformation -Encoding utf8
    Write-Host ''
    Write-Host "State before the repair: $beforePath" -ForegroundColor Gray
}

if ($results.Count -gt 0) {
    $results | Export-Csv -Path (Join-Path $OutputPath 'results.csv') -NoTypeInformation -Encoding utf8
}

Stop-O365Log | Out-Null

# -- Summary ----------------------------------------------------------------
Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan

if ($results.Count -eq 0) {
    if ($WhatIfPreference) {
        Write-Host '  -WhatIf: nothing was changed.' -ForegroundColor Gray
        Write-Host "  $($before.Count) column value(s) on $(@($before | Group-Object ServerRelativeUrl).Count) item(s) would be written." -ForegroundColor Gray
    }
    else {
        Write-Host '  nothing was changed.' -ForegroundColor Gray
    }
}
else {
    $results | Group-Object Status | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)"
    }

    $failures = @($results | Where-Object { $_.Status -eq 'Failed' })
    if ($failures.Count -gt 0) {
        Write-Host ''
        Write-Host '  Failures:' -ForegroundColor Red
        $failures | Select-Object -First 10 | ForEach-Object {
            Write-Host "    $($_.ServerRelativeUrl): $($_.Error)"
        }
    }
}

Write-Host ''
Write-Host 'Re-run ./scripts/Test-DocumentSetSync.ps1 to confirm, and check the' -ForegroundColor Gray
Write-Host 'configuration findings there so the drift does not simply return.' -ForegroundColor Gray
