<#
.SYNOPSIS
    Finds documents and folders whose metadata differs from the Document Set
    they sit in.
.DESCRIPTION
    A Document Set is supposed to keep its contents carrying its own metadata:
    SharePoint copies each *shared* column down when a document is added, and
    again whenever the Document Set's properties are saved. In practice that
    sync stops happening, and there is rarely one cause:

      - files were moved or copied into the Document Set rather than uploaded
        into it, and the copy operation preserves the source's metadata
      - a column was added to the Document Set content type later and never
        registered as a shared column, so nothing was ever pushed
      - the Document Set's values were changed by a script using SystemUpdate,
        which writes the item without running the push-down
      - the push failed part-way on a large Document Set and was never retried
      - folders: SharePoint's own push targets documents, so subfolders inside
        a Document Set routinely keep whatever they were created with

    This command reports the drift. It compares every item underneath each
    Document Set -- files and folders, at any depth -- against the Document Set
    itself, and emits one object per item carrying every column that differs.

    It only reads. Pipe the output to Repair-SpoDocumentSetMetadata to push the
    Document Set's values down. Use Test-SpoDocumentSetSharedColumn to find out
    *why* the sync stopped, which is usually the thing worth fixing so the
    drift does not simply come back.

    Comparison is by term GUID for managed metadata and by lookup ID for
    lookup and person columns, so a renamed term or a differently rendered
    display name is not reported as a difference.
.PARAMETER Library
    Title, URL name, or GUID of the document library to scan.
.PARAMETER DocumentSet
    Wildcard pattern restricting which Document Sets are checked.
.PARAMETER Column
    Compare exactly these columns (internal names) instead of the Document
    Set's shared columns. Use it when the shared column list is itself wrong
    and you want to see the drift regardless.
.PARAMETER IncludeUnsharedColumn
    Also compare columns that are on the Document Set content type but are not
    registered as shared. These are never synced by SharePoint, so they drift
    silently -- but they are also the columns somebody may have deliberately
    set per document, so they are off by default.
.PARAMETER ItemType
    Check files, folders, or both. Default is both, because folders are the
    ones SharePoint's own push-down misses.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling on a big library.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.DocumentSetMismatch'. Each
    carries a Difference collection: one entry per column, with the Document
    Set's value, the item's value, and why they differ.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte
    Lists every item under a Document Set in Projekte whose shared column
    values do not match the Document Set.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte |
        Export-Csv out/projekte-drift.csv -NoTypeInformation
    Keeps a record of the current state before changing anything.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte -DocumentSet 'P-2026-*' |
        Repair-SpoDocumentSetMetadata -WhatIf
    Shows exactly what a repair would write, without writing it.
.EXAMPLE
    Get-SpoDocumentSetMismatch -Library Projekte |
        Select-Object -ExpandProperty Difference |
        Group-Object Field | Sort-Object Count -Descending
    Ranks the columns by how far they have drifted -- the one at the top is
    usually the one that was never registered as shared.
.LINK
    Repair-SpoDocumentSetMetadata
.LINK
    Test-SpoDocumentSetSharedColumn
.LINK
    Get-SpoDocumentSet
