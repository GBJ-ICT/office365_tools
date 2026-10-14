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

    # The menu test ends at the point where the application ID is missing. If
    # this machine has one in its environment or a profile, the launcher would
    # carry on and sign in, so that test is skipped there.
    $idElsewhere = [bool](
        ('Process', 'User', 'Machine' | ForEach-Object { [Environment]::GetEnvironmentVariable('gbj_client_id', $_) } | Where-Object { $_ }) -or
        (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../../config/profiles.json')))

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
        param(
            [string]$Xml,
            [string]$Language,
            [string]$Folder = $script:Upload,
            [string[]]$Answer,
            [switch]$NoWindow,
            [string]$SettingsFile,
            [string]$ReportFolder
        )

        $settings = Join-Path $script:Folder 'upload-check.xml'
        [System.IO.File]::WriteAllText($settings, $Xml, (New-Object System.Text.UTF8Encoding($false)))

        # Without answers it never asks (-NoPrompt); with answers, they are typed
        # for it, as a person would.
        # -NoWindow starts it in a multi-threaded apartment, where a window
        # cannot be drawn, so the questions come up in the console instead.
        $arguments = @('-NoProfile')
        if ($NoWindow) { $arguments += '-MTA' }
        $arguments += @('-ExecutionPolicy', 'Bypass', '-File', $script:Script, '-SettingsPath', $settings)
        if ($Folder) { $arguments += @('-Folder', $Folder) }
        if ($ReportFolder) { $arguments += @('-ReportFolder', $ReportFolder) }
        if (-not $Answer) { $arguments += '-NoPrompt' }

        # The saved language is the person's own file. These runs write to a file
        # of their own unless the test says otherwise, so a test never changes
        # the real one.
        if (-not $SettingsFile) { $SettingsFile = Join-Path $script:Folder 'saved-settings.json' }

        $saved = $env:O365_LANGUAGE
        $savedPath = $env:O365_SETTINGS_PATH
        try {
            $env:O365_LANGUAGE = $Language
            $env:O365_SETTINGS_PATH = $SettingsFile
            if ($Answer) {
                $output = $Answer | & powershell.exe @arguments 2>&1
            }
            else {
                $output = & powershell.exe @arguments 2>&1
            }
            [pscustomobject]@{ Text = ($output | Out-String); Code = $LASTEXITCODE }
        }
        finally {
            $env:O365_LANGUAGE = $saved
            $env:O365_SETTINGS_PATH = $savedPath
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

Describe 'The upload checker launcher, asking its questions' -Skip:(-not $canRunWindowsPowerShell) {

    BeforeAll {
        $script:Plain = '<UploadCheck><Folder>ask</Folder></UploadCheck>'

        # Names a destination but no application ID, so a run that chooses to
        # check what arrived stops at the message about the missing ID.
        $script:WithDestination = '<UploadCheck><Destination>https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest</Destination></UploadCheck>'
    }

    It 'says in English that no folder was chosen' {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'en' -Folder ''

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*No folder was chosen*'
    }

    It 'says in German that no folder was chosen' {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'de' -Folder ''

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*kein Ordner gew*'
    }

    It 'says in English that the folder does not exist, and names it' {
        $missing = Join-Path $script:Folder 'not-there'
        $result = Invoke-Launcher -Xml $script:Plain -Language 'en' -Folder $missing

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*That folder does not exist*'
        $result.Text | Should -BeLike "*$missing*"
    }

    It 'says in German that the folder does not exist, and names it' {
        $missing = Join-Path $script:Folder 'not-there'
        $result = Invoke-Launcher -Xml $script:Plain -Language 'de' -Folder $missing

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*Diesen Ordner gibt es nicht*'
        $result.Text | Should -BeLike "*$missing*"
    }

    It 'shows the folder it will check, in English' {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer '2'

        $result.Text | Should -BeLike '*Folder:  *to-upload*'
    }

    It 'shows the folder it will check, in German' {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'de' -Answer '2'

        $result.Text | Should -BeLike '*Ordner:  *to-upload*'
    }

    It 'offers the three choices in English' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer '2'

        $result.Text | Should -BeLike '*What would you like to do?*'
        $result.Text | Should -BeLike '*1) Check this folder before I upload it*'
        $result.Text | Should -BeLike '*2) I uploaded it already*'
        $result.Text | Should -BeLike '*3) Both*'
    }

    It 'offers the three choices in German, and does not mix in English' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'de' -Answer '2'

        $result.Text | Should -BeLike '*Was m*chtest du tun?*'
        $result.Text | Should -BeLike '*1) Diesen Ordner pr*'
        $result.Text | Should -BeLike '*2) Ich habe ihn schon hochgeladen*'
        $result.Text | Should -BeLike '*3) Beides*'
        $result.Text | Should -Not -BeLike '*What would you like to do*'
    }

    It 'goes on to the question about signing in, which needs the application ID' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'de' -Answer '2'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*Anwendungs-ID*'
    }
}

