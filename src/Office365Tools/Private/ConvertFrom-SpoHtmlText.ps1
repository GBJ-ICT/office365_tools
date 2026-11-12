<#
.SYNOPSIS
    Internal: turns the HTML of a rich text field into printable text and the
    links inside it.
.DESCRIPTION
    An enhanced rich text column holds HTML. Printed as it is, the tags show;
    stripped naively, the paragraphs run together and the links are gone. This
    keeps what a reader sees:

      * Paragraphs, headings, <br> and table rows become line breaks.
      * <ul> items start with a bullet and <ol> items with their number, nested
        lists indented.
      * Entities are decoded ('&amp;' is '&', a non-breaking space is a space).
      * <script>, <style>, comments, event attributes and every tag that has
        no meaning on paper are dropped; the text inside a dropped tag stays
        where it is visible text.
      * <a href> becomes a link that keeps its caption. A relative address is
        resolved against the site URL; an address that is not http, https,
        mailto or tel, or cannot be resolved, is printed as plain text.

    The result is a list of segments (text, and the URL it links to or an empty
    string) next to the plain text those segments add up to. The plain text is
    what the PDF check looks for, so the renderer and the verifier agree.

    This is a small tokenizer, not a browser: it reads the markup SharePoint's
    editor produces. It does not execute or fetch anything.
.PARAMETER Html
    The HTML.
.PARAMETER SiteUrl
    Address of the site, for resolving relative links. Without it a relative
    link is printed as text.
.OUTPUTS
    PSCustomObject with Text and Segment. Each segment has Text and Href.
.EXAMPLE
    ConvertFrom-SpoHtmlText -Html '<p>See <a href="https://example.org/x">Item 6</a></p>'
