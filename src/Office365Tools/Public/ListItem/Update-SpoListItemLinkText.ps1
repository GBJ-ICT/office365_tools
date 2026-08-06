<#
.SYNOPSIS
    Sets a hyperlink column's display text from another column on the same item.
.DESCRIPTION
    A hyperlink column in SharePoint is two values, a URL and the text shown in
    its place. Where that text is supposed to mirror another column, filling it
    in is a second pass over items that already exist -- and when the other
    column is *calculated*, it can only be a second pass: a calculated column
    has no value until the item has been written, so it cannot contribute to
    the write that creates it.

    That is the whole reason this command exists. Creating a register of
    Document Sets is therefore two steps, not one:

        Get-SpoDocumentSetRegisterEntry -Library Projekte -RegisterList Index -ReferenceField Link |
            Add-SpoListItem -Library Index
        Update-SpoListItemLinkText -Library Index -Field Link -TextField Name_x0020_ID

    Only the text changes; the URL is read from the item and written back
    unaltered. Items whose text already matches are left alone entirely -- no
    write, no new version -- so running it again after adding more rows costs
    one read and touches only what is new. Items with no URL, or with nothing
    in the text column, are reported and skipped rather than being given an
    empty link.
.PARAMETER Library
    Title, URL name, or GUID of the list.
.PARAMETER Field
    Internal name of the hyperlink column whose text is to be set.
.PARAMETER TextField
    Internal name of the column to take the text from. May be calculated.
.PARAMETER Id
    Restrict to these list item IDs. Omit to consider every item in the list.
.PARAMETER SystemUpdate
    Write without creating a version or changing Modified/Editor. Appropriate
    here: setting the label on a link is bookkeeping, not a content change --
    but it does remove version history as your undo.
.PARAMETER PassThru
    Emit a result object per item describing what happened.
.OUTPUTS
    None by default. With -PassThru, one 'Office365Tools.RepairResult' per item
    considered, with Status Updated, AlreadyCorrect, Skipped, or Failed.
.EXAMPLE
    Update-SpoListItemLinkText -Library 'CDS Mappen' -Field Reference -TextField Name_x0020_ID -WhatIf

    Shows which links would be relabelled, and what to, without writing.
.EXAMPLE
    Update-SpoListItemLinkText -Library 'CDS Mappen' -Field Reference -TextField Name_x0020_ID -PassThru |
        Where-Object Status -eq 'Skipped'

    Runs it, then looks at the items it could not label -- usually the ones
    whose source column is empty.
.EXAMPLE
    $created = Get-SpoDocumentSetRegisterEntry -Library Projekte -RegisterList Index -ReferenceField Link |
        Add-SpoListItem -Library Index -PassThru
    Update-SpoListItemLinkText -Library Index -Field Link -TextField Name_x0020_ID -Id $created.Id

    Labels only the rows this run created, leaving existing ones untouched.
.LINK
    Get-SpoDocumentSetRegisterEntry
.LINK
    Update-SpoListItem
