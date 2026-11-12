<#
    Tests for "SharePoint list to PDF", the tool behind the menu: the launch
    stub that runs under Windows PowerShell 5.1, and the PowerShell 7 script it
    hands over to.

    The stub is run the way a person runs it, under powershell.exe, with a
    settings file that is wrong in one particular way. The script is run in this
    session with the module's commands mocked, so what it asks, what it passes
    on and when it opens the folder can be checked without a tenant.

    The language of the child runs is fixed with O365_LANGUAGE, so these do not
    depend on the machine they run on.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'The variables are consumed by -ForEach and -Skip on the tests below, which the analyzer does not trace.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars', '',
    Justification = 'A mock body and a parameter filter run in Pester''s own scope, where $script: is not this file''s; what they share with the test has to be global, and is removed in AfterAll.')]
param()

BeforeDiscovery {
    $canRunWindowsPowerShell = [bool](Get-Command powershell.exe -ErrorAction SilentlyContinue)

    # The whole chain, stub to script, needs PowerShell 7 to find PnP.PowerShell.
    $canRunChain = $canRunWindowsPowerShell -and [bool](Get-Command pwsh -ErrorAction SilentlyContinue) -and
    [bool](Get-Module -ListAvailable -Name PnP.PowerShell)

    # The hand-over needs PowerShell 7 to start, and nothing else: PnP.PowerShell
    # is stood in for by an empty module, and the script that prints by one that
    # only writes down what it was given.
    $canHandOver = $canRunWindowsPowerShell -and [bool](Get-Command pwsh -ErrorAction SilentlyContinue)

    # What each wrong settings file says, in each language. Fragments are ASCII
    # so the comparison does not depend on how the console encodes umlauts.
    $cases = @(
        @{
            Name    = 'a setting it does not know'
            Xml     = '<ListToPdf><List>ask</List><Colour>blue</Colour></ListToPdf>'
            English = 'do not recognise'
            German  = 'Einstellung, die ich nicht kenne'
        }
        @{
            Name    = 'a file that is not a settings file of this tool'
            Xml     = '<UploadCheck><Folder>ask</Folder></UploadCheck>'
            English = 'is not a settings file of this tool'
            German  = 'keine Einstellungsdatei dieses Tools'
        }
        @{
            Name    = 'a file that is not valid XML'
            Xml     = '<ListToPdf><List>ask</ListToPdf'
            English = 'could not be read'
            German  = 'konnte nicht gelesen werden'
        }
        @{
            Name    = 'a language it does not know'
            Xml     = '<ListToPdf><Language>fr</Language></ListToPdf>'
            English = 'en, de or auto'
            German  = 'en, de oder auto'
        }
        @{
            Name    = 'an orientation it does not know'
            Xml     = '<ListToPdf><Orientation>Diagonal</Orientation></ListToPdf>'
            English = 'has to be one of: Landscape, Portrait'
            German  = 'muss eine dieser sein: Landscape, Portrait'
        }
        @{
            Name    = 'a paper size it does not know'
            Xml     = '<ListToPdf><PaperSize>B5</PaperSize></ListToPdf>'
            English = 'has to be one of: A4, A3, A5, Letter, Legal'
            German  = 'muss eine dieser sein: A4, A3, A5, Letter, Legal'
        }
        @{
            Name    = 'no site to sign in to'
            Xml     = '<ListToPdf><SiteUrl></SiteUrl><ClientId>00000000-0000-0000-0000-000000000000</ClientId></ListToPdf>'
            English = 'Printing a list means signing in'
            German  = 'Zum Drucken einer Liste musst du dich anmelden'
        }
    )
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Stub = Join-Path $script:RepoRoot 'packaging/ListToPdf/Start-ListToPdf.ps1'
    $script:Tool = Join-Path $script:RepoRoot 'packaging/ListToPdf/Invoke-ListToPdf.ps1'

    $script:Folder = Join-Path ([System.IO.Path]::GetTempPath()) "o365listpdf-$([guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:Folder -ItemType Directory -Force | Out-Null

    function Invoke-Stub {
        param(
            [string]$Xml,
            [string]$Language,
            [string]$ReportFolder
        )

        $settings = Join-Path $script:Folder 'list-to-pdf.xml'
        [System.IO.File]::WriteAllText($settings, $Xml, (New-Object System.Text.UTF8Encoding($false)))

        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:Stub, '-SettingsPath', $settings, '-NoPrompt')
        if ($ReportFolder) { $arguments += @('-ReportFolder', $ReportFolder) }

        $saved = $env:O365_LANGUAGE
        $savedPath = $env:O365_SETTINGS_PATH
        try {
            $env:O365_LANGUAGE = $Language
            $env:O365_SETTINGS_PATH = Join-Path $script:Folder 'saved-settings.json'
            $output = & powershell.exe @arguments 2>&1
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

Describe 'The launch stub of the list-to-PDF tool' {

    It 'is plain ASCII, so Windows PowerShell 5.1 reads it however the console is set' {
        $bytes = [System.IO.File]::ReadAllBytes($script:Stub)

        @($bytes | Where-Object { $_ -gt 127 }) | Should -BeNullOrEmpty
    }

    It 'uses nothing that only PowerShell 7 understands' {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:Stub, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        $newer = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.TernaryExpressionAst] -or
                $node -is [System.Management.Automation.Language.PipelineChainAst] -or
                ($node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Operator -in 'QuestionQuestionEquals', 'QuestionDotEquals') -or
                ($node -is [System.Management.Automation.Language.BinaryExpressionAst] -and $node.Operator -eq 'QuestionQuestion') -or
                ($node -is [System.Management.Automation.Language.ForEachStatementAst] -and $node.Flags -ne 'None')
            }, $true)

        @($newer) | Should -BeNullOrEmpty
    }

    It 'takes what every launcher passes' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:Stub, [ref]$null, [ref]$null)
        $accepted = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        foreach ($parameter in 'SettingsPath', 'ReportFolder', 'Folder', 'NoPrompt', 'Language') {
            $accepted | Should -Contain $parameter
        }
    }

    It 'ships a settings template that is a ListToPdf file naming every setting it reads' {
        $template = New-Object System.Xml.XmlDocument
        $template.Load((Join-Path $script:RepoRoot 'packaging/ListToPdf/list-to-pdf.xml'))

        $template.DocumentElement.Name | Should -Be 'ListToPdf'
        $names = @($template.DocumentElement.ChildNodes | Where-Object { $_.NodeType -eq 'Element' } | ForEach-Object { $_.Name })

        foreach ($setting in 'SiteUrl', 'ClientId', 'List', 'View', 'Orientation', 'PaperSize', 'Reason', 'OutputFolder', 'Language') {
            $names | Should -Contain $setting
        }
    }

    It 'prints A4 landscape unless told otherwise' {
        $template = New-Object System.Xml.XmlDocument
        $template.Load((Join-Path $script:RepoRoot 'packaging/ListToPdf/list-to-pdf.xml'))

        $template.DocumentElement.SelectSingleNode('Orientation').InnerText | Should -Be 'Landscape'
        $template.DocumentElement.SelectSingleNode('PaperSize').InnerText | Should -Be 'A4'
    }
}

