<#
.SYNOPSIS
    Lists the Document Sets in a library and the columns they share downwards.
.DESCRIPTION
    Answers "what Document Sets are in here, and which of their columns are
    supposed to reach the documents inside them" in one pass.

    SharedColumn is the important part. A Document Set copies a column's value
    down to its contents only if that column is registered as a *shared*
    column on the Document Set content type. A column that is on the content
    type but not shared is filled in on the Document Set and then goes
    nowhere -- which is what "the metadata is not syncing" almost always turns
    out to mean.

    Read-only. Use Get-SpoDocumentSetMismatch to find contents whose values
    have actually drifted, and Test-SpoDocumentSetSharedColumn to find columns
    that were never wired up to sync in the first place.
.PARAMETER Library
    Title, URL name, or GUID of the document library.
.PARAMETER Name
    Wildcard pattern restricting which Document Sets are returned.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling on a big library.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.DocumentSet'.
.EXAMPLE
    Get-SpoDocumentSet -Library Projekte
    Lists every Document Set in the Projekte library.
.EXAMPLE
    Get-SpoDocumentSet -Library Projekte | Where-Object SharedColumnCount -eq 0
    Finds Document Sets that share nothing at all -- they can never push
    metadata down, however carefully it is filled in.
.EXAMPLE
    Get-SpoDocumentSet -Library Projekte |
        Select-Object Name, ItemCount, @{ n = 'Shared'; e = { $_.SharedColumn -join ', ' } }
.LINK
    Get-SpoDocumentSetMismatch
.LINK
    Test-SpoDocumentSetSharedColumn
#>
function Get-SpoDocumentSet {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 1)]
        [string]$Name,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library
        $map  = Get-SpoDocumentSetMap -List $list -Name $Name -PageSize $PageSize

        foreach ($documentSet in $map.DocumentSet) {
            $template = Resolve-SpoDocumentSetTemplate `
                -ContentTypeId $documentSet.ContentTypeId `
                -ContentTypeName $documentSet.ContentTypeName

            $children = @($documentSet.Child)

            [pscustomobject]@{
                PSTypeName        = 'Office365Tools.DocumentSet'
                List              = $list.Title
                Name              = $documentSet.Name
                RelativePath      = $documentSet.RelativePath
                ServerRelativeUrl = $documentSet.Url
                ItemId            = $documentSet.ItemId
                # An item does not always carry a readable ContentType value;
                # the resolved content type is the reliable name.
                ContentTypeName   = if ($documentSet.ContentTypeName) { $documentSet.ContentTypeName } else { $template.ContentTypeName }
                ContentTypeId     = $documentSet.ContentTypeId
                Depth             = $documentSet.Depth
                ItemCount         = $children.Count
                FileCount         = @($children | Where-Object { $_.FileSystemObjectType -ne 'Folder' }).Count
                FolderCount       = @($children | Where-Object { $_.FileSystemObjectType -eq 'Folder' }).Count
                SharedColumn      = $template.SharedField
                SharedColumnCount = @($template.SharedField).Count
                TemplateResolved  = $template.Resolved
                SiteUrl           = $script:O365State.SiteUrl
            }
        }
    }
}
