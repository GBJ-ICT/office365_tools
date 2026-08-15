<#
.SYNOPSIS
    Creates a column on a single list, scoped to that list rather than the site.
.DESCRIPTION
    The write half of copying a list's schema, and the list-scoped counterpart
    to New-SpoField.

    The distinction matters more than it looks. New-SpoField creates a *site*
    column: one definition, reusable across lists, and permanent -- you cannot
    take it back out of the site once other lists reference it. This command
    creates a *local* column, which exists only on the list named and disappears
    with it. For a test list mirroring a production one, local is what you want:
    nothing leaks into the site's column gallery, and deleting the list cleans
    up after itself.

    Two ways to call it:

      By schema   Pipe Office365Tools.ListFieldSchema objects from
                  Get-SpoListFieldSchema. The column is recreated as configured
                  on the source, formatter and all.

      By value    Pass -DisplayName, -Type and friends for a column you are
                  describing rather than copying.

    A column whose internal name is already on the list is skipped, not
    duplicated and not overwritten -- so the command is safe to re-run after
    adding one more column to the source, which is how a schema copy actually
    gets used.
.PARAMETER Library
    Title, URL name, or GUID of the list to add the column to.
.PARAMETER Schema
    A definition from Get-SpoListFieldSchema. Accepts pipeline input.
.PARAMETER DisplayName
    Column title, when describing a column rather than copying one.
.PARAMETER InternalName
    Internal name. Derived from -DisplayName if omitted. Permanent once created.
.PARAMETER Type
    Field type.
.PARAMETER Choice
    Options for a Choice or MultiChoice column.
.PARAMETER DefaultValue
    Default value for new items.
.PARAMETER Description
    Description shown under the column on forms.
.PARAMETER Required
    Make a value mandatory on forms.
.PARAMETER AllowUnportableType
    Create Lookup, Taxonomy and Calculated columns anyway. They are refused by
    default because each one produces a column that looks correct and does not
    work -- see Get-SpoListFieldSchema for what breaks in each case.
.PARAMETER AddToDefaultView
    Append the new column to the list's default view. A column nobody can see
    is a common and confusing outcome of a scripted schema copy.
.PARAMETER PassThru
    Emit the created column.
.OUTPUTS
    None by default. With -PassThru, the created column.
.EXAMPLE
    Get-SpoListFieldSchema -Library Tasks | Add-SpoListField -Library TestTasks -WhatIf
    Previews the copy. Nothing is written.

.EXAMPLE
    Import-Clixml out/schema.xml | Add-SpoListField -Library TestTasks -AddToDefaultView
    The other half of a cross-site copy: the source was read under a different
    connection, since only one is live at a time.

