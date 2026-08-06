<#
    These tests enforce the conventions in CONTRIBUTING.md mechanically.

    They are the reason a new contributor can add a command without reading a
    style guide first: if the command is missing help, uses an unapproved verb,
    or mutates the tenant without -WhatIf, CI says so.

    Note the BeforeDiscovery block. Pester evaluates -ForEach while *discovering*
    tests, which happens before BeforeAll runs -- so the module has to be
    imported at discovery time for the command list to exist.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -ForEach on the It blocks below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    $moduleCommands = Get-Command -Module Office365Tools | Sort-Object Name

    $allCommands = @($moduleCommands | ForEach-Object { @{ Name = $_.Name; Verb = $_.Verb; Noun = $_.Noun } })

    $mutating = $moduleCommands | Where-Object {
        $_.Verb -in 'Add', 'New', 'Remove', 'Set', 'Update', 'Import', 'Repair', 'Sync', 'Grant', 'Revoke', 'Disconnect', 'Publish'
    }
    $mutatingCommands = @($mutating | ForEach-Object { @{ Name = $_.Name } })

    $readOnly = $moduleCommands | Where-Object { $_.Verb -in 'Get', 'Find', 'Test', 'Compare' }
    $readOnlyCommands = @($readOnly | ForEach-Object { @{ Name = $_.Name } })
}

BeforeAll {
    $script:ManifestPath = Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1'
    Import-Module $script:ManifestPath -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {

    It 'is a valid manifest' {
        { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports every function listed in FunctionsToExport' {
        $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
        $exported = @(Get-Command -Module Office365Tools).Name

        foreach ($name in $manifest.FunctionsToExport) {
            $exported | Should -Contain $name -Because "the manifest promises $name"
        }
    }

    It 'does not export anything the manifest omits' {
        $manifest = Import-PowerShellDataFile -Path $script:ManifestPath

        foreach ($command in (Get-Command -Module Office365Tools)) {
            $manifest.FunctionsToExport | Should -Contain $command.Name -Because "$($command.Name) is exported but undeclared"
        }
    }

    It 'exports at least one command' {
        @(Get-Command -Module Office365Tools).Count | Should -BeGreaterThan 0
    }
}

Describe 'Command naming' {

    It '<Name> uses an approved verb' -ForEach $allCommands {
        (Get-Verb).Verb | Should -Contain $Verb
    }

    It '<Name> uses a recognised noun prefix' -ForEach $allCommands {
        # Spo for SharePoint-specific operations, O365 for module-level
        # concerns (connection, profiles, logging).
        $Noun | Should -Match '^(Spo|O365)' -Because 'nouns must be prefixed so they do not collide with other modules'
    }
}

Describe 'Command help' {

    It '<Name> has a synopsis distinct from its syntax' -ForEach $allCommands {
        $help = Get-Help $Name -ErrorAction SilentlyContinue
        $help.Synopsis | Should -Not -BeNullOrEmpty
        # PowerShell echoes the syntax line when comment-based help is missing,
        # so a synopsis starting with the command name means there is none.
        $help.Synopsis | Should -Not -BeLike "$Name*"
    }

    It '<Name> has a description' -ForEach $allCommands {
        $help = Get-Help $Name -ErrorAction SilentlyContinue
        $help.Description | Should -Not -BeNullOrEmpty
    }

    It '<Name> has at least one example' -ForEach $allCommands {
        $help = Get-Help $Name -ErrorAction SilentlyContinue
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }
}

Describe 'Safety conventions' {

    It '<Name> supports ShouldProcess because it changes state' -ForEach $mutatingCommands {
        $command = Get-Command $Name
        $command.Parameters.Keys | Should -Contain 'WhatIf' -Because 'every mutating command must be previewable'
        $command.Parameters.Keys | Should -Contain 'Confirm'
    }

    It '<Name> is read-only and therefore takes no WhatIf' -ForEach $readOnlyCommands {
        $command = Get-Command $Name
        $command.Parameters.Keys | Should -Not -Contain 'WhatIf' -Because 'a Get/Find/Test/Compare command must not mutate anything'
    }

    It '<Name> declares CmdletBinding' -ForEach $allCommands {
        (Get-Command $Name).CmdletBinding | Should -BeTrue
    }
}
