<#
    What makes a SharePoint list print well, tested piece by piece without a
    tenant: how each kind of column becomes text and links, how wide the columns
    are, what the first page says, how a view is found by its name, and what a
    real browser makes of all of it.

    The round trips at the bottom skip themselves when there is no browser to
    print with. They need no network and no tenant.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Consumed by -Skip on the It blocks below, which the analyzer does not trace.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'The stand-ins for the PnP commands take parameters they never read, so that a mock of them accepts the same call; and InModuleScope parameters are used inside mock bodies the analyzer does not trace.')]
param()

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    $hasBrowser = $false
    try {
        $null = InModuleScope Office365Tools { Find-SpoChromiumBrowser }
        $hasBrowser = $true
    }
    catch {
        Write-Verbose "No browser for the round trip tests: $($_.Exception.Message)"
    }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
    Set-O365Language -Language en -SessionOnly

    # The PnP commands are stood in for by functions that take anything, so they
    # can be mocked with plain objects whether or not PnP.PowerShell is
    # installed: its own commands refuse an argument that is not a SharePoint
    # list. A function wins over a cmdlet of the same name.
    $script:Stubbed = @()
    foreach ($name in 'Get-PnPView', 'Get-PnPField', 'Get-PnPProperty', 'Get-PnPWeb') {
        Set-Item -Path "function:global:$name" -Value { param($List, $Identity, $Includes, $ClientObject, $Property) }
        $script:Stubbed += $name
    }

    $script:StopSign = [char]::ConvertFromUtf32(0x26D4)
    $script:CheckMark = [char]::ConvertFromUtf32(0x2705)
}

AfterAll {
    foreach ($name in $script:Stubbed) { Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue }
    Set-O365Language -Language en -SessionOnly
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Rich text, as the text a cell shows' {

    It 'removes the tags and keeps each paragraph, bullet and number on its own line' {
        InModuleScope Office365Tools {
            $text = ConvertTo-SpoCellText -Html -Value '<p>a</p><ul><li>b</li></ul><ol><li>c</li></ol>'
            $lines = @($text -split "`n")

            $lines.Count | Should -Be 3
            $lines[0] | Should -Be 'a'
            $lines[1] | Should -Be "$([char]0x2022) b"
            $lines[2] | Should -Be '1. c'
            $text | Should -Not -Match '<'
        }
    }

    It 'indents a nested list' {
        InModuleScope Office365Tools {
            $text = ConvertTo-SpoCellText -Html -Value '<ul><li>outer<ul><li>inner</li></ul></li></ul>'
            @($text -split "`n")[1] | Should -Be "  $([char]0x2022) inner"
        }
    }

    It 'decodes entities and drops scripts, styles and event attributes' {
        InModuleScope Office365Tools {
            $text = ConvertTo-SpoCellText -Html -Value 'Tom &amp; Jo<script>x()</script><style>p{}</style><span onclick="y()">!</span>'
            $text | Should -Be 'Tom & Jo!'
        }
    }

    It 'turns a non-breaking space and a zero-width space into what a reader sees' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Html -Value "<p>a&nbsp;b</p><p>&#8203;</p><p>c</p>" | Should -Be "a b`nc"
        }
    }

    It 'treats a lone less-than sign as text' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Html -Value '<p>1 < 2</p>' | Should -Be '1 < 2'
        }
    }

    It 'leaves a plain string alone when it is not told it is HTML' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value '<p>a</p>' | Should -Be '<p>a</p>'
        }
    }
}

