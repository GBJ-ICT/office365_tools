<#
.SYNOPSIS
    Creates a site column.
.DESCRIPTION
    Creates a reusable column at site level, which you then attach to content
    types with Add-SpoFieldToContentType.

    Two things about internal names are worth knowing before you create one:

      They are permanent. Renaming a column later changes only the display
      title; the internal name stays whatever it was created as. So
      'Priorität' created through the German UI is internally 'Priorit_x00e4_t'
      forever.

      They must be unique across the site. This command checks first and fails
      with a clear message rather than letting the server produce a duplicate.

    If you omit -InternalName, one is derived from the display name by removing
    everything that is not alphanumeric -- which keeps it readable and ASCII.
.PARAMETER DisplayName
    Column title as shown in the UI.
.PARAMETER InternalName
    Internal name. Derived from -DisplayName if omitted.
.PARAMETER Type
    Field type. Text and Note (multi-line) cover most cases; Choice needs
    -Choice.
.PARAMETER Group
    Site column group. Keeping custom columns in their own group makes them
    findable in the column picker.
.PARAMETER Description
    Description shown under the column on forms.
.PARAMETER Required
    Make a value mandatory. Note SharePoint enforces this on forms only -- the
    API and imports can still skip it, which Test-SpoLibraryHealth reports as
    Item.RequiredFieldEmpty.
.PARAMETER Choice
    Options for a Choice or MultiChoice column.
.PARAMETER DefaultValue
    Default value for new items.
.PARAMETER PassThru
    Emit the created column.
.OUTPUTS
    None by default. With -PassThru, the new column.
.EXAMPLE
    New-SpoField -DisplayName 'Contract Value' -Type Currency -Group 'Contract Columns'

.EXAMPLE
    New-SpoField -DisplayName 'Status' -Type Choice -Group 'Contract Columns' `
        -Choice 'Draft', 'Signed', 'Expired' -DefaultValue 'Draft'

.EXAMPLE
    New-SpoField -DisplayName 'Counterparty' -Type Text -Group 'Contract Columns' -WhatIf
    Shows the generated XML without creating anything.
.LINK
    Get-SpoField
.LINK
    Add-SpoFieldToContentType
#>
function New-SpoField {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(Position = 1)]
        [ValidateSet('Text', 'Note', 'Number', 'Currency', 'DateTime', 'Boolean',
            'Choice', 'MultiChoice', 'User', 'UserMulti', 'URL', 'Integer')]
        [string]$Type = 'Text',

        [Parameter()]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
        [string]$InternalName,

        [Parameter()]
        [string]$Group = 'Custom Columns',

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [string[]]$Choice,

        [Parameter()]
        [string]$DefaultValue,

        [Parameter()]
        [switch]$PassThru
    )

    Assert-SpoConnection | Out-Null

    if (-not $InternalName) {
        $InternalName = ($DisplayName -replace '[^A-Za-z0-9]', '')

        if (-not $InternalName -or $InternalName -notmatch '^[A-Za-z]') {
            throw [System.ArgumentException]::new(
                "Could not derive a valid internal name from '$DisplayName'. " +
                'Internal names must start with a letter and contain only letters, digits and underscores. ' +
                'Supply -InternalName explicitly.'
            )
        }
    }

    if ($Type -in 'Choice', 'MultiChoice' -and -not $Choice) {
        throw [System.ArgumentException]::new(
            "A $Type column needs its options. Supply -Choice, for example: -Choice 'Open', 'Closed'"
        )
    }

    $existing = Get-PnPField -Identity $InternalName -ErrorAction SilentlyContinue
    if ($existing) {
        throw [System.InvalidOperationException]::new(
            "A site column with internal name '$InternalName' already exists " +
            "(display name '$($existing.Title)', group '$($existing.Group)'). " +
            'Internal names are permanent and must be unique -- choose a different -InternalName, ' +
            'or reuse the existing column with Add-SpoFieldToContentType.'
        )
    }

    $xmlParams = @{
        DisplayName  = $DisplayName
        InternalName = $InternalName
        Type         = $Type
        Group        = $Group
        Required     = $Required
    }
    if ($Description) { $xmlParams['Description'] = $Description }
    if ($Choice) { $xmlParams['Choice'] = $Choice }
    if ($DefaultValue) { $xmlParams['DefaultValue'] = $DefaultValue }

    $fieldXml = New-SpoFieldXml @xmlParams

    Write-Verbose "Field XML:`n$fieldXml"

    $target = "$DisplayName ($Type, internal name '$InternalName', group '$Group')"

    if (-not $PSCmdlet.ShouldProcess($script:O365State.SiteUrl, "Create site column $target")) {
        # Showing the XML under -WhatIf is genuinely useful: it is the thing
        # that will be sent, and it is where mistakes hide.
        Write-Verbose "Would send:`n$fieldXml"
        return
    }

    try {
        Add-PnPFieldFromXml -FieldXml $fieldXml -ErrorAction Stop | Out-Null
        Write-O365Log "Created site column '$DisplayName' (internal name '$InternalName')." 'Success'
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Failed to create site column '$DisplayName': $($_.Exception.Message)",
            $_.Exception
        )
    }

    if ($PassThru) {
        Get-SpoField -Name $InternalName
    }
}
