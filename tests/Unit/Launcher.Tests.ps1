<#
    Tests for packaging/Office365-Tools.cmd, the double-click launcher, and for
    the tools it runs: every folder under packaging/ with a tool.psd1 in it.

    The launcher is a batch file and a PowerShell script in one, and it is
    handed out: copies already on other people's machines keep fetching the
    newest code from GitHub. So the things that can break it are the things
    checked here -- the two halves no longer fitting together, a tool.psd1 no
    longer reading as data, and an entry script no longer taking what every
    launcher passes it.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -ForEach on the It blocks below, which the analyzer does not trace.')]
param()

BeforeDiscovery {
    $toolCases = @(
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../../packaging') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'tool.psd1') } |
            ForEach-Object { @{ Name = $_.Name; Folder = $_.FullName } })
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

    # Read the way the launcher reads it: as data, never run.
    function Read-ToolManifest {
        param([string]$Folder)

        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $Folder 'tool.psd1'), [ref]$null, [ref]$parseErrors)

        [pscustomobject]@{
            ParseErrors = $parseErrors
            Data        = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false).SafeGetValue()
        }
    }

    $script:AllTools = @(
        Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'packaging') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'tool.psd1') } |
            ForEach-Object { (Read-ToolManifest -Folder $_.FullName).Data })
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

    It 'has the one unpinned <Line> line that build.ps1 rewrites' -ForEach @(
        @{ Line = "`$Tool       = ''" }
        @{ Line = "`$Ref        = 'master'" }
    ) {
        ([regex]::Matches($script:Text, [regex]::Escape($Line))).Count | Should -Be 1
    }

    It 'fetches from this repository' {
        $script:Setting['Repository'] | Should -Be 'GBJ-ICT/office365_tools'
    }

    It 'looks for tools in the folder they are in' {
        $script:Setting['ToolFolder'] | Should -Be 'packaging'
    }
}

Describe 'The tools under packaging/' {

    It 'has at least one' {
        $script:AllTools.Count | Should -BeGreaterThan 0
    }

    It 'gives every tool its own launcher and settings file' {
        # Settings and launchers sit side by side in one folder on the
        # recipient's machine; two of the same name overwrite each other.
        $launchers = @($script:AllTools | ForEach-Object { $_.Launcher })
        $settings = @($script:AllTools | ForEach-Object { Split-Path -Leaf $_.Settings })

        @($launchers | Select-Object -Unique).Count | Should -Be $launchers.Count
        @($settings | Select-Object -Unique).Count | Should -Be $settings.Count
    }
}

Describe 'Tool <Name>' -ForEach $toolCases {

    BeforeAll {
        $manifest = Read-ToolManifest -Folder $Folder
        $script:ToolErrors = $manifest.ParseErrors
        $script:Tool = $manifest.Data
    }

    It 'has a folder name that can be its name' {
        # The launcher keeps its copy of the code in a folder of this name,
        # beside one called _all; a pinned launcher has it in a quoted string.
        $Name | Should -Match '^[A-Za-z][A-Za-z0-9-]*$'
    }

    It 'has a tool.psd1 that parses' {
        $script:ToolErrors | Should -BeNullOrEmpty
    }

    It 'has everything the launcher and the build need' {
        foreach ($field in 'Title', 'Description', 'Entry', 'Settings', 'ReadMe', 'Launcher') {
            $script:Tool[$field] | Should -Not -BeNullOrEmpty -Because "$field is required"
        }
        $script:Tool.Launcher | Should -Match '\.cmd$'
    }

    It 'points at files in its own folder' {
        foreach ($field in 'Entry', 'Settings', 'ReadMe') {
            Test-Path -LiteralPath (Join-Path $Folder $script:Tool[$field]) -PathType Leaf |
                Should -BeTrue -Because "$field is $($script:Tool[$field])"
        }
    }

    It 'has an entry script that takes what every launcher passes' {
        # Every copy already handed out passes these. Renaming one in the entry
        # script breaks all of them at once.
        $entryAst = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $Folder $script:Tool.Entry), [ref]$null, [ref]$null)
        $accepted = @($entryAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        foreach ($parameter in 'SettingsPath', 'ReportFolder', 'Folder', 'NoPrompt') {
            $accepted | Should -Contain $parameter
        }
    }

    It 'prefills only settings its template has' {
        if (-not $script:Tool.ContainsKey('Prefill')) { return }

        $template = New-Object System.Xml.XmlDocument
        $template.Load((Join-Path $Folder $script:Tool.Settings))

        foreach ($element in $script:Tool.Prefill.Keys) {
            $template.DocumentElement.SelectSingleNode($element) | Should -Not -BeNullOrEmpty -Because "<$element> is prefilled"
        }
    }
}
