<#
.SYNOPSIS
    Bulk-renames stored values of a list field across one or more libraries.
.DESCRIPTION
    Renaming a Choice field's options in a content type (or its hub) only
    changes the field definition. Existing item data keeps the old text
    forever, because choice values are stored as plain strings, not
    references to the option list. Nothing rewrites old items automatically.

    This finds every item still holding an old value and rewrites it to the
    new one. It scans every non-hidden list on the connected site that has
    the field, unless -Library restricts it, and uses a CAML query per old
    value so it stays fast even on large libraries.

    Updates go through -SystemUpdate by default: a value rename is bookkeeping,
    not a real content change, so it shouldn't bump Modified/Editor or create
    a version.
.PARAMETER Field
    Internal name of the field to update.
.PARAMETER Mapping
    Hashtable of old value -> new value, e.g. @{ Board = 'BOARD'; Undefined = 'MISC' }.
    Entries where old and new are equal are skipped. An empty-string key (@{ '' = 'MISC' })
    matches items where the field is blank/unset, to fill them in rather than rename them.
.PARAMETER Library
    Restrict the scan to these lists. Omit to check every list on the site.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile, or to reuse
    an existing connection.
.PARAMETER SystemUpdate
    Update without bumping Modified/Editor or creating a version. Defaults to
    $true; pass -SystemUpdate:$false for normal versioned updates.
.PARAMETER FolderOnly
    Only match folders and Document Sets, skipping ordinary files/items. Fields
    like Section are often set once per Document Set rather than per file, so
    a blank-fill without this would also stamp every file inside it.

    Note this matches *plain* folders too, which usually do not carry the field
    on their content type. For a Document Set field, prefer -DocumentSetOnly.
.PARAMETER DocumentSetOnly
    Only match Document Sets (content type derived from 0x0120D520).

    Safer than -FolderOnly for Document Set metadata: a library's plain folders
    are also FSObjType 1, but their content type does not include the field, so
    -FolderOnly would write values that no content type surfaces.
.PARAMETER SkipInapplicable
    Skip items whose content type does not actually carry -Field. A field
    defined on the list still appears in every item's FieldValues, so a blank
    fill can otherwise stamp items the field does not apply to.
.EXAMPLE
    ./scripts/Update-SpoFieldValue.ps1 -Field Section -Mapping @{ Board = 'BOARD'; Undefined = 'MISC' } -WhatIf

    Preview only -- nothing is written.
.EXAMPLE
    ./scripts/Update-SpoFieldValue.ps1 -Field Section -Mapping @{ Board = 'BOARD'; Undefined = 'MISC' }

    Applies the rename everywhere the field is found.
.EXAMPLE
    ./scripts/Update-SpoFieldValue.ps1 -Field Section -Mapping @{ Board = 'BOARD' } -Library Management, Projekte
.EXAMPLE
    ./scripts/Update-SpoFieldValue.ps1 -Field Section -Mapping @{ '' = 'MISC' } -DocumentSetOnly

    Fills every Document Set where Section is blank with 'MISC', leaving files
    and plain folders untouched.
.NOTES
    Uses Update-SpoListItem from the Office365Tools module, so every write
    respects -WhatIf/-Confirm the same way the module commands do.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Field,

    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNull()]
    [hashtable]$Mapping,

    [Parameter()]
    [string[]]$Library,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [bool]$SystemUpdate = $true,

    [Parameter()]
    [switch]$FolderOnly,

    [Parameter()]
    [switch]$DocumentSetOnly,

    [Parameter()]
    [switch]$SkipInapplicable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

$connection = Get-O365Connection -ErrorAction SilentlyContinue
if (-not $connection -or -not $connection.IsLive) {
    if ($ProfileName) { Connect-O365 -ProfileName $ProfileName } else { Connect-O365 }
    $connection = Get-O365Connection
}

