<#
    Tests for finding the application (client) ID to sign in with.

    The lookup is shared with the double-click launcher
    (src/Office365Tools/Private/Shared/ClientId.ps1), so it is tested here
    without the module.
#>

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