Describe 'The launch stub, given a settings file that is wrong' -Skip:(-not $canRunWindowsPowerShell) {

    It 'says <Name> in English, and stops with the exit code for a setup problem' -ForEach $cases {
        $result = Invoke-Stub -Xml $Xml -Language 'en'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike "*$English*"
    }

    It 'says <Name> in German' -ForEach $cases {
        $result = Invoke-Stub -Xml $Xml -Language 'de'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike "*$German*"
    }

    It 'does not show German to someone who chose English' -ForEach $cases {
        (Invoke-Stub -Xml $Xml -Language 'en').Text | Should -Not -BeLike "*$German*"
    }
}

Describe 'The whole chain, from the stub to the script' -Skip:(-not $canRunChain) {

    It 'stops before signing in when the PDF cannot be written, and says so' {
        # A folder inside a file cannot be created, wherever this runs.
        $blocker = Join-Path $script:Folder 'a-file'
        Set-Content -LiteralPath $blocker -Value 'x'
        $xml = "<ListToPdf><SiteUrl>https://contoso.sharepoint.com/sites/team</SiteUrl><ClientId>00000000-0000-0000-0000-000000000000</ClientId><List>Protokoll</List><View>Alle</View><Reason>none</Reason><OutputFolder>$blocker\sub</OutputFolder></ListToPdf>"

        $result = Invoke-Stub -Xml $xml -Language 'en'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*cannot be written to*'
        $result.Text | Should -Not -BeLike '*Signing in to*'
    }

    It 'says the same in German' {
        $blocker = Join-Path $script:Folder 'a-file'
        Set-Content -LiteralPath $blocker -Value 'x'
        $xml = "<ListToPdf><SiteUrl>https://contoso.sharepoint.com/sites/team</SiteUrl><ClientId>00000000-0000-0000-0000-000000000000</ClientId><OutputFolder>$blocker\sub</OutputFolder></ListToPdf>"

        $result = Invoke-Stub -Xml $xml -Language 'de'

        $result.Code | Should -Be 2
        $result.Text | Should -BeLike '*kann nicht nach*geschrieben werden*'
    }
}

