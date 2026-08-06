<#
.SYNOPSIS
    Updates field values on an existing list item.
.DESCRIPTION
    Sets one or more fields on an item identified by ID. Only the supplied
    fields are touched; everything else is left alone.

    Use -SystemUpdate to change values without bumping the Modified timestamp,
    creating a version, or firing workflows -- appropriate for bulk data
    corrections where the edit is bookkeeping, not a real content change.

    -ContentType reclassifies the item. That is a different kind of change from
    setting a field: columns the new content type does not have keep whatever
    they held, they are not cleared, so an item switched between two content
    types with different columns can be left carrying values that no longer
    show on its form.
.PARAMETER Library
    Title, URL name, or GUID of the list.
.PARAMETER Id
    List item ID.
.PARAMETER Values
    Hashtable of internal field name to new value.
.PARAMETER ContentType
    Name or ID of a content type to reclassify the item as. Omit to leave the
    item's content type alone.
.PARAMETER SystemUpdate
    Update without changing Modified/Editor, creating a version, or triggering
    workflows.
.PARAMETER PassThru
    Emit the updated item.
.EXAMPLE
    Update-SpoListItem -Library Tasks -Id 42 -Values @{ Status = 'Done' }
.EXAMPLE
    Get-PnPListItem -List Tasks | ForEach-Object {
        Update-SpoListItem -Library Tasks -Id $_.Id -Values @{ Reviewed = $true } -SystemUpdate
    }
.EXAMPLE
    Update-SpoListItem -Library Index -Id 12 -ContentType 'Project Entry' `
        -Values @{ Reference = 'https://contoso.sharepoint.com/sites/x/Projekte/Forms/AllItems.aspx?id=%2Fsites%2Fx%2FProjekte%2FAlpha' }

    Follows a Document Set that moved to another library: the row keeps its
    identity, but its classification and its link have to change with it.
.LINK
    Add-SpoListItem
.LINK
    Export-SpoListItem
#>
function Update-SpoListItem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        # Not mandatory, because reclassifying an item is a legitimate update
        # on its own -- but one of Values and ContentType has to say what to
        # change, so an empty call is rejected below rather than writing
        # nothing and reporting success.
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [hashtable]$Values = @{},

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter()]
        [switch]$SystemUpdate,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $updated = 0
    }

    process {
        if ($Values.Count -eq 0 -and -not $ContentType) {
            throw [System.ArgumentException]::new(
                "Nothing to update on item $Id in '$Library': -Values is empty and -ContentType was not given. " +
                "Supply the fields to set, a content type to reclassify the item as, or both."
            )
        }

        $list = Resolve-SpoList -Identity $Library

        $changes = @()
        if ($Values.Count -gt 0) { $changes += "fields: $($Values.Keys -join ', ')" }
        if ($ContentType) { $changes += "content type: $ContentType" }

        $description = "Update item $Id ($($changes -join '; '))"

        if (-not $PSCmdlet.ShouldProcess($list.Title, $description)) {
            return
        }

        try {
            $params = @{
                List        = $list.Title
                Identity    = $Id
                ErrorAction = 'Stop'
            }
            if ($Values.Count -gt 0) {
                $params['Values'] = $Values
            }
            if ($ContentType) {
                $params['ContentType'] = $ContentType
            }
            if ($SystemUpdate) {
                $params['UpdateType'] = 'SystemUpdate'
            }

            $item = Set-PnPListItem @params
            $updated++
            Write-O365Log "Updated item $Id in '$($list.Title)'." 'Success'

            if ($PassThru) {
                $item
            }
        }
        catch {
            Write-Error -Message "Failed to update item $Id in '$($list.Title)': $($_.Exception.Message)" -TargetObject $Id
        }
    }

    end {
        if ($updated -gt 0) {
            Write-O365Log "Updated $updated item(s)." 'Info'
        }
    }
}