Describe 'Links inside rich text' {

    It 'keeps the caption and the address of a link' {
        InModuleScope Office365Tools {
            $content = ConvertFrom-SpoHtmlText -Html '<p>See <a href="https://example.org/x">Traktandum 6</a>.</p>'
            $linked = @($content.Segment | Where-Object Href)

            $linked.Count | Should -Be 1
            $linked[0].Href | Should -Be 'https://example.org/x'
            $linked[0].Text | Should -Be 'Traktandum 6'
            $content.Text | Should -Be 'See Traktandum 6.'
        }
    }

    It 'prints a link to anything but http, https, mailto and tel as text' {
        InModuleScope Office365Tools {
            $content = ConvertFrom-SpoHtmlText -Html '<a href="javascript:alert(1)">click</a> <a href="file:///C:/x">file</a>'

            @($content.Segment | Where-Object Href) | Should -BeNullOrEmpty
            $content.Text | Should -Be 'click file'
        }
    }

    It 'resolves a link relative to the site against the site address' {
        InModuleScope Office365Tools {
            $content = ConvertFrom-SpoHtmlText -SiteUrl 'https://contoso.sharepoint.com/sites/x' `
                -Html '<a href="/sites/x/Page.aspx">root</a> <a href="Lists/t/DispForm.aspx?ID=3">relative</a>'

            @($content.Segment | Where-Object Href | ForEach-Object Href) | Should -Be @(
                'https://contoso.sharepoint.com/sites/x/Page.aspx'
                'https://contoso.sharepoint.com/sites/x/Lists/t/DispForm.aspx?ID=3')
        }
    }

    It 'prints a relative link as text when there is no site to resolve it against' {
        InModuleScope Office365Tools {
            $content = ConvertFrom-SpoHtmlText -Html '<a href="/sites/x/Page.aspx">root</a>'

            @($content.Segment | Where-Object Href) | Should -BeNullOrEmpty
            $content.Text | Should -Be 'root'
        }
    }

    It 'does not link an anchor within the page' {
        InModuleScope Office365Tools {
            @((ConvertFrom-SpoHtmlText -Html '<a href="#top">up</a>').Segment | Where-Object Href) | Should -BeNullOrEmpty
        }
    }

    It 'is reported with its row and column when a table is rendered' {
        InModuleScope Office365Tools {
            $rows = @([pscustomobject]@{ Text = '<p>See <a href="https://example.org/x">Item 6</a></p>' })
            $render = ConvertTo-SpoPrintHtml -Row $rows -Column Text -RichText Text

            @($render.Link).Count | Should -Be 1
            $render.Link[0].Href | Should -Be 'https://example.org/x'
            $render.Html | Should -Match '<a href="https://example\.org/x">Item 6</a>'
        }
    }
}

Describe 'People' {

    It 'prints the display name, and several people one to a line' {
        InModuleScope Office365Tools {
            $people = @(
                [pscustomobject]@{ LookupValue = 'Name A'; Email = 'a@example.org' }
                [pscustomobject]@{ LookupValue = 'Name B'; Email = 'b@example.org' })

            (ConvertTo-SpoCellText -Value $people) | Should -Be "Name A`nName B"
            (ConvertTo-SpoCellContent -Value $people).Text | Should -Be "Name A`nName B"
        }
    }

    It 'prints a person with no display name by the account, or else the address' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value ([pscustomobject]@{ LookupValue = ''; Email = 'a@example.org'; LoginName = 'i:0#.f|m|a' }) |
                Should -Be 'i:0#.f|m|a'
            ConvertTo-SpoCellText -Value ([pscustomobject]@{ LookupValue = ''; Email = 'a@example.org' }) |
                Should -Be 'a@example.org'
        }
    }

    It 'links a name to the address when there is one, and a group has none' {
        InModuleScope Office365Tools {
            $content = ConvertTo-SpoCellContent -Value @(
                [pscustomobject]@{ LookupValue = 'Name A'; Email = 'a@example.org' }
                [pscustomobject]@{ LookupValue = 'Team'; Email = '' })

            $linked = @($content.Segment | Where-Object Href)
            $linked.Count | Should -Be 1
            $linked[0].Text | Should -Be 'Name A'
            $linked[0].Href | Should -Be 'mailto:a@example.org'
            $content.Text | Should -Not -Match 'a@example\.org'
        }
    }

    It 'leaves an ordinary lookup, which has no address, as it was' {
        InModuleScope Office365Tools {
            ConvertTo-SpoCellText -Value @(
                [pscustomobject]@{ LookupId = 1; LookupValue = 'Basel' }
                [pscustomobject]@{ LookupId = 2; LookupValue = 'Bern' }) | Should -Be 'Basel; Bern'
        }
    }
}

Describe 'The column type map' {

    # One value per kind of SharePoint column, as the module receives it. The
    # same table is in the issue, in docs/user/tools.md and in
    # docs/sandbox/printing.md.
    It 'prints a <Kind> as <Text>' -ForEach @(
        @{ Kind = 'single line of text'; Value = 'Titterten'; Text = 'Titterten'; Link = '' }
        @{ Kind = 'number'; Value = 42; Text = '42'; Link = '' }
        @{ Kind = 'choice, several allowed'; Value = @('Anna', 'Beat'); Text = 'Anna; Beat'; Link = '' }
        @{ Kind = 'multiple lines, plain'; Value = "eins`nzwei"; Text = "eins`nzwei"; Link = '' }
        @{ Kind = 'date'; Value = [datetime]'2026-11-21'; Text = '2026-11-21'; Link = '' }
        @{ Kind = 'date and time'; Value = [datetime]'2026-11-21 14:30'; Text = '2026-11-21 14:30'; Link = '' }
        @{ Kind = 'yes'; Value = $true; Text = 'Yes'; Link = '' }
        @{ Kind = 'no'; Value = $false; Text = 'No'; Link = '' }
        @{ Kind = 'lookup'; Value = [pscustomobject]@{ LookupId = 3; LookupValue = 'Basel' }; Text = 'Basel'; Link = '' }
        @{ Kind = 'lookup, several'; Value = @([pscustomobject]@{ LookupId = 3; LookupValue = 'Basel' }, [pscustomobject]@{ LookupId = 4; LookupValue = 'Bern' }); Text = 'Basel; Bern'; Link = '' }
        @{ Kind = 'managed metadata term'; Value = [pscustomobject]@{ Label = 'Gottesdienst'; TermGuid = [guid]::NewGuid() }; Text = 'Gottesdienst'; Link = '' }
        @{ Kind = 'hyperlink with a description'; Value = [pscustomobject]@{ Url = 'https://example.org/x'; Description = 'Ticket 42' }; Text = 'Ticket 42'; Link = '' }
        @{ Kind = 'hyperlink without one'; Value = [pscustomobject]@{ Url = 'https://example.org/x'; Description = '' }; Text = 'https://example.org/x'; Link = '' }
        @{ Kind = 'person'; Value = [pscustomobject]@{ LookupValue = 'Pat Example'; Email = 'pat@example.org' }; Text = 'Pat Example'; Link = 'mailto:pat@example.org' }
        @{ Kind = 'group'; Value = [pscustomobject]@{ LookupValue = 'Vorstand'; Email = '' }; Text = 'Vorstand'; Link = '' }
        @{ Kind = 'nothing'; Value = $null; Text = ''; Link = '' }
    ) {
        InModuleScope Office365Tools -Parameters @{ Value = $Value; Text = $Text; Link = $Link } {
            param($Value, $Text, $Link)
            $content = ConvertTo-SpoCellContent -Value $Value

            $content.Text | Should -Be $Text
            (ConvertTo-SpoCellText -Value $Value) | Should -Be $Text
            @($content.Segment | Where-Object Href | ForEach-Object Href) -join ' ' | Should -Be $Link
        }
    }

    It 'links a hyperlink column to its address when the page is rendered' {
        InModuleScope Office365Tools {
            $rows = @([pscustomobject]@{ Link = [pscustomobject]@{ Url = 'https://example.org/x'; Description = 'Ticket 42' } })
            $render = ConvertTo-SpoPrintHtml -Row $rows -Column Link

            $render.Html | Should -Match '<a href="https://example\.org/x">Ticket 42</a>'
        }
    }
}

