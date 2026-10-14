<#
.SYNOPSIS
    Interactive menu for browsing and editing site content types and columns.
.DESCRIPTION
    A menu-driven front end over the module's content type commands, for the
    cases where clicking through SharePoint's settings pages is tedious and
    writing the command by hand means looking up internal names first.

    What it does:

      - lists global (site) content types, grouped
      - shows the columns on any of them
      - creates a content type
      - creates a site column
      - adds existing or brand-new columns to a content type
      - removes columns from a content type

    Two safety properties:

      Nothing is written until you confirm a summary of exactly what will
      happen. The underlying commands also support -WhatIf, and this script
      offers a preview before every change.

      Every write goes through the module commands, so the interactive path and
      the scripted path behave identically. Anything you can do here you can
      also automate, and the script tells you the equivalent command.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile. Ignored if you
    are already connected.
.PARAMETER Group
    Restrict the content type listing to this group. Handy on a site with
    hundreds of them.
.EXAMPLE
    ./scripts/Manage-ContentType.ps1

.EXAMPLE
    ./scripts/Manage-ContentType.ps1 -ProfileName cds -Group 'Custom Content Types'
.NOTES
    Requires an interactive console. For automation use the commands directly:
    Get-SpoContentType, New-SpoContentType, New-SpoField, Get-SpoField,
    Add-SpoFieldToContentType, Remove-SpoFieldFromContentType.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$Group,

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
    Set-O365Language -Language $Language -SessionOnly -WhatIf:$false
}

. (Join-Path $PSScriptRoot 'Shared/ScriptLanguage.ps1')

# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------

function Write-Title {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
}

function Write-Hint {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor DarkGray
}

# Shows the command that would produce the same result, so the interactive
# session doubles as a way to learn the scripted form.
function Write-Equivalent {
    param([string]$Command)
    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.Equivalent') -ForegroundColor DarkGray
    Write-Host "    $Command" -ForegroundColor DarkGray
}

function Read-Choice {
    param(
        [string]$Prompt = 'Choice',
        [string]$Default
    )
    $suffix = if ($Default) { " [$Default]" } else { '' }
    $answer = Read-Host "$Prompt$suffix"
    if (-not $answer -and $Default) { return $Default }
    return $answer.Trim()
}

function Confirm-Action {
    param([string]$Prompt = 'Proceed?')
    $answer = Read-Host "$Prompt $(Get-ScriptString 'ContentTypeMenu.YesNo')"
    return $answer -match '^(y|yes|j|ja)$'
}

<#
    Numbered picker. Returns the selected item(s), or $null if the user backed
    out. Multi-select accepts '1,3,5', ranges '2-6', 'all', or a mix.
#>
function Select-Item {
    param(
        [Parameter(Mandatory)][object[]]$Item,
        [Parameter(Mandatory)][scriptblock]$Label,
        [string]$Title = 'Select',
        [switch]$Multiple,
        [int]$PageSize = 30
    )

    if ($Item.Count -eq 0) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.NothingToChoose') -ForegroundColor Yellow
        return $null
    }

    $filtered = $Item
    $filter = ''

    while ($true) {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor White
        if ($filter) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.FilterActive' $filter $filtered.Count $Item.Count) -ForegroundColor DarkGray
        }
        Write-Host ''

        if ($filtered.Count -eq 0) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.NoMatches') -ForegroundColor Yellow
        }
        else {
            $shown = [Math]::Min($filtered.Count, $PageSize)
            for ($i = 0; $i -lt $shown; $i++) {
                $text = & $Label $filtered[$i]
                Write-Host ('   {0,3}) {1}' -f ($i + 1), $text)
            }
            if ($filtered.Count -gt $shown) {
                Write-Host (Get-ScriptString 'ContentTypeMenu.MoreRows' ($filtered.Count - $shown)) -ForegroundColor DarkGray
            }
        }

        Write-Host ''
        if ($Multiple) {
            Write-Hint (Get-ScriptString 'ContentTypeMenu.PickMany')
        }
        else {
            Write-Hint (Get-ScriptString 'ContentTypeMenu.PickOne')
        }

        $answer = Read-Choice -Prompt '  >'

        if (-not $answer) { continue }
        if ($answer -match '^(b|back|z|q|quit)$') { return $null }

        if ($answer.StartsWith('/')) {
            $filter = $answer.Substring(1).Trim()
            $filtered = if ($filter) {
                @($Item | Where-Object { (& $Label $_) -like "*$filter*" })
            }
            else {
                $Item
            }
            continue
        }

        if ($Multiple -and $answer -match '^(all|alle)$') {
            return $filtered
        }

        # Parse a selection expression into indices.
        $indices = [System.Collections.Generic.List[int]]::new()
        $valid = $true

        foreach ($part in ($answer -split ',')) {
            $part = $part.Trim()
            if (-not $part) { continue }

            if ($part -match '^(\d+)\s*-\s*(\d+)$') {
                $from = [int]$Matches[1]
                $to = [int]$Matches[2]
                if ($from -gt $to) { $from, $to = $to, $from }
                for ($n = $from; $n -le $to; $n++) { $indices.Add($n) }
            }
            elseif ($part -match '^\d+$') {
                $indices.Add([int]$part)
            }
            else {
                $valid = $false
                break
            }
        }

        if (-not $valid -or $indices.Count -eq 0) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.BadSelection') -ForegroundColor Yellow
            continue
        }

        $outOfRange = @($indices | Where-Object { $_ -lt 1 -or $_ -gt $filtered.Count })
        if ($outOfRange.Count -gt 0) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.OutOfRange' ($outOfRange -join ', ')) -ForegroundColor Yellow
            continue
        }

        $selected = @($indices | Sort-Object -Unique | ForEach-Object { $filtered[$_ - 1] })

        if (-not $Multiple -and $selected.Count -gt 1) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.PickJustOne') -ForegroundColor Yellow
            continue
        }

        return $(if ($Multiple) { $selected } else { $selected[0] })
    }
}

# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------

function Get-ContentTypeChoice {
    param([string]$Title = 'Content types')

    $params = @{}
    if ($Group) { $params['Group'] = $Group }

    Write-Host (Get-ScriptString 'ContentTypeMenu.LoadingTypes') -ForegroundColor DarkGray
    $contentTypes = @(Get-SpoContentType @params | Sort-Object Group, Name)

    if ($contentTypes.Count -eq 0) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.NoCustomTypes') -ForegroundColor Yellow
        Write-Hint (Get-ScriptString 'ContentTypeMenu.NoCustomTypesHint')
        return $null
    }

    Select-Item -Item $contentTypes -Title $Title -Label {
        param($ct) '{0,-38} {1}' -f $ct.Name, $ct.Group
    }
}

function Show-ContentTypeDetail {
    param([Parameter(Mandatory)]$ContentType)

    Write-Host (Get-ScriptString 'ContentTypeMenu.LoadingColumns') -ForegroundColor DarkGray
    $detail = Get-SpoContentType -Name $ContentType.Name -IncludeFields | Select-Object -First 1

    Write-Title "$($detail.Name)"
    Write-Host (Get-ScriptString 'ContentTypeMenu.DetailGroup' $detail.Group)
    Write-Host "  ID:          $($detail.Id)"
    if ($detail.Description) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.DetailDescription' $detail.Description)
    }
    if ($detail.Sealed) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Sealed') -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.DetailColumns' $detail.FieldCount) -ForegroundColor White
    Write-Host ''

    if ($detail.FieldCount -eq 0) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.None') -ForegroundColor DarkGray
    }
    else {
        Write-Host ('    {0,-32} {1,-30} {2,-13} {3}' -f (Get-ScriptString 'ContentTypeMenu.HeaderInternal'), (Get-ScriptString 'ContentTypeMenu.HeaderDisplay'), (Get-ScriptString 'ContentTypeMenu.HeaderType'), (Get-ScriptString 'ContentTypeMenu.HeaderRequired')) -ForegroundColor DarkGray
        foreach ($field in ($detail.Fields | Sort-Object InternalName)) {
            $required = if ($field.Required) { Get-ScriptString 'ContentTypeMenu.Yes' } else { '' }
            Write-Host ('    {0,-32} {1,-30} {2,-13} {3}' -f $field.InternalName, $field.DisplayName, $field.Type, $required)
        }
    }

    Write-Equivalent "Get-SpoContentType -Name '$($detail.Name)' -IncludeFields | Select-Object -ExpandProperty Fields"
    return $detail
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

