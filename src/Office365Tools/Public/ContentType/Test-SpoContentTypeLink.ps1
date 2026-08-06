<#
.SYNOPSIS
    Checks list content types against the site content types they descend from.
.DESCRIPTION
    When a site content type is added to a list, SharePoint makes a *copy*. The
    copy does not track later changes to the parent unless someone explicitly
    pushes them. Over a couple of years this produces the classic mess:

      - list copies whose parent site content type was deleted (orphaned)
      - fields added to the parent that never reached the list copies (drift)
      - fields removed from the parent that linger on the list copies
      - list copies renamed so nobody can tell what they descend from

    This command reports all four. It only reads. Use Sync-SpoContentType to
    push parent changes down, or Remove-SpoContentTypeFromList to clear out
    orphans.
.PARAMETER Library
    Check this list only. Omit to check every visible list on the site.
.PARAMETER IncludeHidden
    Also check hidden lists. Off by default because system lists produce noise
    that is never actionable.
.PARAMETER IncludeBuiltIn
    Also check the built-in content types (Document, Item, Folder, and
    friends). Skipped by default -- their parents live in the content type hub
    rather than on this site, so they always look orphaned here.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    Test-SpoContentTypeLink
    Checks every visible list on the connected site.
.EXAMPLE
    Test-SpoContentTypeLink -Library Contracts |
        Where-Object Severity -eq 'Error'
.EXAMPLE
    Test-SpoContentTypeLink | Export-SpoReport -Path out/content-types.html
.LINK
    Sync-SpoContentType
.LINK
    Find-SpoContentTypeByColumn
#>
function Test-SpoContentTypeLink {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeHidden,

        [Parameter()]
        [switch]$IncludeBuiltIn
    )

    begin {
        Assert-SpoConnection | Out-Null

        # Built-in content type IDs whose parents live outside this site.
        $builtInIds = @('0x', '0x01', '0x0101', '0x0120', '0x0120D5')
    }

    process {
        $lists = if ($Library) {
            @(Resolve-SpoList -Identity $Library)
        }
        else {
            @(Get-PnPList | Where-Object { $IncludeHidden -or -not $_.Hidden })
        }

        # Index the site's content types once; every list is compared against it.
        $siteContentTypes = @{}
        foreach ($siteContentType in (Get-PnPContentType)) {
            $siteContentTypes[$siteContentType.Id.StringValue] = $siteContentType
        }

        Write-O365Log "Checking $(@($lists).Count) list(s) against $($siteContentTypes.Count) site content type(s)." 'Info'

        foreach ($list in $lists) {
            if (-not $list.ContentTypesEnabled) {
                continue
            }

            $listContentTypes = @(Get-PnPContentType -List $list -ErrorAction SilentlyContinue)

            foreach ($listContentType in $listContentTypes) {
                $listId = $listContentType.Id.StringValue

                if (-not $IncludeBuiltIn -and $listId -in $builtInIds) {
                    continue
                }

                # A list content type's ID is its parent's ID followed by '00'
                # and a GUID. Longest matching prefix wins, because content
                # type IDs nest.
                $prefixes = $siteContentTypes.Keys | Where-Object {
                    $listId.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) -and $_ -ne $listId
                }
                $candidates = @($prefixes | Sort-Object -Property Length -Descending)
                $parentId = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }

                if (-not $parentId) {
                    $detail = @{
                        ContentTypeId = $listId
                        ListTitle     = $list.Title
                    }
                    New-SpoFinding -RuleId 'ContentType.OrphanedListCopy' -Severity Error -Scope ContentType `
                        -Target "$($list.Title) / $($listContentType.Name)" -List $list.Title `
                        -Message "List content type '$($listContentType.Name)' has no matching site content type; its parent was probably deleted." `
                        -Detail $detail
                    continue
                }

                $parent = $siteContentTypes[$parentId]

                if ($listContentType.Name -ne $parent.Name) {
                    $detail = @{
                        ContentTypeId = $listId
                        ParentId      = $parentId
                        ParentName    = $parent.Name
                    }
                    New-SpoFinding -RuleId 'ContentType.NameDrift' -Severity Info -Scope ContentType `
                        -Target "$($list.Title) / $($listContentType.Name)" -List $list.Title `
                        -Message "List copy is named '$($listContentType.Name)' but descends from site content type '$($parent.Name)'." `
                        -Detail $detail
                }

                $parentFieldObjects = Get-PnPProperty -ClientObject $parent -Property Fields
                $parentFields = @($parentFieldObjects | Where-Object { -not $_.Hidden } | ForEach-Object { $_.InternalName })

                $listFieldObjects = Get-PnPProperty -ClientObject $listContentType -Property Fields
                $listFields = @($listFieldObjects | Where-Object { -not $_.Hidden } | ForEach-Object { $_.InternalName })

                $missing = @($parentFields | Where-Object { $_ -notin $listFields })
                $extra   = @($listFields | Where-Object { $_ -notin $parentFields })

                if ($missing.Count -gt 0) {
                    $detail = @{
                        ContentTypeId = $listId
                        ParentName    = $parent.Name
                        MissingFields = $missing
                    }
                    New-SpoFinding -RuleId 'ContentType.FieldMissingOnListCopy' -Severity Warning -Scope ContentType `
                        -Target "$($list.Title) / $($listContentType.Name)" -List $list.Title `
                        -Message "List copy is missing $($missing.Count) field(s) present on parent '$($parent.Name)': $($missing -join ', ')." `
                        -Detail $detail
                }

                if ($extra.Count -gt 0) {
                    $detail = @{
                        ContentTypeId = $listId
                        ParentName    = $parent.Name
                        ExtraFields   = $extra
                    }
                    New-SpoFinding -RuleId 'ContentType.FieldOnlyOnListCopy' -Severity Info -Scope ContentType `
                        -Target "$($list.Title) / $($listContentType.Name)" -List $list.Title `
                        -Message "List copy has $($extra.Count) field(s) the parent '$($parent.Name)' does not: $($extra -join ', ')." `
                        -Detail $detail
                }
            }
        }

        Write-O365Log 'Content type link check complete.' 'Success'
    }
}
