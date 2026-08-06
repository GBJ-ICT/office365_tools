<#
    Profile store tests.

    These redirect the store to a temporary file via the module's
    $script:O365ProfilePathOverride, so they never touch the developer's real
    config/profiles.json. Everything lives under one Describe because Pester
    requires per-test setup to sit inside a block.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Profile store' {

    BeforeEach {
        $script:TempStore = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-test-$([guid]::NewGuid()).json"
        InModuleScope Office365Tools -Parameters @{ Path = $script:TempStore } {
            param($Path)
            $script:O365ProfilePathOverride = $Path
        }
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempStore) {
            Remove-Item -LiteralPath $script:TempStore -Force
        }
        InModuleScope Office365Tools { $script:O365ProfilePathOverride = $null }
    }

    Context 'Set-O365Profile' {

        It 'creates the store file' {
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/a' `
                -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            Test-Path -LiteralPath $script:TempStore | Should -BeTrue
        }

        It 'writes a profile that Get-O365Profile reads back' {
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/a' `
                -ClientId '11111111-2222-3333-4444-555555555555' -Tenant 'contoso.onmicrosoft.com' `
                -Description 'Production' | Out-Null

            $result = Get-O365Profile -Name prod
            $result.Name        | Should -Be 'prod'
            $result.SiteUrl     | Should -Be 'https://contoso.sharepoint.com/sites/a'
            $result.ClientId    | Should -Be '11111111-2222-3333-4444-555555555555'
            $result.Tenant      | Should -Be 'contoso.onmicrosoft.com'
            $result.Description | Should -Be 'Production'
        }

        It 'makes the first profile the default automatically' {
            Set-O365Profile -Name only -SiteUrl 'https://contoso.sharepoint.com/sites/a' `
                -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            (Get-O365Profile -Name only).IsDefault | Should -BeTrue
        }

        It 'does not steal the default from an existing profile' {
            Set-O365Profile -Name first -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name second -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' | Out-Null

            (Get-O365Profile -Name first).IsDefault | Should -BeTrue
            (Get-O365Profile -Name second).IsDefault | Should -BeFalse
        }

        It 'moves the default when -SetDefault is given' {
            Set-O365Profile -Name first -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name second -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' -SetDefault | Out-Null

            (Get-O365Profile -Name first).IsDefault | Should -BeFalse
            (Get-O365Profile -Name second).IsDefault | Should -BeTrue
        }

        It 'updates an existing profile in place' {
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/old' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/new' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            @(Get-O365Profile).Count | Should -Be 1
            (Get-O365Profile -Name prod).SiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/new'
        }

        It 'rejects a site URL that is not https' {
            { Set-O365Profile -Name bad -SiteUrl 'http://contoso.sharepoint.com/sites/a' `
                    -ClientId '11111111-2222-3333-4444-555555555555' } | Should -Throw
        }

        It 'rejects a client ID that is not a GUID' {
            { Set-O365Profile -Name bad -SiteUrl 'https://contoso.sharepoint.com/sites/a' `
                    -ClientId 'not-a-guid' } | Should -Throw
        }

        It 'writes nothing with -WhatIf' {
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/a' `
                -ClientId '11111111-2222-3333-4444-555555555555' -WhatIf | Out-Null

            Test-Path -LiteralPath $script:TempStore | Should -BeFalse
        }
    }

    Context 'Get-O365Profile' {

        It 'warns and returns nothing when no store exists' {
            Get-O365Profile -WarningAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'lists every profile' {
            Set-O365Profile -Name a -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name b -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' | Out-Null

            @(Get-O365Profile).Count | Should -Be 2
        }

        It 'filters by wildcard' {
            Set-O365Profile -Name prod-eu -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name prod-us -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name test -SiteUrl 'https://contoso.sharepoint.com/sites/c' -ClientId '33333333-2222-3333-4444-555555555555' | Out-Null

            @(Get-O365Profile -Name 'prod-*').Count | Should -Be 2
        }
    }

    Context 'Remove-O365Profile' {

        It 'removes the named profile' {
            Set-O365Profile -Name a -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null
            Set-O365Profile -Name b -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' | Out-Null

            Remove-O365Profile -Name a -Confirm:$false

            @(Get-O365Profile).Name | Should -Be 'b'
        }

        It 'hands the default to the sole survivor' {
            Set-O365Profile -Name a -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' -SetDefault | Out-Null
            Set-O365Profile -Name b -SiteUrl 'https://contoso.sharepoint.com/sites/b' -ClientId '22222222-2222-3333-4444-555555555555' | Out-Null

            Remove-O365Profile -Name a -Confirm:$false

            (Get-O365Profile -Name b).IsDefault | Should -BeTrue
        }

        It 'warns rather than throwing for an unknown profile' {
            Set-O365Profile -Name a -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            { Remove-O365Profile -Name nope -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
            @(Get-O365Profile).Count | Should -Be 1
        }

        It 'removes nothing with -WhatIf' {
            Set-O365Profile -Name a -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            Remove-O365Profile -Name a -WhatIf

            @(Get-O365Profile).Count | Should -Be 1
        }
    }

    Context 'Connect-O365 profile resolution' {

        It 'fails with a helpful message when no store exists' {
            { Connect-O365 } | Should -Throw '*profiles.example.json*'
        }

        It 'fails naming the available profiles when the requested one is missing' {
            Set-O365Profile -Name prod -SiteUrl 'https://contoso.sharepoint.com/sites/a' -ClientId '11111111-2222-3333-4444-555555555555' | Out-Null

            { Connect-O365 -ProfileName nope } | Should -Throw '*prod*'
        }
    }
}