# Escapes a value for embedding in a CAML <Value> element.
function ConvertTo-CamlText {
    param([string]$Text)
    $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

$targetLists = if ($Library) {
    $Library | ForEach-Object {
        $list = Get-PnPList -Identity $_ -ErrorAction SilentlyContinue
        if (-not $list) {
            Write-Error "List or library '$_' was not found on $($connection.SiteUrl)."
        }
        else {
            $list
        }
    }
}
else {
    Get-PnPList | Where-Object { -not $_.Hidden }
}

$pairs = @($Mapping.GetEnumerator() | Where-Object { $_.Key -cne $_.Value })
$totalUpdated = 0
$totalFailed = 0

foreach ($list in $targetLists) {
    $fieldDef = Get-PnPField -List $list -Identity $Field -ErrorAction SilentlyContinue
    if (-not $fieldDef) { continue }

    $camlValueType = if ($fieldDef.TypeAsString -in 'Choice', 'MultiChoice') { 'Choice' } else { 'Text' }

    # A field defined on the list shows up in every item's FieldValues, even
    # for content types that do not include it. Collect the content types that
    # genuinely carry the field so inapplicable items can be skipped.
    $applicableCtIds = @()
    if ($SkipInapplicable -or $DocumentSetOnly) {
        foreach ($ct in (Get-PnPContentType -List $list)) {
            if ($DocumentSetOnly -and -not $ct.Id.StringValue.StartsWith('0x0120D520')) { continue }
            $ctFields = Get-PnPProperty -ClientObject $ct -Property Fields
            if (-not $SkipInapplicable -or ($ctFields | Where-Object InternalName -eq $Field)) {
                $applicableCtIds += $ct.Id.StringValue
            }
        }
        if ($applicableCtIds.Count -eq 0) {
            Write-Verbose "'$($list.Title)': no content type carries '$Field'; skipping."
            continue
        }
    }

    foreach ($pair in $pairs) {
        $oldValue = $pair.Key
        $newValue = $pair.Value
        $isBlank = [string]::IsNullOrEmpty($oldValue)

        $valueCondition = if ($isBlank) {
            "<IsNull><FieldRef Name='$Field'/></IsNull>"
        }
        else {
            "<Eq><FieldRef Name='$Field'/><Value Type='$camlValueType'>$(ConvertTo-CamlText $oldValue)</Value></Eq>"
        }
        $condition = if ($FolderOnly) {
            "<And>$valueCondition<Eq><FieldRef Name='FSObjType'/><Value Type='Integer'>1</Value></Eq></And>"
        }
        else {
            $valueCondition
        }
        $caml = "<View Scope='RecursiveAll'><Query><Where>$condition</Where></Query>" +
        "<ViewFields><FieldRef Name='ID'/></ViewFields><RowLimit>5000</RowLimit></View>"

        $items = @(Get-PnPListItem -List $list -Query $caml)

        if ($applicableCtIds.Count -gt 0) {
            $items = @($items | Where-Object {
                    $itemCtId = "$($_.FieldValues['ContentTypeId'])"
                    $applicableCtIds | Where-Object { $itemCtId.StartsWith($_) }
                })
        }

        if ($items.Count -eq 0) { continue }

        $fromLabel = if ($isBlank) { '(blank)' } else { "'$oldValue'" }
        Write-Host "'$($list.Title)': $($items.Count) item(s) with $Field = $fromLabel -> '$newValue'." -ForegroundColor Cyan

        foreach ($item in $items) {
            $description = "Set $Field = '$newValue' (was $fromLabel) on item $($item.Id)"

            if (-not $PSCmdlet.ShouldProcess($list.Title, $description)) { continue }

            try {
                $params = @{
                    Library      = $list.Title
                    Id           = $item.Id
                    Values       = @{ $Field = $newValue }
                    SystemUpdate = $SystemUpdate
                    ErrorAction  = 'Stop'
                }
                Update-SpoListItem @params | Out-Null
                $totalUpdated++
            }
            catch {
                $totalFailed++
                Write-Error -Message "Failed to update item $($item.Id) in '$($list.Title)': $($_.Exception.Message)" -TargetObject $item.Id
            }
        }
    }
}

$summaryColor = if ($totalFailed -gt 0) { 'Yellow' } else { 'Green' }
Write-Host "Done. $totalUpdated item(s) updated, $totalFailed failed." -ForegroundColor $summaryColor
