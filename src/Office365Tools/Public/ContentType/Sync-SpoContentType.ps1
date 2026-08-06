<#
.SYNOPSIS
    Pushes site content type changes down to the list copies.
.DESCRIPTION
    Adds fields that exist on a site content type but are missing from its list
    copies -- the 'ContentType.FieldMissingOnListCopy' finding from
    Test-SpoContentTypeLink.

    This is deliberately additive. It never removes fields from a list copy,
    because a field on the copy but not the parent may be holding data that
    only exists there. Removing is a separate, explicit decision:
    Remove-SpoFieldFromContentType.
.PARAMETER ContentType
    Name or ID of the site content type to push down.
.PARAMETER Library
    Sync only this list's copy. Omit to sync every list that has a copy.
.PARAMETER IncludeHidden
    Also sync copies on hidden lists.
.PARAMETER PassThru
    Emit a result object per field added.
.EXAMPLE
    Sync-SpoContentType -ContentType 'Contract' -WhatIf
    Shows which fields would be pushed to which lists.
.EXAMPLE
    Sync-SpoContentType -ContentType 'Contract' -Library Contracts
.LINK
    Test-SpoContentTypeLink
#>
function Sync-SpoContentType {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeHidden,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $added = 0
    }

    process {
        $parent = Get-PnPContentType -Identity $ContentType -ErrorAction SilentlyContinue
        if (-not $parent) {
            throw [System.InvalidOperationException]::new(
                "Site content type '$ContentType' was not found."
            )
        }

        $parentId = $parent.Id.StringValue

        $parentFields = @(Get-PnPProperty -ClientObject $parent -Property Fields |
                Where-Object { -not $_.Hidden -and -not $_.ReadOnlyField })

        $lists = if ($Library) {
            @(Resolve-SpoList -Identity $Library)
        }
        else {
            @(Get-PnPList | Where-Object { $_.ContentTypesEnabled -and ($IncludeHidden -or -not $_.Hidden) })
        }

        Write-O365Log "Syncing '$($parent.Name)' into $(@($lists).Count) candidate list(s)." 'Info'

        foreach ($list in $lists) {
            $listContentType = Get-PnPContentType -List $list -ErrorAction SilentlyContinue |
                Where-Object { $_.Id.StringValue.StartsWith($parentId, [System.StringComparison]::OrdinalIgnoreCase) } |
                Select-Object -First 1

            if (-not $listContentType) {
                continue
            }

            $listFields = @(Get-PnPProperty -ClientObject $listContentType -Property Fields |
                    ForEach-Object { $_.InternalName })

            $missing = @($parentFields | Where-Object { $_.InternalName -notin $listFields })

            if ($missing.Count -eq 0) {
                Write-O365Log "'$($list.Title)' is already in sync." 'Info'
                continue
            }

            foreach ($field in $missing) {
                $target = "$($list.Title) / $($listContentType.Name)"

                if (-not $PSCmdlet.ShouldProcess($target, "Add field '$($field.InternalName)'")) {
                    continue
                }

                try {
                    Add-PnPFieldToContentType -Field $field.InternalName -ContentType $listContentType -List $list.Title -ErrorAction Stop
                    $added++
                    Write-O365Log "Added '$($field.InternalName)' to '$target'." 'Success'

                    if ($PassThru) {
                        [pscustomobject]@{
                            PSTypeName        = 'Office365Tools.RepairResult'
                            List              = $list.Title
                            ContentTypeName   = $listContentType.Name
                            FieldInternalName = $field.InternalName
                            Action            = 'AddField'
                            Status            = 'Added'
                            Error             = $null
                        }
                    }
                }
                catch {
                    Write-Error -Message "Failed to add '$($field.InternalName)' to '$target': $($_.Exception.Message)" -TargetObject $target

                    if ($PassThru) {
                        [pscustomobject]@{
                            PSTypeName        = 'Office365Tools.RepairResult'
                            List              = $list.Title
                            ContentTypeName   = $listContentType.Name
                            FieldInternalName = $field.InternalName
                            Action            = 'AddField'
                            Status            = 'Failed'
                            Error             = $_.Exception.Message
                        }
                    }
                }
            }
        }
    }

    end {
        Write-O365Log "Sync complete: $added field(s) added." 'Info'
    }
}
