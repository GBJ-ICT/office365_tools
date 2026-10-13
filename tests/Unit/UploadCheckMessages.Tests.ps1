<#
    Tests that the upload checker launcher reports a bad settings file in the
    language that was chosen.

    It runs the launcher script under Windows PowerShell 5.1, which is how a
    person starts it, with a settings file that is wrong in one particular way.
    Each case checks the English and the German wording, and the exit code the
    launcher uses for "something to fix in the setup".

    The language is fixed with the O365_LANGUAGE environment variable of the
    child process, so these do not depend on the language of the machine they
    run on or on a language the person saved.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -ForEach and -Skip on the tests below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    $canRunWindowsPowerShell = [bool](Get-Command powershell.exe -ErrorAction SilentlyContinue)

    # What each wrong settings file says, in each language. Fragments are ASCII
    # so the comparison does not depend on how the console encodes umlauts.
    $cases = @(
        @{
            Name    = 'a setting it does not know'
            Xml     = '<UploadCheck><Folder>ask</Folder><Colour>blue</Colour></UploadCheck>'
            English = 'do not recognise'
            German  = 'Einstellung, die ich nicht kenne'
        }
        @{
            Name    = 'a target named the old way'
            Xml     = '<UploadCheck><SiteUrl>https://contoso.sharepoint.com</SiteUrl></UploadCheck>'
            English = 'names the target the old way'
            German  = 'noch auf die alte Art'
        }
        @{
            Name    = 'a mode it does not know'
            Xml     = '<UploadCheck><Mode>sometimes</Mode></UploadCheck>'
            English = 'PreFlight, Verify, Both or ask'
            German  = 'PreFlight, Verify, Both oder ask'
        }
        @{
            Name    = 'a number that is not a number'
            Xml     = '<UploadCheck><Mode>PreFlight</Mode><WarnAt>lots</WarnAt></UploadCheck>'
            English = 'has to be a whole number'
            German  = 'muss eine ganze Zahl sein'
        }
        @{
            Name    = 'a language it does not know'
            Xml     = '<UploadCheck><Language>fr</Language></UploadCheck>'
            English = 'en, de or auto'
            German  = 'en, de oder auto'
        }
        @{
            Name    = 'a file that is not an upload checker file'
            Xml     = '<Something><Folder>ask</Folder></Something>'
            English = 'is not an upload checker settings file'
            German  = 'keine Einstellungsdatei der Upload-Pr'
        }
        @{
            Name    = 'a file that is not valid XML'
            Xml     = '<UploadCheck><Folder>ask</UploadCheck'
            English = 'could not be read'
            German  = 'konnte nicht gelesen werden'
        }
    )
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Script = Join-Path $script:RepoRoot 'packaging/UploadCheck/Start-UploadCheck.ps1'

    $script:Folder = Join-Path ([System.IO.Path]::GetTempPath()) "o365msg-$([guid]::NewGuid().ToString('N'))"
    $script:Upload = Join-Path $script:Folder 'to-upload'
    New-Item -Path $script:Upload -ItemType Directory -Force | Out-Null

    function Invoke-Launcher {
        param([string]$Xml, [string]$Language)

        $settings = Join-Path $script:Folder 'upload-check.xml'
        [System.IO.File]::WriteAllText($settings, $Xml, (New-Object System.Text.UTF8Encoding($false)))

        $saved = $env:O365_LANGUAGE
        try {
            $env:O365_LANGUAGE = $Language
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:Script `
                -Folder $script:Upload -SettingsPath $settings -NoPrompt 2>&1
            [pscustomobject]@{ Text = ($output | Out-String); Code = $LASTEXITCODE }
        }
        finally {
            $env:O365_LANGUAGE = $saved
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'The upload checker launcher, given a settings file that is wrong' -Skip:(-not $canRunWindowsPowerShell) {

    It 'says <Name> in English' -ForEach $cases {
        $result = Invoke-Launcher -Xml $Xml -Language 'en'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike "*$English*"
    }

    It 'says <Name> in German' -ForEach $cases {
        $result = Invoke-Launcher -Xml $Xml -Language 'de'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike "*$German*"
    }

    It 'does not show German to someone who chose English' -ForEach $cases {
        $result = Invoke-Launcher -Xml $Xml -Language 'en'

        $result.Text | Should -Not -BeLike "*$German*"
    }
}
