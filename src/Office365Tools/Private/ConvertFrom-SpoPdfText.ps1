<#
.SYNOPSIS
    Internal: reads the text back out of a PDF, so an export can be checked
    against the data it was made from.
.DESCRIPTION
    Verification is the whole point of this file. Anyone can write a PDF; the
    question that matters is whether every row and every column actually
    landed on a page, and the only way to answer it is to read the finished
    file rather than the intention behind it.

    A PDF stores glyphs and positions, not text. Getting characters back means
    inflating the page's content stream, then mapping the codes it draws
    through the font's /ToUnicode CMap -- a browser embeds subset fonts where
    code 3 is whatever letter happened to be third. That is what this does,
    per page and per font, with no dependency beyond .NET.

    If 'pdftotext' (poppler, or the Xpdf tools) is on PATH it is used instead,
    because it is a far more complete implementation of the same idea. The
    built-in reader is the fallback, not the preferred path.

    It is asked for -raw, which is content stream order -- the order the
    browser drew the cells in -- and not -layout, which sorts glyphs by
    position to rebuild the visual grid. That distinction decides whether
    verification works at all. When two cells in one row both wrap, their
    lines sit side by side on the page, so a positional reader interleaves
    them and neither value survives as one contiguous string. In drawing
    order each cell's lines stay together and both read back whole.

    What comes back always says which reader produced it and whether the read
    looked complete, because a verification that quietly reads nothing and
    reports no differences is worse than no verification at all. A caller that
    gets Complete = $false must say 'could not check', never 'checked'.
.PARAMETER Path
    The PDF to read.
.PARAMETER NoExternal
    Do not use pdftotext even if it is present. Mainly for testing the
    built-in reader.
.OUTPUTS
    PSCustomObject with Text, PageCount, Source and Complete.
.EXAMPLE
    $read = ConvertFrom-SpoPdfText -Path out/duties.pdf
    if ($read.Complete) { $read.Text -match 'Titterten' }
