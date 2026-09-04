<#
.SYNOPSIS
    Internal: normalises text so a value read out of a PDF can be compared
    with the value that was printed into it.
.DESCRIPTION
    A PDF does not store the text you gave it. It stores glyphs and positions,
    and reversing that loses things a plain -match would trip over:

      * Line breaks. A cell that wrapped comes back as two runs with nothing
        between them, so 'Inhalt & Bemerkungen' may read as 'Inhalt &Bemerkungen'.
      * Ligatures. A subset font maps 'fi' to one glyph; the reverse mapping
        gives back U+FB01, not 'f' followed by 'i'. FormKC undoes that.
      * Non-breaking and narrow spaces, soft hyphens, zero-width joiners --
        SharePoint text is full of them and none of them survive as themselves.
      * Typographic dashes and quotes, which the browser's font substitution
        may render from a different code point than the one in the source.

    So both sides are folded to the same shape before comparing. -KeepSpace
    collapses runs of whitespace to one space, which keeps word boundaries and
    is the strict comparison; without it every space is removed, which is the
    loose one used to tell 'genuinely absent' from 'printed, but wrapped'.
.PARAMETER Text
    The text to fold.
.PARAMETER KeepSpace
    Collapse whitespace instead of removing it.
.OUTPUTS
    System.String, lower-cased.
.EXAMPLE
    ConvertTo-SpoSearchText -Text "Inhalt  &`nBemerkungen" -KeepSpace
    Returns 'inhalt & bemerkungen'.
#>
function ConvertTo-SpoSearchText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Text,

        [Parameter()]
        [switch]$KeepSpace
    )

    if ([string]::IsNullOrEmpty($Text)) { return '' }

    $folded = $Text

    # Characters that carry no meaning for a comparison and are not reliably
    # reproduced by either renderer or extractor.
    foreach ($invisible in "`u{00AD}", "`u{200B}", "`u{200C}", "`u{200D}", "`u{FEFF}") {
        $folded = $folded.Replace($invisible, '')
    }

    foreach ($space in "`u{00A0}", "`u{2007}", "`u{202F}", "`u{2009}") {
        $folded = $folded.Replace($space, ' ')
    }

    foreach ($dash in "`u{2010}", "`u{2011}", "`u{2012}", "`u{2013}", "`u{2014}", "`u{2212}") {
        $folded = $folded.Replace($dash, '-')
    }

    foreach ($quote in "`u{2018}", "`u{2019}", "`u{201A}", "`u{2032}") {
        $folded = $folded.Replace($quote, "'")
    }

    foreach ($quote in "`u{201C}", "`u{201D}", "`u{201E}", "`u{2033}") {
        $folded = $folded.Replace($quote, '"')
    }

    $folded = $folded.Replace("`u{2026}", '...')

    # Compatibility composition, which is what turns the single ligature glyph
    # a subset font uses back into the letters it stands for.
    $folded = $folded.Normalize([System.Text.NormalizationForm]::FormKC)

    $folded = if ($KeepSpace) {
        ([regex]::Replace($folded, '\s+', ' ')).Trim()
    }
    else {
        [regex]::Replace($folded, '\s+', '')
    }

    return $folded.ToLowerInvariant()
}