Describe 'The stub hands what the settings name over to the script' -Skip:(-not $canHandOver) {

    BeforeAll {
        # A copy of what the stub looks for, with the script that prints swapped
        # for one that writes down the arguments it was started with.
        $script:Copy = Join-Path ([System.IO.Path]::GetTempPath()) "o365handover-$([guid]::NewGuid().ToString('N'))"
        $tool = Join-Path $script:Copy 'packaging/ListToPdf'
        New-Item -Path $tool -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $script:RepoRoot 'src') -Destination $script:Copy -Recurse
        Copy-Item -Path (Join-Path $script:RepoRoot 'packaging/ListToPdf/*') -Destination $tool -Recurse

        Set-Content -LiteralPath (Join-Path $tool 'Invoke-ListToPdf.ps1') -Encoding ascii -Value @'
[System.IO.File]::WriteAllLines($env:O365_HANDOVER_FILE, [string[]]$args)
exit 0
'@

        # The stub asks PowerShell 7 whether PnP.PowerShell is there; an empty
        # module of that name is enough to say yes.
        $script:Modules = Join-Path $script:Copy 'modules'
        $fake = Join-Path $script:Modules 'PnP.PowerShell'
        New-Item -Path $fake -ItemType Directory -Force | Out-Null
        New-ModuleManifest -Path (Join-Path $fake 'PnP.PowerShell.psd1') -ModuleVersion '1.0.0'

        function Invoke-HandOver {
            param([string]$Body)

            $settings = Join-Path $script:Copy 'list-to-pdf.xml'
            $record = Join-Path $script:Copy 'arguments.txt'
            Remove-Item -LiteralPath $record -ErrorAction SilentlyContinue

            $xml = "<ListToPdf><SiteUrl>https://contoso.sharepoint.com/sites/team</SiteUrl><ClientId>00000000-0000-0000-0000-000000000000</ClientId><OutputFolder>$(Join-Path $script:Copy 'out')</OutputFolder>$Body</ListToPdf>"
            [System.IO.File]::WriteAllText($settings, $xml, (New-Object System.Text.UTF8Encoding($false)))

            $saved = @{ Record = $env:O365_HANDOVER_FILE; Modules = $env:PSModulePath; Language = $env:O365_LANGUAGE }
            try {
                $env:O365_HANDOVER_FILE = $record
                $env:PSModulePath = "$($script:Modules);$($env:PSModulePath)"
                $env:O365_LANGUAGE = 'en'

                $stub = Join-Path $tool 'Start-ListToPdf.ps1'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stub -SettingsPath $settings -NoPrompt 2>&1
                [pscustomobject]@{
                    Text      = ($output | Out-String)
                    Code      = $LASTEXITCODE
                    Arguments = $(if (Test-Path -LiteralPath $record) { @(Get-Content -LiteralPath $record) } else { @() })
                }
            }
            finally {
                $env:O365_HANDOVER_FILE = $saved.Record
                $env:PSModulePath = $saved.Modules
                $env:O365_LANGUAGE = $saved.Language
            }
        }

        function Get-HandedOver {
            param($Result, [string]$Name)
            $at = [array]::IndexOf($Result.Arguments, $Name)
            if ($at -ge 0) { $Result.Arguments[$at + 1] } else { $null }
        }
    }

    AfterAll {
        Remove-Item -LiteralPath $script:Copy -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'passes the site, the list, the view and the reason on, as the script takes them' {
        $result = Invoke-HandOver -Body '<List>Protokoll</List><View>Offene Pendenzen</View><Reason>Board meeting</Reason>'

        $result.Code | Should -Be 0
        Get-HandedOver $result '-SiteUrl' | Should -Be 'https://contoso.sharepoint.com/sites/team'
        Get-HandedOver $result '-List' | Should -Be 'Protokoll'
        Get-HandedOver $result '-View' | Should -Be 'Offene Pendenzen'
        Get-HandedOver $result '-Reason' | Should -Be 'Board meeting'
        Get-HandedOver $result '-Orientation' | Should -Be 'Landscape'
        Get-HandedOver $result '-PaperSize' | Should -Be 'A4'
        $result.Arguments | Should -Not -Contain '-NoReason'
    }

    It 'leaves out a list and a view the settings leave to be asked, and says there is no reason when it is none' {
        $result = Invoke-HandOver -Body '<List>ask</List><View></View><Reason>none</Reason>'

        $result.Code | Should -Be 0
        $result.Arguments | Should -Not -Contain '-List'
        $result.Arguments | Should -Not -Contain '-View'
        $result.Arguments | Should -Not -Contain '-Reason'
        $result.Arguments | Should -Contain '-NoReason'
    }
}

