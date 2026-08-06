<#
    Tests for the private helpers. These use InModuleScope because the helpers
    are deliberately not exported -- testing them through the public surface
    would mean mocking PnP for cases that are pure string handling.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SpoRelativePath' {

    It 'computes depth 1 for an item in the library root' {
        InModuleScope Office365Tools {
            $result = Get-SpoRelativePath -ServerRelativeUrl '/sites/team/Documents/plan.docx' -RootUrl '/sites/team/Documents'
            $result.Depth        | Should -Be 1
            $result.RelativePath | Should -Be 'plan.docx'
            $result.Name         | Should -Be 'plan.docx'
            $result.ParentUrl    | Should -Be '/sites/team/Documents'
        }
    }

    It 'computes depth 3 for a nested item' {
        InModuleScope Office365Tools {
            $result = Get-SpoRelativePath -ServerRelativeUrl '/sites/team/Documents/Projects/2026/plan.docx' -RootUrl '/sites/team/Documents'
            $result.Depth        | Should -Be 3
            $result.RelativePath | Should -Be 'Projects/2026/plan.docx'
            $result.ParentUrl    | Should -Be '/sites/team/Documents/Projects/2026'
        }
    }

    It 'tolerates a trailing slash on the root' {
        InModuleScope Office365Tools {
            $result = Get-SpoRelativePath -ServerRelativeUrl '/sites/team/Documents/plan.docx' -RootUrl '/sites/team/Documents/'
            $result.RelativePath | Should -Be 'plan.docx'
        }
    }

    It 'matches the root case-insensitively' {
        InModuleScope Office365Tools {
            $result = Get-SpoRelativePath -ServerRelativeUrl '/sites/team/DOCUMENTS/plan.docx' -RootUrl '/sites/team/documents'
            $result.RelativePath | Should -Be 'plan.docx'
        }
    }

    It 'returns the whole path when the item is not under the root' {
        InModuleScope Office365Tools {
            # Better to hand back something obviously wrong than a silently
            # mangled substring.
            $result = Get-SpoRelativePath -ServerRelativeUrl '/sites/other/Lists/plan.docx' -RootUrl '/sites/team/Documents'
            $result.RelativePath | Should -Be 'sites/other/Lists/plan.docx'
        }
    }
}

Describe 'New-SpoFinding' {

    It 'produces the standard finding shape' {
        InModuleScope Office365Tools {
            $finding = New-SpoFinding -RuleId 'Test.Rule' -Severity Warning -Scope Item `
                -Target '/sites/team/Documents/x.docx' -Message 'Something is off.' -List 'Documents'

            $finding.PSObject.TypeNames | Should -Contain 'Office365Tools.Finding'
            $finding.RuleId             | Should -Be 'Test.Rule'
            $finding.Severity           | Should -Be 'Warning'
            $finding.Scope              | Should -Be 'Item'
            $finding.List               | Should -Be 'Documents'
            $finding.Target             | Should -Be '/sites/team/Documents/x.docx'
            $finding.Message            | Should -Be 'Something is off.'
            $finding.DetectedAt         | Should -BeOfType [datetime]
        }
    }

    It 'converts Detail to an object' {
        InModuleScope Office365Tools {
            $finding = New-SpoFinding -RuleId 'Test.Rule' -Severity Info -Scope List `
                -Target 'Documents' -Message 'x' -Detail @{ Count = 3 }
            $finding.Detail.Count | Should -Be 3
        }
    }

    It 'leaves Detail null when none is supplied' {
        InModuleScope Office365Tools {
            $finding = New-SpoFinding -RuleId 'Test.Rule' -Severity Info -Scope List -Target 'x' -Message 'y'
            $finding.Detail | Should -BeNullOrEmpty
        }
    }

    It 'rejects an unknown severity' {
        InModuleScope Office365Tools {
            { New-SpoFinding -RuleId 'r' -Severity Critical -Scope Item -Target 't' -Message 'm' } | Should -Throw
        }
    }
}

