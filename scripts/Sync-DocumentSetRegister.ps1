<#
.SYNOPSIS
    Adds a list entry for every Document Set in the given libraries that the
    list does not already have.
.DESCRIPTION
    Keeps a flat list -- a register -- in step with the Document Sets spread
    across several libraries. One row per Document Set, carrying its metadata
    and a hyperlink back to the folder.

    It runs in two passes, and the split is not optional. The register's link
    text comes from a *calculated* column, and a calculated column has no value
    until the item exists, so it cannot be part of the write that creates it:

      1. Create  the rows, each with its Document ID link.
      2. Label   those links, reading back the calculated column SharePoint has
                 by then computed. The link keeps its URL and gets the
                 calculated column's text -- 'HG4425-AEB' rather than
                 'GBJCDS-204499463-31'.

    Pass two can be run on its own with -RelabelExisting and no -Plan, which is
    what to do after editing Titles by hand: the calculated column follows the
    Title, and the link text does not follow it until this is re-run.

    Nothing is written without a plan first. Run with no -Plan to get a CSV of
    every proposed row; read it, edit it, then feed it back with -Plan. Editing
    the CSV is the intended workflow rather than an escape hatch -- Title is
    copied verbatim from the Document Set, and verbatim is rarely what you want
    for every one of them.

        ./scripts/Sync-DocumentSetRegister.ps1                      # plan
        ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path> -WhatIf # preview
        ./scripts/Sync-DocumentSetRegister.ps1 -Plan <path>         # write
        ./scripts/Sync-DocumentSetRegister.ps1 -RelabelExisting     # pass two only

    Rows are matched on the Document ID, not on the name and not on the link
    text. A Document ID is assigned once and survives a rename or a move to
    another library, so renaming a Document Set updates nothing and creates no
    duplicate -- and relabelling the link changes only what is displayed, since
    the ID is read from the URL underneath it.

    Each library's Document Sets are registered as their own content type, per
    -ContentTypeMap. That mapping is also what makes a *move* between libraries
    visible: because the Document ID matched, the row is found; because the
    library changed, its content type is now wrong. The plan calls that row an
    Update and the write pass repairs it.

    An Update is deliberately narrow -- the content type, and the reference link
    if the register has one. The metadata columns are left alone, because a
    register gets edited by hand -- Titles shortened, entries annotated -- and
    re-copying every column from the source each run would quietly undo that.
    Nothing is ever deleted here.
.PARAMETER Plan
    A plan CSV from an earlier run. Given, its rows are written to the register.
    Omitted, a new plan is generated and nothing is written.
.PARAMETER Library
    Libraries to read Document Sets from.
.PARAMETER RegisterList
    The list that registers them.
.PARAMETER ContentTypeMap
    Hashtable of library to the register content type its Document Sets are
    registered as. Pass an empty hashtable to put every row in the register's
    default content type.
.PARAMETER ReferenceField
    Internal name of a second hyperlink column pointing at the Document Set in
    its library. Empty by default: the Document ID link already opens the
    Document Set and, unlike a path, keeps working after a move.
.PARAMETER DocumentIdField
    Internal name of the register's hyperlink column carrying the Document ID.
    Also the key for deciding whether a row already exists.
.PARAMETER LinkField
    Internal name of the hyperlink column pass two labels. Defaults to the
    Document ID column.
.PARAMETER LinkTextField
    Internal name of the column that link's text is taken from, in pass two.
    Typically a calculated column.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile.
.PARAMETER OutputPath
    Directory for the plan and the results. Defaults to
    out/documentset-register-<timestamp>.
.PARAMETER RelabelExisting
    In pass two, also fix the link text of rows that were already in the
    register. Off by default: this run did not create them, and their text may
    have been set deliberately. Given without -Plan, it runs pass two alone.
.PARAMETER SkipLinkText
    Run pass one only. The links get their URL but no text; a later run with
    -RelabelExisting can finish the job.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling.
.EXAMPLE
    ./scripts/Sync-DocumentSetRegister.ps1

    Writes a plan and changes nothing.
.EXAMPLE
    ./scripts/Sync-DocumentSetRegister.ps1 -Plan out/documentset-register-20260806_120000/plan.csv -WhatIf

    Shows every row that would be created and every link that would be
    labelled, and performs neither.