Describe 'The upload checker launcher, asking in the console where a window cannot open' -Skip:(-not $canRunWindowsPowerShell) {

    BeforeAll {
        $script:Plain = '<UploadCheck><Folder>ask</Folder></UploadCheck>'
        $script:Address = 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest'
    }

    It 'asks for the folder in English' {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'en' -Folder '' -NoWindow -Answer $script:Upload, '1'

        $result.Text | Should -BeLike '*Which folder are you uploading to SharePoint?*'
        $result.Text | Should -BeLike '*Folder:*'
    }

    It 'asks for the folder in German' {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'de' -Folder '' -NoWindow -Answer $script:Upload, '1'

        $result.Text | Should -BeLike '*Welchen Ordner l*dst du nach SharePoint hoch?*'
        $result.Text | Should -BeLike '*Ordner:*'
    }

    It 'asks for the address in English' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'en' -Folder '' -NoWindow -Answer $script:Upload, '2', $script:Address

        $result.Text | Should -BeLike '*Copy the address out of your browser and paste it here.*'
        $result.Text | Should -BeLike '*Right-click pastes into this window.*'
        $result.Text | Should -BeLike '*Destination: https://contoso*'
    }

    It 'asks for the address in German' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:Plain -Language 'de' -Folder '' -NoWindow -Answer $script:Upload, '2', $script:Address

        $result.Text | Should -BeLike '*Kopiere die Adresse aus deinem Browser*'
        $result.Text | Should -BeLike '*Ein Rechtsklick f*gt in dieses Fenster ein.*'
        $result.Text | Should -BeLike '*Ziel: https://contoso*'
        $result.Text | Should -Not -BeLike '*Right-click pastes*'
    }
}

