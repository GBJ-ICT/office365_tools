<#
.SYNOPSIS
    Adds a site content type to a list or library.
.DESCRIPTION
    Attaches an existing site content type to a list, enabling content type
    management on the list first if it is off (which it is by default on new
    libraries -- a step people routinely forget, then wonder why the content
    type does not appear).

    Optionally makes it the default content type for new items.
.PARAMETER Library
    Title, URL name, or GUID of the target list or library.
.PARAMETER ContentType
    Name or ID of the site content type to add.
.PARAMETER SetDefault
    Make this the default content type for the list, so the New button uses it.
.PARAMETER RemoveDefaultDocument
    After adding, remove the built-in 'Document' content type. Common when a
    library should only ever hold one custom type. Ignored if 'Document' is not
    present.
.PARAMETER PassThru
    Emit the resulting list content type.
.EXAMPLE
    Add-SpoContentTypeToList -Library Contracts -ContentType 'Contract'
.EXAMPLE
    Add-SpoContentTypeToList -Library Contracts -ContentType 'Contract' `
        -SetDefault -RemoveDefaultDocument -WhatIf
.LINK
    Remove-SpoContentTypeFromList
.LINK
    Test-SpoContentTypeLink
#>
function Add-SpoContentTypeToList {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([object])]
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
        [switch]$SetDefault,

        [Parameter()]
        [switch]$RemoveDefaultDocument,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        $siteContentType = Get-PnPContentType -Identity $ContentType -ErrorAction SilentlyContinue
        if (-not $siteContentType) {
            $available = @(Get-PnPContentType | ForEach-Object { $_.Name } | Sort-Object) -join ', '
            throw [System.InvalidOperationException]::new(
                "Site content type '$ContentType' was not found. Available: $available"
            )
        }

        if (-not $list.ContentTypesEnabled) {
            if ($PSCmdlet.ShouldProcess($list.Title, 'Enable content type management')) {
                Set-PnPList -Identity $list.Title -EnableContentTypes $true -ErrorAction Stop
                Write-O365Log "Enabled content type management on '$($list.Title)'." 'Info'
            }
        }

        if ($PSCmdlet.ShouldProcess($list.Title, "Add content type '$($siteContentType.Name)'")) {
            try {
                Add-PnPContentTypeToList -List $list.Title -ContentType $siteContentType.Name -DefaultContentType:$SetDefault -ErrorAction Stop
                Write-O365Log "Added '$($siteContentType.Name)' to '$($list.Title)'." 'Success'
            }
            catch {
                throw [System.InvalidOperationException]::new(
                    "Failed to add '$($siteContentType.Name)' to '$($list.Title)': $($_.Exception.Message)",
                    $_.Exception
                )
            }
        }

        if ($RemoveDefaultDocument) {
            $document = Get-PnPContentType -List $list.Title -ErrorAction SilentlyContinue |
                Where-Object { $_.Id.StringValue -eq '0x0101' -or $_.Name -eq 'Document' }

            if ($document) {
                if ($PSCmdlet.ShouldProcess($list.Title, "Remove built-in content type '$($document.Name)'")) {
                    try {
                        Remove-PnPContentTypeFromList -List $list.Title -ContentType $document.Name -ErrorAction Stop
                        Write-O365Log "Removed built-in '$($document.Name)' from '$($list.Title)'." 'Success'
                    }
                    catch {
                        Write-O365Log "Could not remove built-in content type: $($_.Exception.Message)" 'Warning'
                    }
                }
            }
            else {
                Write-O365Log "No built-in Document content type on '$($list.Title)'; nothing to remove." 'Info'
            }
        }

        if ($PassThru) {
            Get-PnPContentType -List $list.Title | Where-Object { $_.Name -eq $siteContentType.Name }
        }
    }
}
