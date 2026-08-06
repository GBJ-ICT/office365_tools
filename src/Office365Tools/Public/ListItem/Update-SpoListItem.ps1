<#
.SYNOPSIS
    Updates field values on an existing list item.
.DESCRIPTION
    Sets one or more fields on an item identified by ID. Only the supplied
    fields are touched; everything else is left alone.

    Use -SystemUpdate to change values without bumping the Modified timestamp,
    creating a version, or firing workflows -- appropriate for bulk data
    corrections where the edit is bookkeeping, not a real content change.
.PARAMETER Library
    Title, URL name, or GUID of the list.
.PARAMETER Id
    List item ID.
.PARAMETER Values
    Hashtable of internal field name to new value.
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

        [Parameter(Mandatory, Position = 2, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [hashtable]$Values,

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
        $list = Resolve-SpoList -Identity $Library

        $description = "Update item $Id (fields: $($Values.Keys -join ', '))"

        if (-not $PSCmdlet.ShouldProcess($list.Title, $description)) {
            return
        }

        try {
            $params = @{
                List        = $list.Title
                Identity    = $Id
                Values      = $Values
                ErrorAction = 'Stop'
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
