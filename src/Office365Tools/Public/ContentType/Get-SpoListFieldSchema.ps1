<#
.SYNOPSIS
    Reads a list's columns as portable definitions that Add-SpoListField can
    recreate elsewhere.
.DESCRIPTION
    The read half of copying a list's schema. It returns one object per column,
    carrying both a human-readable summary (type, choices, default, required)
    and a rewritten SchemaXml with the source list's provenance stripped out --
    see ConvertTo-SpoPortableFieldXml for what that means and why.

    By default only *custom* columns come back: the ones somebody added to this
    list. The base type's columns -- Title, Created, Modified, Author and the
    rest -- exist on every list already, so copying them is at best a no-op.
    Pass -IncludeBuiltIn if you want the full picture for an audit.

    Not every column type survives a copy, and the ones that do not are marked
    rather than silently mangled:

      Lookup      Points at a list by GUID. That GUID means nothing on another
                  site, and SharePoint accepts the field anyway -- producing a
                  column that renders empty forever.
      Taxonomy    Needs a term set binding plus a hidden note field created
                  alongside it. Copying the visible half leaves it inert.
      Calculated  Portable only if every column its formula references is
                  already on the target, which this command cannot know.

    Each result carries Portable and PortabilityNote so the caller can decide.
    Add-SpoListField refuses the unportable ones unless told otherwise.
.PARAMETER Library
    Title, URL name, or GUID of the list to read.
.PARAMETER Name
    Internal names to limit the read to. All columns if omitted.
.PARAMETER IncludeBuiltIn
    Include columns inherited from the list's base type.
.PARAMETER IncludeHidden
    Include hidden columns. These are usually SharePoint's own bookkeeping and
    copying them is rarely what anyone means.
.PARAMETER IncludeReadOnly
    Include read-only columns. They cannot be written to, so a copy of one is
    decorative.
.PARAMETER DropCustomFormatter
    Strip the JSON column formatter from the emitted SchemaXml.
.OUTPUTS
    Office365Tools.ListFieldSchema objects.
.EXAMPLE
    Get-SpoListFieldSchema -Library 'Aufgaben und Dienste'
    Lists the custom columns and how each one is configured.

.EXAMPLE
    Get-SpoListFieldSchema -Library Tasks | Where-Object Portable |
        Add-SpoListField -Library TestTasks -WhatIf
    The whole copy, previewed. Read and write are separate commands, so this is
    the dry run.

.EXAMPLE
    Get-SpoListFieldSchema -Library Tasks -Name Status, Datum |
        Export-Clixml out/schema.xml
    Keeps a schema snapshot for a target site you will connect to next, since
    only one connection is live at a time.
.LINK
    Add-SpoListField
.LINK
    Get-SpoField
#>
function Get-SpoListFieldSchema {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 1)]
        [string[]]$Name,

        [Parameter()]
        [switch]$IncludeBuiltIn,

        [Parameter()]
        [switch]$IncludeHidden,

        [Parameter()]
        [switch]$IncludeReadOnly,

        [Parameter()]
        [switch]$DropCustomFormatter
    )

    begin {
        Assert-SpoConnection | Out-Null

        # Copying one of these produces a column that looks right and does
        # nothing. The note is what the caller sees instead of a broken column.
        $unportable = @{
            'Lookup'                 = 'Lookup targets a list by GUID, which does not resolve on another site.'
            'LookupMulti'            = 'Lookup targets a list by GUID, which does not resolve on another site.'
            'TaxonomyFieldType'      = 'Managed metadata needs a term set binding and a hidden note field created with it.'
            'TaxonomyFieldTypeMulti' = 'Managed metadata needs a term set binding and a hidden note field created with it.'
            'Calculated'             = 'Formula references other columns by name; they must already exist on the target.'
        }
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        $fields = @(Get-PnPField -List $list -ErrorAction Stop)

        foreach ($field in $fields) {
            if ($Name -and $field.InternalName -notin $Name) { continue }
            if (-not $IncludeBuiltIn -and $field.FromBaseType) { continue }
            if (-not $IncludeHidden -and $field.Hidden) { continue }
            if (-not $IncludeReadOnly -and $field.ReadOnlyField) { continue }

            # Choices are read out of the XML rather than off the object: only
            # the choice field subclasses expose a Choices property, and the
            # module runs under Set-StrictMode, where reaching for one that is
            # not there is an error rather than an empty value. XPath is used
            # for the same reason -- dotted navigation into a missing CHOICES
            # element would throw on every column that is not a choice.
            $choice = @([xml]$field.SchemaXml |
                    ForEach-Object { $_.SelectNodes('/Field/CHOICES/CHOICE') } |
                    ForEach-Object { $_.InnerText })

            $note = $unportable[$field.TypeAsString]

            $portableXml = ConvertTo-SpoPortableFieldXml `
                -SchemaXml $field.SchemaXml `
                -DisplayName $field.Title `
                -DropCustomFormatter:$DropCustomFormatter

            [pscustomobject]@{
                PSTypeName      = 'Office365Tools.ListFieldSchema'
                InternalName    = $field.InternalName
                DisplayName     = $field.Title
                Type            = $field.TypeAsString
                Required        = [bool]$field.Required
                Choice          = $choice
                DefaultValue    = $field.DefaultValue
                Description     = $field.Description
                Group           = $field.Group
                Hidden          = [bool]$field.Hidden
                ReadOnly        = [bool]$field.ReadOnlyField
                BuiltIn         = [bool]$field.FromBaseType
                Portable        = (-not $note)
                PortabilityNote = $note
                SourceList      = $list.Title
                SourceSiteUrl   = $script:O365State.SiteUrl
                SchemaXml       = $portableXml
            }
        }
    }
}
