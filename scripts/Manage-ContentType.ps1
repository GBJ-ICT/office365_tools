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
    [string]$Group
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

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
    Write-Host '  Equivalent command:' -ForegroundColor DarkGray
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
    $answer = Read-Host "$Prompt (y/N)"
    return $answer -match '^(y|yes)$'
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
        Write-Host '  Nothing to choose from.' -ForegroundColor Yellow
        return $null
    }

    $filtered = $Item
    $filter = ''

    while ($true) {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor White
        if ($filter) {
            Write-Host "  filter: '$filter' ($($filtered.Count) of $($Item.Count))" -ForegroundColor DarkGray
        }
        Write-Host ''

        if ($filtered.Count -eq 0) {
            Write-Host '  No matches.' -ForegroundColor Yellow
        }
        else {
            $shown = [Math]::Min($filtered.Count, $PageSize)
            for ($i = 0; $i -lt $shown; $i++) {
                $text = & $Label $filtered[$i]
                Write-Host ('   {0,3}) {1}' -f ($i + 1), $text)
            }
            if ($filtered.Count -gt $shown) {
                Write-Host "        ... and $($filtered.Count - $shown) more. Narrow with /text." -ForegroundColor DarkGray
            }
        }

        Write-Host ''
        if ($Multiple) {
            Write-Hint 'Enter numbers (1,3,5 or 2-6 or all), /text to filter, or B to go back.'
        }
        else {
            Write-Hint 'Enter a number, /text to filter, or B to go back.'
        }

        $answer = Read-Choice -Prompt '  >'

        if (-not $answer) { continue }
        if ($answer -match '^(b|back|q|quit)$') { return $null }

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

        if ($Multiple -and $answer -match '^all$') {
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
            Write-Host '  Not a valid selection.' -ForegroundColor Yellow
            continue
        }

        $outOfRange = @($indices | Where-Object { $_ -lt 1 -or $_ -gt $filtered.Count })
        if ($outOfRange.Count -gt 0) {
            Write-Host "  Out of range: $($outOfRange -join ', ')" -ForegroundColor Yellow
            continue
        }

        $selected = @($indices | Sort-Object -Unique | ForEach-Object { $filtered[$_ - 1] })

        if (-not $Multiple -and $selected.Count -gt 1) {
            Write-Host '  Pick one.' -ForegroundColor Yellow
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

    Write-Host '  Loading content types...' -ForegroundColor DarkGray
    $contentTypes = @(Get-SpoContentType @params | Sort-Object Group, Name)

    if ($contentTypes.Count -eq 0) {
        Write-Host '  No custom content types found on this site.' -ForegroundColor Yellow
        Write-Hint 'Use option 3 to create one, or -Group to widen the filter.'
        return $null
    }

    Select-Item -Item $contentTypes -Title $Title -Label {
        param($ct) '{0,-38} {1}' -f $ct.Name, $ct.Group
    }
}

function Show-ContentTypeDetail {
    param([Parameter(Mandatory)]$ContentType)

    Write-Host '  Loading columns...' -ForegroundColor DarkGray
    $detail = Get-SpoContentType -Name $ContentType.Name -IncludeFields | Select-Object -First 1

    Write-Title "$($detail.Name)"
    Write-Host "  Group:       $($detail.Group)"
    Write-Host "  ID:          $($detail.Id)"
    if ($detail.Description) {
        Write-Host "  Description: $($detail.Description)"
    }
    if ($detail.Sealed) {
        Write-Host '  Sealed:      yes (cannot be modified)' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host "  Columns ($($detail.FieldCount)):" -ForegroundColor White
    Write-Host ''

    if ($detail.FieldCount -eq 0) {
        Write-Host '    (none)' -ForegroundColor DarkGray
    }
    else {
        Write-Host ('    {0,-32} {1,-30} {2,-13} {3}' -f 'INTERNAL NAME', 'DISPLAY NAME', 'TYPE', 'REQ') -ForegroundColor DarkGray
        foreach ($field in ($detail.Fields | Sort-Object InternalName)) {
            $required = if ($field.Required) { 'yes' } else { '' }
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

    Write-Host '  Loading...' -ForegroundColor DarkGray
    $contentTypes = @(Get-SpoContentType @params | Sort-Object Group, Name)

    Write-Title "Site content types ($($contentTypes.Count))"

    if ($contentTypes.Count -eq 0) {
        Write-Host '  None found.' -ForegroundColor Yellow
        Write-Hint 'Built-in types are hidden. Get-SpoContentType -IncludeBuiltIn shows everything.'
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
    $contentType = Get-ContentTypeChoice -Title 'Which content type?'
    if (-not $contentType) { return }
    Show-ContentTypeDetail -ContentType $contentType | Out-Null
}

function Invoke-CreateContentType {
    Write-Title 'Create a content type'

    $name = Read-Choice -Prompt '  Name'
    if (-not $name) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Hint 'The parent decides where the content type can be used.'
    Write-Hint "  Document - for document libraries"
    Write-Hint "  Item     - for plain lists"
    $parent = Read-Choice -Prompt '  Parent' -Default 'Item'

    $group = Read-Choice -Prompt '  Group' -Default 'Custom Content Types'
    $description = Read-Choice -Prompt '  Description (optional)'

    Write-Host ''
    Write-Host '  About to create:' -ForegroundColor White
    Write-Host "    Name:        $name"
    Write-Host "    Parent:      $parent"
    Write-Host "    Group:       $group"
    if ($description) { Write-Host "    Description: $description" }

    $command = "New-SpoContentType -Name '$name' -Parent '$parent' -Group '$group'"
    if ($description) { $command += " -Description '$description'" }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action '  Create it?')) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
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
        Write-Host "  Created '$name'." -ForegroundColor Green
        Write-Hint 'Add columns to it with option 4.'
    }
    catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CreateField {
    Write-Title 'Create a site column'

    $displayName = Read-Choice -Prompt '  Display name'
    if (-not $displayName) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Hint 'Types: Text, Note, Number, Currency, DateTime, Boolean, Choice,'
    Write-Hint '       MultiChoice, User, UserMulti, URL, Integer'
    $type = Read-Choice -Prompt '  Type' -Default 'Text'

    $choices = $null
    if ($type -in 'Choice', 'MultiChoice') {
        Write-Host ''
        Write-Hint 'Enter the options, separated by commas.'
        $raw = Read-Choice -Prompt '  Options'
        $choices = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        if ($choices.Count -eq 0) {
            Write-Host "  A $type column needs at least one option. Cancelled." -ForegroundColor Yellow
            return
        }
    }

    $group = Read-Choice -Prompt '  Group' -Default 'Custom Columns'

    Write-Host ''
    Write-Hint 'Internal name is permanent and must be unique. Leave blank to derive it.'
    $internalName = Read-Choice -Prompt '  Internal name (optional)'

    $required = Confirm-Action '  Required?'

    $derivedName = if ($internalName) { $internalName } else { ($displayName -replace '[^A-Za-z0-9]', '') }

    Write-Host ''
    Write-Host '  About to create:' -ForegroundColor White
    Write-Host "    Display name:  $displayName"
    Write-Host "    Internal name: $derivedName"
    Write-Host "    Type:          $type"
    Write-Host "    Group:         $group"
    Write-Host "    Required:      $(if ($required) { 'yes' } else { 'no' })"
    if ($choices) { Write-Host "    Options:       $($choices -join ', ')" }

    $command = "New-SpoField -DisplayName '$displayName' -Type $type -Group '$group'"
    if ($internalName) { $command += " -InternalName '$internalName'" }
    if ($choices) { $command += " -Choice $(($choices | ForEach-Object { "'$_'" }) -join ', ')" }
    if ($required) { $command += ' -Required' }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action '  Create it?')) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
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
        Write-Host "  Created column '$displayName'." -ForegroundColor Green
        Write-Hint 'Attach it to a content type with option 4.'
        return $derivedName
    }
    catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-AddColumns {
    $contentType = Get-ContentTypeChoice -Title 'Add columns to which content type?'
    if (-not $contentType) { return }

    $detail = Show-ContentTypeDetail -ContentType $contentType

    if ($detail.Sealed) {
        Write-Host ''
        Write-Host '  This content type is sealed and cannot be modified.' -ForegroundColor Red
        return
    }

    Write-Host ''
    Write-Host '  [1] Pick from existing site columns' -ForegroundColor White
    Write-Host '  [2] Create a new column and add it' -ForegroundColor White
    Write-Host '  [B] Back'
    $mode = Read-Choice -Prompt '  >'

    $fieldNames = @()

    if ($mode -eq '2') {
        $created = Invoke-CreateField
        if (-not $created) { return }
        $fieldNames = @($created)
    }
    elseif ($mode -eq '1') {
        Write-Host '  Loading site columns...' -ForegroundColor DarkGray

        $present = @($detail.Fields | ForEach-Object { $_.InternalName })
        $available = @(Get-SpoField | Where-Object { $_.InternalName -notin $present } | Sort-Object Group, DisplayName)

        if ($available.Count -eq 0) {
            Write-Host '  Every site column is already on this content type.' -ForegroundColor Yellow
            return
        }

        $selected = Select-Item -Item $available -Multiple -Title "Which columns? ($($available.Count) available)" -Label {
            param($f) '{0,-30} {1,-28} {2,-12} {3}' -f $f.InternalName, $f.DisplayName, $f.Type, $f.Group
        }

        if (-not $selected) { return }
        $fieldNames = @($selected | ForEach-Object { $_.InternalName })
    }
    else {
        return
    }

    Write-Host ''
    Write-Hint 'Existing lists using this content type hold independent copies.'
    Write-Hint 'Updating them keeps everything in step; skipping causes drift.'
    $updateChildren = Confirm-Action '  Update existing list copies too?'

    Write-Host ''
    Write-Host '  About to add to ' -NoNewline -ForegroundColor White
    Write-Host "$($detail.Name)" -ForegroundColor Cyan -NoNewline
    Write-Host ':' -ForegroundColor White
    foreach ($name in $fieldNames) {
        Write-Host "    + $name"
    }
    Write-Host "  Update list copies: $(if ($updateChildren) { 'yes' } else { 'no' })"

    $command = "Add-SpoFieldToContentType -ContentType '$($detail.Name)' -Field $(($fieldNames | ForEach-Object { "'$_'" }) -join ', ')"
    if ($updateChildren) { $command += ' -UpdateChildren' }
    Write-Equivalent $command

    Write-Host ''
    if (-not (Confirm-Action '  Apply?')) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
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
    $contentType = Get-ContentTypeChoice -Title 'Remove columns from which content type?'
    if (-not $contentType) { return }

    $detail = Show-ContentTypeDetail -ContentType $contentType

    if ($detail.Sealed) {
        Write-Host ''
        Write-Host '  This content type is sealed and cannot be modified.' -ForegroundColor Red
        return
    }

    $removable = @($detail.Fields | Where-Object { -not $_.ReadOnly } | Sort-Object InternalName)

    if ($removable.Count -eq 0) {
        Write-Host '  No removable columns.' -ForegroundColor Yellow
        return
    }

    $selected = Select-Item -Item $removable -Multiple -Title 'Which columns to remove?' -Label {
        param($f) '{0,-30} {1,-28} {2}' -f $f.InternalName, $f.DisplayName, $f.Type
    }

    if (-not $selected) { return }

    Write-Host ''
    Write-Host '  WARNING' -ForegroundColor Red
    Write-Hint 'The site column and its stored data are not deleted, but the column'
    Write-Hint 'stops appearing on forms and views for this content type. Users'
    Write-Hint 'experience that as data loss.'
    Write-Host ''
    Write-Host "  About to remove from $($detail.Name):" -ForegroundColor White
    foreach ($field in $selected) {
        Write-Host "    - $($field.InternalName)  ($($field.DisplayName))" -ForegroundColor Yellow
    }

    $names = ($selected | ForEach-Object { "'$($_.InternalName)'" }) -join ', '
    Write-Equivalent "Find-SpoContentTypeByColumn -ColumnName $names | Remove-SpoFieldFromContentType"

    Write-Host ''
    $typed = Read-Choice -Prompt "  Type the content type name ('$($detail.Name)') to confirm"

    if ($typed -ne $detail.Name) {
        Write-Host '  Did not match. Cancelled.' -ForegroundColor Yellow
        return
    }

    foreach ($field in $selected) {
        try {
            Remove-SpoFieldFromContentType -ContentTypeId $detail.Id `
                -ContentTypeName $detail.Name `
                -FieldInternalName $field.InternalName `
                -Confirm:$false
            Write-Host "    $($field.InternalName): removed" -ForegroundColor Green
        }
        catch {
            Write-Host "    $($field.InternalName): failed -- $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

$connection = Get-O365Connection -ErrorAction SilentlyContinue

if (-not $connection -or -not $connection.IsLive) {
    Write-Host 'Connecting...' -ForegroundColor DarkGray
    if ($ProfileName) {
        Connect-O365 -ProfileName $ProfileName
    }
    else {
        Connect-O365
    }
    $connection = Get-O365Connection
}

while ($true) {
    Write-Title 'Content type manager'
    Write-Host "  Site: $($connection.SiteUrl)" -ForegroundColor DarkGray
    if ($Group) {
        Write-Host "  Group filter: $Group" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  [1] List content types'
    Write-Host '  [2] Inspect a content type'
    Write-Host '  [3] Create a content type'
    Write-Host '  [4] Add columns to a content type'
    Write-Host '  [5] Remove columns from a content type'
    Write-Host '  [6] Create a site column'
    Write-Host '  [Q] Quit'
    Write-Host ''

    $choice = Read-Choice -Prompt '  >'

    switch ($choice) {
        '1' { Invoke-ListContentTypes }
        '2' { Invoke-InspectContentType }
        '3' { Invoke-CreateContentType }
        '4' { Invoke-AddColumns }
        '5' { Invoke-RemoveColumns }
        '6' { Invoke-CreateField | Out-Null }
        { $_ -match '^(q|quit|exit)$' } {
            Write-Host ''
            Write-Host '  Bye.' -ForegroundColor DarkGray
            return
        }
        default {
            Write-Host '  Not an option.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Read-Host '  Press Enter to continue' | Out-Null
}
