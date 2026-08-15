<#
.SYNOPSIS
    Recreates one list's columns on another, as columns local to that list.
.DESCRIPTION
    Makes a test list look like the list it is standing in for: same internal
    names, same types, same choices, same column formatting. The point of the
    internal names matching is that anything written against the original --
    a view, a Power Automate flow, a script that sets Status -- addresses the
    copy by the same names, so testing against it means something.

    Columns are created *local* to the target list rather than as site columns.
    A site column is permanent and visible to every list on the site; a local
    one exists only on the list named and goes away when the list does. For a
    scratch copy of a production list, that difference is the whole point.

    The source is read first and completely, then the connection is switched
    and the target written -- PnP holds one connection at a time, so this runs
    as two phases with the schema kept in memory between them. Passing no
    -Apply stops after the first phase and writes what it *would* create to
    out/, which is the dry run:

        ./scripts/Copy-ListSchema.ps1                        # read and report
        ./scripts/Copy-ListSchema.ps1 -Apply -WhatIf         # preview the writes
        ./scripts/Copy-ListSchema.ps1 -Apply                 # write

    Columns the target already has, by internal name, are left exactly as they
    are: not updated, not duplicated. So the script is re-runnable, and adding
    one column to the source and running it again copies that one column.

    Lookup, managed metadata and calculated columns are reported and skipped.
    Each of them carries a reference that does not survive the move -- a list
    GUID, a term set binding, a formula naming columns that may not be there --
    and SharePoint accepts all three without complaint, leaving a column that
    looks right and never works. -IncludeUnportable overrides that if you know
    what you are getting.
.PARAMETER SourceProfile
    Connection profile naming the site the columns are read from.
.PARAMETER SourceList
    Title or URL name of the list to read.
.PARAMETER TargetProfile
    Connection profile naming the site the columns are created on.
.PARAMETER TargetList
    Title or URL name of the list to write.
.PARAMETER ClientId
    Entra application ID, when connecting by URL instead of by profile.
.PARAMETER SourceSiteUrl
    Source site URL, instead of -SourceProfile.
.PARAMETER TargetSiteUrl
    Target site URL, instead of -TargetProfile.
.PARAMETER ExcludeField
    Internal names to leave out of the copy.
.PARAMETER DropCustomFormatter
    Copy the columns without their JSON formatting, leaving SharePoint's
    default rendering.
.PARAMETER CopyDefaultView
    Also set the target's default view to show the same columns, in the same
    order, as the source's. Without this the copied columns exist but the view
    still shows only Title, which reads as though nothing happened.
.PARAMETER IncludeUnportable
    Attempt lookup, taxonomy and calculated columns too.
.PARAMETER Apply
    Write. Omitted, the script reads the source and reports, changing nothing.
.PARAMETER Interactive
    Force a browser sign-in rather than relying on a cached token. Worth
    reaching for first when a connection hangs instead of failing.
.PARAMETER OutputPath
    Directory for the schema report and log. Defaults to
    out/list-schema-<timestamp>.
.EXAMPLE
    ./scripts/Copy-ListSchema.ps1 -SourceProfile HGTitterten -SourceList 'Aufgaben und Dienste' `
        -TargetProfile TestCDS -TargetList 'Test Aufgaben und Dienste'
    Reads the source and reports what the copy would create. Writes nothing.

.EXAMPLE
    ./scripts/Copy-ListSchema.ps1 -SourceProfile HGTitterten -SourceList 'Aufgaben und Dienste' `
        -TargetProfile TestCDS -TargetList 'Test Aufgaben und Dienste' -Apply -CopyDefaultView
    Creates the columns and makes the default view show them.
.LINK
    Get-SpoListFieldSchema
.LINK
    Add-SpoListField
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Profile')]
param(
    [Parameter(ParameterSetName = 'Profile')]
    [string]$SourceProfile,

    [Parameter(ParameterSetName = 'Profile')]
    [string]$TargetProfile,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$SourceSiteUrl,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$TargetSiteUrl,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$SourceList,

    [Parameter(Mandatory)]
    [string]$TargetList,

    [Parameter()]
    [string[]]$ExcludeField = @(),

    [Parameter()]
    [switch]$DropCustomFormatter,

    [Parameter()]
    [switch]$CopyDefaultView,

    [Parameter()]
    [switch]$IncludeUnportable,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'Office365Tools') -Force

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot '..' 'out' "list-schema-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
# -WhatIf:$false, because this directory holds the plan and the log rather than
# anything on the tenant. Left to inherit, -WhatIf would decline to create it
# and the Resolve-Path below would fail before the preview ever ran.
$null = New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false
$OutputPath = (Resolve-Path $OutputPath).Path

