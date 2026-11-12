<#
.SYNOPSIS
    Internal: tells whether a text that runs over a page break is all in a
    document, in pieces.
.DESCRIPTION
    A cell taller than a page continues on the next one. Read back from the PDF
    the two halves are not next to each other: between them come the rest of
    the first page, the heading row that repeats at the top of the next, and
    the other cells of the row. So the whole text is not there as one run, and
    looking for it as one run reports a value that is in fact all there.

    This looks for it in pieces instead. It takes the longest run of characters
    from the start of the text that is in the document, then the longest from
    where that stopped, and so on. The text is all there when it was covered to
    the end and the number of pieces is no more than there are pages -- a cell
    can break once at each page boundary, no more.

    Both texts are folded with all whitespace removed. A narrow column breaks
    words in the middle, and what a PDF reader returns for that has a space in
    the middle of the word; with the spaces gone the break does not matter.

    That tolerance has to be small to be worth anything: a stretch of text that
    went missing from the middle of a cell would also cut it into two pieces. So
    a piece in the middle has to be at least 20 characters long and the last one
    10: a printed line of a cell holds more than that, and what a rendering
    loses is a word or a line, which leaves a piece too short to count.
.PARAMETER Needle
    The text, folded by ConvertTo-SpoSearchText without -KeepSpace.
.PARAMETER Haystack
    The text of the document, folded the same way.
.PARAMETER MaxPart
    The most pieces that count as a page break: the page count of the document.
.OUTPUTS
    System.Boolean
.EXAMPLE
    Test-SpoSplitText -Needle 'abcdefghijklmnopqrstuvwxyz' -Haystack 'abcdefghijklmnopqrst--page--uvwxyz!' -MaxPart 2
#>
function Test-SpoSplitText {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Needle,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Haystack,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxPart
    )

    $middleMinimum = 20
    $lastMinimum = 10

    # Too short to cut into pieces that mean anything.
    if ($Needle.Length -lt ($middleMinimum + $lastMinimum)) { return $false }

    $at = 0
    $parts = 0

    while ($at -lt $Needle.Length) {
        # The longest run from here that is in the document. A run that is in
        # it has all its shorter beginnings in it too, which is what lets this
        # be searched by halving.
        $low = 0
        $high = $Needle.Length - $at

        while ($low -lt $high) {
            $middle = [int][Math]::Ceiling(($low + $high) / 2)
            if ($Haystack.Contains($Needle.Substring($at, $middle))) {
                $low = $middle
            }
            else {
                $high = $middle - 1
            }
        }

        $isLast = ($at + $low) -ge $Needle.Length
        $minimum = if ($isLast) { $lastMinimum } else { $middleMinimum }

        if ($low -lt $minimum) { return $false }

        $parts++
        if ($parts -gt $MaxPart) { return $false }

        $at += $low
    }

    return $true
}
