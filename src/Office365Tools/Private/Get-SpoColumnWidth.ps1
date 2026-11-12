<#
.SYNOPSIS
    Internal: works out a width for each printed column from what it holds.
.DESCRIPTION
    Left to itself the browser sizes a table column by the shortest it can get
    away with, so a long text column ends up a narrow strip next to wide
    columns that hold a number: one row fills a page, and the page count says
    nothing about how much there is to read.

    This sizes the columns before they are printed:

      * A column whose longest line is short (45 characters or fewer) -- a
        number, a date, a status, a name -- gets the width of that line, and no
        more than 70 mm. When there is room it also gets the width of its
        longest heading word, so headings are not broken in the middle of a
        word; when there is not, the text columns come first and a heading may
        wrap.
      * The other columns share what is left of the printable width, the more
        text a column holds the more it gets (by the square root of its average
        length, so a paragraph does not take the page from a short remark),
        each at least 25 mm and at most 60 % of the printable width.
      * A width the caller gave explicitly is left alone and is taken off
        what is shared.

    The widths are a hint: the table still grows a column rather than clip its
    text. The estimate of a character's width is the font size, so it is a
    little generous for narrow letters and a little short for capitals; what
    matters is that the proportions are right.

    The text columns are given at least half the printable width between them
    when the short columns can do with the rest, and the short columns then wrap
    their lines (never their words) to make room: the height of a row is the
    height of its longest text, so that is where width pays.

    With -Measure it does not return widths but how much room the columns need
    at the least, so the caller can lower the font size until they fit.
.PARAMETER Record
    One dictionary per row, column name to the text printed there.
.PARAMETER Column
    The printed columns, in order.
.PARAMETER Header
    Column name to heading text.
.PARAMETER Fixed
    Column name to a width the caller chose, as given to -ColumnWidth.
.PARAMETER PaperSize
    A3, A4, A5, Letter or Legal.
.PARAMETER Orientation
    Portrait or Landscape.
.PARAMETER Margin
    Page margin as a CSS length.
.PARAMETER FontSize
    Body font size in points.
.PARAMETER RowNumber
    Whether a number column (8 mm) is printed before the others.
.PARAMETER Measure
    Return Required and Printable (both in mm) instead of the widths. Required
    is what the columns need at the least: each short column at the width of its
    longest word, each text column at its minimum.
.OUTPUTS
    Hashtable: column name to a width such as '24.5mm'. Columns in -Fixed are
    not in it. With -Measure, an object with Required and Printable.
.EXAMPLE
    Get-SpoColumnWidth -Record $text -Column Nr, Beschreibung -FontSize 8.5