function Invoke-ListContentTypes {
    $params = @{}
    if ($Group) { $params['Group'] = $Group }

    Write-Host (Get-ScriptString 'ContentTypeMenu.Loading') -ForegroundColor DarkGray
    $contentTypes = @(Get-SpoContentType @params | Sort-Object Group, Name)

    Write-Title (Get-ScriptString 'ContentTypeMenu.ListTitle' $contentTypes.Count)

    if ($contentTypes.Count -eq 0) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.NoneFound') -ForegroundColor Yellow
        Write-Hint (Get-ScriptString 'ContentTypeMenu.BuiltInHidden')
        return
    }

    foreach ($grouping in ($contentTypes | Group-Object Group | Sort-Object Name)) {
        Write-Host ''
        Write-Host "  $($grouping.Name)" -ForegroundColor Yellow
        foreach ($ct in ($grouping.Group | Sort-Object Name)) {
            $description = if ($ct.Description) { " -- $($ct.Description)" } else { '' }
            Write-Host "    $($ct.Name)$description"
        }
    }

    Write-Equivalent 'Get-SpoContentType | Sort-Object Group, Name'
}

function Invoke-InspectContentType {
    $contentType = Get-ContentTypeChoice -Title (Get-ScriptString 'ContentTypeMenu.WhichType')
    if (-not $contentType) { return }
    Show-ContentTypeDetail -ContentType $contentType | Out-Null
}

function Invoke-CreateContentType {
    Write-Title (Get-ScriptString 'ContentTypeMenu.CreateTypeTitle')

    $name = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptName')
    if (-not $name) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Cancelled') -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Hint (Get-ScriptString 'ContentTypeMenu.ParentHint')
    Write-Hint (Get-ScriptString 'ContentTypeMenu.ParentDocument')
    Write-Hint (Get-ScriptString 'ContentTypeMenu.ParentItem')
    $parent = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptParent') -Default 'Item'

    $group = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptGroup') -Default 'Custom Content Types'
    $description = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptDescription')

    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.AboutToCreate') -ForegroundColor White
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryName' $name)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryParent' $parent)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryGroup' $group)
    if ($description) { Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryDescription' $description) }

    $command = "New-SpoContentType -Name '$name' -Parent '$parent' -Group '$group'"
    if ($description) { $command += " -Description '$description'" }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action (Get-ScriptString 'ContentTypeMenu.CreateIt'))) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Cancelled') -ForegroundColor Yellow
        return
    }

    $params = @{
        Name    = $name
        Parent  = $parent
        Group   = $group
        Confirm = $false
    }
    if ($description) { $params['Description'] = $description }

    try {
        New-SpoContentType @params
        Write-Host (Get-ScriptString 'ContentTypeMenu.TypeCreated' $name) -ForegroundColor Green
        Write-Hint (Get-ScriptString 'ContentTypeMenu.TypeCreatedHint')
    }
    catch {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Failed' $_.Exception.Message) -ForegroundColor Red
    }
}

function Invoke-CreateField {
    Write-Title (Get-ScriptString 'ContentTypeMenu.CreateFieldTitle')

    $displayName = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptDisplayName')
    if (-not $displayName) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Cancelled') -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Hint 'Types: Text, Note, Number, Currency, DateTime, Boolean, Choice,'
    Write-Hint '       MultiChoice, User, UserMulti, URL, Integer'
    $type = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptType') -Default 'Text'

    $choices = $null
    if ($type -in 'Choice', 'MultiChoice') {
        Write-Host ''
        Write-Hint (Get-ScriptString 'ContentTypeMenu.OptionsHint')
        $raw = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptOptions')
        $choices = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        if ($choices.Count -eq 0) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.NeedsOption' $type) -ForegroundColor Yellow
            return
        }
    }

    $group = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptGroup') -Default 'Custom Columns'

    Write-Host ''
    Write-Hint (Get-ScriptString 'ContentTypeMenu.InternalNameHint')
    $internalName = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.PromptInternalName')

    $required = Confirm-Action (Get-ScriptString 'ContentTypeMenu.PromptRequired')

    $derivedName = if ($internalName) { $internalName } else { ($displayName -replace '[^A-Za-z0-9]', '') }

    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.AboutToCreate') -ForegroundColor White
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryDisplayName' $displayName)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryInternalName' $derivedName)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryType' $type)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryFieldGroup' $group)
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryRequired' $(if ($required) { Get-ScriptString 'ContentTypeMenu.Yes' } else { Get-ScriptString 'ContentTypeMenu.No' }))
    if ($choices) { Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryOptions' ($choices -join ', ')) }

    $command = "New-SpoField -DisplayName '$displayName' -Type $type -Group '$group'"
    if ($internalName) { $command += " -InternalName '$internalName'" }
    if ($choices) { $command += " -Choice $(($choices | ForEach-Object { "'$_'" }) -join ', ')" }
    if ($required) { $command += ' -Required' }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action (Get-ScriptString 'ContentTypeMenu.CreateIt'))) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Cancelled') -ForegroundColor Yellow
        return
    }

    $params = @{
        DisplayName = $displayName
        Type        = $type
        Group       = $group
        Confirm     = $false
    }
    if ($internalName) { $params['InternalName'] = $internalName }
    if ($choices) { $params['Choice'] = $choices }
    if ($required) { $params['Required'] = $true }

    try {
        New-SpoField @params
        Write-Host (Get-ScriptString 'ContentTypeMenu.FieldCreated' $displayName) -ForegroundColor Green
        Write-Hint (Get-ScriptString 'ContentTypeMenu.FieldCreatedHint')
        return $derivedName
    }
    catch {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Failed' $_.Exception.Message) -ForegroundColor Red
    }
}

