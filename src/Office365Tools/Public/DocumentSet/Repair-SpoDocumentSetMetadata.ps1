<#
.SYNOPSIS
    Copies a Document Set's metadata down onto the documents and folders it
    contains.
.DESCRIPTION
    Takes the output of Get-SpoDocumentSetMismatch and writes the Document
    Set's value onto each item that has drifted -- doing by hand what
    SharePoint's shared-column push-down was supposed to do, and doing it for
    folders as well, which that push-down skips.

    The Document Set always wins. That is the whole model: metadata lives on
    the Document Set, and the contents carry a copy. If an individual document
    is supposed to differ, the column should not be a shared column.

    Two safety behaviours are worth knowing:

    **Empty values are not pushed by default.** If the Document Set's column is
    empty and the item's is not, writing would destroy the only copy of that
    value with nothing to restore it from. Those items are skipped and
    reported as 'SkippedEmptySource'. Pass -ClearEmpty when the Document Set
    really is the authority and the item values are wrong.

    **Version history is your undo.** By default this writes a normal update,
    so every changed item gets a new version and the previous metadata stays
    recoverable. -SystemUpdate writes without creating a version or touching
    Modified/Editor -- tidier in a report, but genuinely irreversible. Export
    the mismatches first either way:

        $drift = Get-SpoDocumentSetMismatch -Library Projekte
        $drift | Export-Csv out/before.csv -NoTypeInformation
        $drift | Repair-SpoDocumentSetMetadata -WhatIf
        $drift | Repair-SpoDocumentSetMetadata

    Fixing the drift does not stop it coming back. If the cause was a column
    that is not registered as shared, Test-SpoDocumentSetSharedColumn will say
    so, and that is the fix that lasts.
.PARAMETER InputObject
    Mismatch objects from Get-SpoDocumentSetMismatch.
.PARAMETER Library
    Repair a whole library: the mismatches are found and repaired in one go.
    Equivalent to piping Get-SpoDocumentSetMismatch into this command.
.PARAMETER DocumentSet
    With -Library, restrict to Document Sets matching this wildcard pattern.
.PARAMETER Column
    Repair only these columns, whatever else the mismatch objects carry.
.PARAMETER ClearEmpty
    Also push empty values, clearing item columns the Document Set leaves
    blank. Off by default because it destroys data that exists nowhere else.
.PARAMETER SystemUpdate
    Write without creating a version or changing Modified/Editor. Faster and
    leaves the audit trail alone -- and removes your ability to undo.
.PARAMETER PassThru
    Emit a result object per item describing what happened.
.OUTPUTS
    None by default. With -PassThru, one 'Office365Tools.RepairResult' per item.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte | Repair-SpoDocumentSetMetadata -WhatIf
    Shows every write that would happen, with the values, and performs none.
.EXAMPLE
    Repair-SpoDocumentSetMetadata -Library Projekte -Confirm:$false
    Finds and repairs the drift in one step, without prompting per item.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte |
        Where-Object Kind -eq 'Folder' |
        Repair-SpoDocumentSetMetadata -PassThru
    Repairs only the folders -- the ones SharePoint's own push-down never
    reaches -- and reports what it wrote.
.LINK
    Get-SpoDocumentSetMismatch
.LINK
    Test-SpoDocumentSetSharedColumn
