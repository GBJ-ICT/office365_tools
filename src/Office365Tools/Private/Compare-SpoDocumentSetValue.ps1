<#
.SYNOPSIS
    Internal: works out how one item's metadata differs from its Document
    Set's, column by column.
.DESCRIPTION
    The decision at the heart of Get-SpoDocumentSetMismatch, kept pure so it
    can be tested without a tenant: given the Document Set's values, an item's
    values, and the columns that matter, it says which columns differ and what
    kind of difference each one is.

    The kind matters more than the fact, because the four kinds have different
    consequences for the repair:

      EmptyOnItem              The ordinary case. The Document Set has a value
                               and the item does not -- it was never pushed.
                               Safe to repair.
      ValueDiffers             Both have values and they disagree. Usually a
                               file copied in from somewhere else, carrying its
                               old metadata. Safe to repair, but worth reading
                               first.
      EmptyOnDocumentSet       The item has a value the Document Set does not.
                               Repairing would delete the only copy of it, so
                               the repair skips these unless told otherwise.
      ColumnMissingFromLibrary A shared column that does not exist on the
                               library. Not repairable by writing a value; the
                               column has to be added first.

    Values are compared through ConvertTo-SpoFieldValueKey, so a renamed term
    or a differently rendered display name is not a difference.
.PARAMETER Column
    Internal names of the columns to compare.
.PARAMETER DocumentSetValue
    Hashtable of internal name to the Document Set's raw value.
.PARAMETER ItemValue
    Hashtable of internal name to the item's raw value.
.PARAMETER AvailableColumn
    Internal names of the columns that exist on the library. Pass $null to
    treat every column as available.
.PARAMETER DisplayName
    Optional hashtable of internal name to display name, for the report.
.PARAMETER SharedColumn
    Internal names that are registered as shared columns, so each difference
    can say whether SharePoint was ever supposed to sync it.
.OUTPUTS
    PSCustomObject per differing column: Field, DisplayName, Reason,
    DocumentSetValue, ItemValue, IsShared.
.EXAMPLE
    Compare-SpoDocumentSetValue -Column $shared -DocumentSetValue $source -ItemValue $target
#>
function Compare-SpoDocumentSetValue {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [string[]]$Column,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNull()]
        [hashtable]$DocumentSetValue,

        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNull()]
        [hashtable]$ItemValue,

        [Parameter()]
        [AllowNull()]
        [string[]]$AvailableColumn,

        [Parameter()]
        [AllowNull()]
        [hashtable]$DisplayName,

        [Parameter()]
        [AllowNull()]
        [string[]]$SharedColumn
    )

    foreach ($name in $Column) {
        $sourceRaw = if ($DocumentSetValue.ContainsKey($name)) { $DocumentSetValue[$name] } else { $null }
        $targetRaw = if ($ItemValue.ContainsKey($name)) { $ItemValue[$name] } else { $null }

        $sourceKey = ConvertTo-SpoFieldValueKey -Value $sourceRaw
        $targetKey = ConvertTo-SpoFieldValueKey -Value $targetRaw

        if ($sourceKey -eq $targetKey) {
            continue
        }

        $reason = if ($null -ne $AvailableColumn -and $name -notin $AvailableColumn) {
            'ColumnMissingFromLibrary'
        }
        elseif ($sourceKey -eq '') {
            'EmptyOnDocumentSet'
        }
        elseif ($targetKey -eq '') {
            'EmptyOnItem'
        }
        else {
            'ValueDiffers'
        }

        [pscustomobject]@{
            Field            = $name
            DisplayName      = if ($DisplayName -and $DisplayName.ContainsKey($name)) { $DisplayName[$name] } else { $name }
            Reason           = $reason
            DocumentSetValue = ConvertTo-SpoFieldValueText -Value $sourceRaw
            ItemValue        = ConvertTo-SpoFieldValueText -Value $targetRaw
            IsShared         = $null -ne $SharedColumn -and $name -in $SharedColumn
        }
    }
}
