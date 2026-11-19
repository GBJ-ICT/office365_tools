<#
    Tests that the tool menu (packaging/Start-Tool.ps1) speaks the chosen
    language and lets it be changed, run the way a person runs it under Windows
    PowerShell 5.1.

    The numbered list is used rather than the window (OFFICE365TOOLS_CONSOLE),
    so the questions can be answered from a script. The window itself is built
    and inspected in Launcher.Tests.ps1.

    Every run gets a settings file of its own through O365_SETTINGS_PATH, so none
    of them changes the language saved on the machine it runs on.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -Skip on the tests below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    $canRunWindowsPowerShell = [bool](Get-Command powershell.exe -ErrorAction SilentlyContinue)

    # Some runs end where the application ID is missing. If this machine has one
    # in its environment or a profile, the launcher would carry on and sign in.
    $idElsewhere = [bool](
        ('Process', 'User', 'Machine' | ForEach-Object { [Environment]::GetEnvironmentVariable('gbj_client_id', $_) } | Where-Object { $_ }) -or
        (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../../config/profiles.json')))
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Script = Join-Path $script:RepoRoot 'packaging/Start-Tool.ps1'

    $script:Folder = Join-Path ([System.IO.Path]::GetTempPath()) "o365menu-$([guid]::NewGuid().ToString('N'))"
    $script:Upload = Join-Path $script:Folder 'to-upload'
    New-Item -Path $script:Upload -ItemType Directory -Force | Out-Null

    # Beside the launcher, where the menu looks for the tool's settings. It names
    # a destination and a mode but no application ID, so a run that starts the
    # upload checker stops at the message about it.
    $script:LauncherPath = Join-Path $script:Folder 'Check-Upload.cmd'
    [System.IO.File]::WriteAllText((Join-Path $script:Folder 'upload-check.xml'), @'
<UploadCheck>
  <Mode>Verify</Mode>
  <Destination>https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest</Destination>
</UploadCheck>
'@, (New-Object System.Text.UTF8Encoding($false)))

    function Invoke-Menu {
        param(
            [string]$Language,
            [string[]]$Answer = @('2'),
            [string]$SettingsFile,
            [string]$Tool
        )

        if (-not $SettingsFile) { $SettingsFile = Join-Path $script:Folder "saved-$([guid]::NewGuid().ToString('N')).json" }

        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:Script,
            '-Root', $script:RepoRoot, '-LauncherPath', $script:LauncherPath, '-Dropped', $script:Upload)
        if ($Tool) { $arguments += @('-Tool', $Tool) }

        $saved = @{
            Language = $env:O365_LANGUAGE
            Path     = $env:O365_SETTINGS_PATH
            Console  = $env:OFFICE365TOOLS_CONSOLE
        }
        try {
            $env:O365_LANGUAGE = $Language
            $env:O365_SETTINGS_PATH = $SettingsFile
            $env:OFFICE365TOOLS_CONSOLE = '1'

            $output = $Answer | & powershell.exe @arguments 2>&1
            [pscustomobject]@{ Text = ($output | Out-String); Code = $LASTEXITCODE; Settings = $SettingsFile }
        }
        finally {
            $env:O365_LANGUAGE = $saved.Language
            $env:O365_SETTINGS_PATH = $saved.Path
            $env:OFFICE365TOOLS_CONSOLE = $saved.Console
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'The tool menu, as a numbered list' -Skip:(-not $canRunWindowsPowerShell) {

    It 'asks in English, and names the tool in English' {
        $result = Invoke-Menu -Language 'en'

        $result.Text | Should -BeLike '*What would you like to do?*'
        $result.Text | Should -BeLike '*1) SharePoint list to PDF*'
        $result.Text | Should -BeLike '*2) Upload checker*'
        $result.Text | Should -BeLike '*Language: English*L = change*'
    }

    It 'asks in German, and names the tool in German' {
        $result = Invoke-Menu -Language 'de'

        $result.Text | Should -BeLike '*Was m*chtest du tun?*'
        $result.Text | Should -BeLike '*1) SharePoint-Liste als PDF*'
        $result.Text | Should -BeLike '*2) Upload-Pr*fung*'
        $result.Text | Should -BeLike '*Sprache: Deutsch*'
        $result.Text | Should -Not -BeLike '*What would you like to do?*'
    }

    It 'describes the tool in the language in use' {
        (Invoke-Menu -Language 'en').Text | Should -BeLike '*Check a folder before uploading it to SharePoint*'
        (Invoke-Menu -Language 'de').Text | Should -BeLike '*Pr*fe einen Ordner, bevor du ihn nach SharePoint*'
    }

    It 'describes the list-to-PDF tool in the language in use' {
        (Invoke-Menu -Language 'en').Text | Should -BeLike '*Print a SharePoint list, or one of its views, to a PDF*'
        (Invoke-Menu -Language 'de').Text | Should -BeLike '*Druckt eine SharePoint-Liste oder eine ihrer Ansichten als PDF*'
    }

    It 'starts the list-to-PDF tool when 1 is chosen, in the language it was asked in' {
        # The upload checker's settings are not read: this is the other tool.
        # It is stopped by what it lacks (no site address, no sign-in details),
        # which is said in the chosen language.
        $german = Invoke-Menu -Language 'de' -Answer '1'
        $english = Invoke-Menu -Language 'en' -Answer '1'

        $german.Text | Should -BeLike '*list-to-pdf.xml*'
        $english.Text | Should -BeLike '*list-to-pdf.xml*'
        $english.Text | Should -Not -BeLike '*upload-check.xml*'
    }

    It 'starts the tool in the language it was asked in' -Skip:$idElsewhere {
        $german = Invoke-Menu -Language 'de'
        $english = Invoke-Menu -Language 'en'

        $german.Code | Should -Be 2
        $german.Text | Should -BeLike '*Anwendungs-ID*'
        $english.Text | Should -BeLike '*Application ID*'
    }

    It 'changes language on L and 2, draws the list again in German, and remembers it' -Skip:$idElsewhere {
        $result = Invoke-Menu -Language 'en' -Answer 'l', '2', '2'

        $result.Text | Should -BeLike '*What would you like to do?*Which language?*Was m*chtest du tun?*'
        $result.Text | Should -BeLike '*Anwendungs-ID*'
        (Get-Content -LiteralPath $result.Settings -Raw | ConvertFrom-Json).language | Should -Be 'de'
    }

    It 'keeps the language when Enter is pressed at the question' {
        $result = Invoke-Menu -Language 'en' -Answer 'l', '', '2'

        $result.Text | Should -BeLike '*Which language?*'
        $result.Text | Should -Not -BeLike '*Was m*chtest du tun?*'
        Test-Path -LiteralPath $result.Settings | Should -BeFalse
    }

    It 'still starts the tool in the new language when the choice cannot be saved' -Skip:$idElsewhere {
        $blocker = Join-Path $script:Folder 'blocker'
        Set-Content -LiteralPath $blocker -Value 'a file'

        $result = Invoke-Menu -Language 'en' -Answer 'l', '2', '2' -SettingsFile (Join-Path $blocker 'settings.json')

        $result.Text | Should -BeLike '*konnte aber nicht in*gespeichert werden*'
        $result.Text | Should -BeLike '*Anwendungs-ID*'
    }
}

Describe 'The tool menu, when it cannot go on' -Skip:(-not $canRunWindowsPowerShell) {

    It 'says in English that a pinned tool is not there' {
        $result = Invoke-Menu -Language 'en' -Tool 'NoSuchTool'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*"NoSuchTool"*does not have that*'
    }

    It 'says in German that a pinned tool is not there' {
        $result = Invoke-Menu -Language 'de' -Tool 'NoSuchTool'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*"NoSuchTool"*enth*lt das nicht*'
        $result.Text | Should -Not -BeLike '*does not have that*'
    }
}