.EXAMPLE
    Add-SpoListField -Library TestTasks -DisplayName Status -Type Choice `
        -Choice 'Open', 'Done' -DefaultValue 'Open' -Required
.LINK
    Get-SpoListFieldSchema
.LINK
    New-SpoField
#>
function Add-SpoListField {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Schema')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Schema')]
        [ValidateNotNull()]
        [psobject]$Schema,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Explicit')]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(ParameterSetName = 'Explicit')]
        [ValidateSet('Text', 'Note', 'Number', 'Currency', 'DateTime', 'Boolean',
            'Choice', 'MultiChoice', 'User', 'UserMulti', 'URL', 'Integer')]
        [string]$Type = 'Text',

        [Parameter(ParameterSetName = 'Explicit')]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
        [string]$InternalName,

        [Parameter(ParameterSetName = 'Explicit')]
        [string[]]$Choice,

        [Parameter(ParameterSetName = 'Explicit')]
        [string]$DefaultValue,

        [Parameter(ParameterSetName = 'Explicit')]
        [string]$Description,

        [Parameter(ParameterSetName = 'Explicit')]
        [switch]$Required,

        [Parameter()]
        [switch]$AllowUnportableType,

        [Parameter()]
        [switch]$AddToDefaultView,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $existingByList = @{}
        $created        = 0
        $skipped        = 0
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        if (-not $existingByList.ContainsKey($list.Title)) {
            $existingByList[$list.Title] = @(Get-PnPField -List $list |
                    ForEach-Object { $_.InternalName })
        }

        if ($PSCmdlet.ParameterSetName -eq 'Schema') {
            # Not $required: that is the -Required switch parameter, and
            # PowerShell variable names are case-insensitive, so the loop would
            # assign a string to a switch-typed variable and fail on the cast.
            foreach ($needed in 'InternalName', 'SchemaXml') {
                if (-not $Schema.PSObject.Properties[$needed]) {
                    throw [System.ArgumentException]::new(
                        "-Schema is missing '$needed'. It expects output from Get-SpoListFieldSchema; " +
                        "to describe a column instead, use the -DisplayName and -Type parameters."
                    )
                }
            }

            $name      = $Schema.InternalName
            $label     = $Schema.DisplayName
            $fieldXml  = $Schema.SchemaXml
            $fieldType = $Schema.Type

            $noteProperty = $Schema.PSObject.Properties['PortabilityNote']
            if ($noteProperty -and $noteProperty.Value -and -not $AllowUnportableType) {
                Write-O365Log (
                    "Skipping '$name' ($fieldType): $($noteProperty.Value) " +
                    'Pass -AllowUnportableType to create it anyway.') 'Warning'
                $skipped++
                return
            }
        }
        else {
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

            $xmlParams = @{
                DisplayName  = $DisplayName
                InternalName = $InternalName
                Type         = $Type
                Required     = $Required
            }
            if ($Description) { $xmlParams['Description'] = $Description }
            if ($Choice) { $xmlParams['Choice'] = $Choice }
            if ($DefaultValue) { $xmlParams['DefaultValue'] = $DefaultValue }

            $name      = $InternalName
            $label     = $DisplayName
            $fieldXml  = New-SpoFieldXml @xmlParams
            $fieldType = $Type
        }

        if ($name -in $existingByList[$list.Title]) {
            Write-O365Log "Column '$name' is already on '$($list.Title)'; leaving it as it is." 'Info'
            $skipped++
            return
        }

        $target = "$label ($fieldType, internal name '$name')"

        if (-not $PSCmdlet.ShouldProcess("$($list.Title): $target", 'Add list column')) {
            Write-Verbose "Would send:`n$fieldXml"
            return
        }

        try {
            Add-PnPFieldFromXml -List $list.Title -FieldXml $fieldXml -ErrorAction Stop | Out-Null
            $existingByList[$list.Title] += $name
            $created++
            Write-O365Log "Added column '$name' to '$($list.Title)'." 'Success'
        }
        catch {
            Write-Error -Message (
                "Failed to add column '$name' to '$($list.Title)': $($_.Exception.Message)"
            ) -TargetObject $fieldXml
            return
        }

        if ($AddToDefaultView) {
            try {
                $view = Get-PnPView -List $list.Title | Where-Object { $_.DefaultView } | Select-Object -First 1

                if (-not $view) {
                    Write-O365Log "List '$($list.Title)' has no default view; '$name' was not added to one." 'Warning'
                }
                elseif ($name -in @($view.ViewFields)) {
                    Write-Verbose "'$name' is already in view '$($view.Title)'."
                }
                else {
                    Set-PnPView -List $list.Title -Identity $view.Id `
                        -Fields (@($view.ViewFields) + $name) -ErrorAction Stop | Out-Null
                    Write-O365Log "Added '$name' to view '$($view.Title)'." 'Success'
                }
            }
            catch {
                Write-O365Log "Column '$name' was created but adding it to the default view failed: $($_.Exception.Message)" 'Warning'
            }
        }

        if ($PassThru) {
            Get-SpoListFieldSchema -Library $list.Title -Name $name -IncludeReadOnly
        }
    }

    end {
        if ($created -gt 0 -or $skipped -gt 0) {
            Write-O365Log "Added $created column(s); skipped $skipped." 'Info'
        }
    }
}