.EXAMPLE
    ./scripts/Sync-DocumentSetRegister.ps1 -Library Projekte -RegisterList 'CDS Mappen' -ProfileName CDS
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$Plan,

    [Parameter()]
    [string[]]$Library = @('Management', 'Projekte', 'Produkte'),

    [Parameter()]
    [string]$RegisterList = 'CDS Mappen',

    # The register's content types are named for the *kind* of thing, the
    # libraries for the plural German noun, and neither name can be derived
    # from the other. Hence a table -- and hence it lives here, in the script
    # that already knows this site's library names, rather than in the module.
    [Parameter()]
    [ValidateNotNull()]
    [hashtable]$ContentTypeMap = @{
        Management = 'CDS Document Set List Entry Management'
        Projekte   = 'CDS Document Set List Entry Project'
        Produkte   = 'CDS Document Set List Entry Product'
    },

    # Empty because this site's register no longer has a separate back-link
    # column. It does not need one: a DocIdRedir link opens the Document Set
    # just as well and, being an ID rather than a path, does not go stale when
    # the folder is renamed or moved to another library.
    [Parameter()]
    [string]$ReferenceField = '',

    [Parameter()]
    [string]$DocumentIdField = 'Document_x0020_ID',

    [Parameter()]
    [string]$LinkField = 'Document_x0020_ID',

    [Parameter()]
    [string]$LinkTextField = 'Name_x0020_ID',

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$RelabelExisting,

    [Parameter()]
    [switch]$SkipLinkText,

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
    $OutputPath = Join-Path $PSScriptRoot "../out/documentset-register-$timestamp"
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
    # -WhatIf:$false because this is a local scratch directory for the plan and
    # the log, not a change to the tenant. Under -WhatIf it still has to exist:
    # a preview that cannot write its own report is not much of a preview.
    New-Item -Path $OutputPath -ItemType Directory -Force -WhatIf:$false | Out-Null
}

Start-O365Log -Path (Join-Path $OutputPath 'register.log') | Out-Null

# The plan CSV is flat, so it can be opened in Excel and edited. These columns
# say what to do and where the row came from; every other column is a register
# column to be written. ContentType is here rather than among the value columns
# because it is not a field value -- it is passed to the write as its own
# parameter and decides which fields the row is even supposed to have.
$provenance = @(
    'Action', 'RegisterItemId', 'ContentType', 'CurrentContentType',
    'SourceList', 'DocumentSetItemId', 'Name', 'ServerRelativeUrl', 'DocumentId'
)

