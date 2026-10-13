<#
    Tests for finding the application (client) ID to sign in with, and for the
    upload checker's launcher reporting what it found.

    The lookup is shared with the double-click launcher
    (src/Office365Tools/Private/Shared/ClientId.ps1), so most of this runs
    without the module. The last Describe runs the launcher script itself under
    Windows PowerShell 5.1, which is how a person starts it.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -Skip on the tests below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    # Decided while the tests are being found, because -Skip is read then. If this
    # machine has the ID in its environment, or a profile, the launcher would
    # find it and there would be nothing missing to report.
    $idElsewhere = [bool](
        ('Process', 'User', 'Machine' | ForEach-Object { [Environment]::GetEnvironmentVariable('gbj_client_id', $_) } | Where-Object { $_ }) -or
        (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../../config/profiles.json')))
    $canRunWindowsPowerShell = [bool](Get-Command powershell.exe -ErrorAction SilentlyContinue)
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    . (Join-Path $script:RepoRoot 'src/Office365Tools/Private/Shared/ClientId.ps1')

    $script:Id = '11111111-2222-3333-4444-555555555555'
    $script:OtherId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'

    function Get-ScratchFolder {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) "o365id-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        $path
    }
}

Describe 'Finding the application ID' {

    BeforeEach {
        $script:Folder = Get-ScratchFolder
        $script:Profiles = Join-Path $script:Folder 'profiles.json'
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'takes the settings file before everything else' {
        Set-Content -LiteralPath $script:Profiles -Value (@{ defaultProfile = 'p'; profiles = @{ p = @{ clientId = $script:OtherId } } } | ConvertTo-Json -Depth 5)

        $result = Resolve-O365ClientId -Configured $script:Id -Environment $script:OtherId -ProfilePath $script:Profiles

        $result.ClientId | Should -Be $script:Id
        $result.Source | Should -Be 'Settings'
    }

    It 'takes the environment variable when the settings file has none' {
        $result = Resolve-O365ClientId -Configured '' -Environment $script:Id -ProfilePath $script:Profiles

        $result.ClientId | Should -Be $script:Id
        $result.Source | Should -Be 'Environment'
    }

    It 'takes the default profile when nothing else has one' {
        Set-Content -LiteralPath $script:Profiles -Value (@{
                defaultProfile = 'prod'
                profiles       = @{ prod = @{ clientId = $script:Id }; test = @{ clientId = $script:OtherId } }
            } | ConvertTo-Json -Depth 5)

        $result = Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles

        $result.ClientId | Should -Be $script:Id
        $result.Source | Should -Be 'Profile'
    }

    It 'finds nothing when nothing has one' {
        Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles | Should -BeNullOrEmpty
    }

    It 'trims a value pasted with spaces around it' {
        (Resolve-O365ClientId -Configured "  $($script:Id)  " -Environment '').ClientId | Should -Be $script:Id
    }

    Context 'a profile file that is no use' {

        It 'is ignored when it is not valid JSON' {
            Set-Content -LiteralPath $script:Profiles -Value 'not { json'

            Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles | Should -BeNullOrEmpty
        }

        It 'is ignored when it names no default profile' {
            Set-Content -LiteralPath $script:Profiles -Value (@{ profiles = @{ p = @{ clientId = $script:Id } } } | ConvertTo-Json -Depth 5)

            Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles | Should -BeNullOrEmpty
        }

        It 'is ignored when the default profile does not exist' {
            Set-Content -LiteralPath $script:Profiles -Value (@{ defaultProfile = 'gone'; profiles = @{ p = @{ clientId = $script:Id } } } | ConvertTo-Json -Depth 5)

            Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles | Should -BeNullOrEmpty
        }

        It 'is ignored when the default profile has no clientId' {
            Set-Content -LiteralPath $script:Profiles -Value (@{ defaultProfile = 'p'; profiles = @{ p = @{ siteUrl = 'https://x' } } } | ConvertTo-Json -Depth 5)

            Resolve-O365ClientId -Configured '' -Environment '' -ProfilePath $script:Profiles | Should -BeNullOrEmpty
        }
    }

    Context 'the environment variable' {

        It 'is read from the process' {
            $saved = [Environment]::GetEnvironmentVariable('O365_TEST_CLIENT_ID', 'Process')
            try {
                [Environment]::SetEnvironmentVariable('O365_TEST_CLIENT_ID', $script:Id, 'Process')

                Get-O365EnvironmentValue -Name 'O365_TEST_CLIENT_ID' | Should -Be $script:Id
            }
            finally {
                [Environment]::SetEnvironmentVariable('O365_TEST_CLIENT_ID', $saved, 'Process')
            }
        }

        It 'is nothing when it is not set anywhere' {
            Get-O365EnvironmentValue -Name 'O365_TEST_SURELY_NOT_SET' | Should -BeNullOrEmpty
        }
    }
}

Describe 'The upload checker launcher, run as a person runs it' -Skip:(-not $canRunWindowsPowerShell) {

    BeforeAll {
        $script:Script = Join-Path $script:RepoRoot 'packaging/UploadCheck/Start-UploadCheck.ps1'
        $script:Folder = Get-ScratchFolder
        $script:Upload = Join-Path $script:Folder 'to-upload'
        New-Item -Path $script:Upload -ItemType Directory | Out-Null

        # A settings file that names a destination but no application ID, set to
        # check what arrived: the case that needs the ID.
        $script:Xml = Join-Path $script:Folder 'upload-check.xml'
        Set-Content -LiteralPath $script:Xml -Value @'
<?xml version="1.0" encoding="utf-8"?>
<UploadCheck>
  <Mode>Verify</Mode>
  <Destination>https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FTest</Destination>
  <ClientId></ClientId>
</UploadCheck>
'@

        function Invoke-Launcher {
            param([string]$Language)

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:Script `
                -Folder $script:Upload -SettingsPath $script:Xml -NoPrompt -Language $Language 2>&1
            [pscustomobject]@{ Text = ($output | Out-String); Code = $LASTEXITCODE }
        }
    }

    AfterAll {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'says what is missing, in English, and stops with the setup exit code' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Language 'en'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*Application ID*'
        $result.Text | Should -BeLike '*gbj_client_id*'
        $result.Text | Should -BeLike '*profiles.json*'
    }

    It 'says it in German when German is asked for' -Skip:$idElsewhere {
        $result = Invoke-Launcher -Language 'de'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*Anwendungs-ID*'
        $result.Text | Should -Not -BeLike '*Application ID*'
    }

    It 'rejects a language it does not know' {
        $result = Invoke-Launcher -Language 'fr'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*en, de or auto*'
    }
}