#>
function ConvertFrom-SpoPdfText {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$NoExternal
    )

    $full = (Resolve-Path -LiteralPath $Path).Path
    $bytes = [System.IO.File]::ReadAllBytes($full)

    if ($bytes.Length -lt 5 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 5) -ne '%PDF-') {
        return [pscustomobject]@{
            Text      = ''
            PageCount = 0
            Source    = 'none'
            Complete  = $false
            Note      = 'The file does not start with %PDF-, so it is not a PDF.'
        }
    }

    # Byte-for-char decoding. Latin1 is the only encoding where an index into
    # the string is an index into the file, which is what stream offsets are.
    $raw = [System.Text.Encoding]::Latin1.GetString($bytes)

    $pageCount = @([regex]::Matches($raw, '/Type\s*/Page\b')).Count
    if ($pageCount -eq 0) {
        $countMatch = [regex]::Match($raw, '/Type\s*/Pages\b[^>]*?/Count\s+(\d+)')
        if ($countMatch.Success) { $pageCount = [int]$countMatch.Groups[1].Value }
    }

    if (-not $NoExternal) {
        $external = Get-Command 'pdftotext' -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($external) {
            $temporary = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-pdftext-$([guid]::NewGuid()).txt"
            try {
                & $external.Source -raw -enc UTF-8 -q $full $temporary 2>$null
                if (Test-Path -LiteralPath $temporary) {
                    $extracted = Get-Content -LiteralPath $temporary -Raw -Encoding utf8
                    return [pscustomobject]@{
                        Text      = [string]$extracted
                        PageCount = $pageCount
                        Source    = 'pdftotext'
                        Complete  = -not [string]::IsNullOrWhiteSpace($extracted)
                        Note      = $null
                    }
                }
            }
            catch {
                Write-O365Log "pdftotext failed, falling back to the built-in reader: $($_.Exception.Message)" 'Warning'
            }
            finally {
                Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # -----------------------------------------------------------------------
    # Built-in reader.
    # -----------------------------------------------------------------------
    function Expand-PdfStream {
        param([byte[]]$Data)

        # Skip 2 first: FlateDecode in a PDF is zlib, whose two-byte header a
        # raw DeflateStream will not accept. Some writers omit it, hence 0.
        foreach ($skip in 2, 0) {
            if ($Data.Length -le $skip) { continue }
            try {
                $source = [System.IO.MemoryStream]::new($Data, $skip, $Data.Length - $skip)
                $sink = [System.IO.MemoryStream]::new()
                $inflate = [System.IO.Compression.DeflateStream]::new(
                    $source, [System.IO.Compression.CompressionMode]::Decompress)
                $inflate.CopyTo($sink)
                $inflate.Dispose()
                $result = $sink.ToArray()
                if ($result.Length -gt 0) { return $result }
            }
            catch {
                Write-Verbose "Inflate at offset $skip failed: $($_.Exception.Message)"
            }
        }

        return $null
    }

    function Get-PdfDictionary {
        param([string]$Text, [int]$Start)

        $depth = 0
        $index = $Start
        while ($index -lt $Text.Length - 1) {
            if ($Text[$index] -eq '<' -and $Text[$index + 1] -eq '<') {
                $depth++
                $index += 2
                continue
            }
            if ($Text[$index] -eq '>' -and $Text[$index + 1] -eq '>') {
                $depth--
                $index += 2
                if ($depth -le 0) { return $Text.Substring($Start, $index - $Start) }
                continue
            }
            $index++
        }
        return $Text.Substring($Start)
    }

    function ConvertFrom-PdfHex {
        param([string]$Hex)

        $clean = [regex]::Replace($Hex, '[^0-9A-Fa-f]', '')
        if ($clean.Length -lt 4) { return '' }

        $builder = [System.Text.StringBuilder]::new()
        for ($index = 0; $index + 3 -lt $clean.Length; $index += 4) {
            [void]$builder.Append([char][Convert]::ToInt32($clean.Substring($index, 4), 16))
        }
        return $builder.ToString()
    }

    # ---- object table -----------------------------------------------------
    $objects = @{}

    foreach ($match in [regex]::Matches($raw, '(?s)(\d+)\s+\d+\s+obj\b(.*?)\bendobj')) {
        $number = [int]$match.Groups[1].Value
        if ($objects.ContainsKey($number)) { continue }

        $body = $match.Groups[2].Value
        $bodyStart = $match.Groups[2].Index

        $streamMatch = [regex]::Match($body, 'stream\r?\n')
        $dictionary = if ($streamMatch.Success) { $body.Substring(0, $streamMatch.Index) } else { $body }

        $streamBytes = $null
        if ($streamMatch.Success) {
            $dataStart = $bodyStart + $streamMatch.Index + $streamMatch.Length

            $lengthMatch = [regex]::Match($dictionary, '/Length\s+(\d+)(?!\s+\d+\s+R)')
            $length = if ($lengthMatch.Success) {
                [int]$lengthMatch.Groups[1].Value
            }
            else {
                $endMatch = [regex]::Match($body.Substring($streamMatch.Index), 'endstream')
                if ($endMatch.Success) { $endMatch.Index - $streamMatch.Length } else { 0 }
            }

            if ($length -gt 0 -and $dataStart + $length -le $bytes.Length) {
                $streamBytes = [byte[]]::new($length)
                [System.Array]::Copy($bytes, $dataStart, $streamBytes, 0, $length)
            }
        }

        $objects[$number] = [pscustomobject]@{
            Dictionary = $dictionary
            Stream     = $streamBytes
        }
    }

    function Get-PdfStreamText {
        param([int]$Number)

        if (-not $objects.ContainsKey($Number)) { return '' }
        $object = $objects[$Number]
        if ($null -eq $object.Stream) { return '' }

        $data = if ($object.Dictionary -match '/FlateDecode') {
            Expand-PdfStream -Data $object.Stream
        }
        else {
            $object.Stream
        }

        if ($null -eq $data) { return '' }
        return [System.Text.Encoding]::Latin1.GetString($data)
    }

    function Resolve-PdfValue {
        param([string]$Container, [string]$Key)

        $reference = [regex]::Match($Container, "/$Key\s+(\d+)\s+\d+\s+R\b")
        if ($reference.Success) {
            $number = [int]$reference.Groups[1].Value
            if ($objects.ContainsKey($number)) { return $objects[$number].Dictionary }
            return $null
        }

        $inline = [regex]::Match($Container, "/$Key\s*<<")
        if ($inline.Success) {
            return Get-PdfDictionary -Text $Container -Start ($inline.Index + $inline.Length - 2)
        }

        return $null
    }

    function Get-PdfCMap {
        param([string]$CMapText)

        $map = @{}
        $codeLength = 2

        $space = [regex]::Match($CMapText, '(?s)begincodespacerange(.*?)endcodespacerange')
        if ($space.Success) {
            $first = [regex]::Match($space.Groups[1].Value, '<([0-9A-Fa-f]+)>')
            if ($first.Success) {
                $codeLength = [math]::Max(1, [int][math]::Floor($first.Groups[1].Value.Length / 2))
            }
        }

        foreach ($block in [regex]::Matches($CMapText, '(?s)beginbfchar(.*?)endbfchar')) {
            foreach ($pair in [regex]::Matches($block.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]*)>')) {
                $map[[Convert]::ToInt32($pair.Groups[1].Value, 16)] = ConvertFrom-PdfHex $pair.Groups[2].Value
            }
        }

        foreach ($block in [regex]::Matches($CMapText, '(?s)beginbfrange(.*?)endbfrange')) {
            $pattern = '(?s)<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:<([0-9A-Fa-f]*)>|\[(.*?)\])'
            foreach ($entry in [regex]::Matches($block.Groups[1].Value, $pattern)) {
                $low = [Convert]::ToInt32($entry.Groups[1].Value, 16)
                $high = [Convert]::ToInt32($entry.Groups[2].Value, 16)
                if ($high -lt $low -or $high - $low -gt 65535) { continue }

                if ($entry.Groups[3].Success) {
                    $base = ConvertFrom-PdfHex $entry.Groups[3].Value
                    if ($base.Length -eq 0) { continue }

                    # A range maps consecutive codes to consecutive characters,
                    # which means incrementing the last unit of the base.
                    $prefix = $base.Substring(0, $base.Length - 1)
                    $last = [int][char]$base[$base.Length - 1]
                    for ($code = $low; $code -le $high; $code++) {
                        $map[$code] = $prefix + [char]($last + ($code - $low))
                    }
                }
                else {
                    $offset = 0
                    foreach ($destination in [regex]::Matches($entry.Groups[4].Value, '<([0-9A-Fa-f]*)>')) {
                        $map[$low + $offset] = ConvertFrom-PdfHex $destination.Groups[1].Value
                        $offset++
                    }
                }
            }
        }

        return [pscustomobject]@{ Map = $map; CodeLength = $codeLength }
    }

    function ConvertFrom-PdfString {
        param([string]$Token, $CMap)

        $codes = [System.Collections.Generic.List[int]]::new()

        if ($Token.StartsWith('<')) {
            $hex = [regex]::Replace($Token.Trim('<', '>'), '[^0-9A-Fa-f]', '')
            $width = if ($CMap) { $CMap.CodeLength * 2 } else { 2 }
            if ($hex.Length % $width -ne 0) { $hex = $hex.PadRight($hex.Length + ($width - $hex.Length % $width), '0') }
            for ($index = 0; $index + $width -le $hex.Length; $index += $width) {
                $codes.Add([Convert]::ToInt32($hex.Substring($index, $width), 16))
            }
        }
        else {
            $literal = $Token.Substring(1, $Token.Length - 2)
            $unescaped = [System.Text.StringBuilder]::new()
            $index = 0
            while ($index -lt $literal.Length) {
                if ($literal[$index] -ne '\') {
                    [void]$unescaped.Append($literal[$index])
                    $index++
                    continue
                }
                $index++
                if ($index -ge $literal.Length) { break }
                $escape = $literal[$index]
                switch ($escape) {
                    'n' { [void]$unescaped.Append("`n"); $index++ }
                    'r' { [void]$unescaped.Append("`r"); $index++ }
                    't' { [void]$unescaped.Append("`t"); $index++ }
                    'b' { $index++ }
                    'f' { $index++ }
                    default {
                        if ($escape -match '[0-7]') {
                            $octal = ''
                            while ($index -lt $literal.Length -and $literal[$index] -match '[0-7]' -and $octal.Length -lt 3) {
                                $octal += $literal[$index]
                                $index++
                            }
                            [void]$unescaped.Append([char][Convert]::ToInt32($octal, 8))
                        }
                        else {
                            [void]$unescaped.Append($escape)
                            $index++
                        }
                    }
                }
            }

            $plain = $unescaped.ToString()
            $width = if ($CMap) { $CMap.CodeLength } else { 1 }
            for ($index = 0; $index + $width -le $plain.Length; $index += $width) {
                $code = 0
                for ($byte = 0; $byte -lt $width; $byte++) {
                    $code = ($code -shl 8) -bor ([int][char]$plain[$index + $byte])
                }
                $codes.Add($code)
            }
        }

        $builder = [System.Text.StringBuilder]::new()
        foreach ($code in $codes) {
            if ($CMap -and $CMap.Map.ContainsKey($code)) {
                [void]$builder.Append($CMap.Map[$code])
            }
            elseif ($code -ge 32 -and $code -lt 65536) {
                [void]$builder.Append([char]$code)
            }
        }

        return $builder.ToString()
    }

    # ---- walk the pages ---------------------------------------------------
    $cmapCache = @{}
    $text = [System.Text.StringBuilder]::new()
    $pageNumbers = @($objects.Keys | Where-Object { $objects[$_].Dictionary -match '/Type\s*/Page\b' } | Sort-Object)

    $tokenPattern = '(?s)' +
    '/([^\s/<>\[\]()]+)\s+[-\d.]+\s+Tf' +
    '|(\[(?:[^\[\]\\]|\\.)*\])\s*TJ' +
    '|(\((?:\\.|[^\\()])*\)|<[0-9A-Fa-f\s]*>)\s*Tj' +
    # No \b around these: 'T*' ends in a non-word character, so a word
    # boundary after it never matches and every line break is lost.
    '|(?<![A-Za-z0-9])(Tm|T\*|ET|BT)(?![A-Za-z0-9])' +
    # 'tx ty Td' is a line break only when ty is non-zero. Without that test
    # this breaks catastrophically on browser output: Chromium positions every
    # single glyph with its own Td, so treating Td as a newline puts one
    # between every pair of letters on the page and no word survives.
    '|([-\d.]+)\s+(?:Td|TD)(?![A-Za-z0-9])'

    foreach ($pageNumber in $pageNumbers) {
        $page = $objects[$pageNumber].Dictionary

        # Fonts first: a code means nothing without the map it is drawn with.
        $fonts = @{}
        $resources = Resolve-PdfValue -Container $page -Key 'Resources'
        if ($resources) {
            $fontDictionary = Resolve-PdfValue -Container $resources -Key 'Font'
            if ($fontDictionary) {
                foreach ($entry in [regex]::Matches($fontDictionary, '/([^\s/<>\[\]()]+)\s+(\d+)\s+\d+\s+R')) {
                    $fontNumber = [int]$entry.Groups[2].Value
                    if (-not $cmapCache.ContainsKey($fontNumber)) {
                        $cmapCache[$fontNumber] = $null
                        if ($objects.ContainsKey($fontNumber)) {
                            $toUnicode = [regex]::Match($objects[$fontNumber].Dictionary, '/ToUnicode\s+(\d+)\s+\d+\s+R')
                            if ($toUnicode.Success) {
                                $cmapText = Get-PdfStreamText -Number ([int]$toUnicode.Groups[1].Value)
                                if ($cmapText) { $cmapCache[$fontNumber] = Get-PdfCMap -CMapText $cmapText }
                            }
                        }
                    }
                    $fonts[$entry.Groups[1].Value] = $cmapCache[$fontNumber]
                }
            }
        }

        $contentNumbers = [System.Collections.Generic.List[int]]::new()
        $single = [regex]::Match($page, '/Contents\s+(\d+)\s+\d+\s+R')
        if ($single.Success) {
            $contentNumbers.Add([int]$single.Groups[1].Value)
        }
        else {
            $array = [regex]::Match($page, '(?s)/Contents\s*\[(.*?)\]')
            if ($array.Success) {
                foreach ($reference in [regex]::Matches($array.Groups[1].Value, '(\d+)\s+\d+\s+R')) {
                    $contentNumbers.Add([int]$reference.Groups[1].Value)
                }
            }
        }

        $content = (@($contentNumbers | ForEach-Object { Get-PdfStreamText -Number $_ }) -join "`n")
        if (-not $content) { continue }

        $currentFont = $null
        foreach ($token in [regex]::Matches($content, $tokenPattern)) {
            if ($token.Groups[1].Success) {
                $name = $token.Groups[1].Value
                $currentFont = if ($fonts.ContainsKey($name)) { $fonts[$name] } else { $null }
            }
            elseif ($token.Groups[2].Success) {
                foreach ($piece in [regex]::Matches($token.Groups[2].Value, '(?s)\((?:\\.|[^\\()])*\)|<[0-9A-Fa-f\s]*>')) {
                    [void]$text.Append((ConvertFrom-PdfString -Token $piece.Value -CMap $currentFont))
                }
            }
            elseif ($token.Groups[3].Success) {
                [void]$text.Append((ConvertFrom-PdfString -Token $token.Groups[3].Value -CMap $currentFont))
            }
            elseif ($token.Groups[4].Success) {
                # A new text object or a new text matrix: the next cell, or the
                # next line of a wrapped one. Separated, so the end of one and
                # the start of the next do not read as a single word.
                [void]$text.Append("`n")
            }
            elseif ($token.Groups[5].Success -and [double]$token.Groups[5].Value -ne 0) {
                [void]$text.Append("`n")
            }
        }

        [void]$text.AppendLine()
    }

    $extracted = $text.ToString()

    return [pscustomobject]@{
        Text      = $extracted
        PageCount = $pageCount
        Source    = 'built-in'
        Complete  = -not [string]::IsNullOrWhiteSpace($extracted)
        Note      = $(if ([string]::IsNullOrWhiteSpace($extracted)) {
                'No text could be read. The PDF may be encrypted, or built from fonts without a /ToUnicode map. Install poppler-utils for pdftotext to read it.'
            })
    }
}