Describe 'The upload checker launcher, offering a language' -Skip:(-not $canRunWindowsPowerShell) {

    BeforeAll {
        $script:WithDestination = '<UploadCheck><Destination>https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest</Destination></UploadCheck>'
    }

    BeforeEach {
        $script:Saved = Join-Path $script:Folder "saved-$([guid]::NewGuid().ToString('N')).json"
    }

    It 'shows the language in use, in English' {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer '2' -SettingsFile $script:Saved

        $result.Text | Should -BeLike '*Language: English*L = change*'
    }

    It 'shows the language in use, in German' {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'de' -Answer '2' -SettingsFile $script:Saved

        $result.Text | Should -BeLike '*Sprache: Deutsch*L = *ndern*'
    }

    It 'switches to German on L and 2, shows the menu again in German, and remembers it' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer 'l', '2', '2' -SettingsFile $script:Saved

        $result.Text | Should -BeLike '*Which language?*'
        $result.Text | Should -BeLike '*What would you like to do?*Was m*chtest du tun?*'
        $result.Text | Should -BeLike '*Anwendungs-ID*'
        (Get-Content -LiteralPath $script:Saved -Raw | ConvertFrom-Json).language | Should -Be 'de'
    }

    It 'switches to English on L and 1, and remembers it' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'de' -Answer 'l', '1', '2' -SettingsFile $script:Saved

        $result.Text | Should -BeLike '*Welche Sprache?*'
        $result.Text | Should -BeLike '*Was m*chtest du tun?*What would you like to do?*'
        $result.Text | Should -BeLike '*Application ID*'
        (Get-Content -LiteralPath $script:Saved -Raw | ConvertFrom-Json).language | Should -Be 'en'
    }

    It 'remembers following Windows as auto' -Skip:$idElsewhere {
        Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer 'l', '3', '2' -SettingsFile $script:Saved | Out-Null

        (Get-Content -LiteralPath $script:Saved -Raw | ConvertFrom-Json).language | Should -Be 'auto'
    }

    It 'keeps the language, and saves nothing, when Enter is pressed at the question' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer 'l', '', '2' -SettingsFile $script:Saved

        $result.Text | Should -BeLike '*Which language?*'
        $result.Text | Should -Not -BeLike '*Was m*chtest du tun?*'
        Test-Path -LiteralPath $script:Saved | Should -BeFalse
    }

    It 'carries on in the new language, and says so, when the choice cannot be saved' -Skip:$idElsewhere {
        $blocker = Join-Path $script:Folder 'blocker'
        Set-Content -LiteralPath $blocker -Value 'a file'

        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -Answer 'l', '2', '2' `
            -SettingsFile (Join-Path $blocker 'settings.json')

        # Said in the language just chosen, which is the one the rest of the run uses.
        $result.Text | Should -BeLike '*konnte aber nicht in*gespeichert werden*'
        $result.Text | Should -BeLike '*Was m*chtest du tun?*'
    }

    It 'does not offer it when the settings file already says what to do' -Skip:$idElsewhere {
        $xml = '<UploadCheck><Mode>Verify</Mode><Destination>https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest</Destination></UploadCheck>'

        $result = Invoke-Launcher -Xml $xml -Language 'en' -Answer 'l' -SettingsFile $script:Saved

        $result.Text | Should -Not -BeLike '*L = change*'
        $result.Text | Should -Not -BeLike '*Which language?*'
    }

    It 'does not offer it when it is told not to ask' {
        $result = Invoke-Launcher -Xml $script:WithDestination -Language 'en' -SettingsFile $script:Saved

        $result.Text | Should -Not -BeLike '*L = change*'
    }
}

Describe 'The upload checker launcher, handing its language to the checker' -Skip:(-not $canRunWindowsPowerShell) {

    BeforeAll {
        # Checks the folder for real, offline: no sign-in, and nothing to find in
        # an empty folder, so it ends with "nothing to fix".
        $script:PreFlight = '<UploadCheck><Mode>PreFlight</Mode></UploadCheck>'
    }

    It 'has the checker report in English when the launcher is in English' {
        $reports = Join-Path $script:Folder "reports-$([guid]::NewGuid().ToString('N'))"
        $result = Invoke-Launcher -Xml $script:PreFlight -Language 'en' -ReportFolder $reports

        $result.Code | Should -Be 0
        $result.Text | Should -BeLike '*Pre-flight:*'
        $result.Text | Should -BeLike '*Ready to upload.*'
    }

    It 'has the checker report in German when the launcher is in German' {
        $reports = Join-Path $script:Folder "reports-$([guid]::NewGuid().ToString('N'))"
        $result = Invoke-Launcher -Xml $script:PreFlight -Language 'de' -ReportFolder $reports

        $result.Code | Should -Be 0
        $result.Text | Should -BeLike '*Vorabpr*fung:*'
        $result.Text | Should -BeLike '*Bereit zum Hochladen.*'
        $result.Text | Should -BeLike '*starte die Pr*fung nochmals*'
    }
}