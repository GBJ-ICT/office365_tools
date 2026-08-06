<#
.SYNOPSIS
    Internal: reads a library once and maps every item to the Document Set that
    contains it.
.DESCRIPTION
    Both Get-SpoDocumentSet and Get-SpoDocumentSetMismatch need the same thing:
    the Document Sets in a library, and for each one, everything underneath it.
    Doing that with a request per Document Set is what makes naive versions of
    this check take an hour on a real library, so the whole list is fetched in
    one paged pass and the hierarchy is derived from the URLs.

    Items are assigned to their *nearest* enclosing Document Set, walking up the
    path. That matters for the case of a Document Set inside a Document Set:
    the inner one owns its contents, and is itself reported as a root rather
    than as a child, because it carries its own metadata.
.PARAMETER List
    The PnP list object, already resolved.
.PARAMETER Name
    Restrict to Document Sets whose name matches this wildcard pattern.
.PARAMETER PageSize
    Items per request.
.OUTPUTS
    PSCustomObject with RootUrl and DocumentSet -- one entry per Document Set,
    each with Item, Url, Name, ContentTypeId, ContentTypeName, Depth and Child.
.EXAMPLE
    $map = Get-SpoDocumentSetMap -List $list -PageSize 500
#>
function Get-SpoDocumentSetMap {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        $List,

        [Parameter(Position = 1)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    $rootFolder = Get-PnPProperty -ClientObject $List -Property RootFolder
    $rootUrl    = $rootFolder.ServerRelativeUrl.TrimEnd('/')

    Write-O365Log "Reading items of '$($List.Title)'." 'Info'

    $items = @(Get-PnPListItem -List $List -PageSize $PageSize)

    Write-O365Log "Read $($items.Count) item(s) from '$($List.Title)'." 'Info'

    $documentSets = [System.Collections.Generic.List[object]]::new()
    $index        = @{}

    foreach ($item in $items) {
        $url = $item.FieldValues['FileRef']

        if (-not $url) {
            continue
        }

        if ($item.FileSystemObjectType -ne 'Folder') {
            continue
        }

        $contentTypeId = [string]$item.FieldValues['ContentTypeId']

        if (-not (Test-SpoIsDocumentSetContentType -ContentTypeId $contentTypeId)) {
            continue
        }

        $leaf = [string]$item.FieldValues['FileLeafRef']

        if ($Name -and $leaf -notlike $Name) {
            continue
        }

        $pathInfo = Get-SpoRelativePath -ServerRelativeUrl $url -RootUrl $rootUrl

        $entry = [pscustomobject]@{
            Item            = $item
            ItemId          = $item.Id
            Url             = $url
            Name            = $leaf
            ContentTypeId   = $contentTypeId
            ContentTypeName = [string]$item.FieldValues['ContentType']
            RelativePath    = $pathInfo.RelativePath
            Depth           = $pathInfo.Depth
            Child           = [System.Collections.Generic.List[object]]::new()
        }

        $documentSets.Add($entry)
        $index[$url.ToLowerInvariant()] = $entry
    }

    Write-O365Log "Found $($documentSets.Count) Document Set(s) in '$($List.Title)'." 'Info'

    if ($documentSets.Count -gt 0) {
        foreach ($item in $items) {
            $url = $item.FieldValues['FileRef']

            if (-not $url -or $index.ContainsKey($url.ToLowerInvariant())) {
                # Document Sets are roots, never children -- including a nested
                # one, which owns the metadata of everything below it.
                continue
            }

            $parent = $url
            while ($parent.Length -gt $rootUrl.Length) {
                $separator = $parent.LastIndexOf('/')
                if ($separator -le 0) {
                    break
                }

                $parent = $parent.Substring(0, $separator)

                $key = $parent.ToLowerInvariant()
                if ($index.ContainsKey($key)) {
                    $index[$key].Child.Add($item)
                    break
                }
            }
        }
    }

    [pscustomobject]@{
        RootUrl     = $rootUrl
        DocumentSet = $documentSets
    }
}
