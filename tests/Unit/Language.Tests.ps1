<#
    Tests for the language support: how a language is chosen, how the string
    tables are loaded, and the rules that keep a message from going missing.

    Design: docs/dev/multilanguage.md.

    The loader (src/Office365Tools/Private/Shared/Language.ps1) is shared with
    the double-click launcher, which runs under Windows PowerShell 5.1. The
    first Describe is about that: the file has to stay ASCII and free of
    PowerShell 7 syntax, because nothing else would notice until someone ran the
    launcher on a machine that only has 5.1.

    Everything here runs without a tenant and without touching the real settings
    file: tests point O365_SETTINGS_PATH at a temporary one.
#>

BeforeAll {
    $script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:SharedFile = Join-Path $script:RepoRoot 'src/Office365Tools/Private/Shared/Language.ps1'
    $script:Resources  = Join-Path $script:RepoRoot 'src/Office365Tools/Resources'

    # The shared loader, as the launcher uses it: dot-sourced, no module.
    . $script:SharedFile

    Import-Module (Join-Path $script:RepoRoot 'src/Office365Tools/Office365Tools.psd1') -Force

    function Get-ScratchFolder {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) "o365lang-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        $path
    }

    function Get-PlaceholderSet {
        param([string]$Text)
        @([regex]::Matches($Text, '\{(\d+)[^}]*\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    }

    # Every .ps1 that can ask for a message, parsed once.
    $script:Sources = @(
        Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src'), (Join-Path $script:RepoRoot 'scripts'), (Join-Path $script:RepoRoot 'packaging') `
            -Filter '*.ps1' -Recurse -File)

    $script:EnglishStrings = Import-PowerShellDataFile -LiteralPath (Join-Path $script:Resources 'en/Strings.psd1')
    $script:GermanStrings  = Import-PowerShellDataFile -LiteralPath (Join-Path $script:Resources 'de/Strings.psd1')
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'The shared loader file' {

    It 'is plain ASCII, because Windows PowerShell 5.1 reads a file without a BOM as ANSI' {
        $bytes = [System.IO.File]::ReadAllBytes($script:SharedFile)

        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }

    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:SharedFile, [ref]$null, [ref]$errors) | Out-Null

        @($errors).Count | Should -Be 0
    }

    It 'uses no syntax that Windows PowerShell 5.1 does not have' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:SharedFile, [ref]$null, [ref]$null)
        $found = [System.Collections.Generic.List[string]]::new()

        foreach ($node in $ast.FindAll({ $true }, $true)) {
            $type = $node.GetType().Name
            $line = $node.Extent.StartLineNumber

            if ($type -eq 'TernaryExpressionAst') { $found.Add("ternary on line $line") }
            if ($type -eq 'PipelineChainAst') { $found.Add("&& or || on line $line") }

            if ($type -eq 'BinaryExpressionAst' -and "$($node.Operator)" -eq 'QuestionQuestion') {
                $found.Add("?? on line $line")
            }
            if ($type -eq 'AssignmentStatementAst' -and "$($node.Operator)" -eq 'QuestionQuestionEquals') {
                $found.Add("??= on line $line")
            }
            if ($type -eq 'MemberExpressionAst' -and $node.PSObject.Properties['NullConditional'] -and $node.NullConditional) {
                $found.Add("?. on line $line")
            }
            if ($type -eq 'CommandParameterAst' -and $node.ParameterName -eq 'Parallel') {
                $found.Add("-Parallel on line $line")
            }
        }

        $found | Should -BeNullOrEmpty -Because 'the launcher dot-sources this file under Windows PowerShell 5.1'
    }

    It 'reads no module state, so it works without the module' {
        $text = Get-Content -LiteralPath $script:SharedFile -Raw

        $text | Should -Not -Match '\$script:O365'
    }
}

