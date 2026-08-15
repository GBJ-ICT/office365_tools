<#
    Get-SpoRecurringDate is pure date arithmetic, so all of it is testable
    without a tenant -- which is the point of keeping it out of the script that
    creates the items.

    The dates below are real calendar facts, not fixtures: September 2026 starts
    on a Tuesday, its Sundays are the 6th, 13th, 20th and 27th, and ISO week 37
    of 2026 runs Monday 7 September to Sunday 13 September.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    # $result.Date.ToString('yyyy-MM-dd') looks like it should work and does
    # not: member enumeration over a collection cannot pass an argument, so
    # the format string has nowhere to go.
    function Format-Day {
        param($Occurrence)
        @($Occurrence) | ForEach-Object { $_.Date.ToString('yyyy-MM-dd') }
    }
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SpoRecurringDate' {

    Context 'weekly' {

        It 'returns every Sunday in the range' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-30' -DayOfWeek Sunday

            (Format-Day $result) | Should -Be @(
                '2026-09-06', '2026-09-13', '2026-09-20', '2026-09-27')
        }

        It 'skips a week when -Interval is 2, anchored on -Start' {
            $result = Get-SpoRecurringDate -Start '2026-09-06' -Until '2026-10-31' -DayOfWeek Sunday -Interval 2

            (Format-Day $result) | Should -Be @(
                '2026-09-06', '2026-09-20', '2026-10-04', '2026-10-18')
        }

        It 'shifts the whole series when -Start moves a week, because -Interval is relative' {
            $result = Get-SpoRecurringDate -Start '2026-09-13' -Until '2026-10-31' -DayOfWeek Sunday -Interval 2

            (Format-Day $result) | Should -Be @(
                '2026-09-13', '2026-09-27', '2026-10-11', '2026-10-25')
        }

        It 'keeps its stride across the new year, where ISO week numbers restart' {
            $result = Get-SpoRecurringDate -Start '2026-12-20' -Until '2027-01-31' -DayOfWeek Sunday -Interval 2

            $gaps = 1..($result.Count - 1) | ForEach-Object {
                ($result[$_].Date - $result[$_ - 1].Date).Days
            }
            $gaps | Should -Not -Contain 7
            $gaps | ForEach-Object { $_ | Should -Be 14 }
        }

        It 'accepts more than one weekday' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-14' -DayOfWeek Saturday, Sunday

            (Format-Day $result) | Should -Be @(
                '2026-09-05', '2026-09-06', '2026-09-12', '2026-09-13')
        }
    }

    Context 'week parity' {

        It 'returns Sundays of odd ISO weeks only' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-10-31' `
                -DayOfWeek Sunday -WeekParity Odd

            $result.IsoWeek | ForEach-Object { $_ % 2 | Should -Be 1 }
        }

        It 'returns Sundays of even ISO weeks only' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-10-31' `
                -DayOfWeek Sunday -WeekParity Even

            $result.IsoWeek | ForEach-Object { $_ % 2 | Should -Be 0 }
        }

        It 'counts a Sunday into the week that began the preceding Monday' {
            # ISO 8601 weeks start on Monday, so Sunday 13 September closes
            # week 37 rather than opening week 38.
            $result = Get-SpoRecurringDate -Start '2026-09-13' -Count 1 -DayOfWeek Sunday

            $result.IsoWeek | Should -Be 37
            $result.WeekParity | Should -Be 'Odd'
        }

        It 'partitions the Sundays: odd and even together are all of them' {
            $all  = Get-SpoRecurringDate -Start '2026-01-01' -Until '2026-12-31' -DayOfWeek Sunday
            $odd  = Get-SpoRecurringDate -Start '2026-01-01' -Until '2026-12-31' -DayOfWeek Sunday -WeekParity Odd
            $even = Get-SpoRecurringDate -Start '2026-01-01' -Until '2026-12-31' -DayOfWeek Sunday -WeekParity Even

            ($odd.Count + $even.Count) | Should -Be $all.Count
        }
    }

    Context 'monthly' {

        It 'returns the first Sunday of each month' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-12-31' `
                -Frequency Monthly -DayOfWeek Sunday -WeekOfMonth First

            (Format-Day $result) | Should -Be @(
                '2026-09-06', '2026-10-04', '2026-11-01', '2026-12-06')
        }

        It 'returns the last Sunday of each month' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-11-30' `
                -Frequency Monthly -DayOfWeek Sunday -WeekOfMonth Last

            (Format-Day $result) | Should -Be @(
                '2026-09-27', '2026-10-25', '2026-11-29')
        }

        It 'repeats the day -Start fell on when told nothing else' {
            $result = Get-SpoRecurringDate -Start '2026-09-15' -Count 3 -Frequency Monthly

            (Format-Day $result) | Should -Be @(
                '2026-09-15', '2026-10-15', '2026-11-15')
        }

        It 'clamps a day number to the length of a short month' {
            $result = Get-SpoRecurringDate -Start '2027-01-31' -Count 3 -Frequency Monthly -DayOfMonth 31

            (Format-Day $result) | Should -Be @(
                '2027-01-31', '2027-02-28', '2027-03-31')
        }

        It 'honours -Interval in months' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Count 3 -Frequency Monthly -Interval 3

            (Format-Day $result) | Should -Be @(
                '2026-09-01', '2026-12-01', '2027-03-01')
        }

        It 'rejects -WeekOfMonth without a weekday to count' {
            { Get-SpoRecurringDate -Start '2026-09-01' -Count 1 -Frequency Monthly -WeekOfMonth First } |
                Should -Throw -ExpectedMessage '*-DayOfWeek*'
        }
    }

    Context 'yearly' {

        It 'repeats the same month and day' {
            $result = Get-SpoRecurringDate -Start '2026-12-24' -Count 3 -Frequency Yearly

            (Format-Day $result) | Should -Be @(
                '2026-12-24', '2027-12-24', '2028-12-24')
        }
    }

    Context 'bounds and exclusions' {

        It 'stops after -Count occurrences' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Count 5 -DayOfWeek Sunday
            $result.Count | Should -Be 5
        }

        It 'includes -Until itself' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-06' -DayOfWeek Sunday
            (Format-Day $result) | Should -Be '2026-09-06'
        }

        It 'leaves out excluded dates' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-30' `
                -DayOfWeek Sunday -ExcludeDate '2026-09-13', '2026-09-27'

            (Format-Day $result) | Should -Be @('2026-09-06', '2026-09-20')
        }

        It 'ignores the time of day on an excluded date' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-14' `
                -DayOfWeek Sunday -ExcludeDate '2026-09-06 17:45'

            (Format-Day $result) | Should -Be '2026-09-13'
        }

        It 'numbers the occurrences from one, after exclusions' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Until '2026-09-30' `
                -DayOfWeek Sunday -ExcludeDate '2026-09-06'

            $result.Occurrence | Should -Be @(1, 2, 3)
        }

        It 'stamps -TimeOfDay onto every date' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Count 2 -DayOfWeek Sunday -TimeOfDay '09:30'

            $result.Date | ForEach-Object { $_.ToString('HH:mm') | Should -Be '09:30' }
        }

        It 'defaults to midnight' {
            $result = Get-SpoRecurringDate -Start '2026-09-01' -Count 1 -DayOfWeek Sunday
            $result.Date.TimeOfDay | Should -Be ([timespan]::Zero)
        }

        It 'returns nothing when the range holds no match' {
            $result = @(Get-SpoRecurringDate -Start '2026-09-07' -Until '2026-09-11' -DayOfWeek Sunday)
            $result.Count | Should -Be 0
        }

        It 'rejects -Until before -Start' {
            { Get-SpoRecurringDate -Start '2026-09-30' -Until '2026-09-01' } |
                Should -Throw -ExpectedMessage '*before*'
        }

        It 'terminates when -Count can never be reached' {
            # Every seventh day from a Monday is always a Monday, so asking for
            # Sundays as well can never match. A filter with no solutions must
            # still stop rather than walk forward forever.
            $result = @(Get-SpoRecurringDate -Start '2026-09-07' -Count 5 `
                    -Frequency Daily -Interval 7 -DayOfWeek Sunday)
            $result.Count | Should -Be 0
        }

        It 'treats -Interval and -WeekParity as independent partitions' {
            # -Interval counts weeks from -Start; -WeekParity reads the ISO week
            # number. Those agree within a year and drift apart across a 53-week
            # one, so the intersection is neither empty nor the whole series.
            $stride = Get-SpoRecurringDate -Start '2026-09-06' -Until '2030-12-31' `
                -DayOfWeek Sunday -Interval 2
            $both = Get-SpoRecurringDate -Start '2026-09-06' -Until '2030-12-31' `
                -DayOfWeek Sunday -Interval 2 -WeekParity Odd

            $both.Count | Should -BeGreaterThan 0
            $both.Count | Should -BeLessThan $stride.Count
        }
    }
}
