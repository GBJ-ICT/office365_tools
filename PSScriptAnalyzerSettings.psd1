@{
    # Rules are the enforcement arm of the conventions in CONTRIBUTING.md.
    # If CI is green, the naming and safety conventions were followed.
    IncludeDefaultRules = $true

    Severity            = @('Error', 'Warning')

    ExcludeRules        = @(
        # We deliberately use Write-Host in the *presentation* layer
        # (scripts/, Format-* helpers) where colourised console output is the
        # point. Module commands emit objects; that is enforced by review.
        'PSAvoidUsingWriteHost',

        # Singular-noun rule fires on nouns like 'SpoPermissionMismatch' that
        # are already singular; the analyzer's heuristic misreads the prefix.
        'PSUseSingularNouns'
    )

    Rules               = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $true
        }

        PSUseConsistentIndentation = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }

        PSUseConsistentWhitespace  = @{
            Enable         = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            # CheckOperator is off because it contradicts
            # PSAlignAssignmentStatement below: aligned '=' signs read as
            # "extra whitespace around a binary operator". We align, so this
            # check has to yield.
            CheckOperator  = $false
            CheckSeparator = $true
        }

        PSAlignAssignmentStatement = @{
            Enable = $true
        }

        PSUseCorrectCasing         = @{
            Enable = $true
        }
    }
}
