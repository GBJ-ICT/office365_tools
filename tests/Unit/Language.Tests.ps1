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
    $script:SharedFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src/Office365Tools/Private/Shared') -Filter '*.ps1' -File)
    $script:Resources   = Join-Path $script:RepoRoot 'src/Office365Tools/Resources'

    # The shared files, as the launcher uses them: dot-sourced, no module.
    foreach ($file in $script:SharedFiles) { . $file.FullName }

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

    # Every folder of string tables: the module's, and one per packaged tool.
    # The module's, the tool menu's (packaging\Resources), and one per tool
    # (packaging\<Tool>\Resources).
    $roots = @($script:Resources, (Join-Path $script:RepoRoot 'packaging/Resources')) + @(
        Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'packaging') -Directory |
            ForEach-Object { Join-Path $_.FullName 'Resources' } |
            Where-Object { Test-Path -LiteralPath $_ })
    $roots = @($roots | ForEach-Object { (Resolve-Path -LiteralPath $_).Path } | Select-Object -Unique)

    $script:Tables = @($roots | ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Substring($script:RepoRoot.Length + 1)
                Root    = $_
                English = Import-PowerShellDataFile -LiteralPath (Join-Path $_ 'en/Strings.psd1')
                German  = Import-PowerShellDataFile -LiteralPath (Join-Path $_ 'de/Strings.psd1')
            }
        })

    # What a key may be looked up in: English, all folders together.
    $script:EnglishStrings = @{}
    foreach ($table in $script:Tables) {
        foreach ($key in $table.English.Keys) { $script:EnglishStrings[$key] = $table.English[$key] }
    }
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'The shared files' {

    # Language.ps1 and ClientId.ps1 are dot-sourced by the module and by the
    # double-click launcher, which runs under Windows PowerShell 5.1. Whatever is
    # in this folder is held to the same two rules.

    It 'are plain ASCII, because Windows PowerShell 5.1 reads a file without a BOM as ANSI' {
        $bad = foreach ($file in $script:SharedFiles) {
            if (@([System.IO.File]::ReadAllBytes($file.FullName) | Where-Object { $_ -gt 127 }).Count -gt 0) { $file.Name }
        }

        $bad | Should -BeNullOrEmpty -Because "these contain a non-ASCII character: $($bad -join ', ')"
    }

    It 'parse without errors' {
        $bad = foreach ($file in $script:SharedFiles) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors) | Out-Null
            if (@($errors).Count -gt 0) { $file.Name }
        }

        $bad | Should -BeNullOrEmpty
    }

    It 'use no syntax that Windows PowerShell 5.1 does not have' {
        $found = [System.Collections.Generic.List[string]]::new()

        foreach ($file in $script:SharedFiles) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            foreach ($node in $ast.FindAll({ $true }, $true)) {
                $type = $node.GetType().Name
                $where = "$($file.Name) line $($node.Extent.StartLineNumber)"

                if ($type -eq 'TernaryExpressionAst') { $found.Add("ternary, $where") }
                if ($type -eq 'PipelineChainAst') { $found.Add("&& or ||, $where") }

                if ($type -eq 'BinaryExpressionAst' -and "$($node.Operator)" -eq 'QuestionQuestion') {
                    $found.Add("??, $where")
                }
                if ($type -eq 'AssignmentStatementAst' -and "$($node.Operator)" -eq 'QuestionQuestionEquals') {
                    $found.Add("??=, $where")
                }
                if ($type -eq 'MemberExpressionAst' -and $node.PSObject.Properties['NullConditional'] -and $node.NullConditional) {
                    $found.Add("?., $where")
                }
                if ($type -eq 'CommandParameterAst' -and $node.ParameterName -eq 'Parallel') {
                    $found.Add("-Parallel, $where")
                }
            }
        }

        $found | Should -BeNullOrEmpty -Because 'the launcher dot-sources these files under Windows PowerShell 5.1'
    }

    It 'read no module state, so they work without the module' {
        $bad = foreach ($file in $script:SharedFiles) {
            if ((Get-Content -LiteralPath $file.FullName -Raw) -match '\$script:O365') { $file.Name }
        }

        $bad | Should -BeNullOrEmpty
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

Describe 'The string tables' {

    # One folder for the module, and one for each packaged tool. Each has an
    # English and a German table, and the same rules apply to all of them.

    It 'have a byte order mark, so Windows PowerShell 5.1 reads them as UTF-8' {
        $bad = foreach ($table in $script:Tables) {
            foreach ($code in 'en', 'de') {
                $bytes = [System.IO.File]::ReadAllBytes((Join-Path $table.Root "$code/Strings.psd1"))
                if (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) { "$($table.Name)/$code" }
            }
        }

        $bad | Should -BeNullOrEmpty -Because "these have no byte order mark: $($bad -join ', ')"
    }

    It 'have the same keys in English and German' {
        $problems = foreach ($table in $script:Tables) {
            foreach ($key in $table.English.Keys) {
                if (-not $table.German.ContainsKey($key)) { "$($table.Name): '$key' has no German text" }
            }
            foreach ($key in $table.German.Keys) {
                if (-not $table.English.ContainsKey($key)) { "$($table.Name): '$key' has no English text" }
            }
        }

        $problems | Should -BeNullOrEmpty -Because ($problems -join '; ')
    }

    It 'use the same placeholders in both languages' {
        $problems = foreach ($table in $script:Tables) {
            foreach ($key in $table.English.Keys) {
                if (-not $table.German.ContainsKey($key)) { continue }

                $english = (Get-PlaceholderSet $table.English[$key]) -join ','
                $german  = (Get-PlaceholderSet $table.German[$key]) -join ','

                if ($english -ne $german) {
                    "${key}: English has {$english}, German has {$german}"
                }
            }
        }

        $problems | Should -BeNullOrEmpty -Because ($problems -join '; ')
    }

    It 'have no empty text' {
        $empty = foreach ($table in $script:Tables) {
            foreach ($language in 'English', 'German') {
                foreach ($key in $table.$language.Keys) {
                    if (-not "$($table.$language[$key])".Trim()) { "$($table.Name)/$language/$key" }
                }
            }
        }

        $empty | Should -BeNullOrEmpty
    }

    It 'have keys written as Area.Name' {
        $bad = foreach ($table in $script:Tables) {
            foreach ($key in ($table.English.Keys + $table.German.Keys | Sort-Object -Unique)) {
                if ($key -notmatch '^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)+$') { "$($table.Name): $key" }
            }
        }

        $bad | Should -BeNullOrEmpty -Because "these do not follow Area.Name: $($bad -join ', ')"
    }

    It 'have no key defined in two folders, where one would silently win' {
        $seen = @{}
        $twice = foreach ($table in $script:Tables) {
            foreach ($key in $table.English.Keys) {
                if ($seen.ContainsKey($key)) { "$key (in $($seen[$key]) and $($table.Name))" } else { $seen[$key] = $table.Name }
            }
        }

        $twice | Should -BeNullOrEmpty -Because ($twice -join '; ')
    }

    It 'use informal German, not Sie' {
        $formal = foreach ($table in $script:Tables) {
            foreach ($entry in $table.German.GetEnumerator()) {
                # Case-sensitive: lower case "sie" is an ordinary word.
                if ($entry.Value -cmatch '\b(Sie|Ihnen|Ihre|Ihr|Ihrem|Ihren)\b') { "$($table.Name): $($entry.Key)" }
            }
        }

        $formal | Should -BeNullOrEmpty -Because "the tools address people with du: $($formal -join ', ')"
    }
}

Describe 'The packaged tools' {

    It 'have a title and a description in English and in German, for the tool menu' {
        $tools = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'packaging') -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'tool.psd1') })

        $tools.Count | Should -BeGreaterThan 0

        $missing = foreach ($tool in $tools) {
            $table = $script:Tables | Where-Object { $_.Root -eq (Join-Path $tool.FullName 'Resources') }
            foreach ($key in "Tool.$($tool.Name).Title", "Tool.$($tool.Name).Description") {
                if (-not $table -or -not $table.English.ContainsKey($key)) { "$key (English)" }
                if (-not $table -or -not $table.German.ContainsKey($key)) { "$key (German)" }
            }
        }

        $missing | Should -BeNullOrEmpty -Because "the tool menu looks these up; missing: $($missing -join ', ')"
    }
}
Describe 'Every message the code asks for' {

    BeforeAll {
        # The helpers that look a key up for everyone else. Their own calls pass
        # the key on as a variable, which is the point of them.
        $helpers = 'Get-O365String', 'Get-LauncherString', 'Get-LauncherLines', 'Get-MenuString', 'Get-MenuLines', 'Get-ScriptString', 'Format-O365String'

        function Find-Enclosing {
            param($Node)
            while ($Node) {
                if ($Node -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $Node.Name }
                $Node = $Node.Parent
            }
            return ''
        }

        # Calls such as: Get-O365String 'Language.NotSaved' $path
        #                Format-O365String -Table $t -Key 'Language.Picker.Title'
        # The key has to be a literal, which is also what lets this test see it.
        $script:Asked = foreach ($file in $script:Sources) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $calls = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in 'Get-O365String', 'Get-LauncherString', 'Get-LauncherLines', 'Get-MenuString', 'Get-MenuLines', 'Get-ScriptString', 'Format-O365String'
                }, $true)

            foreach ($call in $calls) {
                $elements = @($call.CommandElements | Select-Object -Skip 1)
                $first = $null

                if ($call.GetCommandName() -eq 'Format-O365String') {
                    # The key is the argument of -Key.
                    for ($i = 0; $i -lt $elements.Count; $i++) {
                        $element = $elements[$i]
                        if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and $element.ParameterName -eq 'Key') {
                            if ($element.Argument) { $first = $element.Argument }
                            elseif ($i + 1 -lt $elements.Count) { $first = $elements[$i + 1] }
                        }
                    }
                }
                else {
                    $first = $elements | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] } | Select-Object -First 1
                }

                $isLiteral = $first -is [System.Management.Automation.Language.StringConstantExpressionAst]

                [pscustomobject]@{
                    File     = $file.FullName.Substring($script:RepoRoot.Length + 1)
                    Line     = $call.Extent.StartLineNumber
                    Literal  = $isLiteral
                    Key      = if ($isLiteral) { $first.Value } else { $null }
                    InHelper = ((Find-Enclosing $call) -in $helpers)
                }
            }
        }
        $script:Asked = @($script:Asked)
    }

    It 'finds the calls at all' {
        @($script:Asked | Where-Object Literal).Count | Should -BeGreaterThan 20
    }

    It 'passes its key as a literal, so it can be checked' {
        $dynamic = @($script:Asked | Where-Object { -not $_.Literal -and -not $_.InHelper })

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

Describe 'The language picker' {

    BeforeAll {
        $script:Table = @{
            'Language.Name.en'        = 'English'
            'Language.Name.de'        = 'Deutsch'
            'Language.Picker.Line'    = 'Language: {0}   (L = change)'
            'Language.Picker.Title'   = 'Which language?'
            'Language.Picker.Option1' = '    1) English'
            'Language.Picker.Option2' = '    2) Deutsch'
            'Language.Picker.Option3' = '    3) Follow Windows'
            'Language.Picker.Prompt'  = 'Number'
        }
    }

    BeforeEach {
        $script:Folder = Get-ScratchFolder
        $script:Settings = Join-Path $script:Folder 'settings.json'
        Mock Write-Host { }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'the line that says which language is in use' {

        It 'names English' {
            Get-O365LanguageLine -Table $script:Table -Language 'en' | Should -Be 'Language: English   (L = change)'
        }

        It 'names Deutsch' {
            Get-O365LanguageLine -Table $script:Table -Language 'de' | Should -Be 'Language: Deutsch   (L = change)'
        }
    }

    Context 'asking' {

        It 'returns English for 1, and saves it' {
            Mock Read-Host { '1' }

            $result = Read-O365LanguageChoice -Table $script:Table -Path $script:Settings

            $result.Choice | Should -Be 'en'
            $result.Saved | Should -BeTrue
            Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'en'
        }

        It 'returns Deutsch for 2, and saves it' {
            Mock Read-Host { '2' }

            (Read-O365LanguageChoice -Table $script:Table -Path $script:Settings).Choice | Should -Be 'de'
            Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'de'
        }

        It 'returns auto for 3, so Windows decides again' {
            Mock Read-Host { '3' }

            (Read-O365LanguageChoice -Table $script:Table -Path $script:Settings).Choice | Should -Be 'auto'
            Read-O365Setting -Name 'language' -Path $script:Settings | Should -Be 'auto'
        }

        It 'returns nothing, and saves nothing, for Enter' {
            Mock Read-Host { '' }

            Read-O365LanguageChoice -Table $script:Table -Path $script:Settings | Should -BeNullOrEmpty
            Test-Path -LiteralPath $script:Settings | Should -BeFalse
        }

        It 'returns nothing for an answer that is not on the list' {
            Mock Read-Host { 'banana' }

            Read-O365LanguageChoice -Table $script:Table -Path $script:Settings | Should -BeNullOrEmpty
        }

        It 'still returns the choice, saying it was not saved, when the file cannot be written' {
            Mock Read-Host { '2' }
            $blocker = Join-Path $script:Folder 'blocker'
            Set-Content -LiteralPath $blocker -Value 'a file'

            $result = Read-O365LanguageChoice -Table $script:Table -Path (Join-Path $blocker 'settings.json')

            $result.Choice | Should -Be 'de'
            $result.Saved | Should -BeFalse
        }

        It 'keeps a setting it does not know about' {
            Mock Read-Host { '2' }
            Set-Content -LiteralPath $script:Settings -Value '{ "outputFolder": "D:\\reports" }'

            Read-O365LanguageChoice -Table $script:Table -Path $script:Settings | Out-Null

            Read-O365Setting -Name 'outputFolder' -Path $script:Settings | Should -Be 'D:\reports'
        }
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
            $script:O365State.LanguageOverride = $null
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

        It 'with -SessionOnly applies to this session and writes nothing' {
            Set-O365Language -Language 'de' -SessionOnly

            Test-Path -LiteralPath $env:O365_SETTINGS_PATH | Should -BeFalse
            $result = Get-O365Language
            $result.Language | Should -Be 'de'
            $result.Source | Should -Be 'Parameter'
        }

        It 'with -SessionOnly outranks the saved choice and the environment, and leaves the saved choice alone' {
            Set-O365Language -Language 'en'
            $env:O365_LANGUAGE = 'en'

            Set-O365Language -Language 'de' -SessionOnly

            (Get-O365Language).Language | Should -Be 'de'
            (Get-Content -LiteralPath $env:O365_SETTINGS_PATH -Raw | ConvertFrom-Json).language | Should -Be 'en'
        }

        It 'with -SessionOnly changes the texts that follow' {
            Set-O365Language -Language 'en' -SessionOnly
            $english = InModuleScope Office365Tools { Get-O365String 'Language.Save.Action' 'x' }

            Set-O365Language -Language 'de' -SessionOnly
            $german = InModuleScope Office365Tools { Get-O365String 'Language.Save.Action' 'x' }

            $english | Should -Be 'Save the language "x"'
            $german | Should -Be 'Sprache "x" speichern'
        }

        It 'with -SessionOnly and auto gives the session choice up again' {
            Set-O365Language -Language 'de' -SessionOnly
            Set-O365Language -Language 'auto' -SessionOnly

            (Get-O365Language).Source | Should -Not -Be 'Parameter'
        }

        It 'with -SessionOnly needs no confirmation and ignores -WhatIf, since nothing is written' {
            { Set-O365Language -Language 'de' -SessionOnly -WhatIf } | Should -Not -Throw
            (Get-O365Language).Language | Should -Be 'de'
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

        It 'reads the texts of a script from the folder it names, over the module''s' {
            $folder = Get-ScratchFolder
            try {
                foreach ($code in 'en', 'de') {
                    New-Item -Path (Join-Path $folder $code) -ItemType Directory -Force | Out-Null
                }
                Set-Content -LiteralPath (Join-Path $folder 'en/Strings.psd1') -Value "@{ 'Own.Key' = 'own english {0}'; 'Common.MessageUnavailable' = 'overridden ({0})' }"
                Set-Content -LiteralPath (Join-Path $folder 'de/Strings.psd1') -Value "@{ 'Own.Key' = 'eigenes deutsch {0}' }"

                Set-O365Language -Language 'en' -SessionOnly
                $english = Get-O365String -ResourcePath $folder 'Own.Key' 'x'
                Set-O365Language -Language 'de' -SessionOnly
                $german = Get-O365String -ResourcePath $folder 'Own.Key' 'x'
                $module = Get-O365String 'Language.Save.Action' 'x'

                $english | Should -Be 'own english x'
                $german | Should -Be 'eigenes deutsch x'
                $module | Should -Be 'Sprache "x" speichern'
            }
            finally {
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'does not show a script''s texts to a call that did not name its folder' {
            $folder = Get-ScratchFolder
            try {
                New-Item -Path (Join-Path $folder 'en') -ItemType Directory -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $folder 'en/Strings.psd1') -Value "@{ 'Own.Only' = 'only here' }"

                Set-O365Language -Language 'en' -SessionOnly

                Get-O365String -ResourcePath $folder 'Own.Only' | Should -Be 'only here'
                (Get-O365String 'Own.Only' -WarningAction SilentlyContinue) | Should -BeLike 'Message unavailable*'
            }
            finally {
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
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
