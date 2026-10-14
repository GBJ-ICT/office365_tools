<#
    Messages of module commands that can be run without a tenant, in both
    languages. The tables are checked as a whole in Language.Tests.ps1; this is
    about what a person actually reads when one of these commands speaks.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
    Set-O365Language -Language en -SessionOnly
}

AfterAll {
    Set-O365Language -Language en -SessionOnly
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Test-SpoPdfContent, a PDF that is not there' {

    BeforeAll {
        $script:Missing = Join-Path ([System.IO.Path]::GetTempPath()) "o365-no-such-$([guid]::NewGuid()).pdf"
    }

    It 'says so in English, and names the rule' {
        Set-O365Language -Language en -SessionOnly

        $finding = @(Test-SpoPdfContent -Path $script:Missing -Row ([pscustomobject]@{ Name = 'x' }))[0]

        $finding.RuleId | Should -Be 'Pdf.Missing'
        $finding.Message | Should -Be 'The PDF does not exist, so nothing about its contents can be checked.'
    }

    It 'says so in German, with the rule name unchanged' {
        Set-O365Language -Language de -SessionOnly

        $finding = @(Test-SpoPdfContent -Path $script:Missing -Row ([pscustomobject]@{ Name = 'x' }))[0]

        $finding.RuleId | Should -Be 'Pdf.Missing'
        $finding.Message | Should -BeLike 'Das PDF gibt es nicht*'
    }
}

Describe 'The messages that name a command or a parameter' {

    It 'keeps the names in a German sentence, so the advice can be followed' {
        Set-O365Language -Language de -SessionOnly

        $message = Get-O365String 'ContentType.AddField.NoSiteColumn' 'Priority'

        $message | Should -BeLike '*New-SpoField*'
        $message | Should -BeLike '*Get-SpoField*'
        $message | Should -BeLike "*'Priority'*"
    }

    It 'keeps the placeholders in the right place in both languages' {
        Set-O365Language -Language en -SessionOnly
        $english = Get-O365String 'ListItem.Update.Action' 42 'fields: Status'
        Set-O365Language -Language de -SessionOnly
        $german = Get-O365String 'ListItem.Update.Action' 42 'Felder: Status'

        $english | Should -Be 'Update item 42 (fields: Status)'
        $german | Should -Be 'Element 42 aktualisieren (Felder: Status)'
    }
}