Describe 'Column widths' {

    BeforeAll {
        $script:Records = @(
            [ordered]@{ Nr = '4,3'; Datum = "'25/07"; Beschluss = ('wort ' * 120).Trim(); Notiz = ('kurz ' * 20).Trim() }
            [ordered]@{ Nr = '12'; Datum = "'25/08"; Beschluss = ('wort ' * 100).Trim(); Notiz = '' }
        )
    }

    It 'gives a short column the width of its content, never more than 70 mm' {
        InModuleScope Office365Tools -Parameters @{ Records = $script:Records } {
            param($Records)
            $wide = @([ordered]@{ Name = 'x' * 44 })
            $width = Get-SpoColumnWidth -Record $Records -Column Nr, Datum

            [double]($width['Nr'] -replace 'mm$') | Should -BeLessThan 15
            [double]($width['Datum'] -replace 'mm$') | Should -BeLessThan 20
            [double]((Get-SpoColumnWidth -Record $wide -Column Name)['Name'] -replace 'mm$') | Should -BeLessOrEqual 70
        }
    }

    It 'gives a text column more room the more text it holds, within its limits' {
        InModuleScope Office365Tools -Parameters @{ Records = $script:Records } {
            param($Records)
            $width = Get-SpoColumnWidth -Record $Records -Column Nr, Datum, Beschluss, Notiz
            $beschluss = [double]($width['Beschluss'] -replace 'mm$')
            $notiz = [double]($width['Notiz'] -replace 'mm$')
            $printable = 297 - 24

            $beschluss | Should -BeGreaterThan $notiz
            $notiz | Should -BeGreaterOrEqual 25
            $beschluss | Should -BeLessOrEqual (0.6 * $printable + 0.1)
        }
    }

    It 'leaves a column named in -Fixed out of what it works out' {
        InModuleScope Office365Tools -Parameters @{ Records = $script:Records } {
            param($Records)
            $width = Get-SpoColumnWidth -Record $Records -Column Nr, Beschluss -Fixed @{ Beschluss = '40%' }

            $width.ContainsKey('Beschluss') | Should -BeFalse
            $width.ContainsKey('Nr') | Should -BeTrue
        }
    }

    It 'puts the widths on the columns of the printed table, and an explicit width wins' {
        InModuleScope Office365Tools -Parameters @{ Records = $script:Records } {
            param($Records)
            $rows = @($Records | ForEach-Object { [pscustomobject]$_ })

            $automatic = ConvertTo-SpoPrintHtml -Row $rows -Column Nr, Beschluss
            $automatic.Html | Should -Match '<col class="col-nr" style="width: [\d.]+mm">'
            $automatic.Html | Should -Match '<col class="col-beschluss" style="width: [\d.]+mm">'

            $explicit = ConvertTo-SpoPrintHtml -Row $rows -Column Nr, Beschluss -ColumnWidth @{ Beschluss = '40%' }
            $explicit.Html | Should -Match '<col class="col-beschluss" style="width: 40%">'
        }
    }

    It 'lets a long word with no spaces wrap inside its cell' {
        InModuleScope Office365Tools {
            $rows = @([pscustomobject]@{ Link = 'x' * 200 })
            $render = ConvertTo-SpoPrintHtml -Row $rows -Column Link

            $render.Html | Should -Match 'overflow-wrap: anywhere'
            $render.Html | Should -Not -Match 'white-space: nowrap'
        }
    }
}