function Invoke-AddColumns {
    $contentType = Get-ContentTypeChoice -Title (Get-ScriptString 'ContentTypeMenu.AddToWhich')
    if (-not $contentType) { return }

    $detail = Show-ContentTypeDetail -ContentType $contentType

    if ($detail.Sealed) {
        Write-Host ''
        Write-Host (Get-ScriptString 'ContentTypeMenu.SealedError') -ForegroundColor Red
        return
    }

    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.ModeExisting') -ForegroundColor White
    Write-Host (Get-ScriptString 'ContentTypeMenu.ModeNew') -ForegroundColor White
    Write-Host (Get-ScriptString 'ContentTypeMenu.ModeBack')
    $mode = Read-Choice -Prompt '  >'

    $fieldNames = @()

    if ($mode -eq '2') {
        $created = Invoke-CreateField
        if (-not $created) { return }
        $fieldNames = @($created)
    }
    elseif ($mode -eq '1') {
        Write-Host (Get-ScriptString 'ContentTypeMenu.LoadingSiteColumns') -ForegroundColor DarkGray

        $present = @($detail.Fields | ForEach-Object { $_.InternalName })
        $available = @(Get-SpoField | Where-Object { $_.InternalName -notin $present } | Sort-Object Group, DisplayName)

        if ($available.Count -eq 0) {
            Write-Host (Get-ScriptString 'ContentTypeMenu.AllColumnsPresent') -ForegroundColor Yellow
            return
        }

        $selected = Select-Item -Item $available -Multiple -Title (Get-ScriptString 'ContentTypeMenu.WhichColumns' $available.Count) -Label {
            param($f) '{0,-30} {1,-28} {2,-12} {3}' -f $f.InternalName, $f.DisplayName, $f.Type, $f.Group
        }

        if (-not $selected) { return }
        $fieldNames = @($selected | ForEach-Object { $_.InternalName })
    }
    else {
        return
    }

    Write-Host ''
    Write-Hint (Get-ScriptString 'ContentTypeMenu.CopiesHint1')
    Write-Hint (Get-ScriptString 'ContentTypeMenu.CopiesHint2')
    $updateChildren = Confirm-Action (Get-ScriptString 'ContentTypeMenu.PromptUpdateCopies')

    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.AboutToAdd' $detail.Name) -ForegroundColor White
    foreach ($name in $fieldNames) {
        Write-Host "    + $name"
    }
    Write-Host (Get-ScriptString 'ContentTypeMenu.SummaryUpdateCopies' $(if ($updateChildren) { Get-ScriptString 'ContentTypeMenu.Yes' } else { Get-ScriptString 'ContentTypeMenu.No' }))

    $command = "Add-SpoFieldToContentType -ContentType '$($detail.Name)' -Field $(($fieldNames | ForEach-Object { "'$_'" }) -join ', ')"
    if ($updateChildren) { $command += ' -UpdateChildren' }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action (Get-ScriptString 'ContentTypeMenu.Apply'))) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.Cancelled') -ForegroundColor Yellow
        return
    }

    $params = @{
        ContentType = $detail.Name
        Field       = $fieldNames
        PassThru    = $true
        Confirm     = $false
    }
    if ($updateChildren) { $params['UpdateChildren'] = $true }

    $results = @(Add-SpoFieldToContentType @params)

    Write-Host ''
    foreach ($result in $results) {
        $colour = switch ($result.Status) {
            'Added' { 'Green' }
            'AlreadyPresent' { 'DarkGray' }
            default { 'Red' }
        }
        Write-Host "    $($result.FieldInternalName): $($result.Status)" -ForegroundColor $colour
    }
}

