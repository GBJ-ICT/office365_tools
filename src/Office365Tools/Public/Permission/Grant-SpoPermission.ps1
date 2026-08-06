<#
.SYNOPSIS
    Grants a principal a role on a list, folder, or item.
.DESCRIPTION
    Adds a role assignment. If the target currently inherits its permissions,
    inheritance must be broken first -- pass -BreakInheritance to allow that,
    otherwise the command refuses rather than silently changing the security
    model of everything below the target.

    Breaking inheritance is a bigger decision than adding one grant, which is
    why it needs its own explicit opt-in.
.PARAMETER Library
    Library or list title.
.PARAMETER ServerRelativeUrl
    Target folder or file inside the library. Omit to grant at library level.
.PARAMETER Identity
    Login name of the user, or the title of a SharePoint group.
.PARAMETER Role
    Role definition name as it appears in the site, e.g. 'Read', 'Contribute',
    'Full Control'. Names are language-dependent on non-English sites.
.PARAMETER BreakInheritance
    Permit breaking inheritance on the target if it is currently inheriting.
.PARAMETER CopyExisting
    When breaking inheritance, start from a copy of the inherited assignments
    rather than an empty ACL. Without this, breaking inheritance removes
    everyone's access except the new grant.
.EXAMPLE
    Grant-SpoPermission -Library Management -Identity 'anna@contoso.com' -Role Read
.EXAMPLE
    Grant-SpoPermission -Library Management `
        -ServerRelativeUrl '/sites/cds/Management/Board' `
        -Identity 'Board Members' -Role Contribute -BreakInheritance -CopyExisting
.LINK
    Revoke-SpoPermission
.LINK
    Get-SpoPermissionReport
#>
function Grant-SpoPermission {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [string]$ServerRelativeUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Role,

        [Parameter()]
        [switch]$BreakInheritance,

        [Parameter()]
        [switch]$CopyExisting
    )

    Assert-SpoConnection | Out-Null

    $list = Resolve-SpoList -Identity $Library

    $target = if ($ServerRelativeUrl) { $ServerRelativeUrl } else { $list.Title }

    # Confirm the role exists before touching anything, so a typo fails cheaply.
    $roleDefinition = Get-PnPRoleDefinition | Where-Object { $_.Name -eq $Role }
    if (-not $roleDefinition) {
        $available = @(Get-PnPRoleDefinition | ForEach-Object { $_.Name }) -join ', '
        throw [System.InvalidOperationException]::new(
            "Role '$Role' does not exist on this site. Available roles: $available"
        )
    }

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
        if (-not $BreakInheritance) {
            throw [System.InvalidOperationException]::new(
                "'$target' currently inherits its permissions. Granting here requires breaking " +
                'inheritance, which changes the security model for everything below it. ' +
                'Re-run with -BreakInheritance (and normally -CopyExisting) if that is what you want.'
            )
        }

        if ($PSCmdlet.ShouldProcess($target, "Break permission inheritance (copy existing: $($CopyExisting.IsPresent))")) {
            $securable.BreakRoleInheritance($CopyExisting.IsPresent, $false)
            Invoke-PnPQuery
            Write-O365Log "Broke inheritance on '$target'." 'Warning'
        }
        else {
            return
        }
    }

    if ($PSCmdlet.ShouldProcess($target, "Grant '$Role' to '$Identity'")) {
        $params = @{
            List        = $list.Title
            User        = $Identity
            AddRole     = $Role
            ErrorAction = 'Stop'
        }

        try {
            if ($ServerRelativeUrl) {
                $itemId = $securable.Id
                Set-PnPListItemPermission -List $list.Title -Identity $itemId -User $Identity -AddRole $Role -ErrorAction Stop
            }
            else {
                Set-PnPListPermission @params
            }

            Write-O365Log "Granted '$Role' to '$Identity' on '$target'." 'Success'
        }
        catch {
            throw [System.InvalidOperationException]::new(
                "Failed to grant '$Role' to '$Identity' on '$target': $($_.Exception.Message)",
                $_.Exception
            )
        }
    }
}
