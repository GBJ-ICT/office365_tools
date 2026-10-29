<#
    Tests that scripts/Test-Upload.ps1, the checker behind the upload checker,
    speaks the language it is given and writes its reports in it.

    It runs the script as the launcher does, under PowerShell 7 with -File, in
    pre-flight and offline, so no tenant and no sign-in is needed. The folder it
    checks holds a few files that each trip a different rule.

    Every run gets a settings file of its own through O365_SETTINGS_PATH, so none
    of them changes the language saved on the machine it runs on.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Script = Join-Path $script:RepoRoot 'scripts/Test-Upload.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path

    $script:Folder = Join-Path ([System.IO.Path]::GetTempPath()) "o365chk-$([guid]::NewGuid().ToString('N'))"
    $script:Upload = Join-Path $script:Folder 'to-upload'
    New-Item -Path $script:Upload -ItemType Directory -Force | Out-Null

    # An empty file (a warning), a Thumbs.db (information) and an executable
    # (information). The long target prefix below makes every path too long,
    # which is an error.
    New-Item -Path (Join-Path $script:Upload 'empty.txt') -ItemType File | Out-Null
    Set-Content -LiteralPath (Join-Path $script:Upload 'Thumbs.db') -Value 'junk'
    Set-Content -LiteralPath (Join-Path $script:Upload 'setup.exe') -Value 'binary'
    Set-Content -LiteralPath (Join-Path $script:Upload 'fine.docx') -Value 'text'

    $script:LongPrefix = '/sites/team/' + ('Folder/' * 55)

    function Invoke-Check {
        param(
            [string]$Language,
            [string]$EnvironmentLanguage,
            [switch]$TooLong
        )

        $output = Join-Path $script:Folder "out-$([guid]::NewGuid().ToString('N'))"
        $settings = Join-Path $script:Folder "settings-$([guid]::NewGuid().ToString('N')).json"

        $arguments = @('-NoProfile', '-File', $script:Script, '-LocalPath', $script:Upload, '-OutputPath', $output, '-AlwaysReport')
        if ($TooLong) { $arguments += @('-TargetPathPrefix', $script:LongPrefix) } else { $arguments += @('-Offline') }
        if ($Language) { $arguments += @('-Language', $Language) }

        $saved = @{ Language = $env:O365_LANGUAGE; Path = $env:O365_SETTINGS_PATH }
        try {
            $env:O365_LANGUAGE = $EnvironmentLanguage
            $env:O365_SETTINGS_PATH = $settings

            $text = & $script:Pwsh @arguments 2>&1 | Out-String
            [pscustomobject]@{ Text = $text; Code = $LASTEXITCODE; Output = $output; Settings = $settings }
        }
        finally {
            $env:O365_LANGUAGE = $saved.Language
            $env:O365_SETTINGS_PATH = $saved.Path
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Test-Upload.ps1, the console' {

    It 'speaks English when asked' {
        $result = Invoke-Check -Language 'en'

        $result.Text | Should -BeLike '*Pre-flight:*'
        $result.Text | Should -BeLike '*4 file(s)*'
        $result.Text | Should -BeLike '*Path length not checked*'
        $result.Text | Should -BeLike '*Nothing was changed, locally or in SharePoint.*'
    }

    It 'speaks German when asked' {
        $result = Invoke-Check -Language 'de'

        $result.Text | Should -BeLike '*Vorabpr*fung:*'
        $result.Text | Should -BeLike '*4 Datei(en)*'
        $result.Text | Should -BeLike '*Pfadl*nge nicht gepr*ft*'
        $result.Text | Should -BeLike '*Es wurde nichts ver*ndert, weder lokal noch in SharePoint.*'
        $result.Text | Should -Not -BeLike '*Nothing was changed*'
    }

    It 'lets -Language beat a language set in the environment' {
        $result = Invoke-Check -Language 'de' -EnvironmentLanguage 'en'

        $result.Text | Should -BeLike '*Vorabpr*fung:*'
    }

    It 'follows the environment when no language is given' {
        $result = Invoke-Check -EnvironmentLanguage 'de'

        $result.Text | Should -BeLike '*Vorabpr*fung:*'
    }

    It 'leaves the saved choice alone, in either language' {
        $result = Invoke-Check -Language 'de'

        Test-Path -LiteralPath $result.Settings | Should -BeFalse
    }

    It 'rejects a language it does not know' {
        $result = Invoke-Check -Language 'fr'

        $result.Code | Should -Not -Be 0
    }

    It 'ends with the exit code that says what was found, in either language' {
        (Invoke-Check -Language 'en').Code | Should -Be 0
        (Invoke-Check -Language 'de' -TooLong).Code | Should -Be 1
    }

    It 'says what is wrong with a path that is too long, in German' {
        $result = Invoke-Check -Language 'de' -TooLong

        $result.Text | Should -BeLike '*Upload.PathWouldExceed*'
        $result.Text | Should -BeLike '*Fehler*'
        $result.Text | Should -BeLike '*Behebe zuerst die Fehler*'
    }
}

Describe 'Test-Upload.ps1, the report and the findings' {

    It 'titles the report in English, and labels its summary in English' {
        $result = Invoke-Check -Language 'en'
        $html = Get-Content -LiteralPath (Join-Path $result.Output 'preflight.html') -Raw

        $html | Should -BeLike '*Before uploading -- 4 file(s)*'
        $html | Should -BeLike '*Folder checked*'
        $html | Should -BeLike '*Blocked types*'
    }

    It 'titles the report in German, and labels its summary in German' {
        $result = Invoke-Check -Language 'de'
        $html = Get-Content -LiteralPath (Join-Path $result.Output 'preflight.html') -Raw -Encoding utf8

        $html | Should -BeLike '*Vor dem Hochladen -- 4 Datei(en)*'
        $html | Should -BeLike '*Gepr*fter Ordner*'
        $html | Should -BeLike '*Gesperrte Typen*'
    }

    It 'words the findings in the language, and keeps the rule names as they are' {
        $result = Invoke-Check -Language 'de' -TooLong
        $csv = Import-Csv -LiteralPath (Join-Path $result.Output 'findings.csv') -Encoding utf8

        $empty = $csv | Where-Object RuleId -eq 'Upload.EmptyFile'
        $empty.Message | Should -BeLike 'Die Datei ist leer*'

        ($csv | Where-Object RuleId -eq 'Upload.PathWouldExceed').Count | Should -BeGreaterThan 0
    }

    It 'gives the same rule names, headers and file names in German as in English' {
        $english = Invoke-Check -Language 'en' -TooLong
        $german = Invoke-Check -Language 'de' -TooLong

        $en = Import-Csv -LiteralPath (Join-Path $english.Output 'findings.csv')
        $de = Import-Csv -LiteralPath (Join-Path $german.Output 'findings.csv') -Encoding utf8

        # The same columns, the same rules in the same order. Only the message differs.
        ($de[0].PSObject.Properties.Name -join ',') | Should -Be ($en[0].PSObject.Properties.Name -join ',')
        ($de.RuleId -join ',') | Should -Be ($en.RuleId -join ',')
        $de.Message -join '|' | Should -Not -Be ($en.Message -join '|')

        # Names that come from the data are not translated.
        $names = ($de | ForEach-Object { $_.PSObject.Properties.Value }) -join ' '
        $names | Should -BeLike '*setup.exe*'
        $names | Should -BeLike '*empty.txt*'
    }

    It 'words the same findings in English when asked' {
        $result = Invoke-Check -Language 'en' -TooLong
        $csv = Import-Csv -LiteralPath (Join-Path $result.Output 'findings.csv')

        ($csv | Where-Object RuleId -eq 'Upload.EmptyFile').Message | Should -BeLike 'File is empty*'
    }
}