Describe 'Supported languages' {

    It 'are English and German' {
        Get-O365SupportedLanguage | Should -Be @('en', 'de')
    }

    It 'are what Set-O365Language accepts, plus auto' {
        $set = (Get-Command Set-O365Language).Parameters['Language'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

        @($set.ValidValues | Sort-Object) | Should -Be @((@('auto') + (Get-O365SupportedLanguage)) | Sort-Object)
    }

    It 'each have a string table' {
        foreach ($code in (Get-O365SupportedLanguage)) {
            Test-Path -LiteralPath (Join-Path $script:Resources "$code/Strings.psd1") | Should -BeTrue -Because "$code is supported"
        }
    }
}

Describe 'Mapping a Windows culture to a language' {

    It '<Culture> gives <Expected>' -ForEach @(
        @{ Culture = 'de-CH'; Expected = 'de' }
        @{ Culture = 'de-DE'; Expected = 'de' }
        @{ Culture = 'de-AT'; Expected = 'de' }
        @{ Culture = 'de'; Expected = 'de' }
        @{ Culture = 'en-US'; Expected = 'en' }
        @{ Culture = 'en-GB'; Expected = 'en' }
        @{ Culture = 'fr-FR'; Expected = 'en' }
        @{ Culture = 'fr-CH'; Expected = 'en' }
        @{ Culture = 'zh-Hans'; Expected = 'en' }
        @{ Culture = ''; Expected = 'en' }
        @{ Culture = 'not-a-culture-at-all'; Expected = 'en' }
    ) {
        ConvertTo-O365LanguageCode -Culture $Culture | Should -Be $Expected
    }
}

Describe 'Choosing the language' {

    It 'takes -Language before everything else' {
        $result = Resolve-O365Language -Language 'en' -Environment 'de' -Saved 'de' -UICulture 'de-CH'

        $result.Language | Should -Be 'en'
        $result.Source | Should -Be 'Parameter'
    }

    It 'takes the environment variable before the saved setting' {
        $result = Resolve-O365Language -Language '' -Environment 'en' -Saved 'de' -UICulture 'de-CH'

        $result.Language | Should -Be 'en'
        $result.Source | Should -Be 'Environment'
    }

    It 'takes the saved setting before Windows' {
        $result = Resolve-O365Language -Language '' -Environment '' -Saved 'de' -UICulture 'en-US'

        $result.Language | Should -Be 'de'
        $result.Source | Should -Be 'SavedSetting'
    }

    It 'follows Windows when nothing is set' {
        $result = Resolve-O365Language -Language '' -Environment '' -Saved '' -UICulture 'de-CH'

        $result.Language | Should -Be 'de'
        $result.Source | Should -Be 'Windows'
    }

    It 'falls back to English for a Windows language it has no table for' {
        $result = Resolve-O365Language -Language '' -Environment '' -Saved '' -UICulture 'fr-FR'

        $result.Language | Should -Be 'en'
        $result.Source | Should -Be 'Windows'
    }

    It 'uses the default when there is nothing to go on at all' {
        $result = Resolve-O365Language -Language '' -Environment '' -Saved '' -UICulture ''

        $result.Language | Should -Be 'en'
        $result.Source | Should -Be 'Default'
    }

    Context 'auto means "ask the next one"' {

        It 'in -Language' {
            $result = Resolve-O365Language -Language 'auto' -Environment '' -Saved 'de' -UICulture 'en-US'

            $result.Source | Should -Be 'SavedSetting'
        }

        It 'in the environment variable' {
            $result = Resolve-O365Language -Language '' -Environment 'auto' -Saved 'de' -UICulture 'en-US'

            $result.Language | Should -Be 'de'
            $result.Source | Should -Be 'SavedSetting'
        }

        It 'in the saved setting, which then hands over to Windows' {
            $result = Resolve-O365Language -Language '' -Environment '' -Saved 'auto' -UICulture 'de-CH'

            $result.Language | Should -Be 'de'
            $result.Source | Should -Be 'Windows'
        }
    }

    Context 'a value it does not know' {

        It 'is an error for -Language' {
            { Resolve-O365Language -Language 'fr' -Environment '' -Saved '' -UICulture 'en-US' } | Should -Throw '*not supported*'
        }

        It 'is ignored, with a warning, in the environment variable' {
            $result = Resolve-O365Language -Language '' -Environment 'fr' -Saved 'de' -UICulture 'en-US' -WarningVariable warned -WarningAction SilentlyContinue

            $result.Language | Should -Be 'de'
            "$warned" | Should -BeLike '*O365_LANGUAGE*'
        }

        It 'is ignored, with a warning, in the saved setting' {
            $result = Resolve-O365Language -Language '' -Environment '' -Saved 'fr' -UICulture 'de-CH' -WarningVariable warned -WarningAction SilentlyContinue

            $result.Language | Should -Be 'de'
            $result.Source | Should -Be 'Windows'
            "$warned" | Should -BeLike '*saved language*'
        }
    }
}

Describe 'The saved setting' {

    BeforeEach {
        $script:Folder = Get-ScratchFolder
        $script:Settings = Join-Path $script:Folder 'office365_tools/settings.json'
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'is not set when there is no file' {
        Read-O365Setting -Name 'language' -Path $script:Settings | Should -BeNullOrEmpty
    }

    It 'is written, with its folder, and read back' {
        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Should -BeTrue

        Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'de'
    }

    It 'can be changed' {
        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Out-Null
        Write-O365Setting -Name 'language' -Value 'en' -Path $script:Settings | Should -BeTrue

        Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'en'
    }

    It 'keeps a setting it does not know about' {
        New-Item -Path (Split-Path -Parent $script:Settings) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $script:Settings -Value '{ "outputFolder": "D:\\reports", "language": "en" }'

        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Out-Null

        Read-O365Setting -Name 'outputFolder' -Path $script:Settings | Should -Be 'D:\reports'
        Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'de'
    }

    It 'is replaced when the file is not valid JSON, and reads as not set until then' {
        New-Item -Path (Split-Path -Parent $script:Settings) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $script:Settings -Value 'this is { not json'

        Read-O365Setting -Name 'language' -Path $script:Settings | Should -BeNullOrEmpty
        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Should -BeTrue
        Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'de'
    }

    It 'reads as not set when the file is empty' {
        New-Item -Path (Split-Path -Parent $script:Settings) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $script:Settings -Value ''

        Read-O365Setting -Name 'language' -Path $script:Settings | Should -BeNullOrEmpty
    }

    It 'reports a failure to save instead of throwing' {
        # A file where the folder should be: the folder cannot be created.
        $blocker = Join-Path $script:Folder 'blocker'
        Set-Content -LiteralPath $blocker -Value 'a file'

        { Write-O365Setting -Name 'language' -Value 'de' -Path (Join-Path $blocker 'settings.json') } | Should -Not -Throw
        Write-O365Setting -Name 'language' -Value 'de' -Path (Join-Path $blocker 'settings.json') | Should -BeFalse
    }

    It 'leaves no temporary file behind' {
        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Out-Null
        Write-O365Setting -Name 'language' -Value 'en' -Path $script:Settings | Out-Null

        @(Get-ChildItem -LiteralPath (Split-Path -Parent $script:Settings) -Filter '*.tmp').Count | Should -Be 0
    }

    It 'is written without a byte order mark' {
        Write-O365Setting -Name 'language' -Value 'de' -Path $script:Settings | Out-Null

        $bytes = [System.IO.File]::ReadAllBytes($script:Settings)

        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) | Should -BeFalse
    }

    It 'lives under the roaming application data of the user by default' {
        $saved = $env:O365_SETTINGS_PATH
        try {
            $env:O365_SETTINGS_PATH = $null

            Get-O365SettingsPath | Should -BeLike '*office365_tools*settings.json'
        }
        finally {
            $env:O365_SETTINGS_PATH = $saved
        }
    }
}

Describe 'Loading string tables' {

    BeforeEach {
        $script:Folder = Get-ScratchFolder

        function Add-Table {
            param([string]$Root, [string]$Language, [string]$Body)
            $dir = Join-Path $Root $Language
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'Strings.psd1') -Value $Body
        }

        $script:RootA = Join-Path $script:Folder 'a'
        Add-Table $script:RootA 'en' "@{ 'Only.English' = 'english only'; 'Both' = 'english both' }"
        Add-Table $script:RootA 'de' "@{ 'Both' = 'deutsch beide'; 'Only.German' = 'nur deutsch' }"
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'puts the chosen language over English' {
        $table = Import-O365StringTable -Path $script:RootA -Language 'de'

        $table['Both'] | Should -Be 'deutsch beide'
    }

    It 'still has a key that exists only in English' {
        $table = Import-O365StringTable -Path $script:RootA -Language 'de'

        $table['Only.English'] | Should -Be 'english only'
    }

    It 'still has a key that exists only in the chosen language' {
        $table = Import-O365StringTable -Path $script:RootA -Language 'de'

        $table['Only.German'] | Should -Be 'nur deutsch'
    }

    It 'is just English when English is asked for' {
        $table = Import-O365StringTable -Path $script:RootA -Language 'en'

        $table['Both'] | Should -Be 'english both'
        $table.ContainsKey('Only.German') | Should -BeFalse
    }

    It 'falls back to English, without an error, when there is no file for the language' {
        { Import-O365StringTable -Path $script:RootA -Language 'fr' -ErrorAction Stop } | Should -Not -Throw

        (Import-O365StringTable -Path $script:RootA -Language 'fr')['Both'] | Should -Be 'english both'
    }

    It 'lets a later folder override an earlier one' {
        $rootB = Join-Path $script:Folder 'b'
        Add-Table $rootB 'en' "@{ 'Both' = 'second folder' }"

        $table = Import-O365StringTable -Path @($script:RootA, $rootB) -Language 'en'

        $table['Both'] | Should -Be 'second folder'
        $table['Only.English'] | Should -Be 'english only'
    }

    It 'reads umlauts correctly from a file with a byte order mark' {
        $dir = Join-Path $script:RootA 'de'
        [System.IO.File]::WriteAllText(
            (Join-Path $dir 'Strings.psd1'),
            "@{ 'Umlaut' = 'Gr$([char]0x00FC)$([char]0x00DF)e' }",
            (New-Object System.Text.UTF8Encoding($true)))

        (Import-O365StringTable -Path $script:RootA -Language 'de')['Umlaut'] | Should -Be "Gr$([char]0x00FC)$([char]0x00DF)e"
    }
}

Describe 'Looking a message up' {

    BeforeAll {
        $script:Table = @{
            'Hello'                     = 'Hello'
            'Two'                       = 'Copied {0} of {1}'
            'Common.MessageUnavailable' = 'Message unavailable ({0}).'
        }
    }

    It 'returns the text' {
        Format-O365String -Table $script:Table -Key 'Hello' | Should -Be 'Hello'
    }

    It 'fills in the placeholders' {
        Format-O365String -Table $script:Table -Key 'Two' -FormatArguments 3, 7 | Should -Be 'Copied 3 of 7'
    }

    It 'shows a neutral line, not the raw key, when the key is missing' {
        $text = Format-O365String -Table $script:Table -Key 'No.Such.Key' -WarningAction SilentlyContinue

        $text | Should -Be 'Message unavailable (No.Such.Key).'
        $text | Should -Not -BeLike '*[[]*'
    }

    It 'warns, naming the key, when the key is missing' {
        Format-O365String -Table $script:Table -Key 'No.Such.Key' -WarningVariable warned -WarningAction SilentlyContinue | Out-Null

        "$warned" | Should -BeLike "*No.Such.Key*"
    }

    It 'still answers when even the neutral line is missing' {
        $text = Format-O365String -Table @{} -Key 'No.Such.Key' -WarningAction SilentlyContinue

        $text | Should -Not -BeNullOrEmpty
    }
}

Describe 'The string tables of the module' {

    It 'have a byte order mark, so Windows PowerShell 5.1 reads them as UTF-8' -ForEach @(
        @{ Code = 'en' }
        @{ Code = 'de' }
    ) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $script:Resources "$Code/Strings.psd1"))

        $bytes[0] | Should -Be 0xEF
        $bytes[1] | Should -Be 0xBB
        $bytes[2] | Should -Be 0xBF
    }

    It 'have the same keys in English and German' {
        $english = @($script:EnglishStrings.Keys | Sort-Object)
        $german  = @($script:GermanStrings.Keys | Sort-Object)

        $missingInGerman  = @($english | Where-Object { $_ -notin $german })
        $missingInEnglish = @($german | Where-Object { $_ -notin $english })

        $missingInGerman | Should -BeNullOrEmpty -Because "these have no German text: $($missingInGerman -join ', ')"
        $missingInEnglish | Should -BeNullOrEmpty -Because "these have no English text: $($missingInEnglish -join ', ')"
    }

    It 'use the same placeholders in both languages' {
        $problems = foreach ($key in $script:EnglishStrings.Keys) {
            if (-not $script:GermanStrings.ContainsKey($key)) { continue }

            $english = (Get-PlaceholderSet $script:EnglishStrings[$key]) -join ','
            $german  = (Get-PlaceholderSet $script:GermanStrings[$key]) -join ','

            if ($english -ne $german) {
                "${key}: English has {$english}, German has {$german}"
            }
        }

        $problems | Should -BeNullOrEmpty -Because ($problems -join '; ')
    }

    It 'have no empty text' {
        $empty = @($script:EnglishStrings.Keys + $script:GermanStrings.Keys | Where-Object {
                $text = if ($script:EnglishStrings.ContainsKey($_)) { $script:EnglishStrings[$_] } else { $script:GermanStrings[$_] }
                -not "$text".Trim()
            })

        $empty | Should -BeNullOrEmpty
    }

    It 'have keys written as Area.Name' {
        $bad = @(($script:EnglishStrings.Keys + $script:GermanStrings.Keys) |
                Sort-Object -Unique |
                Where-Object { $_ -notmatch '^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)+$' })

        $bad | Should -BeNullOrEmpty -Because "these do not follow Area.Name: $($bad -join ', ')"
    }

    It 'use informal German, not Sie' {
        $formal = @($script:GermanStrings.GetEnumerator() | Where-Object { $_.Value -match '\b(Sie|Ihnen|Ihre|Ihr|Ihrem|Ihren)\b' } | ForEach-Object Key)

        $formal | Should -BeNullOrEmpty -Because "the tools address people with du: $($formal -join ', ')"
    }
}

