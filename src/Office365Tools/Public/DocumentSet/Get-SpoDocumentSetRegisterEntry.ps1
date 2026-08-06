<#
.SYNOPSIS
    Compares the Document Sets in one or more libraries against a list that
    registers them, and describes the rows that are missing.
.DESCRIPTION
    A site often keeps one flat list as an index of the Document Sets scattered
    across its libraries: one row per Document Set, carrying the same metadata
    plus a hyperlink back to the folder. Maintaining that by hand is the kind
    of job that quietly stops happening, and a stale index is worse than none.

    This is the read half. It finds every Document Set in the named libraries,
    works out what the register already has, and emits a ready-to-write entry
    for everything that needs writing. Nothing is changed. The Values property
    is a hashtable in the shape Add-SpoListItem wants:

        Get-SpoDocumentSetRegisterEntry -Library Projekte -RegisterList Index |
            Add-SpoListItem -Library Index -WhatIf

    Each entry carries an Action saying which of three states it is in:

      Create   The register has no row for this Document Set.
      Update   It has one, but the Document Set has since moved to another
               library, so the row is filed under the wrong content type -- and
               its reference link, if it has one, points at the old location.
               Difference lists what drifted.
      Current  The row is right. Only emitted with -IncludeExisting.

    Rows are matched on a key that survives a move between libraries -- the
    Document ID, by default -- which is precisely why Update is a state that
    can occur at all: the row is correctly identified and wrongly filed.

    **An Update is deliberately narrow.** Its Values hold only what the move
    invalidated, never the metadata columns. A register is edited by hand --
    Titles get shortened, entries get annotated -- and re-copying every column
    from the source on each run would quietly undo that work.

    **Columns are matched by internal name.** A column present on both the
    register and the Document Set is copied across, and person, lookup, managed
    metadata and hyperlink values are translated to their writable form on the
    way. That overlap *is* the mapping -- there is no table of column names
    baked in here, which is what keeps the command usable on any site. Use
    -ColumnMap where the two names differ, and -ExcludeColumn to drop one.

    Two columns cannot be matched that way and are named explicitly:

      -ReferenceField    A hyperlink column on the register. The Document Set
                         has no equivalent to copy, so the URL is built: the
                         library's default view plus ?id= pointing at the
                         folder, which is the link that opens the Document Set
                         in its library rather than as a bare folder listing.

      -DocumentIdField   A hyperlink column on the register mirroring the
                         Document Set's Document ID (_dlc_DocIdUrl). Worth
                         filling in, because the Document ID survives a rename
                         and a move between libraries -- it is the only durable
                         identity a Document Set has, and therefore the default
                         -KeyField. Note that it makes -ReferenceField largely
                         redundant: a DocIdRedir link opens the Document Set
                         too, and being an ID rather than a path it does not go
                         stale when the folder moves.

    Matching on that column reads the ID out of its **URL**, never its link
    text. The two normally say the same thing -- SharePoint labels the link with
    the ID -- but a register that relabels it to show something friendlier is
    still perfectly matchable, and would otherwise look entirely unregistered
    and be duplicated wholesale on the next run.

    **Hyperlink text is whatever the source had**, which for a Document ID
    column is the ID itself. A register commonly wants a calculated column
    there instead, and a calculated column has no value until the item exists --
    so it cannot be part of the row that creates it. That is a second pass:
    Update-SpoListItemLinkText, after the rows are in.

    **Content type comes from -ContentTypeMap**, because it cannot be derived.
    A register that classifies its rows by where they came from needs to be
    told which of its content types goes with which library: the two sets of
    names rarely correspond, and guessing at a correspondence that is only
    usually right is worse than not guessing. Unmapped libraries get rows in
    the list's default content type, as before.

    Pass -IncludeExisting to see the Current rows too, which is how you check
    the key is doing what you think before writing anything.
.PARAMETER Library
    Libraries to read Document Sets from. Title, URL name, or GUID.
.PARAMETER RegisterList
    The list that registers the Document Sets.
.PARAMETER ContentTypeMap
    Hashtable of library to the register content type its Document Sets are
    registered as, by name or ID. Keys match either the name given to -Library
    or the library's actual title. Libraries not in the map get the register's
    default content type.
