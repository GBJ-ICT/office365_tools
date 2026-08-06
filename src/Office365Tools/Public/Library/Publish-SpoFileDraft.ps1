<#
.SYNOPSIS
    Publishes draft files as major versions, so readers can see them.
.DESCRIPTION
    Takes the output of Get-SpoFileDraft and publishes the drafts it marked
    Publishable, turning x.1 into (x+1).0. Anything marked otherwise is skipped
    with its reason, whatever is piped in -- this command will not publish a
    draft that the read command refused.

    Every file is re-read and re-checked immediately before it is published,
    because a scan is a snapshot: somebody may have started editing between the
    scan and now. If the version, the editor, or the checkout state has moved
    since the scan, the file is skipped rather than published on stale
    information. That check is the reason this publishes one file at a time.

    Publishing is not destructive. The previous major version and the draft both
    remain in version history, so a mistake is undone by restoring a version --
    unlike a metadata overwrite, which has nothing to restore from.
.PARAMETER InputObject
    Draft objects from Get-SpoFileDraft.
.PARAMETER Comment
    Version comment recorded against the published version.
.PARAMETER PassThru
    Emit a result object per file.
.OUTPUTS
    None by default. With -PassThru, one result object per file.
.EXAMPLE
    Get-SpoFileDraft -Library Projekte -ChangeRecord out/*/before.csv -PublishableOnly |
        Publish-SpoFileDraft -WhatIf
    Shows exactly which drafts would be published.
.EXAMPLE
    Get-SpoFileDraft -Library Projekte -Folder '/sites/CDS/Projects/Kommunikationskonzept' `
        -ChangeRecord out/*/before.csv -PublishableOnly |
        Publish-SpoFileDraft -Comment 'Metadata sync' -PassThru
.LINK
    Get-SpoFileDraft
#>
function Publish-SpoFileDraft {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'PassThru',
        Justification = 'Used inside the $emit script block, which the analyzer does not trace into.')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [psobject]$InputObject,

        [Parameter()]
        [string]$Comment = 'Published by Office365Tools: metadata-only change',

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Assert-SpoConnection | Out-Null
        $published = 0
        $skipped   = 0
        $failed    = 0

        $emit = {
            param($Draft, $Status, $NewVersion, $Failure)

            if (-not $PassThru) { return }

            [pscustomobject]@{
                PSTypeName        = 'Office365Tools.PublishResult'
                List              = $Draft.List
                Name              = $Draft.Name
                ServerRelativeUrl = $Draft.ServerRelativeUrl
                Version           = $Draft.Version
                NewVersion        = $NewVersion
                Status            = $Status
                Reason            = $Draft.Reason
                Error             = $Failure
            }
        }
    }

    process {
        foreach ($required in 'ServerRelativeUrl', 'List', 'ItemId', 'Version', 'Publishable') {
            if ($required -notin $InputObject.PSObject.Properties.Name) {
                Write-Error "Input object is missing the '$required' property. Pipe output from Get-SpoFileDraft."
                return
            }
        }

        $url = $InputObject.ServerRelativeUrl

        if (-not $InputObject.Publishable) {
            $skipped++
            Write-O365Log "Skipping '$url': $($InputObject.Reason)." 'Info'
            & $emit $InputObject 'Skipped' '' $null
            return
        }

        # The scan is a snapshot. Confirm nothing has moved since.
        try {
            $current = Get-PnPListItem -List $InputObject.List -Id $InputObject.ItemId -ErrorAction Stop
        }
        catch {
            $failed++
            Write-Error -Message "Could not re-read '$url': $($_.Exception.Message)" -TargetObject $url
            & $emit $InputObject 'Failed' '' $_.Exception.Message
            return
        }

        $nowVersion  = [string]$current.FieldValues['_UIVersionString']
        $nowCheckout = $current.FieldValues['CheckoutUser']

        if ($nowVersion -ne $InputObject.Version) {
            $skipped++
            Write-O365Log "Skipping '$url': version changed from $($InputObject.Version) to $nowVersion since the scan; somebody has edited it." 'Warning'
            & $emit $InputObject 'SkippedChangedSinceScan' $nowVersion $null
            return
        }

        if ($null -ne $nowCheckout) {
            $skipped++
            Write-O365Log "Skipping '$url': checked out to $($nowCheckout.LookupValue) since the scan." 'Warning'
            & $emit $InputObject 'SkippedCheckedOut' $nowVersion $null
            return
        }

        if (-not $PSCmdlet.ShouldProcess($url, "Publish draft $nowVersion as a major version")) {
            return
        }

        try {
            $file = Get-PnPFile -Url $url -AsFileObject -ErrorAction Stop
            $file.Publish($Comment)
            Invoke-PnPQuery -ErrorAction Stop

            $published++
            Write-O365Log "Published '$url' (was $nowVersion)." 'Success'
            & $emit $InputObject 'Published' '' $null
        }
        catch {
            $failed++
            Write-O365Log "Failed to publish '$url': $($_.Exception.Message)" 'Error'
            Write-Error -Message "Failed to publish '$url': $($_.Exception.Message)" -TargetObject $url
            & $emit $InputObject 'Failed' '' $_.Exception.Message
        }
    }

    end {
        Write-O365Log "Publish complete: $published published, $skipped skipped, $failed failed." 'Info'
    }
}
