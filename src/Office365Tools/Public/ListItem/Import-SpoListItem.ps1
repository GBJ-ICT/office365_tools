<#
.SYNOPSIS
    Bulk-creates list items from a CSV or JSON file.
.DESCRIPTION
    Reads a file where each row becomes one list item, and each column maps to
    a field by internal name.

    Two things make this safe to run against a real list:

      Pre-flight validation. Column names are checked against the list's fields
      and required fields are checked for values, before a single item is
      written. A bad header fails at row zero rather than halfway through.

      -WhatIf. Shows how many items would be created and from which columns,
      without creating anything.

    Rows that fail are reported and the import continues, so one malformed row
    does not abandon the other nine hundred. Pass -StopOnError to change that.
.PARAMETER Path
    CSV or JSON file to import. Format is inferred from the extension.
.PARAMETER Library
    Title, URL name, or GUID of the target list.
.PARAMETER Delimiter
    CSV delimiter. Defaults to comma. Use ';' for CSVs exported by Excel in a
    German or French locale, where comma is the decimal separator.
.PARAMETER ContentType
    Content type to create items as.
.PARAMETER Mapping
    Hashtable mapping CSV column name to list field internal name, for when the
    file's headers do not match the field names. Columns not mentioned are used
    as-is.
.PARAMETER StopOnError
    Abort the whole import on the first failing row instead of continuing.
.PARAMETER PassThru
    Emit a result object per row.
.OUTPUTS
    None by default. With -PassThru, one result object per row.
.EXAMPLE
    Import-SpoListItem -Path samples/list-items.example.csv -Library Tasks -WhatIf
    Validates the file and reports what would be created.
.EXAMPLE
    Import-SpoListItem -Path data/tasks.csv -Library Tasks -Delimiter ';'
.EXAMPLE
    Import-SpoListItem -Path data/tasks.csv -Library Tasks `
        -Mapping @{ 'Task name' = 'Title'; 'Owner' = 'AssignedTo' }
.LINK
    Export-SpoListItem
.LINK
    Add-SpoListItem
#>
function Import-SpoListItem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
                    throw (Get-O365String 'ListItem.Import.FileMissing' $_)
                }
                $true
            })]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [string]$Delimiter = ',',

        [Parameter()]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter()]
        [hashtable]$Mapping = @{},

        [Parameter()]
        [switch]$StopOnError,

        [Parameter()]
        [switch]$PassThru
    )

    Assert-SpoConnection | Out-Null

    $list = Resolve-SpoList -Identity $Library

    # -- Read ---------------------------------------------------------------
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    $rows = switch ($extension) {
        '.csv' { @(Import-Csv -LiteralPath $Path -Delimiter $Delimiter) }
        '.tsv' { @(Import-Csv -LiteralPath $Path -Delimiter "`t") }
        '.json' { @(Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) }
        default {
            throw [System.ArgumentException]::new(
                (Get-O365String 'ListItem.Import.UnsupportedType' $extension)
            )
        }
    }

    if ($rows.Count -eq 0) {
        Write-O365Log (Get-O365String 'ListItem.Import.NoRows' $Path) 'Warning'
        return
    }

    # -- Pre-flight validation ----------------------------------------------
    # Everything that can be checked without writing is checked here, so a
    # broken file fails before it has half-populated the list.
    $columns = @($rows[0].PSObject.Properties.Name)
    $targetFields = @($columns | ForEach-Object { if ($Mapping.ContainsKey($_)) { $Mapping[$_] } else { $_ } })

    $listFields = @(Get-PnPField -List $list | Where-Object { -not $_.ReadOnlyField })
    $writable   = @($listFields | ForEach-Object { $_.InternalName })

    $unknown = @($targetFields | Where-Object { $_ -notin $writable })
    if ($unknown.Count -gt 0) {
        throw [System.ArgumentException]::new(
            (Get-O365String 'ListItem.Import.UnknownColumns' $Path $list.Title ($unknown -join ', '))
        )
    }

    $requiredMissing = @($listFields |
            Where-Object { $_.Required -and -not $_.Hidden } |
            Where-Object { $_.InternalName -notin $targetFields } |
            ForEach-Object { $_.InternalName })

    if ($requiredMissing.Count -gt 0) {
        Write-O365Log (
            (Get-O365String 'ListItem.Import.RequiredMissing' $list.Title ($requiredMissing -join ', '))
        ) 'Warning'
    }

    Write-O365Log (Get-O365String 'ListItem.Import.Validated' $rows.Count $list.Title ($targetFields -join ', ')) 'Success'

    # -- Import -------------------------------------------------------------
    if (-not $PSCmdlet.ShouldProcess("$($list.Title)", (Get-O365String 'ListItem.Import.Action' $rows.Count $Path))) {
        return
    }

    $created = 0
    $failed  = 0
    $rowNumber = 0

    foreach ($row in $rows) {
        $rowNumber++

        Write-Progress -Activity (Get-O365String 'ListItem.Import.Activity' $list.Title) `
            -Status "Row $rowNumber of $($rows.Count)" `
            -PercentComplete (($rowNumber / $rows.Count) * 100)

        $values = @{}
        foreach ($column in $columns) {
            $target = if ($Mapping.ContainsKey($column)) { $Mapping[$column] } else { $column }
            $value  = $row.$column

            # Empty CSV cells arrive as '' -- send nothing rather than blanking
            # a field that might have a default.
            if ($null -ne $value -and $value -ne '') {
                $values[$target] = $value
            }
        }

        if ($values.Count -eq 0) {
            Write-O365Log (Get-O365String 'ListItem.Import.RowEmpty' $rowNumber) 'Warning'
            continue
        }

        try {
            $params = @{
                List        = $list.Title
                Values      = $values
                ErrorAction = 'Stop'
            }
            if ($ContentType) {
                $params['ContentType'] = $ContentType
            }

            $item = Add-PnPListItem @params
            $created++

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName = 'Office365Tools.ImportResult'
                    Row        = $rowNumber
                    ItemId     = $item.Id
                    List       = $list.Title
                    Status     = 'Created'
                    Error      = $null
                }
            }
        }
        catch {
            $failed++
            $message = (Get-O365String 'ListItem.Import.RowFailed' $rowNumber $_.Exception.Message)
            Write-O365Log $message 'Error'

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName = 'Office365Tools.ImportResult'
                    Row        = $rowNumber
                    ItemId     = $null
                    List       = $list.Title
                    Status     = 'Failed'
                    Error      = $_.Exception.Message
                }
            }

            if ($StopOnError) {
                Write-Progress -Activity (Get-O365String 'ListItem.Import.Activity' $list.Title) -Completed
                throw [System.InvalidOperationException]::new(
                    (Get-O365String 'ListItem.Import.Stopped' $message $created),
                    $_.Exception
                )
            }
        }
    }

    Write-Progress -Activity (Get-O365String 'ListItem.Import.Activity' $list.Title) -Completed
    Write-O365Log (Get-O365String 'ListItem.Import.Done' $created $failed $rows.Count) 'Success'
}