#>
function Repair-SpoDocumentSetMetadata {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Pipeline')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Pipeline', Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [psobject]$InputObject,

        [Parameter(ParameterSetName = 'Library', Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(ParameterSetName = 'Library', Position = 1)]
        [string]$DocumentSet,

        [Parameter()]
        [Alias('Field')]
        [string[]]$Column,

        [Parameter()]
        [switch]$ClearEmpty,

        [Parameter()]
        [switch]$SystemUpdate,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null

        $repaired = 0
        $skipped  = 0
        $failed   = 0

        # The Document Set's raw values are not carried on the mismatch object
        # -- it holds display text, which is not what Set-PnPListItem wants.
        # Re-read each Document Set item once and keep the writable form.
        $sourceCache = @{}
    }

    process {
        $mismatches = if ($PSCmdlet.ParameterSetName -eq 'Library') {
            $parameters = @{ Library = $Library }
            if ($DocumentSet) {
                $parameters['DocumentSet'] = $DocumentSet
            }
            if ($Column) {
                $parameters['Column'] = $Column
            }

            @(Get-SpoDocumentSetMismatch @parameters)
        }
        else {
            @($InputObject)
        }

        foreach ($mismatch in $mismatches) {
            $properties = @($mismatch.PSObject.Properties.Name)
            $missing    = @('ServerRelativeUrl', 'List', 'ItemId', 'Difference', 'DocumentSetItemId' |
                    Where-Object { $_ -notin $properties })

            if ($missing.Count -gt 0) {
                Write-Error "Input object is missing the $(($missing | ForEach-Object { "'$_'" }) -join ', ') property. Pipe output from Get-SpoDocumentSetMismatch."
                continue
            }

            $differences = @($mismatch.Difference)

            if ($Column) {
                $differences = @($differences | Where-Object { $_.Field -in $Column })
            }

            foreach ($difference in @($differences | Where-Object { $_.Reason -eq 'ColumnMissingFromLibrary' })) {
                Write-O365Log "Column '$($difference.Field)' is not on library '$($mismatch.List)'; it cannot be written. Add it to the library first." 'Warning'
            }

            $differences = @($differences | Where-Object { $_.Reason -ne 'ColumnMissingFromLibrary' })

            if (-not $ClearEmpty) {
                $emptySource = @($differences | Where-Object { $_.Reason -eq 'EmptyOnDocumentSet' })

                if ($emptySource.Count -gt 0) {
                    Write-O365Log "Skipping $($emptySource.Count) empty column(s) on '$($mismatch.ServerRelativeUrl)': the Document Set has no value to push. Use -ClearEmpty to clear them anyway." 'Info'
                }

                $differences = @($differences | Where-Object { $_.Reason -ne 'EmptyOnDocumentSet' })
            }

            if ($differences.Count -eq 0) {
                $skipped++

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        List              = $mismatch.List
                        Name              = $mismatch.Name
                        ServerRelativeUrl = $mismatch.ServerRelativeUrl
                        Action            = 'PushDocumentSetMetadata'
                        Status            = 'SkippedEmptySource'
                        Column            = ''
                        Error             = $null
                    }
                }
                continue
            }

            $cacheKey = '{0}|{1}' -f $mismatch.List, $mismatch.DocumentSetItemId

            if (-not $sourceCache.ContainsKey($cacheKey)) {
                try {
                    $sourceCache[$cacheKey] = Get-PnPListItem -List $mismatch.List -Id $mismatch.DocumentSetItemId -ErrorAction Stop
                }
                catch {
                    $failed++
                    Write-Error -Message "Could not read Document Set item $($mismatch.DocumentSetItemId) in '$($mismatch.List)': $($_.Exception.Message)" -TargetObject $mismatch.DocumentSetUrl
                    continue
                }
            }

            $source = $sourceCache[$cacheKey]

            $values = @{}
            foreach ($difference in $differences) {
                $raw = if ($source.FieldValues.ContainsKey($difference.Field)) { $source.FieldValues[$difference.Field] } else { $null }
                $values[$difference.Field] = ConvertTo-SpoFieldUpdateValue -Value $raw
            }

            $columnList  = (@($values.Keys) | Sort-Object) -join ', '
            $description = "Set $columnList from Document Set '$($mismatch.DocumentSet)'"

            if (-not $PSCmdlet.ShouldProcess($mismatch.ServerRelativeUrl, $description)) {
                continue
            }

            try {
                $parameters = @{
                    List        = $mismatch.List
                    Identity    = $mismatch.ItemId
                    Values      = $values
                    ErrorAction = 'Stop'
                }
                if ($SystemUpdate) {
                    $parameters['UpdateType'] = 'SystemUpdate'
                }

                Set-PnPListItem @parameters | Out-Null

                $repaired++
                Write-O365Log "Updated $columnList on '$($mismatch.ServerRelativeUrl)'." 'Success'

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        List              = $mismatch.List
                        Name              = $mismatch.Name
                        ServerRelativeUrl = $mismatch.ServerRelativeUrl
                        Action            = 'PushDocumentSetMetadata'
                        Status            = 'Repaired'
                        Column            = $columnList
                        Error             = $null
                    }
                }
            }
            catch {
                $failed++
                Write-O365Log "Failed to update '$($mismatch.ServerRelativeUrl)': $($_.Exception.Message)" 'Error'
                Write-Error -Message "Failed to update '$($mismatch.ServerRelativeUrl)': $($_.Exception.Message)" -TargetObject $mismatch.ServerRelativeUrl

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        List              = $mismatch.List
                        Name              = $mismatch.Name
                        ServerRelativeUrl = $mismatch.ServerRelativeUrl
                        Action            = 'PushDocumentSetMetadata'
                        Status            = 'Failed'
                        Column            = $columnList
                        Error             = $_.Exception.Message
                    }
                }
            }
        }
    }

    end {
        Write-O365Log "Document Set metadata repair complete: $repaired updated, $skipped skipped, $failed failed." 'Info'
    }
}
