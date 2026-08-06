<#
.SYNOPSIS
    Removes a column from one or more content types.
.DESCRIPTION
    Detaches a field from a content type. The site column itself is not
    deleted, and data already stored in the field is not removed -- but the
    field stops appearing on forms and views for that content type, which users
    experience as data loss.

    Accepts Find-SpoContentTypeByColumn output on the pipeline, so the intended
    workflow is look-then-act:

        Find-SpoContentTypeByColumn -ColumnName Priority          # see the blast radius
        Find-SpoContentTypeByColumn -ColumnName Priority |
            Remove-SpoFieldFromContentType -WhatIf                # confirm
        Find-SpoContentTypeByColumn -ColumnName Priority |
            Remove-SpoFieldFromContentType                        # act

    The predecessor script hard-coded a German column name as its default and
    prompted with Read-Host. Defaults are gone, and confirmation is now the
    standard -Confirm/-WhatIf machinery.
.PARAMETER ContentTypeId
    ID of the content type to modify.
.PARAMETER FieldInternalName
    Internal name of the field to remove.
.PARAMETER ContentTypeName
    Display name, used only for messages.
.PARAMETER Library
    Operate on a list's content type rather than the site's.
.PARAMETER PassThru
    Emit a result object per removal.
.EXAMPLE
    Find-SpoContentTypeByColumn -ColumnName Priority | Remove-SpoFieldFromContentType -WhatIf
.EXAMPLE
    Remove-SpoFieldFromContentType -ContentTypeId '0x0101009189AB...' -FieldInternalName Priority
.LINK
    Find-SpoContentTypeByColumn
#>
function Remove-SpoFieldFromContentType {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentTypeId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$FieldInternalName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ContentTypeName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $removed = 0
        $failed  = 0
    }

    process {
        $label = if ($ContentTypeName) { "$ContentTypeName ($ContentTypeId)" } else { $ContentTypeId }

        if (-not $PSCmdlet.ShouldProcess($label, "Remove field '$FieldInternalName'")) {
            return
        }

        try {
            $params = @{
                Field       = $FieldInternalName
                ContentType = $ContentTypeId
                ErrorAction = 'Stop'
            }
            if ($Library) {
                $params['List'] = $Library
            }

            Remove-PnPFieldFromContentType @params

            $removed++
            Write-O365Log "Removed '$FieldInternalName' from '$label'." 'Success'

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName        = 'Office365Tools.RepairResult'
                    ContentTypeName   = $ContentTypeName
                    ContentTypeId     = $ContentTypeId
                    FieldInternalName = $FieldInternalName
                    List              = $Library
                    Action            = 'RemoveField'
                    Status            = 'Removed'
                    Error             = $null
                }
            }
        }
        catch {
            $failed++
            Write-Error -Message "Failed to remove '$FieldInternalName' from '$label': $($_.Exception.Message)" -TargetObject $ContentTypeId

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName        = 'Office365Tools.RepairResult'
                    ContentTypeName   = $ContentTypeName
                    ContentTypeId     = $ContentTypeId
                    FieldInternalName = $FieldInternalName
                    List              = $Library
                    Action            = 'RemoveField'
                    Status            = 'Failed'
                    Error             = $_.Exception.Message
                }
            }
        }
    }

    end {
        Write-O365Log "Field removal complete: $removed removed, $failed failed." 'Info'
    }
}
