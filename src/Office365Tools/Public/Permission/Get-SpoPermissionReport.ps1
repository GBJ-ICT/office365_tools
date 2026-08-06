<#
.SYNOPSIS
    Reports who has access to what in a list or library.
.DESCRIPTION
    Walks a library and emits one row per principal per securable object, which
    is the shape you want for auditing: it drops straight into Excel, groups
    cleanly by principal, and diffs well between runs.

    By default only objects with unique permissions are reported, since
    inheriting objects add rows without adding information. Use
    -IncludeInherited when you need the full effective picture.
.PARAMETER Library
    Title, URL name, or GUID of the library or list.
.PARAMETER IncludeInherited
    Also emit rows for objects that inherit their permissions.
.PARAMETER ExpandGroups
    Resolve SharePoint group membership so each row names a real user. Slower,
    because each group costs a request, but it answers "can Anna open this?"
    which the unexpanded report cannot.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.PermissionEntry'.
.EXAMPLE
    Get-SpoPermissionReport -Library Management |
        Export-Csv out/permissions.csv -NoTypeInformation
.EXAMPLE
    Get-SpoPermissionReport -Library Management -ExpandGroups |
        Where-Object PrincipalLogin -like '*anna*'
    Shows everything Anna can reach in the library.
.LINK
    Get-SpoPermissionMismatch
.LINK
    Find-SpoOrphanedPermission
#>
function Get-SpoPermissionReport {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'ExpandGroups',
        Justification = 'Used inside the $emit script block, which the analyzer does not trace into.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeInherited,

        [Parameter()]
        [switch]$ExpandGroups,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
        $groupCache = @{}
    }

    process {
        $list    = Resolve-SpoList -Identity $Library
        $root    = Get-PnPProperty -ClientObject $list -Property RootFolder
        $rootUrl = $root.ServerRelativeUrl

        Write-O365Log "Building permission report for '$($list.Title)'." 'Info'

        # Emit an object's assignments as flat rows.
        $emit = {
            param($securable, $scope, $target, $relativePath, $hasUnique)

            $assignments = Get-PnPProperty -ClientObject $securable -Property RoleAssignments

            foreach ($assignment in $assignments) {
                $member = Get-PnPProperty -ClientObject $assignment -Property Member
                $roles  = Get-PnPProperty -ClientObject $assignment -Property RoleDefinitionBindings

                $roleNames = @($roles | Where-Object { $_.Id -ne 1073741825 } | ForEach-Object { $_.Name })
                if ($roleNames.Count -eq 0) {
                    continue
                }

                $members = @([pscustomobject]@{ Login = $member.LoginName; Title = $member.Title; Type = $member.PrincipalType })

                if ($ExpandGroups -and $member.PrincipalType -eq 'SharePointGroup') {
                    if (-not $groupCache.ContainsKey($member.LoginName)) {
                        $groupCache[$member.LoginName] = try {
                            @(Get-PnPGroupMember -Group $member.Title -ErrorAction Stop |
                                    ForEach-Object {
                                        [pscustomobject]@{ Login = $_.LoginName; Title = $_.Title; Type = 'User' }
                                    })
                        }
                        catch {
                            Write-O365Log "Could not expand group '$($member.Title)': $($_.Exception.Message)" 'Warning'
                            @()
                        }
                    }

                    $expanded = $groupCache[$member.LoginName]
                    if ($expanded.Count -gt 0) {
                        $members = $expanded | ForEach-Object {
                            [pscustomobject]@{
                                Login = $_.Login
                                Title = $_.Title
                                Type  = 'User'
                                Via   = $member.Title
                            }
                        }
                    }
                }

                foreach ($principal in $members) {
                    [pscustomobject]@{
                        PSTypeName     = 'Office365Tools.PermissionEntry'
                        List           = $list.Title
                        Scope          = $scope
                        Target         = $target
                        RelativePath   = $relativePath
                        HasUnique      = $hasUnique
                        PrincipalTitle = $principal.Title
                        PrincipalLogin = $principal.Login
                        PrincipalType  = $principal.Type
                        ViaGroup       = if ($principal.PSObject.Properties.Name -contains 'Via') { $principal.Via } else { $null }
                        Roles          = $roleNames -join ', '
                        SiteUrl        = $script:O365State.SiteUrl
                    }
                }
            }
        }

        # Library level first.
        & $emit $list 'List' $list.Title '' $list.HasUniqueRoleAssignments

        $items = Get-PnPListItem -List $list -PageSize $PageSize
        $total = @($items).Count
        $index = 0

        foreach ($item in $items) {
            $index++
            $itemUrl = $item.FieldValues['FileRef']
            if (-not $itemUrl) { continue }

            Write-Progress -Activity "Reporting permissions in $($list.Title)" `
                -Status $item.FieldValues['FileLeafRef'] -PercentComplete (($index / [Math]::Max($total, 1)) * 100)

            try {
                $hasUnique = Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments
            }
            catch {
                Write-O365Log "Could not read permission state of '$itemUrl': $($_.Exception.Message)" 'Warning'
                continue
            }

            if (-not $hasUnique -and -not $IncludeInherited) {
                continue
            }

            $pathInfo = Get-SpoRelativePath -ServerRelativeUrl $itemUrl -RootUrl $rootUrl
            $scope    = if ($item.FileSystemObjectType -eq 'Folder') { 'Folder' } else { 'Item' }

            & $emit $item $scope $itemUrl $pathInfo.RelativePath $hasUnique
        }

        Write-Progress -Activity "Reporting permissions in $($list.Title)" -Completed
        Write-O365Log "Permission report for '$($list.Title)' complete." 'Success'
    }
}
