<#
.SYNOPSIS
    Removes a principal's role on a list, folder, or item.
.DESCRIPTION
    Removes a role assignment from a securable object. The target must already
    have unique permissions -- revoking from an inheriting object is not
    possible without breaking inheritance, and this command will not do that
    implicitly.

    Accepts findings from Find-SpoOrphanedPermission on the pipeline, so
    cleaning up deleted accounts is a two-command job.
.PARAMETER Library
    Library or list title.
.PARAMETER ServerRelativeUrl
    Target folder or file. Omit to revoke at library level.
.PARAMETER Identity
    Login name of the user, or the title of a SharePoint group.
.PARAMETER Role
    Role to remove. Omit to remove all of the principal's roles on the target.
.EXAMPLE
    Revoke-SpoPermission -Library Management -Identity 'anna@contoso.com' -Role Read
.EXAMPLE
    Revoke-SpoPermission -Library Management -Identity 'anna@contoso.com' -WhatIf
    Shows what would be removed without removing it.
.LINK
    Grant-SpoPermission
.LINK
    Find-SpoOrphanedPermission
#>
function Revoke-SpoPermission {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Target')]
        [string]$ServerRelativeUrl,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter()]
        [string]$Role
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list   = Resolve-SpoList -Identity $Library
        $target = if ($ServerRelativeUrl) { $ServerRelativeUrl } else { $list.Title }

        if ($ServerRelativeUrl) {
            $securable = try {
                (Get-PnPFolder -Url $ServerRelativeUrl -ErrorAction Stop).ListItemAllFields
            }
            catch {
                Get-PnPFile -Url $ServerRelativeUrl -AsListItem -ErrorAction Stop
            }
            $hasUnique = Get-PnPProperty -ClientObject $securable -Property HasUniqueRoleAssignments
        }
        else {
            $securable = $list
            $hasUnique = $list.HasUniqueRoleAssignments
        }

        if (-not $hasUnique) {
            Write-O365Log (
                "'$target' inherits its permissions, so there is nothing to revoke here. " +
                'Revoke at the level where the permission was granted instead.'
            ) 'Warning'
            return
        }

        $description = if ($Role) { "Revoke '$Role' from '$Identity'" } else { "Revoke all roles from '$Identity'" }

        if (-not $PSCmdlet.ShouldProcess($target, $description)) {
            return
        }

        try {
            if ($ServerRelativeUrl) {
                if ($Role) {
                    Set-PnPListItemPermission -List $list.Title -Identity $securable.Id -User $Identity -RemoveRole $Role -ErrorAction Stop
                }
                else {
                    Set-PnPListItemPermission -List $list.Title -Identity $securable.Id -User $Identity -ClearExisting -ErrorAction Stop
                }
            }
            else {
                if ($Role) {
                    Set-PnPListPermission -List $list.Title -User $Identity -RemoveRole $Role -ErrorAction Stop
                }
                else {
                    throw 'Revoking all roles at list level is not supported; specify -Role.'
                }
            }

            Write-O365Log "$description on '$target'." 'Success'
        }
        catch {
            Write-Error -Message "Failed to revoke on '$target': $($_.Exception.Message)" -TargetObject $target
        }
    }
}
