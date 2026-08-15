<#
.SYNOPSIS
    Generates the dates of a recurring series.
.DESCRIPTION
    Answers "every second Sunday from September to Christmas" and its relatives,
    so that scheduling a series of list items is date arithmetic done once here
    rather than by hand in every script that needs it.

    Nothing about this command touches SharePoint. It needs no connection and no
    network, which is what makes a schedule something you can check before you
    create eighty list items from it.

    Two ways of saying "every other week", and they are not the same:

      -Interval 2     Relative. Counts from -Start: the week -Start falls in,
                      then every second week after it. Move -Start by a week and
                      the whole series shifts.
      -WeekParity Odd Absolute. Keyed to the ISO 8601 week number, so it means
                      the odd calendar weeks -- KW 37, 39, 41 -- whatever
                      -Start happens to be. This is the one people mean when
                      they say "odd weeks", because it agrees with the calendar
                      on the wall and with everyone else's.

    Both are filters and both may be given, but they are not two spellings of
    one idea and combining them rarely does what it looks like. -Interval counts
    weeks from -Start; -WeekParity reads the number off the calendar. The two
    agree within a year and part company across a 53-week one, so their
    intersection thins the series out unevenly. Pick one.

    ISO week numbering puts Sunday at the *end* of its week, not the start. A
    Sunday therefore belongs to the week that began the preceding Monday, which
    is what German KW numbering means and what a service on Sunday of KW 37
    refers to.
.PARAMETER Start
    First date the series can fall on. Also the anchor for -Interval, and the
    day of the month for a monthly or yearly series that names no other.
.PARAMETER Until
    Last date the series can fall on, inclusive.
.PARAMETER Count
    Stop after this many dates instead of at a fixed end.
.PARAMETER Frequency
    Daily, Weekly, Monthly or Yearly. Weekly by default.
.PARAMETER Interval
    Emit every Nth day, week, month or year, counting from -Start.
.PARAMETER DayOfWeek
    Restrict to these weekdays. More than one is allowed.
.PARAMETER WeekParity
    Restrict to odd or even ISO 8601 week numbers.
.PARAMETER WeekOfMonth
    Restrict to the first, second, third, fourth or last such weekday in the
    month -- "first Sunday". Requires -DayOfWeek.
.PARAMETER DayOfMonth
    Restrict to this day number. Clamped to the length of short months, so 31
    still lands on the 28th of February rather than skipping it.
.PARAMETER ExcludeDate
    Dates to leave out: holidays, a week off, anything already scheduled.
.PARAMETER TimeOfDay
    Time to stamp on each date. Midnight if omitted.
.OUTPUTS
    Office365Tools.RecurringDate objects, one per occurrence.
.EXAMPLE
    Get-SpoRecurringDate -Start 2026-09-06 -Until 2026-12-31 -DayOfWeek Sunday -Interval 2
    Every second Sunday, counting from 6 September.

.EXAMPLE
    Get-SpoRecurringDate -Start 2026-09-01 -Until 2027-06-30 -DayOfWeek Sunday -WeekParity Odd
    Sundays in odd calendar weeks.

.EXAMPLE
    Get-SpoRecurringDate -Start 2026-09-01 -Count 12 -Frequency Monthly `
        -DayOfWeek Sunday -WeekOfMonth First -TimeOfDay 09:30
    The first Sunday of each of the next twelve months, at half past nine.

.EXAMPLE
    Get-SpoRecurringDate -Start 2026-09-06 -Until 2026-12-31 -DayOfWeek Sunday `
        -ExcludeDate 2026-12-27 | Select-Object -ExpandProperty Date
    Weekly, minus the Sunday between Christmas and New Year.
.LINK
    Add-SpoListItem