Describe 'Every message the code asks for' {

    BeforeAll {
        # Calls such as: Get-O365String 'Language.NotSaved' $path
        # The key has to be a literal, which is also what lets this test see it.
        $script:Asked = foreach ($file in $script:Sources) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $calls = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in 'Get-O365String', 'Get-LauncherString'
                }, $true)

            foreach ($call in $calls) {
                $elements = @($call.CommandElements | Select-Object -Skip 1)
                $first = $elements | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] } | Select-Object -First 1

                [pscustomobject]@{
                    File     = $file.FullName.Substring($script:RepoRoot.Length + 1)
                    Line     = $call.Extent.StartLineNumber
                    Literal  = ($first -is [System.Management.Automation.Language.StringConstantExpressionAst])
                    Key      = if ($first -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $first.Value } else { $null }
                    Original = $call.Extent.Text
                }
            }
        }
        $script:Asked = @($script:Asked)
    }

    It 'passes its key as a literal, so it can be checked' {
        $dynamic = @($script:Asked | Where-Object { -not $_.Literal })

        $dynamic | Should -BeNullOrEmpty -Because (
            "a computed key cannot be checked: $(($dynamic | ForEach-Object { "$($_.File):$($_.Line)" }) -join ', ')")
    }

    It 'exists in the English table, which is what a missing translation falls back to' {
        $missing = @($script:Asked | Where-Object { $_.Literal -and -not $script:EnglishStrings.ContainsKey($_.Key) })

        $missing | Should -BeNullOrEmpty -Because (
            "no English text for: $(($missing | ForEach-Object { "$($_.Key) ($($_.File):$($_.Line))" }) -join ', ')")
    }

    It 'is reported, not failed, when a text is defined and nothing uses it' {
        $allText = ($script:Sources | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

        $unused = @($script:EnglishStrings.Keys | Where-Object { $allText -notmatch [regex]::Escape("'$_'") })

        if ($unused) {
            Write-Warning "Texts that no code asks for: $($unused -join ', ')"
        }

        $true | Should -BeTrue
    }
}