#>
function ConvertFrom-SpoHtmlText {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'SiteUrl',
        Justification = 'Used inside the script block that resolves a link, which the analyzer does not trace.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Html,

        [Parameter()]
        [string]$SiteUrl
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return [pscustomobject]@{ Text = ''; Segment = @() }
    }

    # Comments, scripts and styles go first, content included: nobody reads
    # them and a script's text must never reach the page.
    $clean = [regex]::Replace($Html, '<!--.*?-->', '', 'Singleline')
    $clean = [regex]::Replace($clean, '<(script|style)\b[^>]*>.*?</\1\s*>', '', 'Singleline, IgnoreCase')

    $attributeOf = {
        param([string]$Attributes, [string]$Name)

        $found = [regex]::Match($Attributes,
            '(?:^|\s)' + $Name + '\s*=\s*(?:"(?<v>[^"]*)"|''(?<v>[^'']*)''|(?<v>[^\s>]+))', 'IgnoreCase')
        if ($found.Success) { return [System.Net.WebUtility]::HtmlDecode($found.Groups['v'].Value) }
        return ''
    }

    $resolve = {
        param([string]$Address)

        $candidate = $Address.Trim()
        if (-not $candidate -or $candidate.StartsWith('#')) { return '' }

        if ($candidate -notmatch '^[A-Za-z][A-Za-z0-9+.\-]*:') {
            if (-not $SiteUrl) { return '' }

            try {
                $base = [uri]($SiteUrl.TrimEnd('/') + '/')
                $candidate = [uri]::new($base, $candidate).AbsoluteUri
            }
            catch {
                return ''
            }
        }

        return (Get-SpoSafeUrl -Url $candidate)
    }

    $items = [System.Collections.Generic.List[object]]::new()
    $lists = [System.Collections.Generic.Stack[object]]::new()
    $href = ''

    $addBreak = { $items.Add(@{ Kind = 'break'; Text = ''; Href = '' }) }
    $addBlock = {
        if ($items.Count -gt 0 -and $items[$items.Count - 1].Kind -ne 'break') { & $addBreak }
    }

    $tokens = [regex]::Matches($clean,
        '<(?<close>/)?(?<name>[A-Za-z][A-Za-z0-9]*)(?<attrs>(?:"[^"]*"|''[^'']*''|[^>"''])*)>|(?<text>[^<]+|<)')

    foreach ($token in $tokens) {
        if ($token.Groups['text'].Success) {
            $piece = [System.Net.WebUtility]::HtmlDecode($token.Groups['text'].Value)
            $piece = $piece.Replace("`u{200B}", '').Replace("`u{FEFF}", '')
            $piece = [regex]::Replace($piece, '[\s\u00A0]+', ' ')
            if ($piece) { $items.Add(@{ Kind = 'text'; Text = $piece; Href = $href }) }
            continue
        }

        $name = $token.Groups['name'].Value.ToLowerInvariant()
        $closing = $token.Groups['close'].Success
        $attributes = $token.Groups['attrs'].Value

        switch -Regex ($name) {
            '^br$' { & $addBreak }
            '^(p|div|h[1-6]|table|tr|blockquote|section|article|header|footer|pre|dl|dt|dd)$' { & $addBlock }
            '^(td|th)$' {
                if ($closing) { $items.Add(@{ Kind = 'text'; Text = ' '; Href = $href }) }
            }
            '^(ul|ol)$' {
                & $addBlock
                if ($closing) {
                    if ($lists.Count -gt 0) { [void]$lists.Pop() }
                }
                else {
                    $lists.Push(@{ Ordered = ($name -eq 'ol'); Number = 0 })
                }
            }
            '^li$' {
                if (-not $closing) {
                    & $addBlock
                    $indent = '  ' * [Math]::Max(0, $lists.Count - 1)
                    $marker = [string][char]0x2022 + ' '
                    if ($lists.Count -gt 0) {
                        $level = $lists.Peek()
                        if ($level.Ordered) {
                            $level.Number++
                            $marker = "$($level.Number). "
                        }
                    }
                    $items.Add(@{ Kind = 'prefix'; Text = $indent + $marker; Href = '' })
                }
            }
            '^a$' {
                $href = if ($closing) { '' } else { & $resolve (& $attributeOf $attributes 'href') }
            }
            '^img$' {
                if (-not $closing) {
                    $alt = & $attributeOf $attributes 'alt'
                    if ($alt) { $items.Add(@{ Kind = 'text'; Text = $alt; Href = $href }) }
                }
            }
            default { }
        }
    }

    # Assemble: no space at the edge of a line, no more than one empty line, and
    # neighbouring pieces with the same link joined into one.
    $segments = [System.Collections.Generic.List[object]]::new()
    $lineStart = $true

    $trimLast = {
        if ($segments.Count -gt 0 -and $segments[$segments.Count - 1].Text -ne "`n") {
            $last = $segments[$segments.Count - 1]
            $last.Text = $last.Text.TrimEnd(' ')
            if ($last.Text -eq '') { $segments.RemoveAt($segments.Count - 1) }
        }
    }

    foreach ($item in $items) {
        switch ($item.Kind) {
            'break' {
                & $trimLast
                $tail = $segments.Count
                $isDoubled = $tail -ge 2 -and $segments[$tail - 1].Text -eq "`n" -and $segments[$tail - 2].Text -eq "`n"
                if ($tail -gt 0 -and -not $isDoubled) {
                    $segments.Add(@{ Text = "`n"; Href = '' })
                }
                $lineStart = $true
            }
            'prefix' {
                $segments.Add(@{ Text = $item.Text; Href = '' })
                $lineStart = $false
            }
            default {
                $piece = $item.Text
                if ($lineStart) { $piece = $piece.TrimStart(' ') }
                if ($piece -eq '') { continue }
                $segments.Add(@{ Text = $piece; Href = $item.Href })
                $lineStart = $false
            }
        }
    }

    & $trimLast
    while ($segments.Count -gt 0 -and $segments[$segments.Count - 1].Text -eq "`n") {
        $segments.RemoveAt($segments.Count - 1)
        & $trimLast
    }

    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($segment in $segments) {
        if ($merged.Count -gt 0 -and $merged[$merged.Count - 1].Href -eq $segment.Href) {
            $merged[$merged.Count - 1].Text += $segment.Text
        }
        else {
            $merged.Add(@{ Text = $segment.Text; Href = $segment.Href })
        }
    }

    $result = @($merged | ForEach-Object { [pscustomobject]@{ Text = $_.Text; Href = $_.Href } })

    return [pscustomobject]@{
        Text    = (@($result | ForEach-Object { $_.Text }) -join '')
        Segment = $result
    }
}
