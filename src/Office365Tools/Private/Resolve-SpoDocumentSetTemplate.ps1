<#
.SYNOPSIS
    Internal: tells whether a content type ID is a Document Set.
.DESCRIPTION
    Every Document Set content type descends from the built-in Document Set
    (0x0120D520), and content type IDs carry their ancestry as a prefix. So the
    check is a prefix match, and it holds for custom Document Set content types
    without having to enumerate them.

    Pure string handling on purpose: it is the one piece of Document Set logic
    that can be unit tested without a tenant.
.PARAMETER ContentTypeId
    The content type ID string, e.g. 0x0120D520005DB65D...
.OUTPUTS
    System.Boolean
.EXAMPLE
    Test-SpoIsDocumentSetContentType -ContentTypeId $item.FieldValues['ContentTypeId']
#>
function Test-SpoIsDocumentSetContentType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        $ContentTypeId
    )

    if ($null -eq $ContentTypeId) {
        return $false
    }

    $id = [string]$ContentTypeId

    if ([string]::IsNullOrWhiteSpace($id)) {
        return $false
    }

    return $id.StartsWith('0x0120D520', [System.StringComparison]::OrdinalIgnoreCase)
}

<#
.SYNOPSIS
    Internal: strips one level of derivation off a content type ID.
.DESCRIPTION
    A derived content type's ID is its parent's ID, then '00', then a
    32-character GUID. Adding a site content type to a list creates exactly
    such a derivation, which is why an item in a library carries an ID the
    Document Set template cannot be looked up by -- the template lives on the
    site content type.

    Note that the shape does not say *which* kind of derivation it is: a custom
    site Document Set is derived from the built-in one in the same way a list
    copy is derived from it. So this answers "what was this derived from",
    not "what is the site content type", and callers try the full ID first and
    fall back to this only if that resolves nothing.

    Returns the input unchanged when it carries no derivation suffix.
.PARAMETER ContentTypeId
    A list or site content type ID.
.OUTPUTS
    System.String
.EXAMPLE
    Get-SpoParentContentTypeId -ContentTypeId '0x0120D5200012...00A1B2...'
#>
function Get-SpoParentContentTypeId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentTypeId
    )

    if ($ContentTypeId -match '^(?<parent>0x.+?)00[0-9A-Fa-f]{32}$') {
        return $Matches['parent']
    }

    return $ContentTypeId
}

<#
.SYNOPSIS
    Internal: resolves a Document Set content type to its template, and above
    all to its shared columns.
.DESCRIPTION
    Shared columns are the whole mechanism behind "the documents inside a
    Document Set carry the Document Set's metadata": SharePoint copies a shared
    column's value down when a document is added and when the Document Set's
    properties are saved. A column that is on the Document Set content type but
    is *not* registered as shared is never copied anywhere, which is the single
    most common reason people find the metadata out of sync.

    The template lives on the *site* content type. Items in a library carry the
    list copy's ID, so lookup is attempted by list ID first, then by the parent
    site content type ID, then by name -- the first that resolves wins.

    Results are cached per connection: a library with 400 Document Sets would
    otherwise repeat the same handful of lookups 400 times.
.PARAMETER ContentTypeId
    Content type ID from the Document Set item.
.PARAMETER ContentTypeName
    Content type name, used as the last lookup attempt.
.OUTPUTS
    PSCustomObject with ContentTypeId, ContentTypeName, Resolved, SharedField,
    WelcomePageField, AllowedContentType, and ContentTypeField (every column on
    the content type, shared or not -- the two lists together are what tells
    you a column was added but never registered as shared).
.EXAMPLE
    $template = Resolve-SpoDocumentSetTemplate -ContentTypeId $id -ContentTypeName 'Projekt'
#>
function Resolve-SpoDocumentSetTemplate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentTypeId,

        [Parameter(Position = 1)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ContentTypeName
    )

    # Keyed by site as well as content type: the same content type ID exists on
    # every site that uses the content type hub, with different list copies.
    $cacheKey = '{0}|{1}' -f $script:O365State.SiteUrl, $ContentTypeId

    if ($script:O365DocumentSetTemplateCache.ContainsKey($cacheKey)) {
        return $script:O365DocumentSetTemplateCache[$cacheKey]
    }

    $candidates = @($ContentTypeId)

    # The parent is only worth trying when it is a custom Document Set content
    # type. Every custom one is derived from the built-in Document Set
    # (0x0120D520), so stripping a level off a *site* content type lands on
    # that built-in -- whose template resolves happily and reports no shared
    # columns at all, which would be a confidently wrong answer.
    $parentId = Get-SpoParentContentTypeId -ContentTypeId $ContentTypeId
    if ($parentId -ne $ContentTypeId -and $parentId.Length -gt '0x0120D520'.Length) {
        $candidates += $parentId
    }

    if ($ContentTypeName) {
        $candidates += $ContentTypeName
    }
    $candidates = @($candidates | Select-Object -Unique)

    $template = $null
    foreach ($candidate in $candidates) {
        $template = Get-PnPDocumentSetTemplate -Identity $candidate -ErrorAction SilentlyContinue
        if ($template) {
            break
        }
    }

    $contentType = $null
    foreach ($candidate in $candidates) {
        $contentType = Get-PnPContentType -Identity $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($contentType) {
            break
        }
    }

    $contentTypeFields = @()
    if ($contentType) {
        $contentTypeFields = try {
            @(Get-PnPProperty -ClientObject $contentType -Property Fields -ErrorAction Stop |
                    ForEach-Object {
                        [pscustomobject]@{
                            InternalName = $_.InternalName
                            DisplayName  = $_.Title
                            TypeAsString = $_.TypeAsString
                            Hidden       = $_.Hidden
                            ReadOnly     = $_.ReadOnlyField
                            Required     = $_.Required
                        }
                    })
        }
        catch {
            Write-O365Log "Could not read columns of content type '$ContentTypeId': $($_.Exception.Message)" 'Warning'
            @()
        }
    }

    $sharedFields  = @()
    $welcomeFields = @()
    $allowedTypes  = @()
    $resolved      = $false

    if ($template) {
        $resolved = $true

        foreach ($property in 'SharedFields', 'WelcomePageFields', 'AllowedContentTypes') {
            $values = try {
                @(Get-PnPProperty -ClientObject $template -Property $property -ErrorAction Stop)
            }
            catch {
                Write-O365Log "Could not read $property of Document Set template '$ContentTypeId': $($_.Exception.Message)" 'Warning'
                @()
            }

            switch ($property) {
                'SharedFields' { $sharedFields = @($values | ForEach-Object { $_.InternalName }) }
                'WelcomePageFields' { $welcomeFields = @($values | ForEach-Object { $_.InternalName }) }
                'AllowedContentTypes' { $allowedTypes = @($values | ForEach-Object { $_.StringValue }) }
            }
        }
    }
    else {
        Write-O365Log "No Document Set template resolved for content type '$ContentTypeId'. Tried: $($candidates -join ', ')." 'Warning'
    }

    $result = [pscustomobject]@{
        PSTypeName         = 'Office365Tools.DocumentSetTemplate'
        ContentTypeId      = $ContentTypeId
        ContentTypeName    = if ($ContentTypeName) { $ContentTypeName } elseif ($contentType) { $contentType.Name } else { '' }
        Resolved           = $resolved
        SharedField        = $sharedFields
        WelcomePageField   = $welcomeFields
        AllowedContentType = $allowedTypes
        ContentTypeField   = $contentTypeFields
    }

    $script:O365DocumentSetTemplateCache[$cacheKey] = $result
    return $result
}
