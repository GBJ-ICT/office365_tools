<#
    Naming rules run entirely offline, so they get the most thorough coverage
    in the suite. Every rule these tests pin down is one that would otherwise
    only be discovered when a real upload failed.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Test-SpoFileName' {

    Context 'acceptable names' {

        It 'emits nothing for <Candidate>' -ForEach @(
            @{ Candidate = 'report.docx' }
            @{ Candidate = 'Q1 budget 2026.xlsx' }
            @{ Candidate = 'Angebot_Müller-GmbH.pdf' }
            @{ Candidate = 'notes' }
            @{ Candidate = 'a' }
            @{ Candidate = 'file.with.many.dots.txt' }
            @{ Candidate = "O'Brien contract.docx" }
            @{ Candidate = 'data (final) [v2].csv' }
        ) {
            Test-SpoFileName -Name $Candidate | Should -BeNullOrEmpty
        }
    }

    Context 'illegal characters' {

        It 'flags <Candidate> containing <Character>' -ForEach @(
            @{ Candidate = 'a"b.txt'; Character = '"' }
            @{ Candidate = 'a*b.txt'; Character = '*' }
            @{ Candidate = 'a:b.txt'; Character = ':' }
            @{ Candidate = 'a<b.txt'; Character = '<' }
            @{ Candidate = 'a>b.txt'; Character = '>' }
            @{ Candidate = 'a?b.txt'; Character = '?' }
            @{ Candidate = 'a/b.txt'; Character = '/' }
            @{ Candidate = 'a\b.txt'; Character = '\' }
            @{ Candidate = 'a|b.txt'; Character = '|' }
        ) {
            $findings = @(Test-SpoFileName -Name $Candidate)
            $findings.RuleId | Should -Contain 'FileName.IllegalCharacter'
            ($findings | Where-Object RuleId -eq 'FileName.IllegalCharacter').Severity | Should -Be 'Error'
        }

        It 'reports every illegal character it finds' {
            $findings = @(Test-SpoFileName -Name 'a:b?c*d.txt')
            $finding = $findings | Where-Object RuleId -eq 'FileName.IllegalCharacter'
            $finding.Detail.Characters | Should -HaveCount 3
        }
    }

    Context 'whitespace and periods' {

        It 'flags a leading space' {
            @(Test-SpoFileName -Name ' report.docx').RuleId | Should -Contain 'FileName.LeadingSpace'
        }

        It 'flags a trailing space' {
            @(Test-SpoFileName -Name 'report.docx ').RuleId | Should -Contain 'FileName.TrailingSpace'
        }

        It 'flags a trailing period' {
            @(Test-SpoFileName -Name 'report.').RuleId | Should -Contain 'FileName.TrailingPeriod'
        }

        It 'flags a trailing period even behind trailing whitespace' {
            @(Test-SpoFileName -Name 'report. ').RuleId | Should -Contain 'FileName.TrailingPeriod'
        }

        It 'does not flag interior spaces' {
            @(Test-SpoFileName -Name 'my report.docx') |
                Where-Object RuleId -eq 'FileName.LeadingSpace' | Should -BeNullOrEmpty
        }
    }

    Context 'reserved names and prefixes' {

        It 'flags reserved name <Candidate>' -ForEach @(
            @{ Candidate = 'CON' }
            @{ Candidate = 'PRN' }
            @{ Candidate = 'AUX' }
            @{ Candidate = 'NUL' }
            @{ Candidate = 'COM1' }
            @{ Candidate = 'LPT9' }
            @{ Candidate = '.lock' }
            @{ Candidate = 'desktop.ini' }
        ) {
            @(Test-SpoFileName -Name $Candidate).RuleId | Should -Contain 'FileName.ReservedName'
        }

        It 'flags a reserved stem even with an extension' {
            @(Test-SpoFileName -Name 'CON.txt').RuleId | Should -Contain 'FileName.ReservedName'
        }

        It 'flags the Office lock-file prefix' {
            @(Test-SpoFileName -Name '~$budget.xlsx').RuleId | Should -Contain 'FileName.ReservedPrefix'
        }

        It 'flags the _vti_ prefix' {
            @(Test-SpoFileName -Name '_vti_config').RuleId | Should -Contain 'FileName.ReservedPrefix'
        }

        It 'does not flag a name that merely contains a reserved word' {
            @(Test-SpoFileName -Name 'CONTRACT.docx') |
                Where-Object RuleId -eq 'FileName.ReservedName' | Should -BeNullOrEmpty
        }
    }

    Context 'length' {

        It 'accepts a 255 character name' {
            $name = 'a' * 255
            @(Test-SpoFileName -Name $name) |
                Where-Object RuleId -eq 'FileName.TooLong' | Should -BeNullOrEmpty
        }

        It 'flags a 256 character name' {
            $name = 'a' * 256
            @(Test-SpoFileName -Name $name).RuleId | Should -Contain 'FileName.TooLong'
        }
    }

    Context 'risky characters' {

        It 'ignores # and % by default' {
            @(Test-SpoFileName -Name 'report #1 (50%).docx') |
                Where-Object RuleId -eq 'FileName.RiskyCharacter' | Should -BeNullOrEmpty
        }

        It 'reports # and % with -IncludeRisky' {
            $findings = @(Test-SpoFileName -Name 'report #1 (50%).docx' -IncludeRisky)
            $findings.RuleId | Should -Contain 'FileName.RiskyCharacter'
            ($findings | Where-Object RuleId -eq 'FileName.RiskyCharacter').Severity | Should -Be 'Info'
        }
    }

    Context 'pipeline and shape' {

        It 'accepts names from the pipeline' {
            $findings = @('ok.docx', 'bad?.docx', 'also bad*.docx' | Test-SpoFileName)
            $findings | Should -HaveCount 2
        }

        It 'emits findings carrying the standard type name' {
            $finding = @(Test-SpoFileName -Name 'bad?.docx')[0]
            $finding.PSObject.TypeNames | Should -Contain 'Office365Tools.Finding'
        }

        It 'sets Target to the name in offline mode' {
            $finding = @(Test-SpoFileName -Name 'bad?.docx')[0]
            $finding.Target | Should -Be 'bad?.docx'
        }

        It 'populates RuleId, Severity, Scope and Message on every finding' {
            foreach ($finding in (Test-SpoFileName -Name ' bad?.docx ')) {
                $finding.RuleId   | Should -Not -BeNullOrEmpty
                $finding.Severity | Should -BeIn @('Error', 'Warning', 'Info')
                $finding.Scope    | Should -Not -BeNullOrEmpty
                $finding.Message  | Should -Not -BeNullOrEmpty
            }
        }

        It 'requires no SharePoint connection' {
            # The whole point of the offline mode: this must not throw even
            # though nothing has connected.
            { Test-SpoFileName -Name 'anything.docx' } | Should -Not -Throw
        }
    }
}
