<#
    Tests for the publish-eligibility rule.

    This is the one piece of logic in the module where a false positive is
    materially worse than a false negative: publishing a draft makes it the
    version every reader sees, and if somebody's unfinished work is in that
    draft, it has just been published for them. So most of these tests assert
    that a draft is *refused*, and why.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    $script:Author = 'global.admin@contoso.com'
    $script:Since  = [datetime]::SpecifyKind([datetime]'2026-08-03 09:30:00', 'Utc')
    $script:Until  = [datetime]::SpecifyKind([datetime]'2026-08-03 11:40:00', 'Utc')
    $script:During = [datetime]::SpecifyKind([datetime]'2026-08-03 10:03:00', 'Utc')
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Test-SpoDraftPublishable' {

    BeforeEach {
        # The happy case, which each test then breaks in exactly one way.
        $script:Ok = @{
            VersionLabel   = '3.1'
            LastEditor     = $script:Author
            Modified       = $script:During
            CheckedOut     = $false
            Author         = $script:Author
            Since          = $script:Since
            Until          = $script:Until
            InChangeRecord = $true
        }
    }

    It 'publishes a draft that is provably nothing but our own change' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeTrue
            $result.Reason      | Should -Be 'Publishable'
        }
    }

    It 'refuses a draft with more than one save since the last published version' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            # 3.2 means two saves since 3.0: ours and somebody else's.
            $Ok.VersionLabel = '3.2'
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'MultipleMinorVersions'
        }
    }

    It 'refuses a file that has never been published' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            # Publishing 0.x would expose content for the first time rather
            # than restore what readers used to see.
            $Ok.VersionLabel = '0.2'
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'NeverPublished'
        }
    }

    It 'refuses a checked-out file' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.CheckedOut = $true
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'CheckedOut'
        }
    }

    It 'refuses anything absent from the change record' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.InChangeRecord = $false
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'NotInChangeRecord'
        }
    }

    It 'refuses a draft last saved by somebody else' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.LastEditor = 'anna@contoso.com'
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'LastEditedBySomeoneElse'
        }
    }

    It 'refuses a draft saved outside the window, even by the right account' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.Modified = [datetime]::SpecifyKind([datetime]'2026-07-01 10:00:00', 'Utc')
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'OutsideWindow'
        }
    }

    It 'refuses when the timestamp is unknown but a window was given' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.Modified = $null
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'UnknownModifiedTime'
        }
    }

    It 'reports an already published file rather than republishing it' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.VersionLabel = '4.0'
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'AlreadyPublished'
        }
    }

    It 'refuses an unknown version' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.VersionLabel = ''
            $result = Test-SpoDraftPublishable @Ok
            $result.Publishable | Should -BeFalse
            $result.Reason      | Should -Be 'UnknownVersion'
        }
    }

    It 'reports checkout ahead of the version rule, because it is the more useful reason' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.CheckedOut = $true
            $Ok.VersionLabel = '3.4'
            (Test-SpoDraftPublishable @Ok).Reason | Should -Be 'CheckedOut'
        }
    }

    It 'still applies the version rule when no change record is required' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.InChangeRecord = $false
            $Ok.RequireChangeRecord = $false

            (Test-SpoDraftPublishable @Ok).Publishable | Should -BeTrue

            $Ok.VersionLabel = '3.3'
            (Test-SpoDraftPublishable @Ok).Reason | Should -Be 'MultipleMinorVersions'
        }
    }

    It 'accepts any timestamp when no window is given' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.Since = $null
            $Ok.Until = $null
            $Ok.Modified = [datetime]::SpecifyKind([datetime]'2001-01-01 00:00:00', 'Utc')
            (Test-SpoDraftPublishable @Ok).Publishable | Should -BeTrue
        }
    }

    It 'treats a high major version the same as a low one' {
        InModuleScope Office365Tools -Parameters @{ Ok = $script:Ok } {
            param($Ok)
            $Ok.VersionLabel = '70.1'
            (Test-SpoDraftPublishable @Ok).Publishable | Should -BeTrue

            $Ok.VersionLabel = '70.63'
            (Test-SpoDraftPublishable @Ok).Reason | Should -Be 'MultipleMinorVersions'
        }
    }
}