Describe 'The script that prints' {

    BeforeAll {
        Import-Module (Join-Path $script:RepoRoot 'src/Office365Tools/Office365Tools.psd1') -Force
        Set-O365Language -Language en -SessionOnly

        # Stand-ins that take anything, so the commands can be mocked whether or
        # not PnP.PowerShell is installed.
        $script:Stubbed = @()
        foreach ($name in 'Get-PnPList') {
            Set-Item -Path "function:global:$name" -Value { }
            $script:Stubbed += $name
        }

        $global:ListPdfDefault = [pscustomobject]@{ Title = 'Alle Elemente'; Id = [guid]::NewGuid(); DefaultView = $true }
        $global:ListPdfOther = [pscustomobject]@{ Title = 'Offene Pendenzen'; Id = [guid]::NewGuid(); DefaultView = $false }
        $global:ListPdfOutput = Join-Path $script:Folder 'out'

        function Invoke-Tool {
            param(
                [hashtable]$Arguments = @{},
                [string[]]$Answer = @()
            )

            # The queue and the list of what was said are made in BeforeEach,
            # where the mocks can see them; this only fills the queue.
            foreach ($item in $Answer) { $global:ListPdfAnswers.Enqueue($item) }
            $global:LASTEXITCODE = $null

            $all = @{
                SiteUrl      = 'https://contoso.sharepoint.com/sites/team'
                ClientId     = '00000000-0000-0000-0000-000000000000'
                OutputFolder = $global:ListPdfOutput
                Language     = 'en'
            }
            foreach ($key in $Arguments.Keys) { $all[$key] = $Arguments[$key] }

            & $script:Tool @all
            $global:LASTEXITCODE
        }
    }

    AfterAll {
        foreach ($name in $script:Stubbed) { Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue }
        Remove-Variable -Name ListPdfAnswers, ListPdfSaid, ListPdfDefault, ListPdfOther, ListPdfOutput -Scope Global -ErrorAction SilentlyContinue
        Set-O365Language -Language en -SessionOnly
        Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Remove-Item -LiteralPath $global:ListPdfOutput -Recurse -Force -ErrorAction SilentlyContinue

        $global:ListPdfAnswers = [System.Collections.Generic.Queue[string]]::new()
        $global:ListPdfSaid = [System.Collections.Generic.List[string]]::new()

        Mock Write-Host { $global:ListPdfSaid.Add([string]$Object) }
        Mock Read-Host { if ($global:ListPdfAnswers.Count -gt 0) { $global:ListPdfAnswers.Dequeue() } else { '' } }
        Mock Start-Process { }
        Mock Connect-O365 { }
        Mock Get-PnPList {
            [pscustomobject]@{ Title = 'Protokoll'; Hidden = $false }
            [pscustomobject]@{ Title = 'Aufgaben'; Hidden = $false }
            [pscustomobject]@{ Title = 'Versteckt'; Hidden = $true }
        }
        Mock Get-SpoListView { @($global:ListPdfDefault, $global:ListPdfOther) }
        Mock Export-SpoListPdf {
            [pscustomobject]@{ Path = $Path; RowCount = 7; ColumnCount = 4; PageCount = 2; Verified = $true; Finding = @() }
        }
    }

    It 'asks which view, from the stored views of the list, and prints the one chosen' {
        Invoke-Tool -Arguments @{ List = 'Protokoll' } -Answer '2', '' | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter {
            $Library -eq 'Protokoll' -and $View -eq $global:ListPdfOther.Id.ToString()
        }
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*Offene Pendenzen*'
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*Alle Elemente*(default view)*'
    }

    It 'takes the default view when Enter is pressed' {
        Invoke-Tool -Arguments @{ List = 'Protokoll' } -Answer '', '' | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $View -eq $global:ListPdfDefault.Id.ToString() }
    }

    It 'asks again after a number that is not on the list' {
        Invoke-Tool -Arguments @{ List = 'Protokoll' } -Answer '9', 'x', '2', '' | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $View -eq $global:ListPdfOther.Id.ToString() }
    }

    It 'maps a view named in the settings, and does not ask' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Offene Pendenzen'; Reason = 'Board meeting' } | Should -Be 0

        Should -Invoke Get-SpoListView -Times 1 -Exactly -ParameterFilter { $View -eq 'Offene Pendenzen' }
        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Reason -eq 'Board meeting' }
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'asks for the reason, and leaves it out when Enter is pressed' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente' } -Answer '' | Should -Be 0

        Should -Invoke Read-Host -Times 1 -Exactly
        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { -not $Reason }
    }

    It 'passes on the reason that was typed' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente' } -Answer 'Quartalsbericht' | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Reason -eq 'Quartalsbericht' }
    }

    It 'does not ask for a reason when told there is none' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'asks which list, from the lists of the site, hidden ones left out' {
        Invoke-Tool -Arguments @{ View = 'Alle Elemente'; NoReason = $true } -Answer '2' | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Library -eq 'Protokoll' -or $Library -eq 'Aufgaben' }
        ($global:ListPdfSaid -join "`n") | Should -Not -BeLike '*Versteckt*'
    }

    It 'signs in to the site, and prints the list, when given the address of a list' {
        $address = 'https://contoso.sharepoint.com/sites/team/Lists/Project%20plan/AllItems.aspx'

        Invoke-Tool -Arguments @{ SiteUrl = $address; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://contoso.sharepoint.com/sites/team' }
        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Library -eq 'Project plan' }
        Should -Invoke Get-PnPList -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*inside the site*sites/team*'
        ($global:ListPdfSaid -join "`n") | Should -BeLike "*names the list 'Project plan'*"
    }

    It 'takes the library from the address of a library view' {
        $address = 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx'

        Invoke-Tool -Arguments @{ SiteUrl = $address; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://contoso.sharepoint.com/sites/team' }
        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Library -eq 'Shared Documents' }
    }

    It 'prefers the list it was told to the one in the address' {
        $address = 'https://contoso.sharepoint.com/sites/team/Lists/Project%20plan/AllItems.aspx'

        Invoke-Tool -Arguments @{ SiteUrl = $address; List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $Library -eq 'Protokoll' }
    }

    It 'asks for the list when the address is only the site, and says nothing about the address' {
        Invoke-Tool -Arguments @{ SiteUrl = 'https://contoso.sharepoint.com/sites/team'; View = 'Alle Elemente'; NoReason = $true } -Answer '1' | Should -Be 0

        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://contoso.sharepoint.com/sites/team' }
        Should -Invoke Get-PnPList -Times 1 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -Not -BeLike '*inside the site*'
    }

    It 'takes the site from a sharing link, says it cannot tell the list, and asks for the list' {
        $link = 'https://contoso.sharepoint.com/:x:/s/team/cQoqB9eGsD2vT4vCAOndDmpvEgUCEliGPoESX5hBteETlJUoRA?e=abc'

        Invoke-Tool -Arguments @{ SiteUrl = $link; View = 'Alle Elemente'; NoReason = $true } -Answer '1' | Should -Be 0

        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://contoso.sharepoint.com/sites/team' }
        Should -Invoke Get-PnPList -Times 1 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*sharing link*sites/team*'
    }

    It 'takes a team site from a sharing link made for one' {
        Invoke-Tool -Arguments @{ SiteUrl = 'https://contoso.sharepoint.com/:f:/t/crew/Ex4kQ'; List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://contoso.sharepoint.com/teams/crew' }
    }

    It 'uses an address it cannot read as it is, and leaves the sign-in to say what is wrong' {
        $code = Invoke-Tool -Arguments @{ SiteUrl = 'https://teams.microsoft.com/l/channel/19%3Aabc/General'; List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true }

        $code | Should -Be 0 -Because ($global:ListPdfSaid -join ' | ')
        Should -Invoke Connect-O365 -Times 1 -Exactly -ParameterFilter { $SiteUrl -eq 'https://teams.microsoft.com/l/channel/19%3Aabc/General' }
    }

    It 'passes on the paper and the orientation, and writes into the folder it was given' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true; PaperSize = 'A3'; Orientation = 'Portrait' } | Should -Be 0

        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter {
            $PaperSize -eq 'A3' -and $Orientation -eq 'Portrait' -and (Split-Path -Parent $Path) -eq $global:ListPdfOutput
        }
    }

    It 'asks nothing under -NoPrompt, and takes the default view' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; NoPrompt = $true } | Should -Be 0

        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Export-SpoListPdf -Times 1 -Exactly -ParameterFilter { $View -eq $global:ListPdfDefault.Id.ToString() -and -not $Reason }
    }

    It 'opens the folder once, after the PDF is done' {
        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 0

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'explorer.exe' }
    }

    It 'stops, names the problem and opens nothing when the view is not there' {
        Mock Get-SpoListView { throw "View 'Nope' was not found on 'Protokoll'. Views on this list: Alle Elemente" }

        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Nope'; NoReason = $true } | Should -Be 1

        Should -Invoke Export-SpoListPdf -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike "*Nope*Alle Elemente*"
    }

    It 'stops and opens nothing when the list is not there' {
        Mock Export-SpoListPdf { throw "There is no list called 'Nirgends'." }

        Invoke-Tool -Arguments @{ List = 'Nirgends'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 1

        Should -Invoke Start-Process -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*could not be printed*Nirgends*'
    }

    It 'leaves no PDF and opens nothing for a view with no rows' {
        Mock Export-SpoListPdf {
            Set-Content -LiteralPath $Path -Value 'x'
            [pscustomobject]@{ Path = $Path; RowCount = 0; ColumnCount = 4; PageCount = 1; Verified = $true; Finding = @() }
        }

        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 1

        @(Get-ChildItem -LiteralPath $global:ListPdfOutput -Filter '*.pdf') | Should -BeNullOrEmpty
        Should -Invoke Start-Process -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*no rows*'
    }

    It 'says so and opens nothing when the finished PDF is missing a value' {
        Mock Export-SpoListPdf {
            [pscustomobject]@{
                Path = $Path; RowCount = 7; ColumnCount = 4; PageCount = 2; Verified = $false
                Finding = @([pscustomobject]@{ Severity = 'Error'; Message = "Row 3, column 'Text': the printed value is not in the PDF." })
            }
        }

        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 1

        Should -Invoke Start-Process -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike "*1 value(s) could not be found*Row 3*"
    }

    It 'shows what is missing from a finding the way the module makes one' {
        # New-SpoFinding keeps a finding's Detail as an object, with the value or
        # the address that was looked for in it, and as $null when there is none.
        Mock Export-SpoListPdf {
            $long = 'The board agreed that the budget for the autumn trip is raised by a fifth, and said so twice'
            [pscustomobject]@{
                Path = $Path; RowCount = 7; ColumnCount = 4; PageCount = 2; Verified = $false
                Finding = @(
                    [pscustomobject]@{ Severity = 'Error'; Message = 'Row 3, column Text: missing.'; Detail = [pscustomobject]@{ Row = 3; Column = 'Text'; Value = $long } }
                    [pscustomobject]@{ Severity = 'Error'; Message = 'Row 4, column Link: no link.'; Detail = [pscustomobject]@{ Row = 4; Column = 'Link'; Href = 'https://contoso.example/a' } }
                    [pscustomobject]@{ Severity = 'Error'; Message = 'The page count is off.'; Detail = $null }
                )
            }
        }

        Invoke-Tool -Arguments @{ List = 'Protokoll'; View = 'Alle Elemente'; NoReason = $true } | Should -Be 1

        $said = $global:ListPdfSaid -join "`n"
        $said | Should -BeLike '*3 value(s) could not be found*'
        # The start of the value, cut at 60 characters; the rest is not repeated.
        $said | Should -BeLike '*Row 3, column Text: missing.*The board agreed that the budget for the autumn trip is rais...*'
        $said | Should -Not -BeLike '*said twice*'
        $said | Should -BeLike '*Row 4, column Link: no link.*https://contoso.example/a*'
        $said | Should -BeLike '*The page count is off.*'
    }

    It 'stops before signing in when the folder cannot be written, and says so in German' {
        $blocker = Join-Path $script:Folder 'a-file'
        Set-Content -LiteralPath $blocker -Value 'x'

        Invoke-Tool -Arguments @{ List = 'Protokoll'; OutputFolder = "$blocker\sub"; Language = 'de' } | Should -Be 2

        Should -Invoke Connect-O365 -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
        ($global:ListPdfSaid -join "`n") | Should -BeLike '*kann nicht nach*geschrieben werden*'
    }
}
