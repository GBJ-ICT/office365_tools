<#
    The PDF export splits into three pieces that can each be tested without a
    tenant: rendering values to cell text, rendering cells to a printable page,
    and folding text so a value read back out of a PDF can be compared with the
    one that went in.

    The round trip through a real browser is at the bottom and skips itself
    when there is no browser to run -- it needs no network and no tenant, but
    it does need Edge or Chrome, which a build agent may not have.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Consumed by -Skip on the It blocks below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    # Pester evaluates -Skip while discovering tests, before BeforeAll runs, so
    # whether there is a browser to print with has to be answered here.
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    $hasBrowser = $false
    try {
        $null = InModuleScope Office365Tools { Find-SpoChromiumBrowser }
        $hasBrowser = $true
    }
    catch {
        Write-Verbose "No browser for the round trip test: $($_.Exception.Message)"
    }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-SpoCellText' {

    It 'renders a date without its time' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value ([datetime]'2026-09-06') | Should -Be '2026-09-06'
        }
    }

    It 'keeps the time when there is one, because a duty roster is unreadable without it' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value ([datetime]'2026-09-06 14:30') | Should -Be '2026-09-06 14:30'
        }
    }

    It 'honours a custom date format' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value ([datetime]'2026-09-06') -DateFormat 'dd.MM.yyyy' | Should -Be '06.09.2026'
        }
    }

    It 'renders null as an empty string rather than the word null' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value $null | Should -Be ''
        }
    }

    It 'joins a multi-value field' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value @('Anna', 'Beat', 'Chiara') | Should -Be 'Anna; Beat; Chiara'
        }
    }

    It 'resolves a lookup-shaped object to its display value' {
        InModuleScope Office365Tools {
            $lookup = [pscustomobject]@{ LookupId = 12; LookupValue = 'Titterten' }
            ConvertTo-SpoCellText -Value $lookup | Should -Be 'Titterten'
        }
    }

    It 'renders a boolean as a word' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value $true | Should -Be 'Yes'
        }
    }
}

Describe 'ConvertTo-SpoSearchText' {

    It 'collapses a line break to a space with -KeepSpace' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text "Inhalt  &`nBemerkungen" -KeepSpace | Should -Be 'inhalt & bemerkungen'
        }
    }

    It 'removes whitespace entirely without it' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text "Inhalt  &`nBemerkungen" | Should -Be 'inhalt&bemerkungen'
        }
    }

    It 'undoes a ligature, which is what a subset font maps back to' {
        InModuleScope Office365Tools {
            # U+FB01 LATIN SMALL LIGATURE FI
            ConvertTo-SpoSearchText -Text "P`u{FB01}ngsten" -KeepSpace | Should -Be 'pfingsten'
        }
    }

    It 'treats a non-breaking space as a space' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text "10`u{00A0}Uhr" -KeepSpace | Should -Be '10 uhr'
        }
    }

    It 'normalises an em dash to a hyphen' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text "Basel `u{2014} Titterten" -KeepSpace | Should -Be 'basel - titterten'
        }
    }

    It 'drops a soft hyphen' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text "Kirchen`u{00AD}kaffee" | Should -Be 'kirchenkaffee'
        }
    }

    It 'returns an empty string for null' {
        InModuleScope Office365Tools {
            ConvertTo-SpoSearchText -Text $null | Should -Be ''
        }
    }
}