#>
function Update-SpoListItemLinkText {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'PassThru',
        Justification = 'Read inside the $emit script block, which the analyzer does not trace into.')]
    [OutputType([pscustomobject])]
    param(
        # Not bound from the pipeline: the items come down it, and a Library
        # property arriving mid-stream would silently change which list is
        # being written to.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Field,

        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$TextField,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int[]]$Id,

        [Parameter()]
        [switch]$SystemUpdate,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null

        $updated = 0
        $correct = 0
        $skipped = 0
        $failed  = 0

        $wanted = [System.Collections.Generic.List[int]]::new()
    }

    process {
        # The null check is load-bearing. With -Id unbound, $Id is $null and
        # @($null) is a one-element array holding it, which List[int].Add
        # happily coerces to 0 -- leaving a filter that matches no item at all
        # and silently doing nothing where the caller asked for every item.
        if ($null -eq $Id) {
            return
        }

        foreach ($value in $Id) {
            $wanted.Add($value)
        }
    }

    end {
        $list = Resolve-SpoList -Identity $Library

        $fields = @(Get-PnPField -List $list)

        $target = $fields | Where-Object { $_.InternalName -eq $Field }
        if (-not $target) {
            throw [System.ArgumentException]::new(
                "Column '$Field' was not found on list '$($list.Title)'. " +
                "Note this must be the internal name, not the display title. " +
                "Run: Get-PnPField -List '$($list.Title)' | Select-Object InternalName, Title"
            )
        }

        if ($target.TypeAsString -notlike 'URL*') {
            throw [System.ArgumentException]::new(
                "Column '$Field' on list '$($list.Title)' is of type '$($target.TypeAsString)', not URL. " +
                "Only a hyperlink column has display text to set; use Update-SpoListItem for anything else."
            )
        }

        if ($TextField -notin @($fields | ForEach-Object { $_.InternalName })) {
            throw [System.ArgumentException]::new(
                "Column '$TextField' was not found on list '$($list.Title)'. " +
                "Run: Get-PnPField -List '$($list.Title)' | Select-Object InternalName, Title"
            )
        }

        $items = @(Get-PnPListItem -List $list -PageSize 500 -Fields @('ID', $Field, $TextField))

        if ($wanted.Count -gt 0) {
            $set   = [System.Collections.Generic.HashSet[int]]::new([int[]]$wanted)
            $items = @($items | Where-Object { $set.Contains($_.Id) })
        }

        Write-O365Log "Considering $($items.Count) item(s) in '$($list.Title)' for link text from '$TextField'." 'Info'

        foreach ($item in $items) {
            $link = $item.FieldValues[$Field]
            $url  = if ($null -ne $link) { [string]$link.Url } else { '' }
            $text = ConvertTo-SpoFieldValueText -Value $item.FieldValues[$TextField]

            $emit = {
                param($Status, $ErrorText)

                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName = 'Office365Tools.RepairResult'
                        List       = $list.Title
                        ItemId     = $item.Id
                        Action     = 'SetLinkText'
                        Status     = $Status
                        Field      = $Field
                        Url        = $url
                        OldText    = if ($null -ne $link) { [string]$link.Description } else { '' }
                        NewText    = $text
                        Error      = $ErrorText
                    }
                }
            }

            if ([string]::IsNullOrWhiteSpace($url)) {
                $skipped++
                Write-O365Log "Item $($item.Id) has no URL in '$Field'; there is no link to label." 'Info'
                & $emit 'Skipped' $null
                continue
            }

            if ([string]::IsNullOrWhiteSpace($text)) {
                $skipped++
                Write-O365Log "Item $($item.Id) has no value in '$TextField'; leaving the link text alone rather than blanking it." 'Warning'
                & $emit 'Skipped' $null
                continue
            }

            if ([string]$link.Description -ceq $text) {
                $correct++
                & $emit 'AlreadyCorrect' $null
                continue
            }

            if (-not $PSCmdlet.ShouldProcess("$($list.Title) item $($item.Id)", "Set '$Field' text to '$text'")) {
                continue
            }

            try {
                $parameters = @{
                    List        = $list.Title
                    Identity    = $item.Id
                    Values      = @{ $Field = "$url, $text" }
                    ErrorAction = 'Stop'
                }
                if ($SystemUpdate) {
                    $parameters['UpdateType'] = 'SystemUpdate'
                }

                Set-PnPListItem @parameters | Out-Null

                $updated++
                Write-O365Log "Set '$Field' text on item $($item.Id) to '$text'." 'Success'
                & $emit 'Updated' $null
            }
            catch {
                $failed++
                Write-O365Log "Failed to set '$Field' text on item $($item.Id): $($_.Exception.Message)" 'Error'
                Write-Error -Message "Failed to set '$Field' text on item $($item.Id) in '$($list.Title)': $($_.Exception.Message)" -TargetObject $item.Id
                & $emit 'Failed' $_.Exception.Message
            }
        }

        Write-O365Log "Link text pass complete: $updated updated, $correct already correct, $skipped skipped, $failed failed." 'Info'
    }
}