function Invoke-RemoveColumns {
    $contentType = Get-ContentTypeChoice -Title (Get-ScriptString 'ContentTypeMenu.RemoveFromWhich')
    if (-not $contentType) { return }

    $detail = Show-ContentTypeDetail -ContentType $contentType

    if ($detail.Sealed) {
        Write-Host ''
        Write-Host (Get-ScriptString 'ContentTypeMenu.SealedError') -ForegroundColor Red
        return
    }

    $removable = @($detail.Fields | Where-Object { -not $_.ReadOnly } | Sort-Object InternalName)

    if ($removable.Count -eq 0) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.NoRemovable') -ForegroundColor Yellow
        return
    }

    $selected = Select-Item -Item $removable -Multiple -Title (Get-ScriptString 'ContentTypeMenu.WhichToRemove') -Label {
        param($f) '{0,-30} {1,-28} {2}' -f $f.InternalName, $f.DisplayName, $f.Type
    }

    if (-not $selected) { return }

    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.Warning') -ForegroundColor Red
    Write-Hint (Get-ScriptString 'ContentTypeMenu.RemoveWarn1')
    Write-Hint (Get-ScriptString 'ContentTypeMenu.RemoveWarn2')
    Write-Hint (Get-ScriptString 'ContentTypeMenu.RemoveWarn3')
    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.AboutToRemove' $detail.Name) -ForegroundColor White
    foreach ($field in $selected) {
        Write-Host "    - $($field.InternalName)  ($($field.DisplayName))" -ForegroundColor Yellow
    }

    $names = ($selected | ForEach-Object { "'$($_.InternalName)'" }) -join ', '
    Write-Equivalent "Find-SpoContentTypeByColumn -ColumnName $names | Remove-SpoFieldFromContentType"

    Write-Host ''
    $typed = Read-Choice -Prompt (Get-ScriptString 'ContentTypeMenu.TypeNameToConfirm' $detail.Name)

    if ($typed -ne $detail.Name) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.NameMismatch') -ForegroundColor Yellow
        return
    }

    foreach ($field in $selected) {
        try {
            Remove-SpoFieldFromContentType -ContentTypeId $detail.Id `
                -ContentTypeName $detail.Name `
                -FieldInternalName $field.InternalName `
                -Confirm:$false
            Write-Host (Get-ScriptString 'ContentTypeMenu.ColumnRemoved' $field.InternalName) -ForegroundColor Green
        }
        catch {
            Write-Host (Get-ScriptString 'ContentTypeMenu.ColumnRemoveFailed' $field.InternalName $_.Exception.Message) -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

$connection = Get-O365Connection -ErrorAction SilentlyContinue

if (-not $connection -or -not $connection.IsLive) {
    Write-Host (Get-ScriptString 'ContentTypeMenu.Connecting') -ForegroundColor DarkGray
    if ($ProfileName) {
        Connect-O365 -ProfileName $ProfileName
    }
    else {
        Connect-O365
    }
    $connection = Get-O365Connection
}

while ($true) {
    Write-Title (Get-ScriptString 'ContentTypeMenu.ManagerTitle')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Site' $connection.SiteUrl) -ForegroundColor DarkGray
    if ($Group) {
        Write-Host (Get-ScriptString 'ContentTypeMenu.GroupFilter' $Group) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu1')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu2')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu3')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu4')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu5')
    Write-Host (Get-ScriptString 'ContentTypeMenu.Menu6')
    Write-Host (Get-ScriptString 'ContentTypeMenu.MenuQuit')
    Write-Host ''

    $choice = Read-Choice -Prompt '  >'

    switch ($choice) {
        '1' { Invoke-ListContentTypes }
        '2' { Invoke-InspectContentType }
        '3' { Invoke-CreateContentType }
        '4' { Invoke-AddColumns }
        '5' { Invoke-RemoveColumns }
        '6' { Invoke-CreateField | Out-Null }
        { $_ -match '^(q|quit|exit|e|ende)$' } {
            Write-Host ''
            Write-Host (Get-ScriptString 'ContentTypeMenu.Bye') -ForegroundColor DarkGray
            return
        }
        default {
            Write-Host (Get-ScriptString 'ContentTypeMenu.NotAnOption') -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Read-Host (Get-ScriptString 'ContentTypeMenu.PressEnter') | Out-Null
}
