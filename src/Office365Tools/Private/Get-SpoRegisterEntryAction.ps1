<#
.SYNOPSIS
    Decides whether a register row needs creating, updating, or nothing.
.DESCRIPTION
    The one judgement in the register sync that can be wrong in an interesting
    way, kept here so it can be tested without a tenant.

    A Document Set keeps its Document ID when it is moved to another library.
    That is what makes the register survive a move -- and also what makes a
    moved Document Set produce a row that is correctly identified and wrongly
    filed: its content type still names the old library, and its reference
    still links into it.

    Two comparisons are deliberately *not* made:

      - No content type drift is reported when nothing was mapped for the
        library, or when the row's current content type could not be read.
        Either way there is nothing to compare against, and reclassifying on a
        guess is worse than leaving it.

      - Metadata columns are not compared at all. A register is hand-edited,
        and treating an edited Title as drift would mean overwriting it on
        every run.
.PARAMETER Current
    The register's existing row -- an object with ContentType and Reference --
    or $null when the register has no row for this Document Set.
.PARAMETER ContentType
    Content type the row should have. Empty when the library is unmapped.
.PARAMETER ReferenceField
    Internal name of the reference column. Empty when the register has none.
.PARAMETER Reference
    Reference URL the row should have.
.OUTPUTS
    PSCustomObject with Action ('Create', 'Update' or 'Current') and Difference,
    the names of the columns that drifted.
.EXAMPLE
    Get-SpoRegisterEntryAction -Current $null -Reference $url -ReferenceField Link

    Action 'Create': the register has no row for it.
.EXAMPLE
    Get-SpoRegisterEntryAction -Current $row -ContentType 'Project Entry' `
        -ReferenceField Link -Reference $url

    Action 'Update' with Difference ContentType, Link when the Document Set has
    moved from the library the row was registered under.
#>
function Get-SpoRegisterEntryAction {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        $Current,

        [Parameter(Position = 1)]
        [AllowEmptyString()]
        [string]$ContentType = '',

        [Parameter(Position = 2)]
        [AllowEmptyString()]
        [string]$ReferenceField = '',

        [Parameter(Position = 3)]
        [AllowEmptyString()]
        [string]$Reference = ''
    )

    if ($null -eq $Current) {
        return [pscustomobject]@{
            Action     = 'Create'
            Difference = @()
        }
    }

    $difference = [System.Collections.Generic.List[string]]::new()

    if ($ContentType -and $Current.ContentType -and $Current.ContentType -ne $ContentType) {
        $difference.Add('ContentType')
    }

    if ($ReferenceField -and $Current.Reference -ne $Reference) {
        $difference.Add($ReferenceField)
    }

    [pscustomobject]@{
        Action     = if ($difference.Count -gt 0) { 'Update' } else { 'Current' }
        Difference = @($difference)
    }
}
