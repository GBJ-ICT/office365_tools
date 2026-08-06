<#
.SYNOPSIS
    Finds permission assignments pointing at principals that no longer resolve.
.DESCRIPTION
    When an account is deleted from Entra ID, SharePoint leaves the role
    assignment behind. The site keeps showing a name that nobody can log in as,
    permission reports stay cluttered, and access reviews get harder every
    year.

    This finds those leftovers, plus empty SharePoint groups still holding
    grants. It only reads -- use Revoke-SpoPermission to clean up what it
    finds.
.PARAMETER Library
    Library or list to scan. Omit to scan site-level groups only.
.PARAMETER IncludeEmptyGroups
    Also report SharePoint groups that hold permissions but have no members.
    These are not broken, but they are usually a leftover from a reorganisation.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    Find-SpoOrphanedPermission -Library Management
.EXAMPLE
    Find-SpoOrphanedPermission -Library Management -IncludeEmptyGroups |
        Export-SpoReport -Path out/orphans.html
.LINK
    Get-SpoPermissionReport
.LINK
    Revoke-SpoPermission
#>
function Find-SpoOrphanedPermission {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeEmptyGroups,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        Write-O365Log 'Checking site groups for orphaned members.' 'Info'

        foreach ($group in (Get-PnPGroup -ErrorAction SilentlyContinue)) {
            $members = @(Get-PnPGroupMember -Group $group.Title -ErrorAction SilentlyContinue)

            if ($members.Count -eq 0) {
                if ($IncludeEmptyGroups) {
                    New-SpoFinding -RuleId 'Permission.EmptyGroup' -Severity Info -Scope Principal `
                        -Target $group.Title `
                        -Message "SharePoint group '$($group.Title)' has no members but may still hold permissions." `
                        -Detail @{ GroupId = $group.Id }
                }
                continue
            }


            foreach ($member in $members) {
                # A deleted account keeps its entry but stops resolving. The
                # tell is an empty e-mail plus a login that still looks like a
                # user principal.
                $isUser = $member.PrincipalType -eq 'User'
                $looksDeleted = $isUser -and [string]::IsNullOrWhiteSpace($member.Email) -and ($member.LoginName -like '*|membership|*')

                if ($looksDeleted) {
                    $detail = @{
                        Group     = $group.Title
                        Title     = $member.Title
                        LoginName = $member.LoginName
                    }
                    New-SpoFinding -RuleId 'Permission.OrphanedPrincipal' -Severity Warning -Scope Principal `
                        -Target $member.LoginName `
                        -Message "User '$($member.Title)' in group '$($group.Title)' does not resolve to an active account." `
                        -Detail $detail
                }
            }
        }

        if (-not $Library) {
            return
        }

        $list = Resolve-SpoList -Identity $Library
        Write-O365Log "Checking unique assignments in '$($list.Title)'." 'Info'

        $items = Get-PnPListItem -List $list -PageSize $PageSize

        foreach ($item in $items) {
            $itemUrl = $item.FieldValues['FileRef']
            if (-not $itemUrl) { continue }

            try {
                $hasUnique = Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments
            }
            catch {
                continue
            }

            if (-not $hasUnique) { continue }

            foreach ($assignment in (Get-PnPProperty -ClientObject $item -Property RoleAssignments)) {
                $member = Get-PnPProperty -ClientObject $assignment -Property Member

                $isUser = $member.PrincipalType -eq 'User'
                $looksDeleted = $isUser -and [string]::IsNullOrWhiteSpace($member.Email) -and ($member.LoginName -like '*|membership|*')

                if ($looksDeleted) {
                    $detail = @{
                        Title     = $member.Title
                        LoginName = $member.LoginName
                        ItemId    = $item.Id
                    }
                    New-SpoFinding -RuleId 'Permission.OrphanedPrincipal' -Severity Warning -Scope Item `
                        -Target $itemUrl -List $list.Title `
                        -Message "Item grants access to '$($member.Title)', which does not resolve to an active account." `
                        -Detail $detail
                }
            }
        }
    }
}
