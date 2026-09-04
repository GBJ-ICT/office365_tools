<#
.SYNOPSIS
    Checks that every value in a set of rows actually appears in a PDF.
.DESCRIPTION
    Answers the question a printed list raises and never settles by itself:
    is all of it on there? Not 'did the file get written', not 'does it look
    about the right length' -- is this specific value, from this specific row
    and column, present in the finished document.

    It reads the text back out of the PDF and looks for each rendered cell in
    it. Comparison is deliberately forgiving about shape and unforgiving about
    substance: a value that wrapped across two lines, hyphenated, or was drawn
    with a ligature still counts as present, but a value that was clipped by a
    column boundary, dropped by a page break, or silently truncated does not.

    Two matches are distinguished. A value found in the text with its spacing
    intact is present. A value found only after all whitespace is removed from
    both sides was printed, but broken across lines -- which a wrapping layout
    does routinely, so those are counted in one Info finding rather than
    reported one by one. -ReportWrapped lists them, which is worth doing when
    the column is a reference number someone will retype.

    The attestation line the exporter prints at the end of the document is
    checked too. It carries the row count and a digest of the data, so finding
    it proves the PDF runs to the end of the data rather than stopping at a
    page boundary -- the failure a page count cannot see.

    When the PDF's text cannot be read at all -- an encrypted file, or fonts
    with no /ToUnicode map -- this reports that as a warning and stops. It
    does not report 'no differences found', because it did not look.

    Read-only. It changes nothing and needs no connection: the PDF and the
    rows are both already in hand, so a file from last month can be checked
    against a CSV of what it should have said.
.PARAMETER Path
    The PDF to check.
.PARAMETER Cell
    Pre-rendered cells: objects with Row, Column and Text. This is what
    Export-SpoListPdf passes, so the check runs against the strings that were
    printed rather than a second rendering of the same data.
.PARAMETER Row
    Source objects to check for, when the cells were not rendered here.
.PARAMETER Column
    Property names to check on each -Row object.
.PARAMETER DateFormat
    Date format used when rendering -Row values, which has to match the format
    the PDF was printed with.
.PARAMETER Attestation
    The exact attestation line expected at the end of the document.
.PARAMETER ExpectedRowCount
    Row count the document should attest to.
.PARAMETER Sample
    Check this many rows, chosen at random, instead of all of them. For a very
    long register where a full check is slower than it is worth.
.PARAMETER Link
    Links that should be clickable in the PDF, as objects with Href and,
    optionally, Row and Column. Checked against the document's link
    annotations, which the text pass cannot see: a PDF can read back perfectly
    and still have lost every link.
.PARAMETER ReportWrapped
    Report every value that was printed across a line break, instead of
    counting them in one finding.
.PARAMETER MaxFinding
    Stop reporting individual missing values after this many, and emit one
    finding saying how many more there were. A PDF that failed to render at
    all would otherwise produce a finding per cell.
.PARAMETER NoExternalReader
    Use the built-in PDF reader even if pdftotext is installed.
.OUTPUTS
    Office365Tools.Finding objects. None means every value was found.
.EXAMPLE
    Test-SpoPdfContent -Path out/duties.pdf -Row $items -Column Title, Datum, Gefaess
    Checks a PDF against the list items it was made from.
.EXAMPLE
    Import-Csv out/expected.csv | Test-SpoPdfContent -Path out/duties.pdf -Column Title, Datum |
        Export-SpoReport -Path out/verification.html
    Checks last month's PDF against a CSV of what it should contain.
.LINK
    Export-SpoListPdf
.LINK
    Export-SpoReport
