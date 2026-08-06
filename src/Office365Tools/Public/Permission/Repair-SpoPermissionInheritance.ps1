<#
.SYNOPSIS
    Resets items to inherit permissions from their parent.
.DESCRIPTION
    Takes the output of Get-SpoPermissionMismatch and, for each item, discards
    the unique permissions so the item inherits from its parent folder again.

    This is destructive and irreversible: SharePoint does not keep a copy of
    the discarded assignments. ConfirmImpact is High, so the command prompts
    unless you pass -Confirm:$false, and -WhatIf shows the full list of what
    would change.

    Recommended workflow:

        $mismatches = Get-SpoPermissionMismatch -Library Docs -MinimumDepth 2
        $mismatches | Export-Csv out/before.csv -NoTypeInformation   # keep a record
        $mismatches | Repair-SpoPermissionInheritance -WhatIf        # review
        $mismatches | Repair-SpoPermissionInheritance                # act
.PARAMETER InputObject
    Mismatch objects from Get-SpoPermissionMismatch.
.PARAMETER Library
    Library title, when identifying items by URL rather than by piping.
.PARAMETER ServerRelativeUrl
    Server-relative URL of a single item to reset.
.PARAMETER PassThru
    Emit a result object per item describing what happened.
.OUTPUTS
    None by default. With -PassThru, one result object per item.
.EXAMPLE
    Get-SpoPermissionMismatch -Library Management -MinimumDepth 2 |
        Repair-SpoPermissionInheritance -WhatIf
.EXAMPLE
    Repair-SpoPermissionInheritance -Library Management `
        -ServerRelativeUrl '/sites/cds/Management/Board/notes.docx'
.LINK
    Get-SpoPermissionMismatch
#>
function Repair-SpoPermissionInheritance {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Pipeline')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Pipeline', Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [psobject]$InputObject,

        [Parameter(ParameterSetName = 'Explicit', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(ParameterSetName = 'Explicit', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRelativeUrl,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $repaired = 0
        $failed   = 0
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Explicit') {
            $list = Resolve-SpoList -Identity $Library
            $targetUrl = $ServerRelativeUrl
            $targetName = Split-Path -Leaf $ServerRelativeUrl
            $listTitle = $list.Title
            $itemId = $null
        }
        else {
            foreach ($required in 'ServerRelativeUrl', 'List') {
                if ($required -notin $InputObject.PSObject.Properties.Name) {
                    Write-Error "Input object is missing the '$required' property. Pipe output from Get-SpoPermissionMismatch."
                    return
                }
            }
            $targetUrl  = $InputObject.ServerRelativeUrl
            $targetName = $InputObject.Name
            $listTitle  = $InputObject.List
            $itemId     = $InputObject.ItemId
        }

        $description = "Discard unique permissions and inherit from parent"

        if (-not $PSCmdlet.ShouldProcess($targetUrl, $description)) {
            return
        }

        try {
            $listItem = if ($itemId) {
                Get-PnPListItem -List $listTitle -Id $itemId -ErrorAction Stop
            }
            else {
                $file = Get-PnPFile -Url $targetUrl -AsListItem -ErrorAction SilentlyContinue
                if ($file) {
                    $file
                }
                else {
                    (Get-PnPFolder -Url $targetUrl -ErrorAction Stop).ListItemAllFields
                }
            }

            $listItem.ResetRoleInheritance()
            Invoke-PnPQuery -ErrorAction Stop

            $repaired++
            Write-O365Log "Reset inheritance on '$targetUrl'." 'Success'

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName        = 'Office365Tools.RepairResult'
                    List              = $listTitle
                    Name              = $targetName
                    ServerRelativeUrl = $targetUrl
                    Action            = 'ResetRoleInheritance'
                    Status            = 'Repaired'
                    Error             = $null
                }
            }
        }
        catch {
            $failed++
            Write-O365Log "Failed to reset inheritance on '$targetUrl': $($_.Exception.Message)" 'Error'
            Write-Error -Message "Failed to reset inheritance on '$targetUrl': $($_.Exception.Message)" -TargetObject $targetUrl

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName        = 'Office365Tools.RepairResult'
                    List              = $listTitle
                    Name              = $targetName
                    ServerRelativeUrl = $targetUrl
                    Action            = 'ResetRoleInheritance'
                    Status            = 'Failed'
                    Error             = $_.Exception.Message
                }
            }
        }
    }

    end {
        Write-O365Log "Repair complete: $repaired repaired, $failed failed." 'Info'
    }
}