Describe 'ConvertTo-SpoPrintHtml' {

    BeforeAll {
        $script:Rows = @(
            [pscustomobject]@{ Titel = 'Gottesdienst'; Datum = [datetime]'2026-09-06'; Gefaess = 'Hauptgottesdienst'; Bemerkungen = 'Mit Abendmahl' }
            [pscustomobject]@{ Titel = 'Anlass <mit> "Zeichen"'; Datum = [datetime]'2026-09-13'; Gefaess = 'Anlass'; Bemerkungen = '' }
            [pscustomobject]@{ Titel = 'Unterricht'; Datum = [datetime]'2026-09-20'; Gefaess = 'Hauptgottesdienst'; Bemerkungen = 'Raum 2' }
        )
    }

    It 'puts every value in the document' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Datum, Gefaess, Bemerkungen

            $render.Html | Should -Match 'Gottesdienst'
            $render.Html | Should -Match '2026-09-20'
            $render.Html | Should -Match 'Raum 2'
        }
    }

    It 'encodes markup in a value instead of emitting it' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel

            $render.Html | Should -Match 'Anlass &lt;mit&gt;'
            $render.Html | Should -Not -Match '<mit>'
        }
    }

    It 'reports one cell per non-empty value, and none for an empty one' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Bemerkungen

            # Three titles, two remarks -- the empty one is not a cell to look
            # for, and verifying it would always fail.
            @($render.Cell).Count | Should -Be 5
            @($render.Cell | Where-Object Column -eq 'Bemerkungen').Count | Should -Be 2
        }
    }

    It 'fixes the sheet in the page rule rather than leaving it to the viewport' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel -PaperSize A3 -Orientation Portrait -Margin '20mm'

            $render.Html | Should -Match '@page \{ size: A3 portrait; margin: 20mm; \}'
        }
    }

    It 'repeats the header row on every page and keeps rows whole' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel

            $render.Html | Should -Match 'thead \{ display: table-header-group; \}'
            $render.Html | Should -Match 'break-inside: avoid'
        }
    }

    It 'never clips a cell, because a clipped cell hides its own contents' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel

            $render.Html | Should -Match 'overflow-wrap: anywhere'
            $render.Html | Should -Not -Match 'table-layout: fixed'
            $render.Html | Should -Not -Match 'text-overflow'
        }
    }

    It 'ends with an attestation naming the row count' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Datum

            $render.Attestation | Should -Match '^Rows 3 / Columns 2 / Digest [0-9A-F]{8} / End of report$'
            $render.Html | Should -Match ([regex]::Escape($render.Attestation))
        }
    }

    It 'gives the same digest for the same data and a different one for different data' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $first = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Datum
            $again = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Datum

            $changed = @($Rows[0], $Rows[1], [pscustomobject]@{ Titel = 'Etwas anderes'; Datum = [datetime]'2026-09-20' })
            $other = ConvertTo-SpoPrintHtml -Row $changed -Column Titel, Datum

            $again.Digest | Should -Be $first.Digest
            $other.Digest | Should -Not -Be $first.Digest
        }
    }

    It 'groups rows and heads each group with its value and count' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Gefaess -GroupBy Gefaess

            $render.Html | Should -Match 'Gefaess: Hauptgottesdienst <span class="count">\(2\)</span>'
            $render.Html | Should -Match 'Gefaess: Anlass <span class="count">\(1\)</span>'
            @([regex]::Matches($render.Html, '<thead>')).Count | Should -Be 2
        }
    }

    It 'gives every cell a class named after its column, so -Css can address one' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel -Css 'td.col-titel { color: red; }'

            $render.Html | Should -Match 'class="col-titel"'
            $render.Html | Should -Match 'td\.col-titel \{ color: red; \}'
        }
    }

    It 'applies a cell formatter and encodes what it returns' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel `
                -CellFormatter { param($Value, $Column) "<$Column> $Value" }

            $render.Html | Should -Match '&lt;Titel&gt; Gottesdienst'
        }
    }

    It 'renders an empty set as a page saying so rather than an empty table' {
        InModuleScope Office365Tools {
            $render = ConvertTo-SpoPrintHtml -Row @() -Column Titel

            $render.RowCount | Should -Be 0
            $render.Html | Should -Match 'Nothing to print'
            $render.Attestation | Should -Match '^Rows 0 '
        }
    }
}

Describe 'Get-SpoCellLink' {

    It 'makes a URL clickable without being asked' {
        InModuleScope Office365Tools {
            Get-SpoCellLink -Value 'https://contoso.sharepoint.com/sites/CDS' -Column 'Quelle' |
                Should -Be 'https://contoso.sharepoint.com/sites/CDS'
        }
    }

    It 'leaves a bare address as text' {
        InModuleScope Office365Tools {
            # It looks like an address; a list column full of these is far more
            # often an account or a reference, and a guessed mailto is a link
            # nobody can follow.
            Get-SpoCellLink -Value 'someone@example.com' -Column 'Melder' |
                Should -BeNullOrEmpty
        }
    }

    It 'links a value that says it is a mailbox' {
        InModuleScope Office365Tools {
            Get-SpoCellLink -Value 'mailto:someone@example.com' -Column 'Melder' |
                Should -Be 'mailto:someone@example.com'
        }
    }

    It 'refuses a scheme that is not a link' {
        InModuleScope Office365Tools {
            # List content deciding what the browser executes, in a print that
            # runs from a local file.
            Get-SpoCellLink -Value 'javascript:alert(1)' -Column 'Titel' | Should -BeNullOrEmpty
            Get-SpoCellLink -Value 'file:///C:/Windows' -Column 'Titel' | Should -BeNullOrEmpty
        }
    }

    It 'leaves ordinary text alone' {
        InModuleScope Office365Tools {
            Get-SpoCellLink -Value 'Drucker kaputt' -Column 'Titel' | Should -BeNullOrEmpty
        }
    }

    It 'fills a template from the row and escapes what it inserts' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ID = 42; Titel = 'a b'; Ort = 'Basel/Land' }

            Get-SpoCellLink -Value 'a b' -Column 'Titel' -Row $row `
                -LinkColumn @{ Titel = 'https://x/DispForm.aspx?ID={ID}&q={Ort}' } |
                Should -Be 'https://x/DispForm.aspx?ID=42&q=Basel%2FLand'
        }
    }

    It 'inserts a placeholder verbatim when asked' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ Pfad = 'sites/CDS/Lists/x' }

            Get-SpoCellLink -Value 'x' -Column 'Titel' -Row $row `
                -LinkColumn @{ Titel = 'https://contoso.sharepoint.com/{Pfad:raw}' } |
                Should -Be 'https://contoso.sharepoint.com/sites/CDS/Lists/x'
        }
    }

    It 'prefers a formatter over a template' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ID = 7 }

            Get-SpoCellLink -Value 'x' -Column 'Titel' -Row $row `
                -LinkColumn @{ Titel = 'https://template/{ID}' } `
                -LinkFormatter { param($Value, $Column, $Row) "https://formatter/$Column/$($Row.ID)?v=$Value" } |
                Should -Be 'https://formatter/Titel/7?v=x'
        }
    }

    It 'links nothing when -NoAutoLink is set' {
        InModuleScope Office365Tools {
            Get-SpoCellLink -Value 'https://contoso.sharepoint.com' -Column 'Quelle' -NoAutoLink |
                Should -BeNullOrEmpty
        }
    }
}

Describe 'Links in the rendered page' {

    BeforeAll {
        $script:LinkRows = @(
            [pscustomobject]@{ ID = 11; Titel = 'Drucker kaputt'; Melder = 'a@example.com'; Quelle = 'https://contoso.sharepoint.com/p/1' }
            [pscustomobject]@{ ID = 12; Titel = 'Beamer defekt'; Melder = 'b@example.com'; Quelle = '' }
        )
    }

    It 'emits an anchor for a value that is a URL' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:LinkRows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Melder, Quelle

            $render.Html | Should -Match '<a href="https://contoso\.sharepoint\.com/p/1">'
            # The address is printed, not linked.
            $render.Html | Should -Not -Match '<a href="mailto:'
        }
    }

    It 'reports what it linked, with the row and column' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:LinkRows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Melder, Quelle `
                -LinkColumn @{ Titel = 'https://contoso.sharepoint.com/DispForm.aspx?ID={ID}' }

            # Two titles and one URL -- the empty Quelle is not a link, and a
            # bare address is text.
            @($render.Link).Count | Should -Be 3

            $title = @($render.Link | Where-Object { $_.Column -eq 'Titel' -and $_.Row -eq 2 })[0]
            $title.Href | Should -Be 'https://contoso.sharepoint.com/DispForm.aspx?ID=12'
            $title.Text | Should -Be 'Beamer defekt'
        }
    }

    It 'keeps the link when a formatter shortens the text' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:LinkRows } {
            param($Rows)
            # The href comes from the raw value, so shortening the caption does
            # not shorten where the link goes.
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Quelle `
                -CellFormatter { param($Value, $Column) if ($Column -eq 'Quelle' -and $Value) { 'Seite' } else { '' } }

            $render.Html | Should -Match '<a href="https://contoso\.sharepoint\.com/p/1">Seite</a>'
        }
    }

    It 'prints plain text under -NoAutoLink' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:LinkRows } {
            param($Rows)
            $render = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Melder, Quelle -NoAutoLink

            $render.Html | Should -Not -Match '<a href'
            @($render.Link).Count | Should -Be 0
            # Still printed, just not clickable.
            $render.Html | Should -Match 'a@example\.com'
        }
    }
}

Describe 'Test-SpoPdfContent' {

    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-pdf-$([guid]::NewGuid())"
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force
        }
    }

    It 'reports a PDF that is not there' {
        $findings = @(Test-SpoPdfContent -Path (Join-Path $script:TempDir 'absent.pdf') -Cell @())

        $findings.Count | Should -Be 1
        $findings[0].RuleId | Should -Be 'Pdf.Missing'
        $findings[0].Severity | Should -Be 'Error'
    }

    It 'reports a file that is not a PDF instead of reading it as one' {
        $path = Join-Path $script:TempDir 'not-really.pdf'
        Set-Content -LiteralPath $path -Value 'This is a text file with a misleading extension.'

        $findings = @(Test-SpoPdfContent -Path $path -Cell @())

        $findings[0].RuleId | Should -Be 'Pdf.NotAPdf'
        $findings[0].Severity | Should -Be 'Error'
    }

    It 'says it could not check rather than reporting success when no rows are given' {
        $path = Join-Path $script:TempDir 'empty.pdf'
        Set-Content -LiteralPath $path -Value '%PDF-1.4'

        $findings = @(Test-SpoPdfContent -Path $path -Row $null)

        $findings[0].RuleId | Should -Be 'Pdf.NothingToCheck'
    }
}

Describe 'The round trip through a browser' {

    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-roundtrip-$([guid]::NewGuid())"
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null

        $script:Rows = 1..40 | ForEach-Object {
            [pscustomobject]@{
                Nr      = "HG-$('{0:D4}' -f $_)"
                Titel   = "Eintrag $_"
                Datum   = (Get-Date '2026-01-04').AddDays(7 * $_)
                Gefaess = @('Hauptgottesdienst', 'Anlass', 'Unterricht')[$_ % 3]
            }
        }
    }

    AfterAll {
        if ($script:TempDir -and (Test-Path -LiteralPath $script:TempDir)) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force
        }
    }

    It 'prints, reads back, and finds every value' -Skip:(-not $hasBrowser) {
        $pdf = Join-Path $script:TempDir 'roundtrip.pdf'

        $render = InModuleScope Office365Tools -Parameters @{ Rows = $script:Rows; Pdf = $pdf; Dir = $script:TempDir } {
            param($Rows, $Pdf, $Dir)
            $rendered = ConvertTo-SpoPrintHtml -Row $Rows -Column Nr, Titel, Datum, Gefaess -Title 'Round trip'
            $html = Join-Path $Dir 'roundtrip.html'
            Set-Content -LiteralPath $html -Value $rendered.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $rendered
        }

        Test-Path -LiteralPath $pdf | Should -BeTrue

        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell `
                -Attestation $render.Attestation -ExpectedRowCount $render.RowCount -NoExternalReader)

        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
        @($findings | Where-Object RuleId -eq 'Pdf.NoTextLayer') | Should -BeNullOrEmpty
    }

    It 'keeps the links clickable in the PDF' -Skip:(-not $hasBrowser) {
        $pdf = Join-Path $script:TempDir 'links.pdf'

        $rows = @(
            [pscustomobject]@{ ID = 1; Titel = 'Erster'; Quelle = 'https://contoso.sharepoint.com/p/1' }
            [pscustomobject]@{ ID = 2; Titel = 'Zweiter'; Quelle = 'https://contoso.sharepoint.com/p/2' }
        )

        $render = InModuleScope Office365Tools -Parameters @{ Rows = $rows; Pdf = $pdf; Dir = $script:TempDir } {
            param($Rows, $Pdf, $Dir)
            $rendered = ConvertTo-SpoPrintHtml -Row $Rows -Column Titel, Quelle -Title 'Links' `
                -LinkColumn @{ Titel = 'https://contoso.sharepoint.com/DispForm.aspx?ID={ID}' }
            $html = Join-Path $Dir 'links.html'
            Set-Content -LiteralPath $html -Value $rendered.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $rendered
        }

        $inPdf = @(InModuleScope Office365Tools -Parameters @{ Pdf = $pdf } {
                param($Pdf)
                Get-SpoPdfLink -Path $Pdf
            })

        # A link is an annotation, not text: this is the only way to see one.
        $inPdf | Should -Contain 'https://contoso.sharepoint.com/DispForm.aspx?ID=2'
        $inPdf | Should -Contain 'https://contoso.sharepoint.com/p/1'

        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell -Link $render.Link `
                -Attestation $render.Attestation -ExpectedRowCount $render.RowCount -NoExternalReader)

        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    }

    It 'reports a link that is not in the PDF' -Skip:(-not $hasBrowser) {
        $pdf = Join-Path $script:TempDir 'links.pdf'

        if (-not (Test-Path -LiteralPath $pdf)) {
            Set-ItResult -Skipped -Because 'the print in the previous test did not run'
            return
        }

        $absent = @([pscustomobject]@{ Row = 9; Column = 'Titel'; Text = 'x'; Href = 'https://example.invalid/nope' })
        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $absent -Link $absent -NoExternalReader)

        @($findings | Where-Object RuleId -eq 'Pdf.MissingLink').Count | Should -Be 1
    }

    It 'reports a value that was never printed' -Skip:(-not $hasBrowser) {
        $pdf = Join-Path $script:TempDir 'roundtrip.pdf'

        if (-not (Test-Path -LiteralPath $pdf)) {
            Set-ItResult -Skipped -Because 'the print in the previous test did not run'
            return
        }

        $absent = @([pscustomobject]@{ Row = 99; Column = 'Titel'; Text = 'Dieser Wert steht nirgends im Dokument' })
        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $absent -NoExternalReader)

        @($findings | Where-Object RuleId -eq 'Pdf.MissingValue').Count | Should -Be 1
    }
}