#>
function Test-SpoPdfContent {
    [CmdletBinding(DefaultParameterSetName = 'Row')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Cell')]
        [AllowEmptyCollection()]
        [object[]]$Cell,

        [Parameter(Mandatory, ParameterSetName = 'Row', ValueFromPipeline)]
        [AllowNull()]
        [psobject]$Row,

        [Parameter(ParameterSetName = 'Row')]
        [string[]]$Column,

        [Parameter(ParameterSetName = 'Row')]
        [string]$DateFormat = 'yyyy-MM-dd',

        [Parameter()]
        [string]$Attestation,

        [Parameter()]
        [int]$ExpectedRowCount = -1,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Sample,

        [Parameter()]
        [object[]]$Link,

        [Parameter()]
        [switch]$ReportWrapped,

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$MaxFinding = 50,

        [Parameter()]
        [switch]$NoExternalReader
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Row' -and $null -ne $Row) {
            $collected.Add($Row)
        }
    }

    end {
        $target = if (Test-Path -LiteralPath $Path) { (Resolve-Path -LiteralPath $Path).Path } else { $Path }

        if (-not (Test-Path -LiteralPath $Path)) {
            New-SpoFinding -RuleId 'Pdf.Missing' -Severity Error -Scope Item -Target $target `
                -Message 'The PDF does not exist, so nothing about its contents can be checked.'
            return
        }

        # -------------------------------------------------------------------
        # Turn whatever was passed into one list of cells to look for.
        # -------------------------------------------------------------------
        $cells = if ($PSCmdlet.ParameterSetName -eq 'Cell') {
            @($Cell)
        }
        else {
            $rows = @($collected)
            if ($rows.Count -eq 0) {
                New-SpoFinding -RuleId 'Pdf.NothingToCheck' -Severity Warning -Scope Item -Target $target `
                    -Message 'No rows were supplied, so the PDF was not checked against anything.'
                return
            }

            $names = if ($Column) {
                $Column
            }
            else {
                @($rows[0].PSObject.Properties |
                        Where-Object { $_.Name -notlike 'PS*' } |
                        ForEach-Object { $_.Name })
            }

            $built = [System.Collections.Generic.List[object]]::new()
            for ($index = 0; $index -lt $rows.Count; $index++) {
                foreach ($name in $names) {
                    $value = if ($null -ne $rows[$index].PSObject.Properties[$name]) {
                        $rows[$index].PSObject.Properties[$name].Value
                    }
                    else {
                        $null
                    }

                    $text = ConvertTo-SpoCellText -Value $value -DateFormat $DateFormat
                    if (-not [string]::IsNullOrWhiteSpace($text)) {
                        $built.Add([pscustomobject]@{ Row = $index + 1; Column = $name; Text = $text })
                    }
                }
            }
            $built.ToArray()
        }

        if ($Sample -and $cells.Count -gt 0) {
            $rowNumbers = @($cells | ForEach-Object { $_.Row } | Sort-Object -Unique)
            if ($Sample -lt $rowNumbers.Count) {
                $keep = @($rowNumbers | Get-Random -Count $Sample)
                $cells = @($cells | Where-Object { $_.Row -in $keep })
                Write-O365Log "Checking a sample of $Sample row(s) out of $($rowNumbers.Count)." 'Info'
            }
        }

        # -------------------------------------------------------------------
        # Read the document back.
        # -------------------------------------------------------------------
        $read = ConvertFrom-SpoPdfText -Path $Path -NoExternal:$NoExternalReader

        if ($read.Source -eq 'none') {
            New-SpoFinding -RuleId 'Pdf.NotAPdf' -Severity Error -Scope Item -Target $target `
                -Message 'The file is not a PDF, so the export did not produce what it reported.' `
                -Detail @{ Note = $read.Note }
            return
        }

        if ($read.PageCount -le 0) {
            New-SpoFinding -RuleId 'Pdf.NoPages' -Severity Error -Scope Item -Target $target `
                -Message 'The PDF contains no pages.'
            return
        }

        if (-not $read.Complete) {
            New-SpoFinding -RuleId 'Pdf.NoTextLayer' -Severity Warning -Scope Item -Target $target `
                -Message 'No text could be read from the PDF, so its contents were not verified. The file itself may still be correct.' `
                -Detail @{ Reader = $read.Source; PageCount = $read.PageCount; Note = $read.Note }
            return
        }

        $collapsed = ConvertTo-SpoSearchText -Text $read.Text -KeepSpace
        $stripped = ConvertTo-SpoSearchText -Text $read.Text

        # -------------------------------------------------------------------
        # The end of the document, which is what proves it is all there.
        # -------------------------------------------------------------------
        if ($Attestation) {
            $expected = ConvertTo-SpoSearchText -Text $Attestation
            if (-not $stripped.Contains($expected)) {
                New-SpoFinding -RuleId 'Pdf.TruncatedDocument' -Severity Error -Scope Item -Target $target `
                    -Message 'The closing attestation line is not in the PDF, so the document does not run to the end of the data.' `
                    -Detail @{ Expected = $Attestation; PageCount = $read.PageCount }
            }
        }

        if ($ExpectedRowCount -ge 0) {
            $stated = [regex]::Match($stripped, 'rows(\d+)/columns')
            if ($stated.Success -and [int]$stated.Groups[1].Value -ne $ExpectedRowCount) {
                New-SpoFinding -RuleId 'Pdf.RowCountMismatch' -Severity Error -Scope Item -Target $target `
                    -Message "The PDF attests to $($stated.Groups[1].Value) row(s) but $ExpectedRowCount were exported." `
                    -Detail @{ InDocument = [int]$stated.Groups[1].Value; Expected = $ExpectedRowCount }
            }
        }

        # -------------------------------------------------------------------
        # Every value. Identical values are looked for once and reported for
        # each row that holds one.
        # -------------------------------------------------------------------
        $missing = [System.Collections.Generic.List[object]]::new()
        $wrapped = [System.Collections.Generic.List[object]]::new()
        $checked = 0

        foreach ($group in ($cells | Group-Object { ConvertTo-SpoSearchText -Text $_.Text -KeepSpace })) {
            $needle = $group.Name
            if ([string]::IsNullOrEmpty($needle)) { continue }

            $checked += $group.Count

            $found = if ($needle.Length -lt 4) {
                # A short value has to match on its own. Otherwise 'Mai' is
                # 'present' because some other row says 'Maier'.
                [regex]::IsMatch($collapsed, '(?<![\p{L}\p{N}])' + [regex]::Escape($needle) + '(?![\p{L}\p{N}])')
            }
            else {
                $collapsed.Contains($needle)
            }

            if ($found) { continue }

            $loose = ConvertTo-SpoSearchText -Text $group.Group[0].Text
            if ($loose -and $stripped.Contains($loose)) {
                foreach ($item in $group.Group) { $wrapped.Add($item) }
                continue
            }

            foreach ($item in $group.Group) { $missing.Add($item) }
        }

        # A miss rate this high is not a list with a few dropped values; it is
        # a reader that could not follow the file's font encoding. Say so,
        # rather than let the caller act on hundreds of false alarms.
        $suspect = $checked -gt 0 -and ($missing.Count / [double]$checked) -gt 0.4

        if ($suspect) {
            New-SpoFinding -RuleId 'Pdf.ExtractionSuspect' -Severity Warning -Scope Item -Target $target `
                -Message "$($missing.Count) of $checked values were not found, which usually means the PDF's text could not be read correctly rather than that the values are absent. Open the PDF, or install pdftotext, before acting on the findings below." `
                -Detail @{ Reader = $read.Source; Missing = $missing.Count; Checked = $checked }
        }

        $reported = 0
        foreach ($item in $missing) {
            if ($reported -ge $MaxFinding) { break }
            $reported++

            New-SpoFinding -RuleId 'Pdf.MissingValue' -Severity Error -Scope Item -Target $target `
                -Message "Row $($item.Row), column '$($item.Column)': the printed value is not in the PDF." `
                -Detail @{ Row = $item.Row; Column = $item.Column; Value = $item.Text }
        }

        if ($missing.Count -gt $reported) {
            New-SpoFinding -RuleId 'Pdf.MoreMissingValues' -Severity Error -Scope Item -Target $target `
                -Message "$($missing.Count - $reported) further value(s) were also missing and are not listed individually." `
                -Detail @{ Total = $missing.Count; Listed = $reported }
        }

        if ($wrapped.Count -gt 0) {
            if ($ReportWrapped) {
                foreach ($item in ($wrapped | Select-Object -First $MaxFinding)) {
                    New-SpoFinding -RuleId 'Pdf.WrappedValue' -Severity Info -Scope Item -Target $target `
                        -Message "Row $($item.Row), column '$($item.Column)': printed, but broken across lines." `
                        -Detail @{ Row = $item.Row; Column = $item.Column; Value = $item.Text }
                }
            }
            else {
                # Wrapping is what this layout does instead of clipping, so a
                # finding per wrapped cell would bury the ones that matter.
                New-SpoFinding -RuleId 'Pdf.WrappedValues' -Severity Info -Scope Item -Target $target `
                    -Message "$($wrapped.Count) of $checked value(s) were printed across a line break and were matched with spacing ignored. Pass -ReportWrapped to list them." `
                    -Detail @{ Wrapped = $wrapped.Count; Checked = $checked }
            }
        }

        # -------------------------------------------------------------------
        # Links, which the text pass cannot see: a clickable link is an
        # annotation over a rectangle, not a string in the content stream. A
        # PDF can therefore read perfectly and still have lost every link.
        # -------------------------------------------------------------------
        $missingLinks = 0
        if ($Link -and @($Link).Count -gt 0) {
            $expected = @($Link | Where-Object { $_ -and $_.PSObject.Properties['Href'] -and $_.Href })
            $actual = @(Get-SpoPdfLink -Path $Path)

            # Compared case-insensitively and without a trailing slash: a
            # producer may normalise either, and neither changes where the
            # link goes.
            $normalise = { param([string]$Uri) $Uri.Trim().TrimEnd('/').ToLowerInvariant() }
            $present = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]@($actual | ForEach-Object { & $normalise $_ }),
                [System.StringComparer]::Ordinal
            )

            $absent = @($expected | Where-Object { -not $present.Contains((& $normalise $_.Href)) })
            $missingLinks = $absent.Count

            $listed = 0
            foreach ($item in $absent) {
                if ($listed -ge $MaxFinding) { break }
                $listed++

                $where = if ($item.PSObject.Properties['Row'] -and $item.PSObject.Properties['Column']) {
                    "Row $($item.Row), column '$($item.Column)'"
                }
                else {
                    'A link'
                }

                $detail = @{ Href = $item.Href }
                if ($item.PSObject.Properties['Row']) { $detail['Row'] = $item.Row }
                if ($item.PSObject.Properties['Column']) { $detail['Column'] = $item.Column }

                New-SpoFinding -RuleId 'Pdf.MissingLink' -Severity Error -Scope Item -Target $target `
                    -Message "$($where): the cell was printed but carries no clickable link in the PDF." `
                    -Detail $detail
            }

            if ($absent.Count -gt $listed) {
                New-SpoFinding -RuleId 'Pdf.MoreMissingLinks' -Severity Error -Scope Item -Target $target `
                    -Message "$($absent.Count - $listed) further link(s) were also missing and are not listed individually." `
                    -Detail @{ Total = $absent.Count; Listed = $listed }
            }

            if ($actual.Count -eq 0 -and $expected.Count -gt 0) {
                New-SpoFinding -RuleId 'Pdf.NoLinks' -Severity Error -Scope Item -Target $target `
                    -Message "$($expected.Count) link(s) were rendered but the PDF carries no link annotations at all. The browser printed the text without the links." `
                    -Detail @{ Expected = $expected.Count }
            }
        }

        Write-O365Log (
            "Checked $checked value(s) against '$target': $($missing.Count) missing, $($wrapped.Count) wrapped" +
            $(if ($Link -and @($Link).Count -gt 0) { ", $missingLinks link(s) missing." } else { '.' })
        ) $(if ($missing.Count -gt 0 -or $missingLinks -gt 0) { 'Warning' } else { 'Success' })
    }
}