Describe 'Many columns on one page' {

    BeforeAll {
        # Twelve columns shaped like a board's decision list: short ones with
        # long headings, and three long texts.
        $script:Wide = 1..6 | ForEach-Object {
            [pscustomobject]@{
                Nr = "$_"; Protokollziffer = "4.$_"; Beschlusstitel = "Titel $_ zur Finanzierung"; Verantwortung = 'Andreas Koenig'
                Sitzungseinladung = 'Link'; Besprechungsdatum = '2025-11-21'; Status = 'in Kraft (VS)'
                Einstieg = ('wort ' * (80 + $_ * 20)).Trim(); Inhalte = ('satz ' * (120 + $_ * 30)).Trim(); Beschluesse = ('text ' * (200 + $_ * 40)).Trim()
            }
        }
        $script:WideColumns = 'Nr', 'Protokollziffer', 'Beschlusstitel', 'Verantwortung', 'Sitzungseinladung', 'Besprechungsdatum', 'Status', 'Einstieg', 'Inhalte', 'Beschluesse'
    }

    It 'gives the text columns at least half the page between them' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Wide; Columns = $script:WideColumns } {
            param($Rows, $Columns)
            $records = foreach ($row in $Rows) { $record = [ordered]@{}; foreach ($name in $Columns) { $record[$name] = [string]$row.$name }; $record }
            $width = Get-SpoColumnWidth -Record @($records) -Column $Columns

            $text = 0.0
            foreach ($name in 'Einstieg', 'Inhalte', 'Beschluesse') { $text += [double]($width[$name] -replace 'mm$') }

            $text | Should -BeGreaterOrEqual (0.5 * 273 - 1)
        }
    }

    It 'never makes a date or a word narrower than the word itself' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Wide; Columns = $script:WideColumns } {
            param($Rows, $Columns)
            $records = foreach ($row in $Rows) { $record = [ordered]@{}; foreach ($name in $Columns) { $record[$name] = [string]$row.$name }; $record }
            $width = Get-SpoColumnWidth -Record @($records) -Column $Columns
            $charMm = 8.5 * 0.5 * 25.4 / 72

            # '2025-11-21' is ten characters that cannot be split.
            [double]($width['Besprechungsdatum'] -replace 'mm$') | Should -BeGreaterOrEqual (10 * $charMm)
            [double]($width['Verantwortung'] -replace 'mm$') | Should -BeGreaterOrEqual (7 * $charMm)
        }
    }

    It 'adds up to no more than the printable width' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Wide; Columns = $script:WideColumns } {
            param($Rows, $Columns)
            $records = foreach ($row in $Rows) { $record = [ordered]@{}; foreach ($name in $Columns) { $record[$name] = [string]$row.$name }; $record }
            $width = Get-SpoColumnWidth -Record @($records) -Column $Columns

            $sum = 0.0
            foreach ($name in $Columns) { $sum += [double]($width[$name] -replace 'mm$') }
            $sum | Should -BeLessOrEqual (273 + 1)
        }
    }

    It 'lowers the type until the columns fit, when no size was asked for' {
        InModuleScope Office365Tools {
            $rows = @([pscustomobject]@{ A = '1' }) | ForEach-Object {
                $row = [ordered]@{}
                1..30 | ForEach-Object { $row["Spalte$_"] = 'wert' }
                [pscustomobject]$row
            }
            $columns = 1..30 | ForEach-Object { "Spalte$_" }

            $reduced = ConvertTo-SpoPrintHtml -Row $rows -Column $columns
            $asked = ConvertTo-SpoPrintHtml -Row $rows -Column $columns -FontSize 8.5

            $reduced.FontSize | Should -BeLessThan 8.5
            $reduced.FontSize | Should -BeGreaterOrEqual 6
            $asked.FontSize | Should -Be 8.5
        }
    }

    It 'keeps the type as it is when the columns fit' {
        InModuleScope Office365Tools -Parameters @{ Rows = $script:Wide; Columns = $script:WideColumns } {
            param($Rows, $Columns)
            (ConvertTo-SpoPrintHtml -Row $Rows -Column $Columns).FontSize | Should -Be 8.5
        }
    }
}

Describe 'Test-SpoSplitText' {

    BeforeAll {
        $script:Needle = (1..13 | ForEach-Object { 'k{0:D3}' -f $_ }) -join ''
    }

    It 'finds a text that a page break cut in two' {
        InModuleScope Office365Tools -Parameters @{ Needle = $script:Needle } {
            param($Needle)
            $haystack = $Needle.Substring(0, 30) + 'headerrowothercells' + $Needle.Substring(30)

            Test-SpoSplitText -Needle $Needle -Haystack $haystack -MaxPart 2 | Should -BeTrue
        }
    }

    It 'allows no more pieces than there are pages' {
        InModuleScope Office365Tools -Parameters @{ Needle = $script:Needle } {
            param($Needle)
            $haystack = $Needle.Substring(0, 30) + 'headerrowothercells' + $Needle.Substring(30)

            Test-SpoSplitText -Needle $Needle -Haystack $haystack -MaxPart 1 | Should -BeFalse
        }
    }

    It 'does not accept a text that lost a stretch in the middle' {
        InModuleScope Office365Tools -Parameters @{ Needle = $script:Needle } {
            param($Needle)
            # Ten characters gone from the middle: the first piece is twelve.
            $haystack = $Needle.Substring(0, 12) + 'xx' + $Needle.Substring(22)

            Test-SpoSplitText -Needle $Needle -Haystack $haystack -MaxPart 5 | Should -BeFalse
        }
    }

    It 'does not accept a text whose end is missing' {
        InModuleScope Office365Tools -Parameters @{ Needle = $script:Needle } {
            param($Needle)
            Test-SpoSplitText -Needle $Needle -Haystack $Needle.Substring(0, 40) -MaxPart 5 | Should -BeFalse
        }
    }

    It 'is not tried on a text too short to cut' {
        InModuleScope Office365Tools {
            Test-SpoSplitText -Needle 'abc' -Haystack 'abc' -MaxPart 2 | Should -BeFalse
        }
    }
}

