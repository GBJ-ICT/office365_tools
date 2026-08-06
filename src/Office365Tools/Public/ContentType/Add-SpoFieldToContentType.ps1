<#
.SYNOPSIS
    Adds existing site columns to a content type.
.DESCRIPTION
    Attaches one or more site columns to a content type. The columns must
    already exist -- create them with New-SpoField first, or reuse the ones
    SharePoint ships with.

    -UpdateChildren is the parameter that matters. A site content type that has
    already been added to lists exists as independent copies on each of them;
    without -UpdateChildren the new column reaches the site definition only,
    and every list keeps the old shape. That is exactly the drift
    Test-SpoContentTypeLink reports as ContentType.FieldMissingOnListCopy.

    Adding a column that is already on the content type is a no-op, reported
    and skipped rather than treated as an error.
.PARAMETER ContentType
    Name or ID of the content type to modify.
.PARAMETER Field
    Internal name(s) of the site column(s) to add.
.PARAMETER Library
    Modify a list's content type copy rather than the site content type.
.PARAMETER Required
    Mark the column required on this content type.
.PARAMETER Hidden
    Hide the column on this content type's forms.
.PARAMETER UpdateChildren
    Push the change down to list copies that already inherit from this content
    type. Recommended whenever the content type is already in use.
.PARAMETER PassThru
    Emit a result object per column added.
.OUTPUTS
    None by default. With -PassThru, one result object per column.
.EXAMPLE
    Add-SpoFieldToContentType -ContentType 'Contract' -Field ContractValue -UpdateChildren

.EXAMPLE
    Add-SpoFieldToContentType -ContentType 'Contract' -Field ContractValue, SignedDate, Counterparty -WhatIf
    Shows what would be added without adding it.
.EXAMPLE
    Get-SpoField -Group 'Contract Columns' |
        Add-SpoFieldToContentType -ContentType 'Contract' -UpdateChildren
    Adds every column from a group.
.LINK
    New-SpoField
.LINK
    Remove-SpoFieldFromContentType
.LINK
    Sync-SpoContentType
#>
function Add-SpoFieldToContentType {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('InternalName', 'FieldInternalName')]
        [string[]]$Field,

        [Parameter()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [switch]$Hidden,

        [Parameter()]
        [switch]$UpdateChildren,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null

        $target = if ($Library) {
            $list = Resolve-SpoList -Identity $Library
            Get-PnPContentType -List $list -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $ContentType -or $_.Id.StringValue -eq $ContentType } |
                Select-Object -First 1
        }
        else {
            Get-PnPContentType -Identity $ContentType -ErrorAction SilentlyContinue
        }

        if (-not $target) {
            $where = if ($Library) { "list '$Library'" } else { 'this site' }
            throw [System.InvalidOperationException]::new(
                "Content type '$ContentType' was not found on $where. " +
                'Run Get-SpoContentType to see what exists.'
            )
        }

        if ($target.Sealed) {
            throw [System.InvalidOperationException]::new(
                "Content type '$($target.Name)' is sealed and cannot be modified. " +
                'Unseal it in the site settings first, or inherit a new content type from it.'
            )
        }

        # Existing columns, so re-adding one is a reported no-op rather than an
        # error from the server.
        $targetFields = Get-PnPProperty -ClientObject $target -Property Fields
        $existingFields = @($targetFields | ForEach-Object { $_.InternalName })

        $added = 0
        $skipped = 0
    }

    process {
        foreach ($fieldName in $Field) {
            if ($fieldName -in $existingFields) {
                $skipped++
                Write-O365Log "'$fieldName' is already on '$($target.Name)'; skipped." 'Info'

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        ContentTypeName   = $target.Name
                        FieldInternalName = $fieldName
                        List              = $Library
                        Action            = 'AddField'
                        Status            = 'AlreadyPresent'
                        Error             = $null
                    }
                }
                continue
            }

            $siteField = Get-PnPField -Identity $fieldName -ErrorAction SilentlyContinue
            if (-not $siteField) {
                Write-Error -Message (
                    "Site column '$fieldName' does not exist. Create it with New-SpoField, " +
                    'or check the internal name with Get-SpoField.'
                ) -TargetObject $fieldName
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($target.Name, "Add column '$fieldName'")) {
                continue
            }

            try {
                $params = @{
                    Field       = $fieldName
                    ContentType = $target
                    ErrorAction = 'Stop'
                }
                if ($Library) { $params['List'] = $Library }
                if ($Required) { $params['Required'] = $true }
                if ($Hidden) { $params['Hidden'] = $true }
                if ($UpdateChildren) { $params['UpdateChildren'] = $true }

                Add-PnPFieldToContentType @params

                $added++
                $existingFields += $fieldName
                Write-O365Log "Added '$fieldName' to '$($target.Name)'." 'Success'

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        ContentTypeName   = $target.Name
                        FieldInternalName = $fieldName
                        List              = $Library
                        Action            = 'AddField'
                        Status            = 'Added'
                        Error             = $null
                    }
                }
            }
            catch {
                Write-Error -Message "Failed to add '$fieldName' to '$($target.Name)': $($_.Exception.Message)" -TargetObject $fieldName

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName        = 'Office365Tools.RepairResult'
                        ContentTypeName   = $target.Name
                        FieldInternalName = $fieldName
                        List              = $Library
                        Action            = 'AddField'
                        Status            = 'Failed'
                        Error             = $_.Exception.Message
                    }
                }
            }
        }
    }

    end {
        if ($added -gt 0 -or $skipped -gt 0) {
            Write-O365Log "Column changes complete: $added added, $skipped already present." 'Info'
        }

        if ($added -gt 0 -and -not $UpdateChildren -and -not $Library) {
            Write-O365Log (
                'Existing list copies of this content type were not updated. ' +
                'Re-run with -UpdateChildren, or use Sync-SpoContentType, to push the change down.'
            ) 'Warning'
        }
    }
}