.PARAMETER ReferenceField
    Internal name of a hyperlink column on the register that should link back
    to the Document Set. Omit if the register has no such column.
.PARAMETER DocumentIdField
    Internal name of a hyperlink column on the register that should carry the
    Document Set's Document ID. Omit if the register has no such column, or if
    the Document ID service is not enabled on the site.
.PARAMETER KeyField
    Register column used to decide whether an entry already exists. Defaults to
    -DocumentIdField, then -ReferenceField, then Title -- in that order of
    preference, because that is their order of durability.
.PARAMETER ColumnMap
    Hashtable of register internal name to Document Set internal name, for
    columns whose names differ. Overrides the automatic match.
.PARAMETER ExcludeColumn
    Register columns to leave empty even though the names match.
.PARAMETER IncludeExisting
    Also emit entries the register already has and has right, with Action
    'Current'.
.PARAMETER PageSize
    Items fetched per request. Lower it if you hit throttling on a big library.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.DocumentSetRegisterEntry'.
    Values is the hashtable to write and ContentType the content type to write
    it as -- both named to bind to Add-SpoListItem on the pipeline. Action says
    whether that is a create or an update, Difference what drifted, SourceList
    which library the entry came from. There is deliberately no List or Library
    property: Add-SpoListItem aliases -Library to 'List', so one would bind on
    the pipeline and write the entries straight back into the library they were
    read from.
.EXAMPLE
    Get-SpoDocumentSetRegisterEntry -Library Projekte -RegisterList 'CDS Mappen' `
        -ReferenceField Reference -DocumentIdField Document_x0020_ID

    Lists the Document Sets in Projekte that the register does not have yet.
.EXAMPLE
    Get-SpoDocumentSetRegisterEntry -Library Management, Projekte -RegisterList Index `
        -ReferenceField Link -DocumentIdField DocId -ContentTypeMap @{
            Management = 'Management Entry'
            Projekte   = 'Project Entry'
        } | Add-SpoListItem -Library Index

    Registers each library's Document Sets as its own content type. ContentType
    binds from the entry, so the pipeline needs no per-library loop.