Start-O365Log -Path (Join-Path $OutputPath 'copy-schema.log') | Out-Null

try {
    # ---------------------------------------------------------------------
    # Phase one: read the source.
    # ---------------------------------------------------------------------
    if ($PSCmdlet.ParameterSetName -eq 'Url') {
        Connect-O365 -SiteUrl $SourceSiteUrl -ClientId $ClientId -Interactive:$Interactive
    }
    elseif ($SourceProfile) {
        Connect-O365 -ProfileName $SourceProfile -Interactive:$Interactive
    }
    else {
        Connect-O365 -Interactive:$Interactive
    }

    Write-Host "Reading '$SourceList' ..." -ForegroundColor Cyan

    $schema = @(Get-SpoListFieldSchema -Library $SourceList -DropCustomFormatter:$DropCustomFormatter |
            Where-Object { $_.InternalName -notin $ExcludeField })

    $sourceViewFields = @()
    if ($CopyDefaultView) {
        $sourceView = Get-PnPView -List $SourceList | Where-Object { $_.DefaultView } | Select-Object -First 1
        if ($sourceView) {
            $sourceViewFields = @($sourceView.ViewFields)
        }
        else {
            Write-Warning "Source list '$SourceList' has no default view; -CopyDefaultView will be skipped."
        }
    }

    $choiceColumn = @{ Name = 'Choice'; Expression = { $_.Choice -join ' | ' } }

    $schema |
        Select-Object InternalName, DisplayName, Type, Required, Portable, $choiceColumn, DefaultValue, PortabilityNote |
        Export-Csv -Path (Join-Path $OutputPath 'schema.csv') -NoTypeInformation -Encoding UTF8

    $schema | Export-Clixml -Path (Join-Path $OutputPath 'schema.xml')

    Write-Host ''
    $schema | Format-Table -AutoSize InternalName, DisplayName, Type, Required, Portable |
        Out-String -Width 200 | Write-Host

    $blocked = @($schema | Where-Object { -not $_.Portable })
    foreach ($field in $blocked) {
        Write-Warning "$($field.InternalName) ($($field.Type)): $($field.PortabilityNote)"
    }

    if (-not $Apply) {
        Write-Host "Read $($schema.Count) column(s) from '$SourceList'. Nothing written." -ForegroundColor Yellow
        Write-Host "Schema written to $OutputPath"
        Write-Host 'Re-run with -Apply to create these columns on the target.' -ForegroundColor Yellow
        return
    }

    # ---------------------------------------------------------------------
    # Phase two: write the target. The source connection is gone from here.
    # ---------------------------------------------------------------------
    if ($PSCmdlet.ParameterSetName -eq 'Url') {
        Connect-O365 -SiteUrl $TargetSiteUrl -ClientId $ClientId -Interactive:$Interactive
    }
    elseif ($TargetProfile) {
        Connect-O365 -ProfileName $TargetProfile -Interactive:$Interactive
    }
    else {
        Connect-O365 -Interactive:$Interactive
    }

    Write-Host "Writing to '$TargetList' ..." -ForegroundColor Cyan

    # -WhatIf on this script does not reach into the module by itself: a
    # function defined in a module reads $WhatIfPreference in the module's
    # scope, where the script's switch never set it. Forwarding it explicitly
    # is what makes the preview a preview.
    $schema | Add-SpoListField -Library $TargetList `
        -AllowUnportableType:$IncludeUnportable `
        -WhatIf:$WhatIfPreference

    if ($CopyDefaultView -and $sourceViewFields.Count -gt 0) {
        $targetView = Get-PnPView -List $TargetList | Where-Object { $_.DefaultView } | Select-Object -First 1

        if (-not $targetView) {
            Write-Warning "Target list '$TargetList' has no default view."
        }
        else {
            # Only the columns that actually exist on the target: the source
            # view may list one that was skipped as unportable, and a view
            # naming a column the list does not have fails as a whole.
            $present = @(Get-PnPField -List $TargetList | ForEach-Object { $_.InternalName })
            $wanted  = @($sourceViewFields | Where-Object { $_ -in $present })

            if ($PSCmdlet.ShouldProcess("$TargetList / $($targetView.Title)", "Set view columns to $($wanted -join ', ')")) {
                Set-PnPView -List $TargetList -Identity $targetView.Id -Fields $wanted | Out-Null
                Write-Host "Default view now shows: $($wanted -join ', ')" -ForegroundColor Green
            }
        }
    }

    Write-Host ''
    Write-Host "Done. Log and schema in $OutputPath" -ForegroundColor Green
}
finally {
    Stop-O365Log | Out-Null
}
