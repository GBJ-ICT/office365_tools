<#
.SYNOPSIS
    Finds items whose unique permissions differ from their parent's.
.DESCRIPTION
    Reports every item in a library that has broken permission inheritance AND
    whose resulting permissions actually differ from what it would have
    inherited. Items with unique permissions that happen to match their parent
    are not reported -- they are harmless, and reporting them buries the real
    findings.

    This command only reads. To act on what it finds, pipe it to
    Repair-SpoPermissionInheritance. That separation is deliberate: the
    predecessor script was named check_for_permission_mismatches.ps1 but reset
    inheritance as a side effect, which is not a thing a script called "check"
    should ever do.

    Comparison is against the immediate parent folder, not the library root, so
    an intentionally-restricted folder does not make every file inside it look
    like a finding.
.PARAMETER Library
    Title, URL name, or GUID of the document library or list to scan.
.PARAMETER Folder
    Restrict the scan to a server-relative folder inside the library.
.PARAMETER ItemType
    Scan files, folders, or both. Default is both.
.PARAMETER MinimumDepth
    Ignore items shallower than this. Depth 1 is the library root. The common
    case is -MinimumDepth 2, which suppresses top-level folders that are
    usually restricted on purpose.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling on a big library.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.PermissionMismatch'.
.EXAMPLE
    Get-SpoPermissionMismatch -Library Management
    Lists every mismatch in the Management library.
.EXAMPLE
    Get-SpoPermissionMismatch -Library Management -MinimumDepth 2 |
        Export-Csv out/mismatches.csv -NoTypeInformation
    Ignores top-level folders and saves the rest for review.
.EXAMPLE
    Get-SpoPermissionMismatch -Library Management -MinimumDepth 2 |
        Repair-SpoPermissionInheritance -WhatIf
    Shows exactly what a repair would change, without changing anything.
.LINK
    Repair-SpoPermissionInheritance
.LINK
    Get-SpoPermissionReport
#>
function Get-SpoPermissionMismatch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [string]$Folder,

        [Parameter()]
        [ValidateSet('All', 'File', 'Folder')]
        [string]$ItemType = 'All',

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MinimumDepth = 1,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library
        $root = Get-PnPProperty -ClientObject $list -Property RootFolder
        $rootUrl = $root.ServerRelativeUrl

        Write-O365Log "Scanning '$($list.Title)' for permission mismatches." 'Info'

        $listAssignments = Get-PnPProperty -ClientObject $list -Property RoleAssignments
        $listSignature   = Get-SpoPermissionSignature -RoleAssignment $listAssignments

        # Parent signatures are looked up repeatedly (every file in a folder
        # shares one), and each lookup is a round trip. Cache them.
        $signatureCache = @{ $rootUrl = $listSignature }

        $items = Get-PnPListItem -List $list -PageSize $PageSize

        if (-not $items) {
            Write-O365Log "Library '$($list.Title)' contains no items." 'Warning'
            return
        }

        Write-O365Log "Checking $(@($items).Count) item(s)." 'Info'

        $checked = 0
        foreach ($item in $items) {
            $checked++
            $itemUrl  = $item.FieldValues['FileRef']
            $itemName = $item.FieldValues['FileLeafRef']

            if (-not $itemUrl) {
                continue
            }

            Write-Progress -Activity "Checking permissions in $($list.Title)" `
                -Status $itemName -PercentComplete (($checked / @($items).Count) * 100)

            $isFolder = $item.FileSystemObjectType -eq 'Folder'
            $kind     = if ($isFolder) { 'Folder' } else { 'File' }

            if ($ItemType -ne 'All' -and $ItemType -ne $kind) {
                continue
            }

            if ($Folder -and -not $itemUrl.StartsWith($Folder.TrimEnd('/'), [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $pathInfo = Get-SpoRelativePath -ServerRelativeUrl $itemUrl -RootUrl $rootUrl

            if ($pathInfo.Depth -lt $MinimumDepth) {
                continue
            }

            try {
                $hasUnique = Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments
            }
            catch {
                Write-O365Log "Could not read permission state of '$itemUrl': $($_.Exception.Message)" 'Warning'
                continue
            }

            if (-not $hasUnique) {
                continue
            }

            $itemSignature = Get-SpoPermissionSignature -RoleAssignment (
                Get-PnPProperty -ClientObject $item -Property RoleAssignments
            )

            $parentUrl = $pathInfo.ParentUrl

            if (-not $signatureCache.ContainsKey($parentUrl)) {
                $signatureCache[$parentUrl] = try {
                    $parentFolder = Get-PnPFolder -Url $parentUrl -ErrorAction Stop
                    Get-SpoPermissionSignature -RoleAssignment (
                        Get-PnPProperty -ClientObject $parentFolder.ListItemAllFields -Property RoleAssignments
                    )
                }
                catch {
                    Write-O365Log "Could not read parent permissions for '$parentUrl'; comparing against the library instead." 'Warning'
                    $listSignature
                }
            }

            $parentSignature = $signatureCache[$parentUrl]

            if ($itemSignature -eq $parentSignature) {
                # Unique permissions, but identical to what it would inherit.
                # Cosmetically untidy, functionally fine. Not a finding.
                continue
            }

            [pscustomobject]@{
                PSTypeName        = 'Office365Tools.PermissionMismatch'
                List              = $list.Title
                Kind              = $kind
                Name              = $itemName
                RelativePath      = $pathInfo.RelativePath
                ServerRelativeUrl = $itemUrl
                Depth             = $pathInfo.Depth
                ParentUrl         = $parentUrl
                ItemSignature     = $itemSignature
                ParentSignature   = $parentSignature
                ItemId            = $item.Id
                SiteUrl           = $script:O365State.SiteUrl
            }
        }

        Write-Progress -Activity "Checking permissions in $($list.Title)" -Completed
        Write-O365Log "Finished scanning '$($list.Title)'." 'Success'
    }
}