Describe 'The printed page' {

    It 'names an emoji-capable font' {
        InModuleScope Office365Tools {
            (ConvertTo-SpoPrintHtml -Row @([pscustomobject]@{ A = 'x' }) -Column A).Html | Should -Match 'Segoe UI Emoji'
        }
    }

    It 'prints the title, the time, who exported and why in one block, once' {
        InModuleScope Office365Tools {
            $rows = 1..30 | ForEach-Object { [pscustomobject]@{ Gruppe = "G$($_ % 3)"; A = "row $_" } }
            $render = ConvertTo-SpoPrintHtml -Row $rows -Column Gruppe, A -GroupBy Gruppe -Title 'Protokoll' `
                -ExportedBy 'Pat Example' -Reason 'Board meeting' -ExportedAt ([datetime]'2026-11-12 14:30') -Source 'Site / List / View'

            @([regex]::Matches($render.Html, 'class="docinfo"')).Count | Should -Be 1
            $render.Html | Should -Match '<h1>Protokoll</h1>'
            $render.Html | Should -Match '>Exported</span><span class="v">2026-11-12 14:30<'
            $render.Html | Should -Match '>Exported by</span><span class="v">Pat Example<'
            $render.Html | Should -Match '>Reason</span><span class="v">Board meeting<'
            $render.Html | Should -Match '>Source</span><span class="v">Site / List / View<'
            $render.Html | Should -Match '30 row\(s\), 2 column\(s\)'
            # Above the first table, and so not in the repeated header row.
            $render.Html.IndexOf('class="docinfo"') | Should -BeLessThan $render.Html.IndexOf('<table>')
        }
    }

    It 'leaves out the reason, and who, when there are none' {
        InModuleScope Office365Tools {
            $render = ConvertTo-SpoPrintHtml -Row @([pscustomobject]@{ A = 'x' }) -Column A -Source ''

            $render.Html | Should -Not -Match '>Reason<'
            $render.Html | Should -Not -Match '>Exported by<'
            $render.Html | Should -Not -Match '>Source<'
            $render.Html | Should -Match '>Exported<'
        }
    }

    It 'escapes what it prints in the block' {
        InModuleScope Office365Tools {
            $render = ConvertTo-SpoPrintHtml -Row @([pscustomobject]@{ A = 'x' }) -Column A -Reason '<b>x</b>' -ExportedBy '<i>me</i>'

            $render.Html | Should -Match '&lt;b&gt;x&lt;/b&gt;'
            $render.Html | Should -Match '&lt;i&gt;me&lt;/i&gt;'
            $render.Html | Should -Not -Match '<b>x</b>'
        }
    }

    It 'says its labels in German when German is in use' {
        Set-O365Language -Language de -SessionOnly
        try {
            InModuleScope Office365Tools {
                $render = ConvertTo-SpoPrintHtml -Row @([pscustomobject]@{ A = 'x' }) -Column A -Reason 'Grund x' -ExportedBy 'Pat'
                $render.Html | Should -Match '>Exportiert von<'
                $render.Html | Should -Match '>Grund<'
            }
        }
        finally {
            Set-O365Language -Language en -SessionOnly
        }
    }
}

Describe 'Emoji in the check of a PDF' {

    It 'drops an emoji from both sides, so the words around it are still compared' {
        InModuleScope Office365Tools -Parameters @{ Stop = $script:StopSign; Check = $script:CheckMark } {
            param($Stop, $Check)
            ConvertTo-SpoSearchText -Text "$Stop nicht erledigt" -KeepSpace | Should -Be 'nicht erledigt'
            ConvertTo-SpoSearchText -Text "$Check" | Should -Be ''
            ConvertTo-SpoSearchText -Text "ok $([char]::ConvertFromUtf32(0x1F44D)) gut" -KeepSpace | Should -Be 'ok gut'
        }
    }
}

Describe 'Finding a view by its name' {

    BeforeAll {
        $script:Alle = [guid]::NewGuid()
        $script:Offen = [guid]::NewGuid()
        $script:List = [pscustomobject]@{ Title = 'Protokoll' }

        $script:Views = @(
            [pscustomobject]@{ Id = [guid]::NewGuid(); Title = 'Zebra'; DefaultView = $false; Hidden = $false; PersonalView = $false; ViewFields = @('Title'); ViewQuery = '' }
            [pscustomobject]@{ Id = $script:Offen; Title = 'Offene Pendenzen'; DefaultView = $false; Hidden = $false; PersonalView = $false; ViewFields = @('Title', 'Status'); ViewQuery = '<Where><Eq><FieldRef Name="Status"/><Value Type="Text">offen</Value></Eq></Where>' }
            [pscustomobject]@{ Id = $script:Alle; Title = 'Alle Elemente'; DefaultView = $true; Hidden = $false; PersonalView = $false; ViewFields = @('Title'); ViewQuery = '' }
            [pscustomobject]@{ Id = [guid]::NewGuid(); Title = 'Intern'; DefaultView = $false; Hidden = $true; PersonalView = $false; ViewFields = @('Title'); ViewQuery = '' }
            [pscustomobject]@{ Id = [guid]::NewGuid(); Title = 'Meine'; DefaultView = $false; Hidden = $false; PersonalView = $true; ViewFields = @('Title'); ViewQuery = '' }
        )
    }

    It 'maps a title to the view and its id' {
        InModuleScope Office365Tools -Parameters @{ Views = $script:Views; List = $script:List; Offen = $script:Offen } {
            param($Views, $List, $Offen)
            Mock Get-PnPView { $Views }

            $view = Resolve-SpoView -List $List -Identity 'Offene Pendenzen'

            $view.Id | Should -Be $Offen
            $view.ViewFields | Should -Be @('Title', 'Status')
            $view.ViewQuery | Should -Match 'offen'
        }
    }

    It 'accepts the id as well, with or without braces' {
        InModuleScope Office365Tools -Parameters @{ Views = $script:Views; List = $script:List; Offen = $script:Offen } {
            param($Views, $List, $Offen)
            Mock Get-PnPView { $Views }

            (Resolve-SpoView -List $List -Identity "$Offen").Title | Should -Be 'Offene Pendenzen'
            (Resolve-SpoView -List $List -Identity "{$Offen}").Title | Should -Be 'Offene Pendenzen'
        }
    }

    It 'lists the views to choose between: default first, hidden and personal ones left out' {
        InModuleScope Office365Tools -Parameters @{ Views = $script:Views; List = $script:List } {
            param($Views, $List)
            Mock Get-PnPView { $Views }

            @(Resolve-SpoView -List $List | ForEach-Object Title) | Should -Be @('Alle Elemente', 'Offene Pendenzen', 'Zebra')
        }
    }

    It 'names the views there are when the name is not one of them' {
        InModuleScope Office365Tools -Parameters @{ Views = $script:Views; List = $script:List } {
            param($Views, $List)
            Mock Get-PnPView { $Views }

            { Resolve-SpoView -List $List -Identity 'Nope' } | Should -Throw -ExpectedMessage "*'Nope'*Alle Elemente, Offene Pendenzen, Zebra*"
        }
    }

    It 'is what Get-SpoListView returns for a library' {
        Mock -ModuleName Office365Tools Assert-SpoConnection { $true }
        Mock -ModuleName Office365Tools Resolve-SpoList { [pscustomobject]@{ Title = 'Protokoll' } }
        Mock -ModuleName Office365Tools Get-PnPView { $script:Views }

        @(Get-SpoListView -Library Protokoll).Count | Should -Be 3
        (Get-SpoListView -Library Protokoll -View 'Alle Elemente').DefaultView | Should -BeTrue
    }
}

Describe 'Export-SpoListPdf, given a view by name' {

    BeforeAll {
        $script:Folder = Join-Path ([System.IO.Path]::GetTempPath()) "o365-listpdf-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:Folder -ItemType Directory -Force | Out-Null
        $script:OffenId = [guid]::NewGuid()
    }

    AfterAll {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Mock -ModuleName Office365Tools Assert-SpoConnection { $true }
        Mock -ModuleName Office365Tools Resolve-SpoList { [pscustomobject]@{ Title = 'Protokoll'; Id = [guid]::NewGuid() } }
        Mock -ModuleName Office365Tools Get-PnPView {
            [pscustomobject]@{
                Id = $script:OffenId; Title = 'Offene Pendenzen'; DefaultView = $false; Hidden = $false; PersonalView = $false
                ViewFields = @('LinkTitle', 'Beschluss'); ViewQuery = '<OrderBy><FieldRef Name="ID"/></OrderBy>'
            }
        }
        Mock -ModuleName Office365Tools Get-PnPField {
            [pscustomobject]@{ InternalName = 'Title'; Title = 'Titel'; Hidden = $false; TypeAsString = 'Text'; SchemaXml = '<Field/>' }
            [pscustomobject]@{ InternalName = 'Beschluss'; Title = 'Beschluss'; Hidden = $false; TypeAsString = 'Note'; SchemaXml = '<Field RichText="TRUE" />' }
        }
        Mock -ModuleName Office365Tools Get-PnPWeb { [pscustomobject]@{ CurrentUser = [pscustomobject]@{ Title = 'Pat Example' } } }
        Mock -ModuleName Office365Tools Export-SpoListItem {
            [pscustomobject]@{ ID = 1; Title = 'Erster'; Beschluss = '<p>Siehe <a href="https://example.org/p">Planner</a></p>' }
        }
        Mock -ModuleName Office365Tools Invoke-SpoBrowserPrint { [pscustomobject]@{ Browser = 'test' } }
    }

    It 'reads the columns and the query of the view the name belongs to, with people kept as objects' {
        $result = Export-SpoListPdf -Library Protokoll -View 'Offene Pendenzen' -Path (Join-Path $script:Folder 'a.pdf') -SkipVerification

        $result.Printed | Should -BeTrue
        Should -Invoke -ModuleName Office365Tools Export-SpoListItem -Times 1 -Exactly -ParameterFilter {
            $Structured -and $Query -like '*OrderBy*' -and $Field -contains 'Title' -and $Field -contains 'Beschluss'
        }
    }

    It 'says who exported and why, from the sign-in and the parameter, and names the view' {
        $path = Join-Path $script:Folder 'b.pdf'
        $result = Export-SpoListPdf -Library Protokoll -View "{$($script:OffenId)}" -Path $path -SkipVerification -KeepHtml -Reason 'Board meeting'
        $html = Get-Content -LiteralPath $result.HtmlPath -Raw -Encoding utf8

        $result.ExportedBy | Should -Be 'Pat Example'
        $html | Should -Match '>Exported by</span><span class="v">Pat Example<'
        $html | Should -Match '>Reason</span><span class="v">Board meeting<'
        $html | Should -Match 'Protokoll - Offene Pendenzen'
        $html | Should -Match '<a href="https://example\.org/p">Planner</a>'
    }

    It 'takes -ExportedBy over the signed-in user' {
        $result = Export-SpoListPdf -Library Protokoll -Path (Join-Path $script:Folder 'c.pdf') -SkipVerification -ExportedBy 'Someone Else'

        $result.ExportedBy | Should -Be 'Someone Else'
        Should -Invoke -ModuleName Office365Tools Get-PnPWeb -Times 0 -Exactly
    }

    It 'stops and names the views when the name is not one of them, and writes nothing' {
        Mock -ModuleName Office365Tools Get-PnPView { [pscustomobject]@{ Id = [guid]::NewGuid(); Title = 'Alle'; DefaultView = $true; Hidden = $false; PersonalView = $false; ViewFields = @('Title'); ViewQuery = '' } }
        $path = Join-Path $script:Folder 'd.pdf'

        { Export-SpoListPdf -Library Protokoll -View 'Nope' -Path $path -SkipVerification } | Should -Throw -ExpectedMessage "*'Nope'*Alle*"
        Test-Path -LiteralPath $path | Should -BeFalse
    }
}

Describe 'What a real browser makes of it' {

    BeforeAll {
        $script:Dir = Join-Path ([System.IO.Path]::GetTempPath()) "o365-listpdf-rt-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:Dir -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        if ($script:Dir -and (Test-Path -LiteralPath $script:Dir)) { Remove-Item -LiteralPath $script:Dir -Recurse -Force }
    }

    It 'prints a text of 3000 characters in full' -Skip:(-not $hasBrowser) {
        $long = (1..430 | ForEach-Object { 'wort{0:D3}' -f $_ }) -join ' '
        $long.Length | Should -BeGreaterThan 3000

        $pdf = Join-Path $script:Dir 'long.pdf'
        $render = InModuleScope Office365Tools -Parameters @{ Long = $long; Pdf = $pdf; Dir = $script:Dir } {
            param($Long, $Pdf, $Dir)
            $r = ConvertTo-SpoPrintHtml -Row @([pscustomobject]@{ Nr = '1'; Text = $Long }) -Column Nr, Text
            $html = Join-Path $Dir 'long.html'
            Set-Content -LiteralPath $html -Value $r.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $r
        }

        $read = InModuleScope Office365Tools -Parameters @{ Pdf = $pdf } { param($Pdf) ConvertFrom-SpoPdfText -Path $Pdf -NoExternal }
        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell -Attestation $render.Attestation -ExpectedRowCount 1 -NoExternalReader)

        (($read.Text -replace '\s+', '').Contains(($long -replace '\s+', ''))) | Should -BeTrue
        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    }

    It 'prints emoji, links and people together, and every one of them checks out' -Skip:(-not $hasBrowser) {
        $rich = "<p>$($script:StopSign) nicht erledigt</p><p>$($script:CheckMark) erledigt</p><ul><li>Beratung <a href=""https://example.org/planner/1"">Planner - Slogans</a></li></ul>"
        $rows = @(
            [pscustomobject]@{ Nr = '1'; Wer = @([pscustomobject]@{ LookupValue = 'Raphael Beispiel'; Email = 'r@example.org' }, [pscustomobject]@{ LookupValue = 'Joel Muster'; Email = '' }); Text = $rich }
            [pscustomobject]@{ Nr = '2'; Wer = $null; Text = 'ohne alles' }
        )

        $pdf = Join-Path $script:Dir 'mixed.pdf'
        $render = InModuleScope Office365Tools -Parameters @{ Rows = $rows; Pdf = $pdf; Dir = $script:Dir } {
            param($Rows, $Pdf, $Dir)
            $r = ConvertTo-SpoPrintHtml -Row $Rows -Column Nr, Wer, Text -RichText Text -ExportedBy 'Pat Example' -Reason 'Quartalsbericht'
            $html = Join-Path $Dir 'mixed.html'
            Set-Content -LiteralPath $html -Value $r.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $r
        }

        $inPdf = @(InModuleScope Office365Tools -Parameters @{ Pdf = $pdf } { param($Pdf) Get-SpoPdfLink -Path $Pdf })
        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell -Link $render.Link `
                -Attestation $render.Attestation -ExpectedRowCount $render.RowCount -NoExternalReader)

        $inPdf | Should -Contain 'https://example.org/planner/1'
        $inPdf | Should -Contain 'mailto:r@example.org'
        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
        @($findings | Where-Object RuleId -in 'Pdf.NoTextLayer', 'Pdf.ExtractionSuspect') | Should -BeNullOrEmpty
    }

    It 'checks a cell taller than a page, which continues on the next one' -Skip:(-not $hasBrowser) {
        # Far more than a page of text in one narrow cell, beside another column.
        $tall = (1..1500 | ForEach-Object { 'satz{0:D4}' -f $_ }) -join ' '
        $rows = @([pscustomobject]@{ Nr = '1'; Text = $tall; Daneben = 'kurz' }, [pscustomobject]@{ Nr = '2'; Text = 'ein kurzer Text'; Daneben = 'auch kurz' })
        $pdf = Join-Path $script:Dir 'tall.pdf'

        $render = InModuleScope Office365Tools -Parameters @{ Rows = $rows; Pdf = $pdf; Dir = $script:Dir } {
            param($Rows, $Pdf, $Dir)
            $r = ConvertTo-SpoPrintHtml -Row $Rows -Column Nr, Text, Daneben
            $html = Join-Path $Dir 'tall.html'
            Set-Content -LiteralPath $html -Value $r.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $r
        }

        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell -Attestation $render.Attestation -ExpectedRowCount 2 -NoExternalReader)
        $read = InModuleScope Office365Tools -Parameters @{ Pdf = $pdf } { param($Pdf) ConvertFrom-SpoPdfText -Path $Pdf -NoExternal }

        $read.PageCount | Should -BeGreaterThan 1
        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    }

    It 'still reports a value that is not in a document of several pages' -Skip:(-not $hasBrowser) {
        $pdf = Join-Path $script:Dir 'tall.pdf'
        if (-not (Test-Path -LiteralPath $pdf)) { Set-ItResult -Skipped -Because 'the print in the previous test did not run'; return }

        $lost = (1..300 | ForEach-Object { 'fehlt{0:D4}' -f $_ }) -join ' '
        $absent = @([pscustomobject]@{ Row = 1; Column = 'Text'; Text = $lost })
        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $absent -NoExternalReader)

        @($findings | Where-Object RuleId -eq 'Pdf.MissingValue').Count | Should -Be 1
    }

    It 'finds a link whose address the browser wrote differently' -Skip:(-not $hasBrowser) {
        $rows = @([pscustomobject]@{ Nr = '1'; Text = '<p>Siehe <a href="https://example.org/ein Pfad/Seite.aspx?a=b c">die Seite</a></p>' })
        $pdf = Join-Path $script:Dir 'spaces.pdf'

        $render = InModuleScope Office365Tools -Parameters @{ Rows = $rows; Pdf = $pdf; Dir = $script:Dir } {
            param($Rows, $Pdf, $Dir)
            $r = ConvertTo-SpoPrintHtml -Row $Rows -Column Nr, Text -RichText Text
            $html = Join-Path $Dir 'spaces.html'
            Set-Content -LiteralPath $html -Value $r.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
            $r
        }

        $findings = @(Test-SpoPdfContent -Path $pdf -Cell $render.Cell -Link $render.Link -Attestation $render.Attestation -ExpectedRowCount 1 -NoExternalReader)

        @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    }

    It 'prints the header block on the first page only' -Skip:(-not $hasBrowser) {
        $rows = 1..120 | ForEach-Object { [pscustomobject]@{ Nr = "$_"; Text = "Zeile $_ mit etwas Text, damit die Seite voll wird" } }
        $pdf = Join-Path $script:Dir 'pages.pdf'

        InModuleScope Office365Tools -Parameters @{ Rows = $rows; Pdf = $pdf; Dir = $script:Dir } {
            param($Rows, $Pdf, $Dir)
            $r = ConvertTo-SpoPrintHtml -Row $Rows -Column Nr, Text -ExportedBy 'Pat Example' -Reason 'Einmalig genannt'
            $html = Join-Path $Dir 'pages.html'
            Set-Content -LiteralPath $html -Value $r.Html -Encoding utf8
            $null = Invoke-SpoBrowserPrint -HtmlPath $html -Path $Pdf
        }

        $read = InModuleScope Office365Tools -Parameters @{ Pdf = $pdf } { param($Pdf) ConvertFrom-SpoPdfText -Path $Pdf -NoExternal }

        $read.PageCount | Should -BeGreaterThan 1
        @([regex]::Matches($read.Text, 'Einmalig genannt')).Count | Should -Be 1
    }
}