Describe 'ConvertTo-SpoReportHtml' {

    It 'HTML-encodes values so a file name cannot break the page' {
        InModuleScope Office365Tools {
            $finding = New-SpoFinding -RuleId 'Test.Rule' -Severity Error -Scope Item `
                -Target '/sites/team/Q1 <script>alert(1)</script>.docx' -Message 'Bad name.'

            $html = ConvertTo-SpoReportHtml -Item @($finding) -Title 'Test'

            $html | Should -Not -Match '<script>alert'
            $html | Should -Match '&lt;script&gt;'
        }
    }

    It 'encodes the title too' {
        InModuleScope Office365Tools {
            $html = ConvertTo-SpoReportHtml -Item @() -Title 'A & B <c>'
            $html | Should -Match 'A &amp; B &lt;c&gt;'
        }
    }

    It 'renders an empty-state message for no findings' {
        InModuleScope Office365Tools {
            $html = ConvertTo-SpoReportHtml -Item @() -Title 'Empty'
            $html | Should -Match 'Nothing to report'
        }
    }

    It 'produces a complete, self-contained document' {
        InModuleScope Office365Tools {
            $finding = New-SpoFinding -RuleId 'R' -Severity Info -Scope Item -Target 't' -Message 'm'
            $html = ConvertTo-SpoReportHtml -Item @($finding) -Title 'T'

            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match '</html>'
            $html | Should -Match '<style>'
            # No external references: the report has to survive being e-mailed.
            $html | Should -Not -Match '<script src='
            $html | Should -Not -Match '<link .*href='
        }
    }

    It 'groups findings by severity with counts' {
        InModuleScope Office365Tools {
            $findings = @(
                New-SpoFinding -RuleId 'A' -Severity Error -Scope Item -Target 't1' -Message 'm'
                New-SpoFinding -RuleId 'B' -Severity Error -Scope Item -Target 't2' -Message 'm'
                New-SpoFinding -RuleId 'C' -Severity Info -Scope Item -Target 't3' -Message 'm'
            )
            $html = ConvertTo-SpoReportHtml -Item $findings -Title 'T'

            $html | Should -Match 'sev-Error'
            $html | Should -Match 'sev-Info'
            $html | Should -Match '2 finding\(s\)'
        }
    }

    It 'falls back to a plain table for non-finding objects' {
        InModuleScope Office365Tools {
            $rows = @([pscustomobject]@{ Alpha = 1; Beta = 'two' })
            $html = ConvertTo-SpoReportHtml -Item $rows -Title 'T'

            $html | Should -Match '<th>Alpha</th>'
            $html | Should -Match '<th>Beta</th>'
            $html | Should -Match 'two'
        }
    }
}

Describe 'ConvertTo-SpoPermissionSignature' {

    # The CSOM types cannot be constructed in a test, and Get-PnPProperty
    # type-checks its -ClientObject parameter before any mock runs -- which is
    # exactly why the canonicalisation lives in its own pure function.

    It 'returns an empty string for no entries' {
        InModuleScope Office365Tools {
            ConvertTo-SpoPermissionSignature -Entry @() | Should -Be ''
            ConvertTo-SpoPermissionSignature -Entry $null | Should -Be ''
        }
    }

    It 'is stable regardless of principal order' {
        InModuleScope Office365Tools {
            $a = @(
                [pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) }
                [pscustomobject]@{ LoginName = 'bob'; RoleIds = @(1073741827) }
            )
            $b = @(
                [pscustomobject]@{ LoginName = 'bob'; RoleIds = @(1073741827) }
                [pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) }
            )

            ConvertTo-SpoPermissionSignature -Entry $a |
                Should -Be (ConvertTo-SpoPermissionSignature -Entry $b)
        }
    }

    It 'is stable regardless of role order within a principal' {
        InModuleScope Office365Tools {
            $a = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741827, 1073741826) })
            $b = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826, 1073741827) })

            ConvertTo-SpoPermissionSignature -Entry $a |
                Should -Be (ConvertTo-SpoPermissionSignature -Entry $b)
        }
    }

    It 'ignores the Limited Access role' {
        InModuleScope Office365Tools {
            $withLimited    = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826, 1073741825) })
            $withoutLimited = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) })

            ConvertTo-SpoPermissionSignature -Entry $withLimited |
                Should -Be (ConvertTo-SpoPermissionSignature -Entry $withoutLimited)
        }
    }

    It 'drops a principal holding only Limited Access' {
        InModuleScope Office365Tools {
            $entries = @([pscustomobject]@{ LoginName = 'traverse-only'; RoleIds = @(1073741825) })
            ConvertTo-SpoPermissionSignature -Entry $entries | Should -Be ''
        }
    }

    It 'distinguishes different principals' {
        InModuleScope Office365Tools {
            $a = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) })
            $b = @([pscustomobject]@{ LoginName = 'bob'; RoleIds = @(1073741826) })

            ConvertTo-SpoPermissionSignature -Entry $a |
                Should -Not -Be (ConvertTo-SpoPermissionSignature -Entry $b)
        }
    }

    It 'distinguishes different roles for the same principal' {
        InModuleScope Office365Tools {
            $read  = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) })
            $write = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741827) })

            ConvertTo-SpoPermissionSignature -Entry $read |
                Should -Not -Be (ConvertTo-SpoPermissionSignature -Entry $write)
        }
    }

    It 'distinguishes a principal having an extra role' {
        InModuleScope Office365Tools {
            $one = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826) })
            $two = @([pscustomobject]@{ LoginName = 'anna'; RoleIds = @(1073741826, 1073741827) })

            ConvertTo-SpoPermissionSignature -Entry $one |
                Should -Not -Be (ConvertTo-SpoPermissionSignature -Entry $two)
        }
    }
}

Describe 'Get-SpoPermissionSignature' {

    It 'returns an empty string for no assignments' {
        InModuleScope Office365Tools {
            Get-SpoPermissionSignature -RoleAssignment $null | Should -Be ''
        }
    }
}