#>
function Get-SpoColumnWidth {
    [CmdletBinding()]
    [OutputType([hashtable], [pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Record,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Column,

        [Parameter()]
        [hashtable]$Header = @{},

        [Parameter()]
        [hashtable]$Fixed = @{},

        [Parameter()]
        [ValidateSet('A3', 'A4', 'A5', 'Letter', 'Legal')]
        [string]$PaperSize = 'A4',

        [Parameter()]
        [ValidateSet('Portrait', 'Landscape')]
        [string]$Orientation = 'Landscape',

        [Parameter()]
        [ValidatePattern('^\d+(\.\d+)?(mm|cm|in|pt|px)$')]
        [string]$Margin = '12mm',

        [Parameter()]
        [ValidateRange(4.0, 24.0)]
        [double]$FontSize = 8.5,

        [Parameter()]
        [switch]$RowNumber,

        [Parameter()]
        [switch]$Measure
    )

    $shortestLimit = 45      # characters: a longer line makes a text column
    $shortCap = 70.0         # mm
    $shortFloor = 10.0       # mm: the least a short column is given
    $textMin = 25.0          # mm
    $textMaxShare = 0.6      # of the printable width
    $padding = 3.4           # mm: cell padding and border

    $sheet = switch ($PaperSize) {
        'A3' { @(297.0, 420.0) }
        'A4' { @(210.0, 297.0) }
        'A5' { @(148.0, 210.0) }
        'Letter' { @(215.9, 279.4) }
        'Legal' { @(215.9, 355.6) }
    }
    $pageWidth = if ($Orientation -eq 'Landscape') { $sheet[1] } else { $sheet[0] }

    $unit = @{ 'mm' = 1.0; 'cm' = 10.0; 'in' = 25.4; 'pt' = 25.4 / 72.0; 'px' = 25.4 / 96.0 }
    $marginParts = [regex]::Match($Margin, '^(?<n>\d+(\.\d+)?)(?<u>mm|cm|in|pt|px)$')
    $marginMm = [double]::Parse($marginParts.Groups['n'].Value, [cultureinfo]::InvariantCulture) * $unit[$marginParts.Groups['u'].Value]

    $printable = $pageWidth - 2 * $marginMm
    if ($RowNumber) { $printable -= 8.0 }

    $charMm = $FontSize * 0.5 * 25.4 / 72.0
    # Headings are set a little smaller than the text and in bold, which is wider.
    $headCharMm = $charMm * 0.9 * 1.15

    $short = [ordered]@{}     # column -> @{ Content; Floor }
    $weight = @{}
    $takenFixed = 0.0

    foreach ($name in $Column) {
        if ($Fixed.ContainsKey($name)) {
            $given = [string]$Fixed[$name]
            if ($given -match '^\s*(?<n>\d+(\.\d+)?)\s*%$') {
                $takenFixed += $printable * [double]::Parse($Matches['n'], [cultureinfo]::InvariantCulture) / 100.0
            }
            elseif ($given -match '^\s*(?<n>\d+(\.\d+)?)\s*(?<u>mm|cm|in|pt|px)$') {
                $takenFixed += [double]::Parse($Matches['n'], [cultureinfo]::InvariantCulture) * $unit[$Matches['u']]
            }
            continue
        }

        $longestLine = 0
        $longestToken = 0
        $total = 0
        $filled = 0

        foreach ($row in $Record) {
            $value = if ($row.Contains($name)) { [string]$row[$name] } else { '' }
            if ([string]::IsNullOrWhiteSpace($value)) { continue }

            $filled++
            $total += $value.Length
            foreach ($line in ($value -split "`r?`n")) {
                if ($line.Length -gt $longestLine) { $longestLine = $line.Length }
            }
            # The longest single word: a column can wrap between words, but a
            # date or a name broken in the middle is not readable.
            foreach ($token in ($value -split '\s+')) {
                if ($token.Length -gt $longestToken) { $longestToken = $token.Length }
            }
        }

        $caption = if ($Header.ContainsKey($name)) { [string]$Header[$name] } else { $name }
        $longestWord = 0
        foreach ($word in ($caption -split '\s+')) {
            if ($word.Length -gt $longestWord) { $longestWord = $word.Length }
        }

        if ($longestLine -le $shortestLimit) {
            $content = [Math]::Min($shortCap, [Math]::Max($longestLine * $charMm + $padding, $shortFloor))
            $floor = [Math]::Min($shortCap, [Math]::Max($content, $longestWord * $headCharMm + $padding))
            $least = [Math]::Min($content, [Math]::Max($longestToken * $charMm + $padding, 8.0))
            $short[$name] = @{ Content = $content; Floor = $floor; Least = $least }
        }
        else {
            # How much a column has to say: the square root of the average length
            # of what it holds, so a long text gets more room without a paragraph
            # taking the whole page from a short remark.
            $weight[$name] = [Math]::Sqrt([double]$total / [Math]::Max(1, $filled))
        }
    }

    # What the text columns must have, and what they are given when the others
    # can spare it: at least half the page between them, because they are what
    # is being read and the height of a row is their height.
    $textReserve = $weight.Count * $textMin
    $textPreferred = if ($weight.Count -gt 0) { [Math]::Max($textReserve, 0.5 * $printable) } else { 0.0 }

    $contentTotal = 0.0
    $floorTotal = 0.0
    $leastTotal = 0.0
    foreach ($entry in $short.Values) {
        $contentTotal += $entry.Content
        $floorTotal += $entry.Floor
        $leastTotal += $entry.Least
    }

    if ($Measure) {
        return [pscustomobject]@{ Required = $leastTotal + $textReserve + $takenFixed; Printable = $printable }
    }

    # The room the short columns may use: what the text columns are not given.
    # When even their narrowest do not fit in that, they take what they need
    # and the text columns give up what they were preferred, down to their
    # minimum at the most.
    $roomPreferred = $printable - $takenFixed - $textPreferred
    $roomMost = $printable - $takenFixed - $textReserve
    $room = [Math]::Min($roomMost, [Math]::Max($roomPreferred, $leastTotal))

    $result = @{}
    if ($short.Count -gt 0) {
        if ($floorTotal -le $room) {
            # Everything fits, headings included.
            foreach ($name in $short.Keys) { $result[$name] = $short[$name].Floor }
        }
        elseif ($contentTotal -le $room) {
            # The content fits but the headings do not all: hand the spare room
            # to the columns whose heading is longest, in proportion to what each
            # lacks, so the least heading breaking in the middle of a word.
            $spare = $room - $contentTotal
            $lack = $floorTotal - $contentTotal
            foreach ($name in $short.Keys) {
                $want = $short[$name].Floor - $short[$name].Content
                $result[$name] = $short[$name].Content + $(if ($lack -gt 0) { $spare * $want / $lack } else { 0 })
            }
        }
        elseif ($leastTotal -le $room) {
            # The content does not fit but the narrowest does: each column
            # between the two, in proportion to how much it can give up. Words
            # stay whole; it is lines that wrap.
            $spare = $room - $leastTotal
            $give = $contentTotal - $leastTotal
            foreach ($name in $short.Keys) {
                $want = $short[$name].Content - $short[$name].Least
                $result[$name] = $short[$name].Least + $(if ($give -gt 0) { $spare * $want / $give } else { 0 })
            }
        }
        else {
            # Not even the narrowest fit at this size, which the caller meets by
            # lowering the type: share what there is and let words break.
            $scale = [Math]::Max($room, 8.0 * $short.Count) / $leastTotal
            foreach ($name in $short.Keys) { $result[$name] = [Math]::Max(8.0, $short[$name].Least * $scale) }
        }
    }

    if ($weight.Count -gt 0) {
        $used = 0.0
        foreach ($width in $result.Values) { $used += $width }
        $remaining = [Math]::Max($printable - $used - $takenFixed, $textReserve)
        $maximum = $textMaxShare * $printable

        # A column pinned to a limit gives its surplus, or takes its shortfall,
        # from the others; a few passes settle it.
        $open = [System.Collections.Generic.List[string]]::new()
        foreach ($name in $weight.Keys) { $open.Add($name) }
        $settled = @{}

        for ($pass = 0; $pass -lt 4 -and $open.Count -gt 0; $pass++) {
            $share = $remaining - (($settled.Values | Measure-Object -Sum).Sum)
            if ($null -eq $share) { $share = $remaining }
            $totalWeight = 0.0
            foreach ($name in $open) { $totalWeight += $weight[$name] }

            $pinned = $false
            foreach ($name in @($open)) {
                $proposal = $share * $weight[$name] / $totalWeight

                if ($proposal -lt $textMin) {
                    $settled[$name] = $textMin
                    [void]$open.Remove($name)
                    $pinned = $true
                }
                elseif ($proposal -gt $maximum) {
                    $settled[$name] = $maximum
                    [void]$open.Remove($name)
                    $pinned = $true
                }
            }

            if (-not $pinned) {
                foreach ($name in $open) { $settled[$name] = $share * $weight[$name] / $totalWeight }
                $open.Clear()
            }
        }

        foreach ($name in $open) { $settled[$name] = $textMin }
        foreach ($name in $settled.Keys) { $result[$name] = $settled[$name] }
    }

    $formatted = @{}
    foreach ($name in $result.Keys) {
        $formatted[$name] = [string]::Format([cultureinfo]::InvariantCulture, '{0:0.#}mm', $result[$name])
    }

    return $formatted
}