# ===========================================================================
# Planning
# ===========================================================================
# -RelabelExisting on its own is the exception: there is nothing to plan when
# the run is only going to fix link text on rows that already exist.
if (-not $Plan -and -not $RelabelExisting) {
    Write-Host ''
    Write-Host '=== Planning ===' -ForegroundColor Cyan

    $parameters = @{
        Library         = $Library
        RegisterList    = $RegisterList
        ReferenceField  = $ReferenceField
        DocumentIdField = $DocumentIdField
        ContentTypeMap  = $ContentTypeMap
        PageSize        = $PageSize
    }

    $entries = @(Get-SpoDocumentSetRegisterEntry @parameters)

    if ($entries.Count -eq 0) {
        Write-Host ''
        Write-Host "Nothing to do: '$RegisterList' is in step with every Document Set in $($Library -join ', ')." -ForegroundColor Green
        Stop-O365Log | Out-Null
        return
    }

    # One column per register field, across all entries -- a library missing a
    # column must not shift the columns of the rows from another one.
    $columns = @($entries | ForEach-Object { $_.Values.Keys } | Sort-Object -Unique)

    $rows = foreach ($entry in $entries) {
        $row = [ordered]@{}
        foreach ($name in $provenance) {
            $row[$name] = $entry.$name
        }
        foreach ($name in $columns) {
            $value = if ($entry.Values.ContainsKey($name)) { $entry.Values[$name] } else { '' }
            # Multi-value columns arrive as an array; ';' survives a round trip
            # through Excel where a comma would not.
            $row[$name] = if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) { @($value) -join ';' } else { $value }
        }
        [pscustomobject]$row
    }

    $planPath = Join-Path $OutputPath 'plan.csv'
    $rows | Export-Csv -Path $planPath -NoTypeInformation -Encoding utf8

    Write-Host ''
    foreach ($sourceGroup in ($entries | Group-Object SourceList | Sort-Object Name)) {
        foreach ($actionGroup in ($sourceGroup.Group | Group-Object Action | Sort-Object Name)) {
            Write-Host ("  {0,-24} {1,-8} {2,4} row(s)" -f $sourceGroup.Name, $actionGroup.Name.ToLower(), $actionGroup.Count)
        }
    }

    $moved = @($entries | Where-Object Action -eq 'Update')
    if ($moved.Count -gt 0) {
        Write-Host ''
        Write-Host "  $($moved.Count) row(s) belong to a Document Set that has moved library:" -ForegroundColor Yellow
        foreach ($entry in $moved) {
            Write-Host ("    {0,-6} {1} -- {2} -> {3}" -f $entry.RegisterItemId, $entry.Name, $entry.CurrentContentType, $entry.ContentType) -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host "  register columns: $($columns -join ', ')" -ForegroundColor Gray

    Write-Host ''
    Write-Host "Plan written to: $((Resolve-Path $planPath).Path)" -ForegroundColor Green
    Write-Host 'Nothing was changed.' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Read it, edit the values you want different, then:' -ForegroundColor Gray
    Write-Host "    ./scripts/Sync-DocumentSetRegister.ps1 -Plan '$planPath' -WhatIf" -ForegroundColor Gray

    Stop-O365Log | Out-Null
    return
}

# ===========================================================================
# Pass 1 -- create the rows
# ===========================================================================
# All empty under -RelabelExisting with no -Plan: the loop below then has
# nothing to iterate and the run falls through to pass two, which is the whole
# of that mode. Everything here stays guarded rather than being wrapped in one
# big if, so there is only one copy of the write logic to reason about.
$planRows     = @()
$planColumns  = @()
$valueColumns = @()
$alreadyThere = @{}
$byId         = @{}
$contentTypeNames = @{}

$results = [System.Collections.Generic.List[object]]::new()
$touched = [System.Collections.Generic.List[int]]::new()

if ($Plan) {
    if (-not (Test-Path -LiteralPath $Plan)) {
        throw "Plan file '$Plan' was not found. Run the script without -Plan to generate one."
    }

    $planRows = @(Import-Csv -Path $Plan -Encoding utf8)

    if ($planRows.Count -eq 0) {
        Write-Host "Plan '$Plan' has no rows." -ForegroundColor Yellow
        Stop-O365Log | Out-Null
        return
    }

    $planColumns = @($planRows[0].PSObject.Properties.Name)
    $valueColumns = @($planColumns | Where-Object { $_ -notin $provenance })

    # Only creates need columns to write. A plan that is all updates legitimately
    # has none: a Document Set that moved library changes its row's content type
    # and nothing else, and the content type is not a column.
    $hasCreate = @($planRows | Where-Object { 'Action' -notin $planColumns -or [string]::IsNullOrWhiteSpace($_.Action) -or $_.Action -eq 'Create' }).Count -gt 0

    if ($valueColumns.Count -eq 0 -and $hasCreate) {
        throw "Plan '$Plan' has rows to create but no register columns, only provenance ones ($($provenance -join ', ')). It is probably the wrong file."
    }

    foreach ($required in @('Name', 'DocumentId')) {
        if ($required -notin $planColumns) {
            throw "Plan '$Plan' has no '$required' column. Generate a plan by running this script without -Plan, rather than writing one by hand."
        }
    }

    # Re-read the register rather than trusting the plan to still be accurate. A
    # plan is a file: it can be a day old, or half of it can already have been
    # applied by an earlier run that failed part way through. Matching on Document
    # ID here is what makes re-running the same plan safe.
    #
    # By content type ID rather than the item's ContentType field value, which
    # comes back empty often enough that trusting it would report every row as
    # correctly filed.
    foreach ($registerType in @(Get-PnPContentType -List $RegisterList)) {
        $contentTypeNames[[string]$registerType.StringId] = $registerType.Name
    }

    foreach ($item in @(Get-PnPListItem -List $RegisterList -PageSize $PageSize -Fields @('ID', 'ContentTypeId', $DocumentIdField))) {
        $byId[$item.Id] = $item

        $link = $item.FieldValues[$DocumentIdField]
        if ($null -eq $link) { continue }

        # The ID out of the URL, not the link text -- pass two overwrites that
        # text with the calculated column, so a row labelled 'HG4425-AEB' would
        # otherwise stop matching its own Document Set and be created a second
        # time. Same rule as ConvertTo-SpoRegisterKey in the module; the two are
        # comparing against the same plan and have to agree.
        $key = if ([string]$link.Url -match 'DocIdRedir\.aspx\?(?:.*&)?ID=([^&]+)') { [uri]::UnescapeDataString($Matches[1]) }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$link.Description)) { [string]$link.Description }
        else { [string]$link.Url }

        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $alreadyThere[$key.Trim().ToLowerInvariant()] = $item.Id
        }
    }

    Write-Host ''
    Write-Host '=== Writing entries ===' -ForegroundColor Cyan
    Write-Host "  $($planRows.Count) row(s) from $(Split-Path -Leaf $Plan)"
    Write-Host "  columns: $($valueColumns -join ', ')" -ForegroundColor Gray
    Write-Host "  '$RegisterList' already holds $($alreadyThere.Count) row(s) with a Document ID" -ForegroundColor Gray
    Write-Host ''
}

