<#
.SYNOPSIS
    Creates a site content type.
.DESCRIPTION
    Creates a new content type at site level, inheriting from a parent.

    The parent matters more than people expect: it determines whether the
    content type can be used in a document library at all. Inherit from
    'Document' (or something descended from it) for libraries; from 'Item' for
    plain lists. The default is 'Item', which is the safe choice for lists but
    will not work in a document library -- pass -Parent Document for those.
.PARAMETER Name
    Name of the new content type, as it will appear in the UI.
.PARAMETER Group
    Group to file it under. Creating your own group (rather than using a
    built-in one) keeps custom types together and out of SharePoint's own
    listings.
.PARAMETER Parent
    Name or ID of the content type to inherit from. Defaults to 'Item'.
.PARAMETER Description
    Description shown in the content type gallery.
.PARAMETER PassThru
    Emit the created content type.
.OUTPUTS
    None by default. With -PassThru, the new content type.
.EXAMPLE
    New-SpoContentType -Name 'Contract' -Parent Document -Group 'Custom Content Types'
    Creates a document content type usable in libraries.
.EXAMPLE
    New-SpoContentType -Name 'Support Ticket' -Group 'Custom Content Types' -WhatIf
    Shows what would be created without creating it.
.EXAMPLE
    New-SpoContentType -Name 'Signed Contract' -Parent 'Contract' -Group 'Custom Content Types'
    Inherits from a custom content type, so it starts with all of its columns.
.LINK
    Get-SpoContentType
.LINK
    Add-SpoFieldToContentType
#>
function New-SpoContentType {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('ContentTypeName')]
        [string]$Name,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Group = 'Custom Content Types',

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Parent = 'Item',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $existing = Get-PnPContentType -Identity $Name -ErrorAction SilentlyContinue
        if ($existing) {
            throw [System.InvalidOperationException]::new(
                (Get-O365String 'ContentType.New.Exists' $Name $existing.Id.StringValue)
            )
        }

        $parentContentType = Get-PnPContentType -Identity $Parent -ErrorAction SilentlyContinue
        if (-not $parentContentType) {
            throw [System.InvalidOperationException]::new(
                (Get-O365String 'ContentType.New.NoParent' $Parent)
            )
        }

        $target = "$Name (inheriting from $($parentContentType.Name), group '$Group')"

        if (-not $PSCmdlet.ShouldProcess($script:O365State.SiteUrl, (Get-O365String 'ContentType.New.Action' $target))) {
            return
        }

        try {
            $params = @{
                Name              = $Name
                Group             = $Group
                ParentContentType = $parentContentType
                ErrorAction       = 'Stop'
            }
            if ($Description) {
                $params['Description'] = $Description
            }

            Add-PnPContentType @params | Out-Null
            Write-O365Log (Get-O365String 'ContentType.New.Created' $Name $Group) 'Success'
        }
        catch {
            throw [System.InvalidOperationException]::new(
                (Get-O365String 'ContentType.New.Failed' $Name $_.Exception.Message),
                $_.Exception
            )
        }

        if ($PassThru) {
            Get-SpoContentType -Name $Name
        }
    }
}
