<#
.SYNOPSIS
    Internal: strips a field's <Field> XML of everything that ties it to the
    list it came from, so it can be recreated somewhere else.
.DESCRIPTION
    SharePoint's SchemaXml describes the column *and* its position in one
    particular list: which database column holds it (ColName, RowOrdinal),
    which web defined it (SourceID, WebId, ListId), and which revision of it
    this is (Version). Sent to another list unchanged, those attributes are at
    best ignored and at worst wrong -- SourceID naming a web that does not own
    the field is how a copied column ends up unusable.

    So the provenance attributes come out, the shape of the column stays in:
    choices, defaults, rich-text settings, user-picker mode, and the JSON
    column formatter all survive, because they are what make the copy look like
    the original rather than merely share its name.

    Two attributes get corrected rather than removed:

      ID     Replaced with a fresh GUID. Field IDs are unique per site, and a
             copy within the same site collides otherwise.

      Title  Overwritten from DisplayName. The two drift apart -- renaming a
             column through the UI updates DisplayName and leaves Title at
             whatever it was first called -- and Title is the one nothing reads
             back, so the stale value is invisible until the copy shows it.
.PARAMETER SchemaXml
    The source field's SchemaXml.
.PARAMETER DisplayName
    Display name to force onto the copy. Defaults to the source's DisplayName.
.PARAMETER Id
    Field GUID for the copy. A fresh one is generated if omitted.
.PARAMETER DropCustomFormatter
    Remove the CustomFormatter attribute, leaving the copy with SharePoint's
    default rendering. The formatter is usually worth keeping; it is dropped
    when the copy exists to test the data rather than the presentation.
.OUTPUTS
    System.String containing the rewritten <Field> element.
.EXAMPLE
    ConvertTo-SpoPortableFieldXml -SchemaXml $field.SchemaXml
#>
function ConvertTo-SpoPortableFieldXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds a string. Nothing outside this process is touched.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaXml,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [guid]$Id = [guid]::NewGuid(),

        [Parameter()]
        [switch]$DropCustomFormatter
    )

    try {
        $document = [xml]$SchemaXml
    }
    catch {
        throw [System.ArgumentException]::new(
            "SchemaXml is not well-formed XML: $($_.Exception.Message)",
            $_.Exception
        )
    }

    $field = $document.DocumentElement

    # LocalName, not Name. PowerShell's XML adapter resolves .Name to the
    # *attribute* called Name, which every <Field> has and which holds the
    # column's internal name -- so the obvious spelling compares the wrong
    # string and rejects valid input.
    if ($field.LocalName -ne 'Field') {
        throw [System.ArgumentException]::new(
            "Expected a <Field> element, got <$($field.LocalName)>."
        )
    }

    # Provenance, storage mapping and revision state. All of it belongs to the
    # list the field was read from, none of it to the copy.
    $strip = @(
        'SourceID', 'SourceIDPrefix', 'WebId', 'ListId',
        'ColName', 'ColName2', 'RowOrdinal',
        'Version', 'FromBaseType', 'Sealed', 'ReadOnly'
    )
    foreach ($attribute in $strip) {
        $field.RemoveAttribute($attribute)
    }

    if ($DropCustomFormatter) {
        $field.RemoveAttribute('CustomFormatter')
    }

    $field.SetAttribute('ID', "{$($Id.ToString().ToUpperInvariant())}")

    $effectiveName = if ($DisplayName) {
        $DisplayName
    }
    elseif ($field.HasAttribute('DisplayName')) {
        $field.GetAttribute('DisplayName')
    }
    else {
        $field.GetAttribute('Name')
    }

    $field.SetAttribute('DisplayName', $effectiveName)
    $field.SetAttribute('Title', $effectiveName)

    return $field.OuterXml
}
