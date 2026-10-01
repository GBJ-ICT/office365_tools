<#
    Tests for packaging/Office365-Tools.cmd, the double-click launcher, and for
    packaging/tools.psd1, the list of tools it runs.

    The launcher is a batch file and a PowerShell script in one, and it is
    handed out: copies already on other people's machines keep fetching the
    newest tool list and the newest code from GitHub. So the things that can
    break it are the things checked here -- the two halves no longer fitting
    together, the list no longer reading as data, and an entry script no longer
    taking what every launcher passes it.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -ForEach on the It blocks below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    # Read the way the launcher reads it: as data, never run.
    $listPath = Join-Path $PSScriptRoot '../../packaging/tools.psd1'
    $listAst = [System.Management.Automation.Language.Parser]::ParseFile($listPath, [ref]$null, [ref]$null)
    $listTable = $listAst.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)

    $toolCases = @($listTable.SafeGetValue().Tools | ForEach-Object { @{ Tool = $_ } })
}

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '../..'
    $script:LauncherPath = Join-Path $script:RepoRoot 'packaging/Office365-Tools.cmd'
    $script:Bytes = [System.IO.File]::ReadAllBytes($script:LauncherPath)
    $script:Text = [System.Text.Encoding]::ASCII.GetString($script:Bytes)

    $parseErrors = $null
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $script:Text, [ref]$null, [ref]$parseErrors)
    $script:ParseErrors = $parseErrors

    # The launcher's settings, read the way PowerShell would assign them. Type
    # checks before property access: build.ps1 runs the tests under strict
    # mode, where asking an AST node for a property it lacks throws.
    $script:Setting = @{}
    $assignments = $script:Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and
            $node.Right.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $false)
    foreach ($assignment in $assignments) {
        $script:Setting[$assignment.Left.VariablePath.UserPath] = $assignment.Right.Expression.Value
    }

    $listPath = Join-Path $script:RepoRoot 'packaging/tools.psd1'
    $listErrors = $null
    $listAst = [System.Management.Automation.Language.Parser]::ParseFile($listPath, [ref]$null, [ref]$listErrors)
    $script:ListErrors = $listErrors
    $script:ToolList = @($listAst.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false).SafeGetValue().Tools)
}

Describe 'Office365-Tools.cmd' {

    It 'parses as PowerShell, batch half and all' {
        $script:ParseErrors | Should -BeNullOrEmpty
    }

    It 'opens with the line that is a label to cmd and a comment to PowerShell' {
        $script:Text | Should -Match '^<# :'
    }

    It 'closes the batch half exactly once' {
        ([regex]::Matches($script:Text, '#>')).Count | Should -Be 1
    }

    It 'is plain ASCII, because cmd reads it before any encoding is set' {
        @($script:Bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }

    It 'ends every line in CRLF, which cmd needs for its labels' {
        $bareLf = 0
        for ($i = 0; $i -lt $script:Bytes.Length; $i++) {
            if ($script:Bytes[$i] -eq 10 -and ($i -eq 0 -or $script:Bytes[$i - 1] -ne 13)) { $bareLf++ }
        }
        $bareLf | Should -Be 0
    }

    It 'has the one unpinned $Tool line that build.ps1 rewrites for a single-tool ZIP' {
        ([regex]::Matches($script:Text, [regex]::Escape("`$Tool       = ''"))).Count | Should -Be 1
    }

    It 'fetches from this repository' {
        $script:Setting['Repository'] | Should -Be 'GBJ-ICT/office365_tools'
    }

    It 'names the tool list that exists' {
        Test-Path -LiteralPath (Join-Path $script:RepoRoot ($script:Setting['ToolList'] -replace '\\', '/')) | Should -BeTrue
    }
}

Describe 'tools.psd1' {

    It 'parses' {
        $script:ListErrors | Should -BeNullOrEmpty
    }

    It 'lists at least one tool' {
        $script:ToolList.Count | Should -BeGreaterThan 0
    }

    It 'gives every tool its own name, launcher and settings file' {
        # Settings and launchers sit side by side in one folder on the
        # recipient's machine; two of the same name overwrite each other.
        $names = @($script:ToolList | ForEach-Object { $_.Name })
        $launchers = @($script:ToolList | ForEach-Object { $_.Launcher })
        $settings = @($script:ToolList | ForEach-Object { Split-Path -Leaf $_.Settings })

        @($names | Select-Object -Unique).Count | Should -Be $names.Count
        @($launchers | Select-Object -Unique).Count | Should -Be $launchers.Count
        @($settings | Select-Object -Unique).Count | Should -Be $settings.Count
    }
}

Describe 'Tool <Tool.Name>' -ForEach $toolCases {

    It 'has everything the launcher and the build need' {
        foreach ($field in 'Name', 'Title', 'Description', 'Entry', 'Settings', 'ReadMe', 'Launcher') {
            $Tool[$field] | Should -Not -BeNullOrEmpty -Because "$field is required"
        }
        $Tool.Launcher | Should -Match '\.cmd$'
    }

    It 'points at files that exist' {
        foreach ($field in 'Entry', 'Settings', 'ReadMe') {
            Test-Path -LiteralPath (Join-Path $script:RepoRoot $Tool[$field]) | Should -BeTrue -Because "$field is $($Tool[$field])"
        }
    }

    It 'has an entry script that takes what every launcher passes' {
        # Every copy already handed out passes these. Renaming one in the entry
        # script breaks all of them at once.
        $entryAst = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:RepoRoot $Tool.Entry), [ref]$null, [ref]$null)
        $accepted = @($entryAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        foreach ($parameter in 'SettingsPath', 'ReportFolder', 'Folder', 'NoPrompt') {
            $accepted | Should -Contain $parameter
        }
    }

    It 'prefills only settings its template has' {
        if (-not $Tool.ContainsKey('Prefill')) { return }

        $template = New-Object System.Xml.XmlDocument
        $template.Load((Join-Path $script:RepoRoot $Tool.Settings))

        foreach ($element in $Tool.Prefill.Keys) {
            $template.DocumentElement.SelectSingleNode($element) | Should -Not -BeNullOrEmpty -Because "<$element> is prefilled"
        }
    }
}
