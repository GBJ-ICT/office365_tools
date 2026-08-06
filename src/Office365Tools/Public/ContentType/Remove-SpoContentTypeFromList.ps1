<#
.SYNOPSIS
    Removes a content type from a list or library.
.DESCRIPTION
    Detaches a content type from a list. SharePoint refuses if any item still
    uses it, so this command checks item usage first and reports the count --
    a clearer failure than the server's generic error.
.PARAMETER Library
    Title, URL name, or GUID of the list or library.
.PARAMETER ContentType
    Name or ID of the list content type to remove.
.PARAMETER Force
    Skip the in-use check and let the server decide. Useful when the check
    itself is too slow on a very large library.
.EXAMPLE
    Remove-SpoContentTypeFromList -Library Contracts -ContentType 'Old Contract'
.EXAMPLE
    Remove-SpoContentTypeFromList -Library Contracts -ContentType 'Old Contract' -WhatIf
.LINK
    Add-SpoContentTypeToList
#>
function Remove-SpoContentTypeFromList {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        $listContentType = Get-PnPContentType -List $list.Title -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $ContentType -or $_.Id.StringValue -eq $ContentType }

        if (-not $listContentType) {
            Write-O365Log "Content type '$ContentType' is not attached to '$($list.Title)'; nothing to remove." 'Warning'
            return
        }

        if (-not $Force) {
            $inUse = @(Get-PnPListItem -List $list.Title -PageSize 500 |
                    Where-Object { $_.FieldValues['ContentTypeId'] -and
                        $_.FieldValues['ContentTypeId'].ToString().StartsWith($listContentType.Id.StringValue) })

            if ($inUse.Count -gt 0) {
                throw [System.InvalidOperationException]::new(
                    "$($inUse.Count) item(s) in '$($list.Title)' still use content type '$ContentType'. " +
                    'Change those items to a different content type first, or re-run with -Force to let ' +
                    'the server reject the operation itself.'
                )
            }
        }

        if ($PSCmdlet.ShouldProcess($list.Title, "Remove content type '$ContentType'")) {
            try {
                Remove-PnPContentTypeFromList -List $list.Title -ContentType $listContentType.Name -ErrorAction Stop
                Write-O365Log "Removed '$ContentType' from '$($list.Title)'." 'Success'
            }
            catch {
                Write-Error -Message "Failed to remove '$ContentType' from '$($list.Title)': $($_.Exception.Message)" -TargetObject $list.Title
            }
        }
    }
}