foreach ($row in $planRows) {
    $documentId  = [string]$row.DocumentId
    $documentKey = $documentId.Trim().ToLowerInvariant()

    # A plan written before Action existed is a plan of creates.
    $action = if ('Action' -in $planColumns -and -not [string]::IsNullOrWhiteSpace($row.Action)) { $row.Action } else { 'Create' }

    if ($action -notin @('Create', 'Update')) {
        # Not a fussy check. Create is the fall-through, so an Action this
        # script does not understand would otherwise be *written* -- the one
        # mistake that cannot be undone by re-running.
        Write-Host "  skipped $($row.Name) -- Action '$action' is not one this script writes" -ForegroundColor Yellow
        continue
    }

    $contentType = if ('ContentType' -in $planColumns) { [string]$row.ContentType } else { '' }

    $values = @{}
    foreach ($name in $valueColumns) {
        $value = $row.$name
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $values[$name] = $value
        }
    }

    $label = if ($values.ContainsKey('Title')) { $values['Title'] } else { $row.Name }

    $record = {
        param($Status, $ItemId, $ErrorText)

        $results.Add([pscustomobject]@{
                Action         = $action
                SourceList     = $row.SourceList
                Name           = $row.Name
                DocumentId     = $documentId
                ContentType    = $contentType
                RegisterItemId = $ItemId
                Status         = $Status
                Error          = $ErrorText
            })
    }

    # -- Update: a Document Set that has moved library ----------------------
    if ($action -eq 'Update') {
        $itemId = if ('RegisterItemId' -in $planColumns -and $row.RegisterItemId) { [int]$row.RegisterItemId }
        elseif ($documentKey -and $alreadyThere.ContainsKey($documentKey)) { $alreadyThere[$documentKey] }
        else { 0 }

        if ($itemId -eq 0 -or -not $byId.ContainsKey($itemId)) {
            & $record 'NotFound' $null "No row in '$RegisterList' for Document ID '$documentId'. It may have been deleted since the plan was written; re-plan."
            Write-Host "  MISSING $label -- no such row any more; re-plan" -ForegroundColor Red
            continue
        }

        # Re-check against the list, not the plan. If someone else already
        # reclassified the row, saying so beats writing it a second time.
        $existingItem = $byId[$itemId]
        $existingType = [string]$existingItem.FieldValues['ContentTypeId']
        $currentType  = if ($contentTypeNames.ContainsKey($existingType)) { $contentTypeNames[$existingType] } else { '' }
        $typeChange   = if ($contentType -and $currentType -ne $contentType) { $contentType } else { '' }

        if (-not $typeChange -and $values.Count -eq 0) {
            & $record 'AlreadyCorrect' $itemId $null
            Write-Host ("  ok      {0,-6} {1} -- already {2}" -f $itemId, $label, $currentType) -ForegroundColor DarkGray
            continue
        }

        try {
            $parameters = @{
                Library     = $RegisterList
                Id          = $itemId
                Values      = $values
                ErrorAction = 'Stop'
                Confirm     = $false
                WhatIf      = $WhatIfPreference
            }
            if ($typeChange) {
                $parameters['ContentType'] = $typeChange
            }

            Update-SpoListItem @parameters | Out-Null

            if ($WhatIfPreference) {
                $what = @(@($typeChange) + @($values.Keys) | Where-Object { $_ }) -join ', '
                Write-Host ("  would update   {0,-6} {1} -- {2}" -f $itemId, $label, $what) -ForegroundColor DarkGray
                continue
            }

            $touched.Add($itemId)
            & $record 'Updated' $itemId $null
            Write-Host ("  updated {0,-6} {1} -- {2} -> {3}" -f $itemId, $label, $currentType, ($typeChange ? $typeChange : $currentType)) -ForegroundColor Yellow
        }
        catch {
            & $record 'Failed' $itemId $_.Exception.Message
            Write-Host "  FAILED  $label -- $($_.Exception.Message)" -ForegroundColor Red
        }

        continue
    }

    # -- Create -------------------------------------------------------------
    if ($documentId -and $alreadyThere.ContainsKey($documentKey)) {
        & $record 'AlreadyPresent' $alreadyThere[$documentKey] $null
        Write-Host ("  skipped {0,-6} {1} -- already in the register" -f $alreadyThere[$documentKey], $row.Name) -ForegroundColor DarkGray
        continue
    }

    try {
        $parameters = @{
            Library     = $RegisterList
            Values      = $values
            PassThru    = $true
            ErrorAction = 'Stop'
            # -WhatIf is forwarded explicitly, and that is not belt and braces.
            # $WhatIfPreference set by this script's -WhatIf does *not* reach a
            # function defined inside a module: the function resolves preference
            # variables in the module's scope, where it is still false. Rely on
            # it and -WhatIf writes for real while the script reports nothing.
            WhatIf      = $WhatIfPreference
        }
        if ($contentType) {
            $parameters['ContentType'] = $contentType
        }

        $item = Add-SpoListItem @parameters

        if ($WhatIfPreference) {
            Write-Host ("  would create   {0} -- {1}" -f $label, ($contentType ? $contentType : 'default content type')) -ForegroundColor DarkGray
            continue
        }

        $touched.Add($item.Id)
        & $record 'Created' $item.Id $null
        Write-Host ("  created {0,-6} {1}" -f $item.Id, $label) -ForegroundColor Green
    }
    catch {
        & $record 'Failed' $null $_.Exception.Message
        Write-Host "  FAILED  $label -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($results.Count -gt 0) {
    $results | Export-Csv -Path (Join-Path $OutputPath 'written.csv') -NoTypeInformation -Encoding utf8
}

