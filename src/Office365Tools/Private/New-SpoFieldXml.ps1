<#
.SYNOPSIS
    Internal: builds the CAML <Field> XML for a new site column.
.DESCRIPTION
    Add-PnPField at web scope accepts only DisplayName, InternalName and Type --
    no group, no required flag, no choices. Anything beyond a bare column has
    to go through Add-PnPFieldFromXml, so this generates that XML.

    Kept separate from New-SpoField so the XML generation, which is fiddly and
    easy to get subtly wrong, can be tested without a tenant.

    Every value is XML-escaped. A choice like 'R&D' or a display name with an
    angle bracket would otherwise produce malformed XML that SharePoint rejects
    with a spectacularly unhelpful error.
.PARAMETER DisplayName
    Column title as shown in the UI.
.PARAMETER InternalName
    Internal name. Must be unique and is permanent.
.PARAMETER Type
    SharePoint field type, e.g. Text, Note, Choice, Number, DateTime, Boolean,
    User, URL, Currency, MultiChoice.
.PARAMETER Group
    Site column group.
.PARAMETER Description
    Column description.
.PARAMETER Required
    Whether a value is mandatory.
.PARAMETER Choice
    Options for Choice and MultiChoice types.
.PARAMETER DefaultValue
    Default value for new items.
.PARAMETER Id
    Field GUID. One is generated if omitted.
.OUTPUTS
    System.String containing the <Field> element.
.EXAMPLE
    New-SpoFieldXml -DisplayName 'Status' -InternalName 'Status' -Type Choice `
        -Group 'Custom Columns' -Choice 'Open', 'Closed'
#>
function New-SpoFieldXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds a string. Nothing outside this process is touched.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InternalName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Type,

        [Parameter()]
        [string]$Group,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [string[]]$Choice,

        [Parameter()]
        [string]$DefaultValue,

        [Parameter()]
        [guid]$Id = [guid]::NewGuid()
    )

    $escape = { param($Value) [System.Security.SecurityElement]::Escape([string]$Value) }

    $attributes = [ordered]@{
        Type        = & $escape $Type
        DisplayName = & $escape $DisplayName
        Name        = & $escape $InternalName
        StaticName  = & $escape $InternalName
        ID          = "{$($Id.ToString().ToUpperInvariant())}"
        Required    = if ($Required) { 'TRUE' } else { 'FALSE' }
    }

    if ($Group) {
        $attributes['Group'] = & $escape $Group
    }
    if ($Description) {
        $attributes['Description'] = & $escape $Description
    }

    # Choice columns render as a dropdown unless told otherwise; MultiChoice
    # ignores Format, so only set it for the single-select case.
    if ($Type -eq 'Choice') {
        $attributes['Format'] = 'Dropdown'
    }

    $attributeText = ($attributes.GetEnumerator() | ForEach-Object { "$($_.Key)=`"$($_.Value)`"" }) -join ' '

    $children = [System.Collections.Generic.List[string]]::new()

    if ($Choice -and $Type -in 'Choice', 'MultiChoice') {
        $options = ($Choice | ForEach-Object { "      <CHOICE>$(& $escape $_)</CHOICE>" }) -join "`n"
        $children.Add("    <CHOICES>`n$options`n    </CHOICES>")
    }

    if ($DefaultValue) {
        $children.Add("    <Default>$(& $escape $DefaultValue)</Default>")
    }

    if ($children.Count -eq 0) {
        return "<Field $attributeText />"
    }

    return "<Field $attributeText>`n$($children -join "`n")`n</Field>"
}
