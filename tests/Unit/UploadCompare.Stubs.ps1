<#
    Stand-ins for the PnP cmdlets Compare-SpoFolder calls, plus a builder for
    the list items it walks. Dot-sourced inside InModuleScope so that Mock has
    a command to replace: PnP.PowerShell is deliberately not a dependency of
    this module, so on a machine without it these names do not otherwise exist.
#>

$script:StubRoot = '/sites/team/Freigegebene Dokumente'

# The parameters exist so that the mocks can filter on them; the stub bodies
# are never reached, which is what the analyzer is objecting to.
function Get-PnPListItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Justification = 'Stub standing in for a PnP cmdlet.')]
    param($List, $PageSize)
}

function Get-PnPProperty {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Justification = 'Stub standing in for a PnP cmdlet.')]
    param($ClientObject, $Property)
}

Mock Assert-SpoConnection { $true }
Mock Write-O365Log {}
Mock Resolve-SpoList { [pscustomobject]@{ Title = 'Dokumente' } }
Mock Get-PnPProperty { [pscustomobject]@{ ServerRelativeUrl = $script:StubRoot } } -ParameterFilter { $Property -eq 'RootFolder' }

# Builds what Get-PnPListItem returns: paths are given relative to the library
# root, which is how they read in the tests.
function New-StubItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Test helper that builds in-memory objects.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$Folder = @(),
        [string[]]$File = @()
    )

    foreach ($path in $Folder) {
        [pscustomobject]@{
            FileSystemObjectType = 'Folder'
            Id                   = 1
            FieldValues          = @{ FileRef = "$script:StubRoot/$path" }
        }
    }

    foreach ($path in $File) {
        [pscustomobject]@{
            FileSystemObjectType = 'File'
            Id                   = 2
            FieldValues          = @{ FileRef = "$script:StubRoot/$path"; 'File_x0020_Size' = '1' }
        }
    }
}
