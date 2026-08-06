<#
.SYNOPSIS
    Internal: reduces a set of role assignments to a single comparable string.
.DESCRIPTION
    Two securable objects have "the same permissions" when the same principals
    hold the same role definitions. This builds a canonical signature from
    login names and role definition IDs -- both stable identifiers, unlike
    display names which vary by UI language.

    The work is split in two on purpose:

      Get-SpoPermissionSignature   fetches the CSOM properties (needs a tenant)
      ConvertTo-SpoPermissionSignature  does the canonicalisation (pure)

    The canonicalisation is where the subtle rules live -- sort order,
    Limited Access filtering -- so it is the part worth testing, and splitting
    lets the tests exercise it without SharePoint types that cannot be faked.
.PARAMETER RoleAssignment
    The RoleAssignments collection from a list, folder, or item.
.OUTPUTS
    System.String. An empty string means "no meaningful assignments".
.EXAMPLE
    $signature = Get-SpoPermissionSignature -RoleAssignment $assignments
#>
function Get-SpoPermissionSignature {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $RoleAssignment
    )

    if (-not $RoleAssignment) {
        return ''
    }

    $entries = foreach ($assignment in $RoleAssignment) {
        $member          = Get-PnPProperty -ClientObject $assignment -Property Member
        $roleDefinitions = Get-PnPProperty -ClientObject $assignment -Property RoleDefinitionBindings

        [pscustomobject]@{
            LoginName = $member.LoginName
            RoleIds   = @($roleDefinitions | ForEach-Object { $_.Id })
        }
    }

    return ConvertTo-SpoPermissionSignature -Entry @($entries)
}

<#
.SYNOPSIS
    Internal: canonicalises extracted permission entries into a signature.
.DESCRIPTION
    The pure half of the signature logic. Given login names and role IDs, it
    produces a string that is identical for two objects with equivalent
    permissions and different otherwise.

    Two rules matter:

      Sorting happens at both levels -- role IDs within a principal, then whole
      principal entries -- so assignment order never affects the result.

      'Limited Access' (role ID 1073741825) is dropped. SharePoint adds it
      automatically so a principal can traverse to a child it has real rights
      on. It appears and disappears on its own, so including it would make
      identical permission sets compare as different.
.PARAMETER Entry
    Objects with LoginName and RoleIds members.
.OUTPUTS
    System.String
#>
function ConvertTo-SpoPermissionSignature {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Entry
    )

    if (-not $Entry) {
        return ''
    }

    $limitedAccessRoleId = 1073741825

    $parts = foreach ($item in $Entry) {
        if (-not $item) { continue }

        $realRoles = $item.RoleIds | Where-Object { $_ -ne $limitedAccessRoleId }
        $realRoleIds = @($realRoles | Sort-Object)

        if ($realRoleIds.Count -eq 0) {
            continue
        }

        '{0}|{1}' -f $item.LoginName, ($realRoleIds -join ',')
    }

    return (@($parts) | Sort-Object) -join ';'
}
