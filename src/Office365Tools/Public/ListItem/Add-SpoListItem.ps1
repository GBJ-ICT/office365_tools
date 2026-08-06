<#
.SYNOPSIS
    Adds an item to a SharePoint list.
.DESCRIPTION
    Creates one list item from a hashtable of field values. Field names are the
    *internal* names, not the display titles -- use Get-PnPField or
    Export-SpoListItem to discover them.

    Before writing, the supplied field names are checked against the list's
    actual fields. A typo in a field name would otherwise be accepted silently
    by SharePoint and the value simply dropped, which is a miserable thing to
    debug later.
.PARAMETER Library
    Title, URL name, or GUID of the target list.
.PARAMETER Values
    Hashtable of internal field name to value.
.PARAMETER ContentType
    Name or ID of the content type to create the item as.
.PARAMETER SkipFieldValidation
    Skip the pre-flight field name check. Faster in bulk loops where the caller
    has already validated once.
.PARAMETER PassThru
    Emit the created item.
.OUTPUTS
    None by default. With -PassThru, the created list item.
.EXAMPLE
    Add-SpoListItem -Library Tasks -Values @{ Title = 'Review budget'; Status = 'Open' }
.EXAMPLE
    Add-SpoListItem -Library Tasks -Values @{ Title = 'Review budget' } -WhatIf
.EXAMPLE
    Add-SpoListItem -Library Contracts -ContentType 'Contract' `
        -Values @{ Title = 'ACME 2026'; ContractValue = 15000 } -PassThru
.LINK
    Import-SpoListItem
.LINK
    Update-SpoListItem
#>
function Add-SpoListItem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [hashtable]$Values,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ContentTypeName')]
        [string]$ContentType,

        [Parameter()]
        [switch]$SkipFieldValidation,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $fieldCache = @{}
        $added      = 0
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        if (-not $SkipFieldValidation) {
            if (-not $fieldCache.ContainsKey($list.Title)) {
                $fieldCache[$list.Title] = @(Get-PnPField -List $list |
                        Where-Object { -not $_.ReadOnlyField } |
                        ForEach-Object { $_.InternalName })
            }

            $known   = $fieldCache[$list.Title]
            $unknown = @($Values.Keys | Where-Object { $_ -notin $known })

            if ($unknown.Count -gt 0) {
                throw [System.ArgumentException]::new(
                    "Field(s) not found on list '$($list.Title)': $($unknown -join ', '). " +
                    "Note these must be internal names, not display titles. " +
                    "Run: Get-PnPField -List '$($list.Title)' | Select-Object InternalName, Title"
                )
            }
        }

        $label = if ($Values.ContainsKey('Title')) { $Values['Title'] } else { '(no title)' }

        if (-not $PSCmdlet.ShouldProcess("$($list.Title): $label", 'Add list item')) {
            return
        }

        try {
            $params = @{
                List        = $list.Title
                Values      = $Values
                ErrorAction = 'Stop'
            }
            if ($ContentType) {
                $params['ContentType'] = $ContentType
            }

            $item = Add-PnPListItem @params
            $added++
            Write-O365Log "Added item $($item.Id) to '$($list.Title)'." 'Success'

            if ($PassThru) {
                $item
            }
        }
        catch {
            Write-Error -Message "Failed to add item to '$($list.Title)': $($_.Exception.Message)" -TargetObject $Values
        }
    }

    end {
        if ($added -gt 0) {
            Write-O365Log "Added $added item(s)." 'Info'
        }
    }
}