.EXAMPLE
    Get-SpoDocumentSetRegisterEntry -Library Management, Projekte -RegisterList Index `
        -ReferenceField Link -ContentTypeMap $map |
        Where-Object Action -eq 'Update' |
        Select-Object Name, SourceList, CurrentContentType, ContentType

    The Document Sets that have moved library since they were registered.
.EXAMPLE
    Get-SpoDocumentSetRegisterEntry -Library Management, Projekte, Produkte `
        -RegisterList 'CDS Mappen' -ReferenceField Reference `
        -DocumentIdField Document_x0020_ID -IncludeExisting |
        Group-Object SourceList, Exists -NoElement

    Checks the matching before writing anything: how many of each library the
    register already has.
.EXAMPLE
    Get-SpoDocumentSetRegisterEntry -Library Projekte -RegisterList Index -ReferenceField Link |
        Add-SpoListItem -Library Index -WhatIf

    Shows every row that would be created, and creates none.
.LINK
    Add-SpoListItem
.LINK
    Update-SpoListItemLinkText
.LINK
    Get-SpoDocumentSet
#>
function Get-SpoDocumentSetRegisterEntry {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string[]]$Library,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$RegisterList,

        [Parameter()]
        [string]$ReferenceField,

        [Parameter()]
        [string]$DocumentIdField,

        [Parameter()]
        [string]$KeyField,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable]$ContentTypeMap = @{},

        [Parameter()]
        [ValidateNotNull()]
        [hashtable]$ColumnMap = @{},

        [Parameter()]
        [string[]]$ExcludeColumn,

        [Parameter()]
        [switch]$IncludeExisting,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null

        $register = Resolve-SpoList -Identity $RegisterList

        # Attachments and ContentType are writable but are not metadata to
        # copy; the reference and Document ID columns are built rather than
        # matched, so they must not also be picked up by the name match.
        $neverMatch = @('Attachments', 'ContentType') + @($ExcludeColumn)
        if ($ReferenceField) { $neverMatch += $ReferenceField }
        if ($DocumentIdField) { $neverMatch += $DocumentIdField }

        $registerFields = @(Get-PnPField -List $register |
                Where-Object { -not $_.ReadOnlyField -and -not $_.Hidden })

        $registerFieldNames = @($registerFields | ForEach-Object { $_.InternalName })

        foreach ($name in @($ReferenceField, $DocumentIdField, $KeyField | Where-Object { $_ })) {
            if ($name -notin $registerFieldNames) {
                throw [System.ArgumentException]::new(
                    "Column '$name' is not a writable column on list '$($register.Title)'. " +
                    "Note this must be the internal name, not the display title. " +
                    "Run: Get-PnPField -List '$($register.Title)' | Select-Object InternalName, Title"
                )
            }
        }

        # Matched columns, and the Document Set column each one reads from.
        $matched = @{}
        foreach ($name in $registerFieldNames) {
            if ($name -in $neverMatch) { continue }
            $matched[$name] = $name
        }
        foreach ($entry in $ColumnMap.GetEnumerator()) {
            $matched[[string]$entry.Key] = [string]$entry.Value
        }

        if (-not $KeyField) {
            $KeyField = if ($DocumentIdField) { $DocumentIdField }
            elseif ($ReferenceField) { $ReferenceField }
            else { 'Title' }
        }

        # Check the map against the register now rather than letting each write
        # fail one at a time: a typo here misfiles every row from one library,
        # and the list of what was available is the useful half of the message.
        $registerContentTypes = @(Get-PnPContentType -List $register)

        # Keyed by ID, because an item's ContentType field value is not
        # dependable -- it comes back empty often enough that a comparison
        # against it silently decides everything is fine. ContentTypeId is
        # always there and matches the list content type's StringId exactly.
        $contentTypeNames = @{}
        foreach ($registerType in $registerContentTypes) {
            $contentTypeNames[[string]$registerType.StringId] = $registerType.Name
        }

        # Resolved to names, so that a map written with IDs still compares equal
        # to what an existing row reports and does not read as permanent drift.
        $wantedContentType = @{}

        foreach ($entry in $ContentTypeMap.GetEnumerator()) {
            $wantedType = [string]$entry.Value
            $known = @($registerContentTypes | Where-Object { $_.Name -eq $wantedType -or [string]$_.StringId -eq $wantedType })

            if ($known.Count -eq 0) {
                throw [System.ArgumentException]::new(
                    "Content type '$wantedType', mapped from library '$($entry.Key)', is not on list '$($register.Title)'. " +
                    "Available: $(($registerContentTypes | ForEach-Object Name) -join ', '). " +
                    "Add it to the list first, or correct -ContentTypeMap."
                )
            }

            $wantedContentType[[string]$entry.Key] = $known[0].Name
        }

        Write-O365Log "Register '$($register.Title)': matching $($matched.Count) column(s) by name, keyed on '$KeyField'." 'Info'

        # Index the register once. Two entries under one key means the register
        # already has duplicates -- reported rather than silently collapsed,
        # because it changes what "already present" means.
        $existing = @{}
        $registerItems = @(Get-PnPListItem -List $register -PageSize $PageSize)

        # Keys that cannot identify one row, either because the register holds
        # several under them or because several Document Sets claim the same
        # one. Such a row is matched to whichever came first, so comparing it
        # against a source says nothing -- see the note in the process block.
        $ambiguous = [System.Collections.Generic.HashSet[string]]::new()
        $claimed   = @{}

        foreach ($item in $registerItems) {
            $key = ConvertTo-SpoRegisterKey -Value $item.FieldValues[$KeyField]

            if ($key -eq '') {
                Write-O365Log "Register item $($item.Id) has no value in '$KeyField'; it cannot be matched and may be duplicated." 'Warning'
                continue
            }

            if ($existing.ContainsKey($key)) {
                Write-O365Log "Register items $($existing[$key].Id) and $($item.Id) share the key '$key' in '$KeyField'." 'Warning'
                $ambiguous.Add($key) | Out-Null
                continue
            }

            $link       = if ($ReferenceField) { $item.FieldValues[$ReferenceField] } else { $null }
            $typeId     = [string]$item.FieldValues['ContentTypeId']

            $existing[$key] = [pscustomobject]@{
                Id          = $item.Id
                ContentType = if ($contentTypeNames.ContainsKey($typeId)) { $contentTypeNames[$typeId] } else { '' }
                Reference   = if ($null -ne $link) { [string]$link.Url } else { '' }
            }
        }

        Write-O365Log "Register '$($register.Title)' holds $($registerItems.Count) item(s), $($existing.Count) with a usable key." 'Info'

        $siteUrl = $script:O365State.SiteUrl
    }

    process {
        foreach ($libraryName in $Library) {
            $list = Resolve-SpoList -Identity $libraryName

            # Either the name the caller used or the library's real title, so a
            # map written against titles still works when -Library was given a
            # URL name or a GUID, and vice versa.
            $contentType = if ($wantedContentType.ContainsKey($libraryName)) { $wantedContentType[$libraryName] }
            elseif ($wantedContentType.ContainsKey($list.Title)) { $wantedContentType[$list.Title] }
            else { '' }

            if ($ContentTypeMap.Count -gt 0 -and -not $contentType) {
                Write-O365Log "Library '$($list.Title)' is not in -ContentTypeMap; its entries get the default content type of '$($register.Title)'." 'Warning'
            }

            $libraryFieldNames = @(Get-PnPField -List $list | ForEach-Object { $_.InternalName })

            # Ask for only the columns that will be read. A library with a few
            # thousand items is the normal case here, and the default full-item
            # fetch is the difference between seconds and minutes.
            $wanted = [System.Collections.Generic.List[string]]::new()
            foreach ($name in @('ID', 'FileLeafRef', 'FileRef', 'ContentTypeId')) {
                $wanted.Add($name)
            }
            foreach ($name in @($matched.Values) + @('_dlc_DocId', '_dlc_DocIdUrl')) {
                if ($name -in $libraryFieldNames -and $name -notin $wanted) {
                    $wanted.Add($name)
                }
            }

            $unavailable = @($matched.GetEnumerator() |
                    Where-Object { $_.Value -notin $libraryFieldNames } |
                    ForEach-Object { $_.Value })

            if ($unavailable.Count -gt 0) {
                Write-O365Log "Library '$($list.Title)' has no column(s) $(($unavailable | Sort-Object) -join ', '); those register columns stay empty." 'Info'
            }

            if ($DocumentIdField -and '_dlc_DocId' -notin $libraryFieldNames) {
                Write-O365Log "Library '$($list.Title)' has no Document ID column. Enable the Document ID service on the site, or the register's '$DocumentIdField' stays empty." 'Warning'
            }

            $rootFolder = Get-PnPProperty -ClientObject $list -Property RootFolder
            $rootUrl    = $rootFolder.ServerRelativeUrl.TrimEnd('/')

            $items = @(Get-PnPListItem -List $list -PageSize $PageSize -Fields @($wanted))

            Write-O365Log "Read $($items.Count) item(s) from '$($list.Title)'." 'Info'

            foreach ($item in $items) {
                if ($item.FileSystemObjectType -ne 'Folder') { continue }
                if (-not (Test-SpoIsDocumentSetContentType -ContentTypeId ([string]$item.FieldValues['ContentTypeId']))) { continue }

                $url = [string]$item.FieldValues['FileRef']
                if (-not $url) { continue }

                $pathInfo  = Get-SpoRelativePath -ServerRelativeUrl $url -RootUrl $rootUrl
                $reference = New-SpoDocumentSetReference -SiteUrl $siteUrl -ViewUrl $list.DefaultViewUrl -ServerRelativeUrl $url

                $values = @{}
                foreach ($entry in $matched.GetEnumerator()) {
                    if ($entry.Value -notin $libraryFieldNames) { continue }

                    $writable = ConvertTo-SpoFieldUpdateValue -Value $item.FieldValues[$entry.Value]
                    if ($null -ne $writable) {
                        $values[$entry.Key] = $writable
                    }
                }

                if ($ReferenceField) {
                    # No description: the text comes from a calculated column
                    # that does not exist until the item does.
                    $values[$ReferenceField] = $reference
                }

                $documentId = [string]$item.FieldValues['_dlc_DocId']

                if ($DocumentIdField) {
                    $writable = ConvertTo-SpoFieldUpdateValue -Value $item.FieldValues['_dlc_DocIdUrl']
                    if ($null -ne $writable) {
                        $values[$DocumentIdField] = $writable
                    }
                }

                $key = if ($KeyField -eq $DocumentIdField) { $documentId.Trim().ToLowerInvariant() }
                elseif ($KeyField -eq $ReferenceField) { $reference.ToLowerInvariant() }
                else { ConvertTo-SpoRegisterKey -Value $item.FieldValues[$KeyField] }

                if ($key -eq '') {
                    Write-O365Log "Document Set '$url' has no value for the key column; skipped rather than risk a duplicate." 'Warning'
                    continue
                }

                $exists  = $existing.ContainsKey($key)
                $current = if ($exists) { $existing[$key] } else { $null }

                # A key that several Document Sets answer to -- copying a
                # Document Set copies its Document ID, so this is not rare --
                # matches all of them to whichever row came first. Comparing
                # that row against the second and third claimant would report
                # its reference as drifted every run and rewrite it to a
                # different one each time. There is nothing to compare here, so
                # nothing is emitted; the warning is the useful output.
                if ($exists) {
                    if ($ambiguous.Contains($key) -or $claimed.ContainsKey($key)) {
                        Write-O365Log ("Document Set '$url' shares the key '$key' with " +
                            "$(if ($claimed.ContainsKey($key)) { "'$($claimed[$key])'" } else { "another register row" }) " +
                            "and register item $($current.Id). It cannot be told apart from them, so it is left alone. " +
                            "Use -KeyField with the reference column if each copy needs its own row.") 'Warning'
                        continue
                    }

                    $claimed[$key] = $url
                }

                # What a move between libraries invalidates. Both follow from
                # the same event, and fixing one without the other leaves a row
                # that is either filed wrongly or linked to the old location.
                $verdict    = Get-SpoRegisterEntryAction -Current $current -ContentType $contentType `
                    -ReferenceField ([string]$ReferenceField) -Reference $reference
                $action     = $verdict.Action
                $difference = @($verdict.Difference)

                if ($action -eq 'Current' -and -not $IncludeExisting) { continue }

                if ($action -eq 'Update') {
                    # Only what drifted. See the note in the description: a
                    # register is hand-edited, and re-copying the metadata
                    # columns on every run would undo those edits.
                    $narrowed = @{}
                    if ($ReferenceField -and $ReferenceField -in $difference) {
                        $narrowed[$ReferenceField] = $reference
                    }
                    $values = $narrowed

                    Write-O365Log "Register item $($current.Id) ('$([string]$item.FieldValues['FileLeafRef'])') is out of step with '$($list.Title)': $($difference -join ', ')." 'Warning'
                }

                # SourceList, not List: Add-SpoListItem aliases its -Library
                # parameter to 'List', so a List property here would bind on the
                # pipeline and write the entries into the library they came
                # from. The destination is named, deliberately, only once.
                [pscustomobject]@{
                    PSTypeName         = 'Office365Tools.DocumentSetRegisterEntry'
                    SourceList         = $list.Title
                    RegisterList       = $register.Title
                    Name               = [string]$item.FieldValues['FileLeafRef']
                    RelativePath       = $pathInfo.RelativePath
                    ServerRelativeUrl  = $url
                    DocumentSetItemId  = $item.Id
                    DocumentId         = $documentId
                    Reference          = $reference
                    Key                = $key
                    KeyField           = $KeyField
                    Action             = $action
                    Exists             = $exists
                    RegisterItemId     = if ($exists) { $current.Id } else { $null }
                    ContentType        = $contentType
                    CurrentContentType = if ($exists) { $current.ContentType } else { '' }
                    Difference         = $difference
                    Values             = $values
                }
            }
        }
    }
}
