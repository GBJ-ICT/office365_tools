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

    $script:StopSign = [char]::ConvertFromUtf32(0x26D4)
    $script:CheckMark = [char]::ConvertFromUtf32(0x2705)
}

AfterAll {
    Set-O365Language -Language en -SessionOnly
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
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
}