#>
function Get-SpoRecurringDate {
    [CmdletBinding(DefaultParameterSetName = 'Until')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [datetime]$Start,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Until')]
        [datetime]$Until,

        [Parameter(Mandatory, ParameterSetName = 'Count')]
        [ValidateRange(1, 1000)]
        [int]$Count,

        [Parameter()]
        [ValidateSet('Daily', 'Weekly', 'Monthly', 'Yearly')]
        [string]$Frequency = 'Weekly',

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$Interval = 1,

        [Parameter()]
        [System.DayOfWeek[]]$DayOfWeek,

        [Parameter()]
        [ValidateSet('Any', 'Odd', 'Even')]
        [string]$WeekParity = 'Any',

        [Parameter()]
        [ValidateSet('Any', 'First', 'Second', 'Third', 'Fourth', 'Last')]
        [string]$WeekOfMonth = 'Any',

        [Parameter()]
        [ValidateRange(1, 31)]
        [int]$DayOfMonth,

        [Parameter()]
        [datetime[]]$ExcludeDate,

        [Parameter()]
        [timespan]$TimeOfDay
    )

    # Not `if ($DayOfWeek)`. [DayOfWeek]::Sunday is 0, and PowerShell unwraps a
    # one-element array to its element before testing it for truth -- so the
    # single most likely value anyone passes here is the one that would read as
    # "no weekday given".
    #
    # The type constraint on the variable is what keeps .Count answerable: an
    # untyped $weekday would be the bare enum after one value, and $null rather
    # than an empty array after none.
    [System.DayOfWeek[]]$weekday = @()
    if ($PSBoundParameters.ContainsKey('DayOfWeek')) { $weekday = $DayOfWeek }

    if ($WeekOfMonth -ne 'Any' -and $weekday.Count -eq 0) {
        throw [System.ArgumentException]::new(
            "-WeekOfMonth needs a weekday to count: 'first' what? " +
            "Add -DayOfWeek, for example: -WeekOfMonth First -DayOfWeek Sunday"
        )
    }

    if ($PSCmdlet.ParameterSetName -eq 'Until' -and $Until.Date -lt $Start.Date) {
        throw [System.ArgumentException]::new(
            "-Until ($($Until.ToString('yyyy-MM-dd'))) is before -Start ($($Start.ToString('yyyy-MM-dd')))."
        )
    }

    $startDate  = $Start.Date
    $hasDayOfMonth = $PSBoundParameters.ContainsKey('DayOfMonth')

    # 1 January 2001 was a Monday, which makes it a usable origin for a
    # monotonic week counter. Comparing week *indices* rather than week numbers
    # keeps -Interval working across a year boundary, where ISO numbering
    # restarts at 1 and a naive difference goes negative.
    $epochMonday = [datetime]::new(2001, 1, 1)

    $mondayOf = {
        param([datetime]$Date)
        $Date.Date.AddDays( - ((([int]$Date.DayOfWeek + 6) % 7)))
    }

    $weekIndexOf = {
        param([datetime]$Date)
        [int][math]::Floor(((& $mondayOf $Date) - $epochMonday).TotalDays / 7)
    }

    $anchorWeek  = & $weekIndexOf $startDate
    $anchorMonth = ($startDate.Year * 12) + $startDate.Month

    $excluded = @{}
    foreach ($date in $ExcludeDate) { $excluded[$date.Date] = $true }

    # A month-length-aware day number: asking for the 31st of a 30-day month
    # means its last day, not "no occurrence this month".
    $clampedDay = {
        param([int]$Day, [datetime]$InMonth)
        [math]::Min($Day, [datetime]::DaysInMonth($InMonth.Year, $InMonth.Month))
    }

    if ($PSCmdlet.ParameterSetName -eq 'Until') {
        $lastDate = $Until.Date
        $wanted   = [int]::MaxValue
    }
    else {
        # Count has no natural end date, so the walk needs one anyway. Twenty
        # years is past any plausible schedule and keeps a filter that matches
        # nothing from looping forever.
        $lastDate = $startDate.AddYears(20)
        $wanted   = $Count
    }

    $occurrence = 0
    $cursor     = $startDate

    while ($cursor -le $lastDate -and $occurrence -lt $wanted) {
        $current = $cursor
        $cursor  = $cursor.AddDays(1)

        if ($weekday.Count -gt 0 -and $current.DayOfWeek -notin $weekday) { continue }
        if ($excluded.ContainsKey($current)) { continue }

        $isoWeek = [System.Globalization.ISOWeek]::GetWeekOfYear($current)

        if ($WeekParity -ne 'Any') {
            $parity = if ($isoWeek % 2 -eq 1) { 'Odd' } else { 'Even' }
            if ($parity -ne $WeekParity) { continue }
        }

        if ($WeekOfMonth -ne 'Any') {
            $matchesPosition = if ($WeekOfMonth -eq 'Last') {
                $current.AddDays(7).Month -ne $current.Month
            }
            else {
                $position = [int][math]::Floor(($current.Day - 1) / 7) + 1
                $position -eq @{ First = 1; Second = 2; Third = 3; Fourth = 4 }[$WeekOfMonth]
            }
            if (-not $matchesPosition) { continue }
        }

        # An if-chain rather than a switch, deliberately. `continue` inside a
        # PowerShell switch advances the *switch*, not the enclosing loop, so
        # every rejection here would fall through to the emit below.
        if ($Frequency -eq 'Daily') {
            $inPhase = ((($current - $startDate).Days % $Interval) -eq 0)
        }
        elseif ($Frequency -eq 'Weekly') {
            $inPhase = (((((& $weekIndexOf $current)) - $anchorWeek) % $Interval) -eq 0)
        }
        else {
            if ($Frequency -eq 'Monthly') {
                $monthIndex = ($current.Year * 12) + $current.Month
                $inPhase    = ((($monthIndex - $anchorMonth) % $Interval) -eq 0)
            }
            else {
                $sameMonth = $current.Month -eq $startDate.Month
                $inPhase   = ((($current.Year - $startDate.Year) % $Interval) -eq 0) -and $sameMonth
            }

            # Which day *within* the month, once the month itself qualifies.
            # Given neither a day number nor a weekday, a monthly series repeats
            # the day -Start fell on.
            if ($inPhase) {
                if ($hasDayOfMonth) {
                    $inPhase = $current.Day -eq (& $clampedDay $DayOfMonth $current)
                }
                elseif ($weekday.Count -eq 0 -and $WeekOfMonth -eq 'Any') {
                    $inPhase = $current.Day -eq (& $clampedDay $startDate.Day $current)
                }
            }
        }

        if (-not $inPhase) { continue }

        $occurrence++

        $stamped = if ($PSBoundParameters.ContainsKey('TimeOfDay')) {
            $current.Add($TimeOfDay)
        }
        else {
            $current
        }

        [pscustomobject]@{
            PSTypeName = 'Office365Tools.RecurringDate'
            Occurrence = $occurrence
            Date       = $stamped
            DayOfWeek  = $current.DayOfWeek
            IsoYear    = [System.Globalization.ISOWeek]::GetYear($current)
            IsoWeek    = $isoWeek
            WeekParity = if ($isoWeek % 2 -eq 1) { 'Odd' } else { 'Even' }
        }
    }
}