Describe 'Language commands' {

    BeforeEach {
        $script:Folder = Get-ScratchFolder
        $script:Saved = @{
            Path     = $env:O365_SETTINGS_PATH
            Language = $env:O365_LANGUAGE
        }

        $env:O365_SETTINGS_PATH = Join-Path $script:Folder 'settings.json'
        $env:O365_LANGUAGE = $null
    }

    AfterEach {
        $env:O365_SETTINGS_PATH = $script:Saved.Path
        $env:O365_LANGUAGE = $script:Saved.Language

        InModuleScope Office365Tools {
            $script:O365State.Language = $null
            $script:O365State.Strings = $null
        }

        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Set-O365Language' {

        It 'saves the choice, and Get-O365Language reports it as the saved setting' {
            Set-O365Language -Language 'de'

            $result = Get-O365Language

            $result.Language | Should -Be 'de'
            $result.Source | Should -Be 'SavedSetting'
        }

        It 'changes nothing under -WhatIf' {
            Set-O365Language -Language 'de' -WhatIf

            Test-Path -LiteralPath $env:O365_SETTINGS_PATH | Should -BeFalse
        }

        It 'returns the result with -PassThru' {
            $result = Set-O365Language -Language 'en' -PassThru

            $result.Language | Should -Be 'en'
        }

        It 'with auto, follows Windows again' {
            Set-O365Language -Language 'de'
            Set-O365Language -Language 'auto'

            (Get-O365Language).Source | Should -Not -Be 'SavedSetting'
        }

        It 'rejects a language it does not know' {
            { Set-O365Language -Language 'fr' } | Should -Throw
        }

        It 'applies the choice to this session, and warns, when it cannot be saved' {
            $blocker = Join-Path $script:Folder 'blocker'
            Set-Content -LiteralPath $blocker -Value 'a file'
            $env:O365_SETTINGS_PATH = Join-Path $blocker 'settings.json'

            Set-O365Language -Language 'de' -WarningVariable warned -WarningAction SilentlyContinue

            "$warned" | Should -Not -BeNullOrEmpty
            (Get-O365Language).Language | Should -Be 'de'
        }
    }

    Context 'Get-O365Language' {

        It 'lets the environment variable outrank the saved setting' {
            Set-O365Language -Language 'de'
            $env:O365_LANGUAGE = 'en'

            $result = Get-O365Language

            $result.Language | Should -Be 'en'
            $result.Source | Should -Be 'Environment'
        }

        It 'treats O365_LANGUAGE=auto as not set' {
            Set-O365Language -Language 'de'
            $env:O365_LANGUAGE = 'auto'

            (Get-O365Language).Source | Should -Be 'SavedSetting'
        }

        It 'says where the settings file is' {
            (Get-O365Language).SettingsPath | Should -Be $env:O365_SETTINGS_PATH
        }
    }

    Context 'Get-O365String' {

        It 'answers in German when German is chosen' {
            Set-O365Language -Language 'de'

            InModuleScope Office365Tools {
                Get-O365String 'Language.NotSaved' 'X:\settings.json'
            } | Should -BeLike 'Die Sprache gilt*X:\settings.json*'
        }

        It 'answers in English when English is chosen' {
            Set-O365Language -Language 'en'

            InModuleScope Office365Tools {
                Get-O365String 'Language.NotSaved' 'X:\settings.json'
            } | Should -BeLike 'The language applies*X:\settings.json*'
        }

        It 'switches language without reloading the module' {
            Set-O365Language -Language 'de'
            $german = InModuleScope Office365Tools { Get-O365String 'Language.Save.Action' 'de' }

            Set-O365Language -Language 'en'
            $english = InModuleScope Office365Tools { Get-O365String 'Language.Save.Action' 'en' }

            $german | Should -Not -Be $english
        }

        It 'shows a neutral line and logs a warning for a key that does not exist' {
            Set-O365Language -Language 'en'

            $text = InModuleScope Office365Tools {
                Get-O365String 'No.Such.Key' -WarningVariable warned -WarningAction SilentlyContinue
            }

            $text | Should -Be 'Message unavailable (No.Such.Key).'
        }
    }
}
