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
            Write-O365Log (Get-O365String 'ContentType.RemoveFromList.NotAttached' $ContentType $list.Title) 'Warning'
            return
        }

        if (-not $Force) {
            $inUse = @(Get-PnPListItem -List $list.Title -PageSize 500 |
                    Where-Object { $_.FieldValues['ContentTypeId'] -and
                        $_.FieldValues['ContentTypeId'].ToString().StartsWith($listContentType.Id.StringValue) })

            if ($inUse.Count -gt 0) {
                throw [System.InvalidOperationException]::new(
                    (Get-O365String 'ContentType.RemoveFromList.InUse' $inUse.Count $list.Title $ContentType)
                )
            }
        }

        if ($PSCmdlet.ShouldProcess($list.Title, (Get-O365String 'ContentType.RemoveFromList.Action' $ContentType))) {
            try {
                Remove-PnPContentTypeFromList -List $list.Title -ContentType $listContentType.Name -ErrorAction Stop
                Write-O365Log (Get-O365String 'ContentType.RemoveFromList.Removed' $ContentType $list.Title) 'Success'
            }
            catch {
                Write-Error -Message (Get-O365String 'ContentType.RemoveFromList.Failed' $ContentType $list.Title $_.Exception.Message) -TargetObject $list.Title
            }
        }
    }
}