# ===========================================================================
# Pass 2 -- label the links
# ===========================================================================
$labelled = @()

if ($SkipLinkText) {
    Write-Host ''
    Write-Host 'Skipping the link text pass (-SkipLinkText).' -ForegroundColor Yellow
}
elseif ($WhatIfPreference -and -not $RelabelExisting) {
    # Described rather than previewed, because pass one created nothing under
    # -WhatIf: there are no row IDs to narrow to, and an unnarrowed call would
    # preview relabelling every row in the register. -RelabelExisting means
    # exactly that, so it is let through below.
    Write-Host ''
    Write-Host "Pass two would set '$LinkField' text from '$LinkTextField' on the rows created above." -ForegroundColor Gray
}
elseif ($touched.Count -eq 0 -and -not $RelabelExisting) {
    Write-Host ''
    Write-Host 'Nothing was written, so there is no link text to set.' -ForegroundColor Yellow
}
else {
    Write-Host ''
    Write-Host '=== Setting link text ===' -ForegroundColor Cyan

    $parameters = @{
        Library     = $RegisterList
        Field       = $LinkField
        TextField   = $LinkTextField
        PassThru    = $true
        Confirm     = $false
        ErrorAction = 'Continue'
        WhatIf      = $WhatIfPreference
    }
    if (-not $RelabelExisting) {
        $parameters['Id'] = @($touched)
    }

    $labelled = @(Update-SpoListItemLinkText @parameters)

    if ($labelled.Count -gt 0) {
        $labelled | Export-Csv -Path (Join-Path $OutputPath 'link-text.csv') -NoTypeInformation -Encoding utf8
    }

    foreach ($group in ($labelled | Group-Object Status | Sort-Object Name)) {
        Write-Host ("  {0,-16} {1,4}" -f $group.Name, $group.Count)
    }
}

Stop-O365Log | Out-Null

# -- Summary ----------------------------------------------------------------
Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan
Write-Host "  entries created  : $(@($results | Where-Object Status -eq 'Created').Count)"
Write-Host "  entries updated  : $(@($results | Where-Object Status -eq 'Updated').Count)"
Write-Host "  already present  : $(@($results | Where-Object Status -eq 'AlreadyPresent').Count)"
Write-Host "  already correct  : $(@($results | Where-Object Status -eq 'AlreadyCorrect').Count)"
Write-Host "  rows not found   : $(@($results | Where-Object Status -eq 'NotFound').Count)"
Write-Host "  entries failed   : $(@($results | Where-Object Status -eq 'Failed').Count)"
Write-Host "  links labelled   : $(@($labelled | Where-Object Status -eq 'Updated').Count)"
Write-Host ''
Write-Host "Reports written to: $((Resolve-Path $OutputPath).Path)" -ForegroundColor Green

if (@($results | Where-Object Status -eq 'Failed').Count -gt 0) {
    Write-Host ''
    Write-Host 'Some rows failed. written.csv has the reason for each. Fix the plan and re-run the same' -ForegroundColor Yellow
    Write-Host 'file: rows that succeeded are matched by Document ID and will not be written twice.' -ForegroundColor Yellow
}
