<#
.SYNOPSIS
    Creates a run of list items on a recurring date -- every second Sunday, the
    Sundays of odd weeks, the first of each month -- with the same column values
    on each.
.DESCRIPTION
    For a list whose rows are a calendar: one entry per service, per duty, per
    shift. The entries are created empty on purpose. Scheduling them is the part
    a script does well; deciding who is doing what is the part it does not, and
    that is what the list is for once the rows exist.

    It runs in two passes, and the plan in between is the point rather than a
    formality:

        ./scripts/New-ListItemDateSeries.ps1 -Start 2026-09-06 -Until 2026-12-31 `
            -DayOfWeek Sunday -Interval 2                            # plan
        ./scripts/New-ListItemDateSeries.ps1 -Plan <path> -WhatIf    # preview
        ./scripts/New-ListItemDateSeries.ps1 -Plan <path>            # write

    The plan is a CSV, one row per date, and editing it is the intended
    workflow. Any column whose name does not start with an underscore is written
    to the list, so:

      - change a date, and that entry moves;
      - delete a row, and that entry is not created;
      - add a column to the CSV, and it is written to every row that has a
        value for it;
      - leave a cell empty, and that column is left unset rather than blanked;
      - rename a column with a leading underscore, and it stops being written
        without being deleted.

    The underscore-prefixed columns -- _Occurrence, _DayOfWeek, _IsoWeek -- are
    there to make the plan readable while you check it. They are never sent.

    COLUMN NAMES

    Columns may be named the way they read on the list. 'Gefäss', 'Inhalt &
    Bemerkungen' and 'Stellvertretung' all work, and so do the internal names
    behind them -- Gef_x00e4_ss, Bemerkungen, Pikett. This holds for -DateField,
    for the keys of -Default, for -DuplicateKey, and for the column headers of a
    plan CSV.

    The translation happens in the second pass, against the list itself, because
    that is the first moment there is a connection to ask. A misspelled column
    therefore surfaces when the plan is written rather than when it is drawn up,
    and the error names every column the list has. Where a display name is
    shared by two columns -- SharePoint permits it -- the internal name is the
    only way to say which one is meant, and the error says so.

    NOT CREATING THE SAME ENTRY TWICE

    Before writing, the entries already on the list are read, and a plan row is
    skipped when its -DuplicateKey values are all present on one of them. The
    default key is the date column plus 'Bezeichnung' and 'Gefäss': a duty
    roster holds several entries per day, one per duty per vessel, and those
    three together are what makes one of them distinct.

    Any of the three that the list does not have is dropped from the key with a
    note, so the default is also serviceable on a list with a single entry per
    day. Pass -DuplicateKey explicitly for anything else -- including
    -DuplicateKey Bezeichnung, Gefäss with no date at all, which creates each
    combination once and never again.

    A key column the plan carries no value for is worth knowing about, and the
    script warns: an empty cell only ever matches an entry that is empty there
    too, so the check quietly stops catching anything.

    Dates are compared as local dates. SharePoint returns them in UTC, so a
    midnight entry read back from a site in a different timezone than this
    machine can land on the previous day.
.PARAMETER List
    Title or URL name of the list.
.PARAMETER DateField
    The date column the schedule is written to. Display name or internal name.
.PARAMETER Start
    First date the series can fall on, and the anchor for -Interval.
.PARAMETER Until
    Last date the series can fall on, inclusive.
.PARAMETER Count
    Create this many entries instead of stopping at a date.
.PARAMETER Frequency
    Daily, Weekly, Monthly or Yearly.
.PARAMETER Interval
    Every Nth day, week, month or year, counting from -Start.
.PARAMETER DayOfWeek
    Weekdays the series falls on.
.PARAMETER WeekParity
    Restrict to odd or even ISO 8601 calendar weeks.
.PARAMETER WeekOfMonth
    First, Second, Third, Fourth or Last such weekday of the month.
.PARAMETER DayOfMonth
    Day number for a monthly or yearly series.
.PARAMETER ExcludeDate
    Dates to leave out: holidays, a week away, anything already scheduled.
.PARAMETER TimeOfDay
    Time of day to stamp on each entry. Midnight if omitted.
.PARAMETER Default
    Column name to the value every entry gets. Display names and internal names
    are both accepted. These become columns in the plan, so any one of them can
    be overridden per row.

    Either a hashtable or a JSON object -- -Default '{"Status":"terminiert"}'.
    The JSON form exists because `pwsh ./scripts/New-ListItemDateSeries.ps1 ...`
    runs under -File semantics, where every argument arrives as a string and a
    hashtable literal does not survive the trip. From a PowerShell prompt, a
    hashtable is fine.
.PARAMETER TitleTemplate
    Format string for the Title column, given the date -- for example
    'Gottesdienst {0:dd.MM.yyyy}'. Title is left empty if omitted.
.PARAMETER ContentType
    Content type to create the entries as.
.PARAMETER DuplicateKey
    Columns identifying an entry for the purpose of not creating it twice.
    Display names and internal names are both accepted.

    Defaults to -DateField plus 'Bezeichnung' and 'Gefäss', minus whichever of
    those the list does not have.
.PARAMETER AllowDuplicate
    Create every planned row, even one the list already has.
.PARAMETER Plan
    A plan CSV from an earlier run. Given, its rows are written to the list.
    Omitted, a plan is generated and nothing is written.
.PARAMETER ProfileName
    Connection profile. Omit to use the default profile.
.PARAMETER Interactive
    Force a browser sign-in rather than relying on a cached token. Worth
    reaching for first when a connection hangs instead of failing.
.PARAMETER OutputPath
    Directory for the plan and log. Defaults to out/item-series-<timestamp>.
.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -List test_tasks_and_services -DateField Datum `
        -Start 2026-09-06 -Until 2026-12-31 -DayOfWeek Sunday -Interval 2 `
        -Default @{ Status = '📆 terminiert'; Art = 'Protagonist' }
    Plans an entry every second Sunday to the end of the year. Writes nothing.
    'Art' is the display name of the Bezeichnung column, and either will do.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -Plan out/item-series-20260813_120000/plan.csv -WhatIf
    Previews the writes for a plan, after you have edited it.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -Plan out/item-series-20260813_120000/plan.csv `
        -ProfileName TestCds -Interactive
    Writes it. -Interactive is what this tenant needs; without it the sign-in
    hangs rather than failing.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -List test_tasks_and_services -DateField Datum `
        -Start 2026-09-06 -Until 2027-06-30 -DayOfWeek Sunday -WeekParity Odd `
        -ExcludeDate 2026-12-27 -Default @{ Status = '📆 terminiert' }
    Sundays of odd calendar weeks, skipping the one after Christmas.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -DateField Datum -Start 2026-09-06 -Count 12 `
        -DayOfWeek Sunday -Default @{ 'Gefäss' = "G'V."; Art = 'Küche' }
    Twelve Sundays from the sixth, rather than an end date. The display names
    'Gefäss' and 'Art' are resolved against the list when the plan is written.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -DateField Datum -Start 2026-09-01 -Until 2027-08-31 `
        -Frequency Monthly -DayOfWeek Sunday -WeekOfMonth First `
        -Default @{ 'Gefäss' = "F'H." }
    The first Sunday of every month for a year.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -DateField Datum -Start 2026-09-15 -Until 2027-03-15 `
        -Frequency Monthly -DayOfMonth 15 -TimeOfDay 19:30
    The fifteenth of each month at half past seven.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -DateField Datum -Start 2026-09-06 -Until 2026-12-31 `
        -DayOfWeek Sunday -TitleTemplate 'Gottesdienst {0:dd.MM.yyyy}'
    Gives each entry a title built from its own date.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -Plan out/plan.csv -DuplicateKey Datum, Art, 'Gefäss'
    The default key, spelled out with display names. An entry is a duplicate
    only when the day, the duty and the vessel all match.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -Plan out/plan.csv -DuplicateKey Bezeichnung, 'Gefäss'
    Every combination of duty and vessel is created once, whatever its date --
    the literal reading of "skip it if Bezeichnung and Gefäss already exist".
    Useful for seeding a list, not for extending a roster.

.EXAMPLE
    ./scripts/New-ListItemDateSeries.ps1 -Plan out/plan.csv -AllowDuplicate
    Writes every row without reading the list first. The escape hatch for a
    roster that deliberately repeats.
.LINK
    Get-SpoRecurringDate
.LINK
    Add-SpoListItem
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Until')]
param(
    [Parameter()]
    [string]$List = 'test_tasks_and_services',

    [Parameter()]
    [string]$DateField = 'Datum',

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [datetime]$Start = (Get-Date).Date,

    [Parameter(ParameterSetName = 'Until')]
    [datetime]$Until,

    [Parameter(Mandatory, ParameterSetName = 'Count')]
    [ValidateRange(1, 1000)]
    [int]$Count,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [ValidateSet('Daily', 'Weekly', 'Monthly', 'Yearly')]
    [string]$Frequency = 'Weekly',

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [ValidateRange(1, 60)]
    [int]$Interval = 1,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [System.DayOfWeek[]]$DayOfWeek,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [ValidateSet('Any', 'Odd', 'Even')]
    [string]$WeekParity = 'Any',

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [ValidateSet('Any', 'First', 'Second', 'Third', 'Fourth', 'Last')]
    [string]$WeekOfMonth = 'Any',

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [ValidateRange(1, 31)]
    [int]$DayOfMonth,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [datetime[]]$ExcludeDate,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [timespan]$TimeOfDay,

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [object]$Default = @{},

    [Parameter(ParameterSetName = 'Until')]
    [Parameter(ParameterSetName = 'Count')]
    [string]$TitleTemplate,

    [Parameter(Mandatory, ParameterSetName = 'Plan')]
    [ValidateNotNullOrEmpty()]
    [string]$Plan,

    [Parameter()]
    [string]$ContentType,

    [Parameter()]
    [string[]]$DuplicateKey,

    [Parameter()]
    [switch]$AllowDuplicate,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'Office365Tools') -Force

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot '..' 'out' "item-series-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
# -WhatIf:$false, because this directory holds the plan and the log rather than
# anything on the tenant. Left to inherit, -WhatIf would decline to create it
# and the Resolve-Path below would fail before the preview ever ran.
$null = New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false
$OutputPath = (Resolve-Path $OutputPath).Path

# The default key is the date plus the two columns that tell one of a day's
# entries from another. Whether it was defaulted matters later: a column the
# caller named and the list does not have is a mistake worth stopping for,
# while one this script guessed at is not.
$keyWasDefaulted = -not $PSBoundParameters.ContainsKey('DuplicateKey')
if (-not $DuplicateKey) { $DuplicateKey = @($DateField, 'Bezeichnung', 'Gefäss') }

# -Default arrives as a hashtable from a PowerShell prompt and as a string from
# `pwsh script.ps1 -Default ...`, which is -File semantics and stringifies every
# argument. Accepting JSON is what makes the documented command line work.
$defaultValue = @{}
if ($Default -is [hashtable]) {
    $defaultValue = $Default
}
elseif ($Default -is [System.Collections.IDictionary]) {
    foreach ($entry in $Default.GetEnumerator()) { $defaultValue[$entry.Key] = $entry.Value }
}
elseif ($Default -is [string] -and -not [string]::IsNullOrWhiteSpace($Default)) {
    try {
        $parsed = $Default | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        throw ("-Default could not be read as JSON: $($_.Exception.Message) " +
            'From a shell, pass it as JSON: -Default ''{"Status":"terminiert"}''. ' +
            'From a PowerShell prompt, a hashtable works: -Default @{ Status = ''terminiert'' }')
    }

    if ($parsed -isnot [System.Collections.IDictionary]) {
        throw '-Default must be a JSON object, for example: -Default ''{"Status":"terminiert"}'''
    }

    foreach ($entry in $parsed.GetEnumerator()) { $defaultValue[$entry.Key] = $entry.Value }
}
elseif ($null -ne $Default -and $Default -isnot [string]) {
    throw "-Default must be a hashtable or a JSON object, not $($Default.GetType().Name)."
}

# Column names carrying context for the reader rather than values for the list.
$annotationPrefix = '_'

Start-O365Log -Path (Join-Path $OutputPath 'series.log') | Out-Null

try {
    # -------------------------------------------------------------------------
    # Pass one: work out the dates and write a plan. Nothing is created here,
    # and this pass needs no connection at all -- Get-SpoRecurringDate is
    # arithmetic, so a schedule can be checked before a tenant is involved.
    #
    # Column names are carried through as written. There is nothing here to
    # check them against; that happens in pass two.
    # -------------------------------------------------------------------------
    if ($PSCmdlet.ParameterSetName -ne 'Plan') {

        $recurrence = @{
            Start      = $Start
            Frequency  = $Frequency
            Interval   = $Interval
            WeekParity = $WeekParity
        }
        if ($PSCmdlet.ParameterSetName -eq 'Count') { $recurrence['Count'] = $Count }
        else {
            if (-not $PSBoundParameters.ContainsKey('Until')) {
                throw "Give the series an end: either -Until <date> or -Count <n>."
            }
            $recurrence['Until'] = $Until
        }
        if ($PSBoundParameters.ContainsKey('DayOfWeek')) { $recurrence['DayOfWeek'] = $DayOfWeek }
        if ($WeekOfMonth -ne 'Any') { $recurrence['WeekOfMonth'] = $WeekOfMonth }
        if ($PSBoundParameters.ContainsKey('DayOfMonth')) { $recurrence['DayOfMonth'] = $DayOfMonth }
        if ($PSBoundParameters.ContainsKey('ExcludeDate')) { $recurrence['ExcludeDate'] = $ExcludeDate }
        if ($PSBoundParameters.ContainsKey('TimeOfDay')) { $recurrence['TimeOfDay'] = $TimeOfDay }

        $dates = @(Get-SpoRecurringDate @recurrence)

        if ($dates.Count -eq 0) {
            Write-Warning 'That recurrence matches no dates. Nothing to plan.'
            return
        }

        $rows = foreach ($occurrence in $dates) {
            $row = [ordered]@{
                "${annotationPrefix}Occurrence" = $occurrence.Occurrence
                "${annotationPrefix}DayOfWeek"  = $occurrence.DayOfWeek
                "${annotationPrefix}IsoWeek"    = '{0}-KW{1:d2}' -f $occurrence.IsoYear, $occurrence.IsoWeek
                $DateField                      = $occurrence.Date.ToString('yyyy-MM-dd HH:mm')
            }

            if ($TitleTemplate) {
                $row['Title'] = [string]::Format($TitleTemplate, $occurrence.Date)
            }

            foreach ($key in ($defaultValue.Keys | Sort-Object)) {
                $row[$key] = $defaultValue[$key]
            }

            [pscustomobject]$row
        }

        $planPath = Join-Path $OutputPath 'plan.csv'

        # With a BOM, because the headers are the list's own column names and
        # those are German here. Excel reads a BOM-less UTF-8 CSV as the system
        # codepage and turns 'Gefäss' into a header that matches nothing.
        $rows | Export-Csv -Path $planPath -NoTypeInformation -Encoding utf8BOM

        $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

        Write-Host "Planned $($dates.Count) entry(s) for '$List'." -ForegroundColor Cyan
        Write-Host "Plan: $planPath" -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Read it, edit it, then write it:' -ForegroundColor Yellow
        Write-Host "  ./scripts/New-ListItemDateSeries.ps1 -List '$List' -DateField '$DateField' -Plan '$planPath' -WhatIf"
        Write-Host "  ./scripts/New-ListItemDateSeries.ps1 -List '$List' -DateField '$DateField' -Plan '$planPath'"
        return
    }

    # -------------------------------------------------------------------------
    # Pass two: write the plan.
    # -------------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $Plan)) {
        throw "Plan file '$Plan' was not found."
    }

    $planRows = @(Import-Csv -LiteralPath $Plan -Encoding utf8BOM)

    if ($planRows.Count -eq 0) {
        Write-Warning "Plan '$Plan' has no rows."
        return
    }

    $valueColumn = @($planRows[0].PSObject.Properties.Name |
            Where-Object { -not $_.StartsWith($annotationPrefix) })

    if ($ProfileName) {
        Connect-O365 -ProfileName $ProfileName -Interactive:$Interactive
    }
    else {
        Connect-O365 -Interactive:$Interactive
    }

    # -------------------------------------------------------------------------
    # Column names, as the list spells them.
    #
    # Everything downstream -- the values hashtable, the duplicate key, the
    # lookup into FieldValues -- needs internal names, and the internal name of
    # a German column is something like Gef_x00e4_ss, which nobody should have
    # to type. So both spellings are accepted and translated here, at the first
    # point where there is a list to ask.
    # -------------------------------------------------------------------------
    Write-Host "Reading the columns of '$List' ..." -ForegroundColor Cyan

    # Resolved to a list object first, and by URL name as well as by title.
    # Get-PnPList -Identity matches the title and the GUID but not the folder
    # name a list URL is built from, so 'test_tasks_and_services' -- which is
    # what the address bar shows -- comes back as "does not exist at site",
    # reading like the wrong site rather than the wrong spelling.
    #
    # RootFolder.Name is not populated by a plain Get-PnPList; ServerRelativeUrl
    # is, so the folder name comes from its last segment.
    $urlNameOf = { param($SpoList) ($SpoList.RootFolder.ServerRelativeUrl -split '/')[-1] }

    $targetList = Get-PnPList -Identity $List -ErrorAction SilentlyContinue
    if (-not $targetList) {
        $targetList = @(Get-PnPList | Where-Object { (& $urlNameOf $_) -eq $List })[0]
    }
    if (-not $targetList) {
        $visible = @(Get-PnPList | Where-Object { -not $_.Hidden } |
                ForEach-Object { "$($_.Title) [$(& $urlNameOf $_)]" } | Sort-Object)
        throw "List '$List' was not found. This site has: $($visible -join '; ')"
    }

    $listField = @(Get-PnPField -List $targetList)

    $internalName = @{}     # internal name -> itself, for the identity case
    $titleToName = @{}      # display name  -> every internal name using it

    foreach ($field in $listField) {
        $internalName[$field.InternalName] = $field.InternalName

        if (-not $titleToName.ContainsKey($field.Title)) { $titleToName[$field.Title] = @() }
        $titleToName[$field.Title] = @($titleToName[$field.Title]) + $field.InternalName
    }

    $writable = @($listField |
            Where-Object { -not $_.ReadOnlyField -and -not $_.Hidden } |
            ForEach-Object { "$($_.Title) [$($_.InternalName)]" } |
            Sort-Object)

    # Returns the internal name, or $null when the list has no such column.
    # Whether that is fatal depends on who asked, so it is not decided here.
    $resolveColumn = {
        param([string]$Name)

        $wanted = ([string]$Name).Trim()

        if ($internalName.ContainsKey($wanted)) { return $internalName[$wanted] }

        if ($titleToName.ContainsKey($wanted)) {
            $candidate = @($titleToName[$wanted])
            if ($candidate.Count -eq 1) { return $candidate[0] }

            # SharePoint allows two columns to share a display name. When they
            # do, the display name is not an answer to which one is meant.
            throw ("'$wanted' is the display name of more than one column on '$List': " +
                "$($candidate -join ', '). Name it by its internal name instead.")
        }

        return $null
    }

    $dateColumn = & $resolveColumn $DateField
    if (-not $dateColumn) {
        throw ("-DateField '$DateField' matches no column on '$List'. " +
            "Its columns are: $($writable -join '; ')")
    }

    $columnOf = @{}     # plan header -> internal name
    foreach ($header in $valueColumn) {
        $resolved = & $resolveColumn $header
        if (-not $resolved) {
            throw ("The plan column '$header' matches no column on '$List'. " +
                "Its columns are: $($writable -join '; '). " +
                "Display names and internal names are both accepted; to keep a " +
                "column in the plan without writing it, rename it with a leading underscore.")
        }
        $columnOf[$header] = $resolved
    }

    if ($dateColumn -notin $columnOf.Values) {
        throw ("The plan has no '$DateField' column. Its value columns are: $($valueColumn -join ', '). " +
            "Pass -DateField with the name the plan actually uses.")
    }

    $duplicateColumn = @()
    foreach ($keyName in $DuplicateKey) {
        $resolved = & $resolveColumn $keyName

        if (-not $resolved) {
            if ($keyWasDefaulted) {
                Write-Host "  '$keyName' is not a column here; leaving it out of the duplicate check." -ForegroundColor DarkGray
                continue
            }
            throw ("-DuplicateKey names '$keyName', which matches no column on '$List'. " +
                "Its columns are: $($writable -join '; ')")
        }

        if ($resolved -notin $duplicateColumn) { $duplicateColumn += $resolved }
    }

    if (-not $AllowDuplicate -and $duplicateColumn.Count -eq 0) {
        throw "None of the -DuplicateKey columns exist on '$List'. Pass -AllowDuplicate to write without the check."
    }

    if (-not $AllowDuplicate) {
        Write-Host "  duplicate check: $($duplicateColumn -join ' + ')" -ForegroundColor DarkGray

        $keyNotPlanned = @($duplicateColumn | Where-Object { $_ -notin $columnOf.Values })
        if ($keyNotPlanned.Count -gt 0) {
            Write-Warning ("The duplicate check uses $($keyNotPlanned -join ', '), which the plan has no column for. " +
                'A plan row is empty there, so it can only match an entry that is empty there too -- ' +
                'in practice nothing will be recognised as a duplicate.')
        }
    }

    # A date read back from SharePoint is UTC; a date typed into the plan is
    # local. Both are reduced to a local calendar day before they are compared,
    # because that is the granularity the duplicate check is about.
    $asKeyText = {
        param($Value, [string]$Column)

        if ($null -eq $Value) { return '' }

        if ($Value -is [datetime]) {
            $local = if ($Value.Kind -eq [System.DateTimeKind]::Utc) { $Value.ToLocalTime() } else { $Value }
            return $local.ToString('yyyy-MM-dd')
        }

        $text = [string]$Value

        # Parsed as a date only for the date column. TryParse is looser than it
        # looks -- it reads a bare "5" as the fifth of the current month -- so
        # letting it near a choice or a number would turn 'Gefäss 5' into a
        # date and stop it matching the same value read back from the list.
        if ($Column -eq $dateColumn) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse($text, [cultureinfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed.ToString('yyyy-MM-dd')
            }
        }

        return $text.Trim()
    }

    $existingKeys = @{}
    if (-not $AllowDuplicate) {
        Write-Host "Reading existing entries from '$List' ..." -ForegroundColor Cyan

        foreach ($item in (Get-PnPListItem -List $targetList -PageSize 500)) {
            $parts = foreach ($column in $duplicateColumn) {
                & $asKeyText $item.FieldValues[$column] $column
            }
            $existingKeys[($parts -join '||')] = $true
        }

        Write-Host "  $($existingKeys.Count) existing entry key(s)." -ForegroundColor DarkGray
    }

    $created = 0
    $skipped = 0

    foreach ($row in $planRows) {
        $values = @{}

        foreach ($header in $valueColumn) {
            $raw = $row.$header
            $column = $columnOf[$header]

            if ($null -eq $raw -or [string]::IsNullOrWhiteSpace([string]$raw)) { continue }

            if ($column -eq $dateColumn) {
                $parsed = [datetime]::MinValue
                if (-not [datetime]::TryParse([string]$raw, [cultureinfo]::InvariantCulture,
                        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                    Write-Warning "Row '$raw' is not a date this can read; skipping it."
                    $skipped++
                    $values = $null
                    break
                }
                $values[$column] = $parsed
            }
            else {
                $values[$column] = $raw
            }
        }

        if ($null -eq $values -or $values.Count -eq 0) { continue }

        # The label names the entry the way the duplicate check sees it, so a
        # skip and the reason for it read as one line.
        $label = ([datetime]$values[$dateColumn]).ToString('yyyy-MM-dd')
        $detail = @(foreach ($column in $duplicateColumn) {
                if ($column -ne $dateColumn -and $values.ContainsKey($column)) { [string]$values[$column] }
            })
        if ($detail.Count -gt 0) { $label = "$label  $($detail -join ' / ')" }

        if (-not $AllowDuplicate) {
            $parts = foreach ($column in $duplicateColumn) {
                if ($values.ContainsKey($column)) { & $asKeyText $values[$column] $column } else { '' }
            }
            $key = $parts -join '||'

            if ($existingKeys.ContainsKey($key)) {
                Write-Host "  skip $label -- already on the list" -ForegroundColor DarkGray
                $skipped++
                continue
            }

            # Registered now so a plan holding the same key twice does not
            # create it twice either.
            $existingKeys[$key] = $true
        }

        # WhatIf travels in the splat rather than through a ShouldProcess gate
        # here. Both would be wrong together: the gate would return false under
        # -WhatIf, Add-SpoListItem would never be reached, and the count below
        # would report that a preview was going to create nothing.
        # By title, not by whatever -List was spelled as: Add-SpoListItem
        # resolves its own list, and the title is the spelling that always works.
        $addParams = @{
            Library = $targetList.Title
            Values  = $values
            WhatIf  = $WhatIfPreference
        }
        if ($ContentType) { $addParams['ContentType'] = $ContentType }

        Add-SpoListItem @addParams
        $created++

        if (-not $WhatIfPreference) {
            Write-Host "  created $label" -ForegroundColor Green
        }
    }

    Write-Host ''
    if ($WhatIfPreference) {
        Write-Host "Would create $created entry(s); $skipped skipped." -ForegroundColor Yellow
    }
    else {
        Write-Host "Created $created entry(s); $skipped skipped." -ForegroundColor Green
    }
    Write-Host "Log: $OutputPath"
}
finally {
    Stop-O365Log | Out-Null
}
