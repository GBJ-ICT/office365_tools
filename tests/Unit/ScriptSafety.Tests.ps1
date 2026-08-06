<#
    A script in scripts/ that declares -WhatIf has to make it mean something.

    The trap this guards is specific and it is silent. $WhatIfPreference, set by
    a script's own -WhatIf, does *not* reach a function defined inside a module:
    the function resolves preference variables in the module's scope, where it
    is still false. So

        ./scripts/Do-Thing.ps1 -WhatIf     # inside: Add-SpoListItem -Values $v

    writes for real, while every `if ($WhatIfPreference)` in the script agrees
    that nothing happened -- and the summary at the end reports zero changes.
    There is no error and no warning; the only symptom is the tenant.

    Two patterns are correct, and both are in use here:

      forward   Add-SpoListItem ... -WhatIf:$WhatIfPreference
                (or a splat carrying WhatIf)
      gate      if (-not $PSCmdlet.ShouldProcess(...)) { continue }
                before the call, so the script decides for itself

    This test accepts either and rejects a script that does neither.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Consumed by -ForEach on the It block below, which the analyzer does not trace.')]
param()

BeforeAll {
    # Not BeforeDiscovery: that scope is gone by the time the It bodies run.
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    $script:MutatingCommand = @(Get-Command -Module Office365Tools |
            Where-Object { $_.Verb -in 'Add', 'New', 'Remove', 'Set', 'Update', 'Import', 'Repair', 'Sync', 'Grant', 'Revoke', 'Publish' } |
            ForEach-Object { $_.Name })
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

BeforeDiscovery {
    $scriptRoot = Join-Path $PSScriptRoot '../../scripts'

    $shouldProcessScripts = @(
        Get-ChildItem -Path $scriptRoot -Filter '*.ps1' |
            Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match 'SupportsShouldProcess' } |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    )
}

Describe 'Scripts that declare -WhatIf' {

    It '<Name> makes -WhatIf reach every mutating command it calls' -ForEach $shouldProcessScripts {
        $text   = Get-Content -Raw -LiteralPath $Path
        $tokens = $null
        $errors = $null
        $ast    = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)

        $errors | Should -BeNullOrEmpty -Because 'the script has to parse before anything else can be checked'

        # A script that gates its own writes has already answered the question.
        $gatesItself = $text -match '\$PSCmdlet\.ShouldProcess'

        $mutating = $script:MutatingCommand

        $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -in $mutating
            }.GetNewClosure(), $true)

        foreach ($call in $calls) {
            $elements = @($call.CommandElements)

            $forwarded = @($elements | Where-Object {
                    $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'WhatIf'
                }).Count -gt 0

            # A splatted hashtable is trusted: whether it carries WhatIf is not
            # decidable from the call site, and the splat is the pattern the
            # module's own scripts use.
            $splatted = @($elements | Where-Object {
                    $_ -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.Splatted
                }).Count -gt 0

            ($forwarded -or $splatted -or $gatesItself) |
                Should -BeTrue -Because "$($call.GetCommandName()) on line $($call.Extent.StartLineNumber) of $Name would write under -WhatIf: preference variables do not cross into module scope"
        }
    }
}
