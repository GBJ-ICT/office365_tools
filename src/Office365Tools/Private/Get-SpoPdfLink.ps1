<#
.SYNOPSIS
    Internal: reads the link annotations back out of a PDF.
.DESCRIPTION
    A clickable link in a PDF is not text. It is a /Annot of /Subtype /Link
    covering a rectangle, carrying a /URI action -- so reading the page text
    proves nothing about whether the links survived. This reads the URLs
    themselves, which is what makes 'the links are still there' checkable
    rather than a thing to test by clicking.

    Annotation dictionaries are normally uncompressed even when the page
    content is not, so the raw file is scanned first; if that finds nothing,
    the Flate-compressed object streams are inflated and scanned too, which is
    where a producer other than a browser tends to put them.
.PARAMETER Path
    The PDF to read.
.OUTPUTS
    System.String[]. Every URI the document links to, in file order, with
    duplicates kept -- a count is part of what a caller checks.
.EXAMPLE
    Get-SpoPdfLink -Path out/tickets.pdf
#>
function Get-SpoPdfLink {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    # Latin1 keeps one byte as one character, so offsets from the regex are
    # offsets into the file. Any other encoding silently reflows the arithmetic.
    $raw = [System.Text.Encoding]::Latin1.GetString($bytes)

    # A PDF string is (...) with backslash escapes, or <hex>. Both appear.
    $unescape = {
        param([string]$Token)

        if ($Token.StartsWith('<')) {
            $hex = ($Token.Trim('<', '>') -replace '\s', '')
            if ($hex.Length % 2 -eq 1) { $hex += '0' }
            $chars = for ($i = 0; $i -lt $hex.Length; $i += 2) {
                [char][System.Convert]::ToInt32($hex.Substring($i, 2), 16)
            }
            return (-join $chars)
        }

        $inner = $Token.Substring(1, $Token.Length - 2)
        $builder = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $inner.Length; $i++) {
            if ($inner[$i] -ne '\') {
                [void]$builder.Append($inner[$i])
                continue
            }

            $i++
            if ($i -ge $inner.Length) { break }
            switch ($inner[$i]) {
                'n' { [void]$builder.Append("`n") }
                'r' { [void]$builder.Append("`r") }
                't' { [void]$builder.Append("`t") }
                'b' { [void]$builder.Append("`b") }
                'f' { [void]$builder.Append("`f") }
                default { [void]$builder.Append($inner[$i]) }
            }
        }

        return $builder.ToString()
    }

    $scan = {
        param([string]$Text)

        $found = [System.Collections.Generic.List[string]]::new()
        $pattern = '/URI\s*(\((?:\\.|[^\\()])*\)|<[0-9A-Fa-f\s]*>)'
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $uri = (& $unescape $match.Groups[1].Value).Trim()
            if ($uri) { $found.Add($uri) }
        }
        return $found
    }

    # @() around the call because the pipeline unrolls the list the scriptblock
    # returns, and a single hit would otherwise arrive as a bare string.
    $links = [System.Collections.Generic.List[string]]::new()
    foreach ($uri in @(& $scan $raw)) { $links.Add($uri) }

    if ($links.Count -gt 0) { return $links.ToArray() }

    # Nothing in the clear. Inflate what can be inflated and look again.
    foreach ($match in [regex]::Matches($raw, '(?s)stream\r?\n(.*?)endstream')) {
        $body = $match.Groups[1].Value
        if ($body.Length -lt 3) { continue }

        $payload = [System.Text.Encoding]::Latin1.GetBytes($body)

        # A zlib stream opens with a two-byte header that DeflateStream does
        # not consume; without it the first block is read as garbage.
        foreach ($offset in 2, 0) {
            try {
                $compressed = [System.IO.MemoryStream]::new($payload, $offset, $payload.Length - $offset)
                $deflate = [System.IO.Compression.DeflateStream]::new($compressed, [System.IO.Compression.CompressionMode]::Decompress)
                $output = [System.IO.MemoryStream]::new()
                $deflate.CopyTo($output)
                $deflate.Dispose()

                $inflated = [System.Text.Encoding]::Latin1.GetString($output.ToArray())
                foreach ($uri in @(& $scan $inflated)) { $links.Add($uri) }
                break
            }
            catch {
                # Not a Flate stream at this offset, or not compressed at all.
                continue
            }
        }
    }

    return $links.ToArray()
}