#>
function Get-SpoDocumentSetMismatch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 1)]
        [Alias('Name')]
        [string]$DocumentSet,

        [Parameter()]
        [Alias('Field')]
        [string[]]$Column,

        [Parameter()]
        [switch]$IncludeUnsharedColumn,

        [Parameter()]
        [ValidateSet('All', 'File', 'Folder')]
        [string]$ItemType = 'All',

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        # The library's own columns, indexed once: needed to report a shared
        # column that does not exist on the library at all (which cannot be
        # repaired by writing a value), and to give findings a display name.
        $listFields = @{}
        foreach ($field in (Get-PnPField -List $list -ErrorAction SilentlyContinue)) {
            $listFields[$field.InternalName] = $field
        }

        $map = Get-SpoDocumentSetMap -List $list -Name $DocumentSet -PageSize $PageSize

        if (@($map.DocumentSet).Count -eq 0) {
            Write-O365Log "No Document Sets found in '$($list.Title)'." 'Warning'
            return
        }

        $checked = 0
        $total   = @($map.DocumentSet).Count

        foreach ($sourceSet in $map.DocumentSet) {
            $checked++

            Write-Progress -Activity "Checking Document Set metadata in $($list.Title)" `
                -Status $sourceSet.Name -PercentComplete (($checked / $total) * 100)

            $template = Resolve-SpoDocumentSetTemplate `
                -ContentTypeId $sourceSet.ContentTypeId `
                -ContentTypeName $sourceSet.ContentTypeName

            $columns = if ($Column) {
                @($Column)
            }
            else {
                $shared = @($template.SharedField)

                if ($IncludeUnsharedColumn) {
                    $shared += @($template.ContentTypeField |
                            Where-Object { Test-SpoSyncableColumn -Field $_ } |
                            ForEach-Object { $_.InternalName })
                }

                @($shared | Select-Object -Unique)
            }

            if ($columns.Count -eq 0) {
                Write-O365Log "Document Set '$($sourceSet.Name)' has no shared columns; nothing to compare. Run Test-SpoDocumentSetSharedColumn to see why." 'Warning'
                continue
            }

            $children = @($sourceSet.Child)

            if ($children.Count -eq 0) {
                continue
            }

            # The Document Set's own values are the reference for every item
            # below it, so lift them out once per Document Set.
            $reference = @{}
            foreach ($name in $columns) {
                $reference[$name] = if ($sourceSet.Item.FieldValues.ContainsKey($name)) {
                    $sourceSet.Item.FieldValues[$name]
                }
                else {
                    $null
                }
            }

            $displayNames = @{}
            foreach ($name in $columns) {
                $displayNames[$name] = if ($listFields.ContainsKey($name)) { $listFields[$name].Title } else { $name }
            }

            foreach ($item in $children) {
                $itemUrl = $item.FieldValues['FileRef']

                if (-not $itemUrl) {
                    continue
                }

                $isFolder = $item.FileSystemObjectType -eq 'Folder'
                $kind     = if ($isFolder) { 'Folder' } else { 'File' }

                if ($ItemType -ne 'All' -and $ItemType -ne $kind) {
                    continue
                }

                $itemValues = @{}
                foreach ($name in $columns) {
                    $itemValues[$name] = if ($item.FieldValues.ContainsKey($name)) { $item.FieldValues[$name] } else { $null }
                }

                $differences = @(Compare-SpoDocumentSetValue `
                        -Column $columns `
                        -DocumentSetValue $reference `
                        -ItemValue $itemValues `
                        -AvailableColumn @($listFields.Keys) `
                        -DisplayName $displayNames `
                        -SharedColumn @($template.SharedField))

                if ($differences.Count -eq 0) {
                    continue
                }

                $relative = Get-SpoRelativePath -ServerRelativeUrl $itemUrl -RootUrl $sourceSet.Url

                [pscustomobject]@{
                    PSTypeName        = 'Office365Tools.DocumentSetMismatch'
                    List              = $list.Title
                    DocumentSet       = $sourceSet.Name
                    DocumentSetUrl    = $sourceSet.Url
                    DocumentSetItemId = $sourceSet.ItemId
                    Kind              = $kind
                    Name              = [string]$item.FieldValues['FileLeafRef']
                    RelativePath      = $relative.RelativePath
                    ServerRelativeUrl = $itemUrl
                    ItemId            = $item.Id
                    ContentTypeName   = [string]$item.FieldValues['ContentType']
                    DifferenceCount   = $differences.Count
                    DifferingColumn   = (@($differences | ForEach-Object { $_.Field }) -join ', ')
                    Difference        = $differences
                    SiteUrl           = $script:O365State.SiteUrl
                }
            }
        }

        Write-Progress -Activity "Checking Document Set metadata in $($list.Title)" -Completed
        Write-O365Log "Finished checking Document Set metadata in '$($list.Title)'." 'Success'
    }
}
