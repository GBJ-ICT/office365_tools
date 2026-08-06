<#
.SYNOPSIS
    Lists draft (minor version) files and whether each may safely be published.
.DESCRIPTION
    A library with minor versions enabled shows readers the last *published*
    version. Anything saved since then is a draft that only the author and
    people with edit rights can see. So a metadata correction applied in bulk
    leaves every touched document as a draft, and readers carry on seeing the
    old version without the metadata.

    This finds those drafts and classifies each one. It only reads; pipe it to
    Publish-SpoFileDraft to act.

    A draft is reported Publishable only when it is provably nothing but our own
    change:

      - it appears in -ChangeRecord, the record of what we actually wrote
      - its version is x.1, i.e. exactly one save since the last published
        version -- with minor versions on, anybody else's save would have made
        it x.2
      - that save was made by -Author inside -Since/-Until
      - it is not checked out

    Everything else is reported with the reason it was refused, which is the
    part worth reading: MultipleMinorVersions means somebody has unfinished work
    underneath, and NeverPublished means the file has never had a published
    version at all, so publishing would expose it for the first time rather than
    restore it.
.PARAMETER Library
    Title, URL name, or GUID of the document library.
.PARAMETER Folder
    Restrict to a server-relative folder -- a single Document Set, say.
.PARAMETER ChangeRecord
    Path(s) to CSV files with a ServerRelativeUrl column, listing what was
    changed. The before.csv written by Repair-DocumentSetSync.ps1 is exactly
    this. Files absent from it are refused.
.PARAMETER Author
    Only drafts whose current version was made by this account may be published.
.PARAMETER Since
    Earliest acceptable timestamp (UTC) for the draft version.
.PARAMETER Until
    Latest acceptable timestamp (UTC) for the draft version.
.PARAMETER IgnoreChangeRecord
    Judge drafts on the version rule alone, without a change record. Weaker:
    the record is what turns inference into a whitelist.
.PARAMETER PublishableOnly
    Emit only the drafts that may be published.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.FileDraft'.
.EXAMPLE
    Get-SpoFileDraft -Library Projekte -ChangeRecord out/documentset-repair-*/before.csv |
        Group-Object Reason
    Shows how many drafts fall into each category before changing anything.
.EXAMPLE
    Get-SpoFileDraft -Library Projekte -Folder '/sites/CDS/Projects/Kommunikationskonzept' `
        -ChangeRecord out/documentset-repair-*/before.csv -PublishableOnly |
        Publish-SpoFileDraft -WhatIf
.LINK
    Publish-SpoFileDraft
#>
function Get-SpoFileDraft {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [string]$Folder,

        [Parameter()]
        [string[]]$ChangeRecord,

        [Parameter()]
        [string]$Author,

        [Parameter()]
        [datetime]$Since,

        [Parameter()]
        [datetime]$Until,

        [Parameter()]
        [switch]$IgnoreChangeRecord,

        [Parameter()]
        [switch]$PublishableOnly,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null

        $record = @{}
        if ($ChangeRecord) {
            foreach ($path in (Resolve-Path -Path $ChangeRecord -ErrorAction SilentlyContinue)) {
                foreach ($row in (Import-Csv -LiteralPath $path.Path)) {
                    if ($row.PSObject.Properties.Name -contains 'ServerRelativeUrl' -and $row.ServerRelativeUrl) {
                        $record[$row.ServerRelativeUrl] = $true
                    }
                }
            }
            Write-O365Log "Change record covers $($record.Count) item(s)." 'Info'
        }

        if (-not $IgnoreChangeRecord -and $record.Count -eq 0) {
            throw [System.InvalidOperationException]::new(
                'No change record was loaded. Pass -ChangeRecord with the before.csv written by the repair, ' +
                'or -IgnoreChangeRecord to judge drafts on the version rule alone.'
            )
        }
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        # Not $since/$until: PowerShell variable names are case-insensitive, so
        # those would be the typed parameters themselves, and assigning $null to
        # a [datetime] throws.
        $windowStart = if ($PSBoundParameters.ContainsKey('Since')) { $Since } else { $null }
        $windowEnd   = if ($PSBoundParameters.ContainsKey('Until')) { $Until } else { $null }

        foreach ($item in (Get-PnPListItem -List $list -PageSize $PageSize)) {
            if ($item.FileSystemObjectType -eq 'Folder') {
                continue
            }

            $url = [string]$item.FieldValues['FileRef']
            if (-not $url) {
                continue
            }

            if ($Folder -and -not $url.StartsWith($Folder.TrimEnd('/') + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $version = [string]$item.FieldValues['_UIVersionString']

            # Published files are the goal state, not a finding.
            if ($version -match '^[1-9][0-9]*\.0$') {
                continue
            }

            $checkoutUser = $item.FieldValues['CheckoutUser']
            $editor       = if ($item.FieldValues['Editor']) { [string]$item.FieldValues['Editor'].Email } else { '' }
            $modified     = $item.FieldValues['Modified']

            $verdict = Test-SpoDraftPublishable -VersionLabel $version `
                -LastEditor $editor -Modified $modified `
                -CheckedOut ($null -ne $checkoutUser) `
                -Author $Author -Since $windowStart -Until $windowEnd `
                -InChangeRecord $record.ContainsKey($url) `
                -RequireChangeRecord (-not $IgnoreChangeRecord)

            if ($PublishableOnly -and -not $verdict.Publishable) {
                continue
            }

            [pscustomobject]@{
                PSTypeName        = 'Office365Tools.FileDraft'
                List              = $list.Title
                Name              = [string]$item.FieldValues['FileLeafRef']
                ServerRelativeUrl = $url
                ItemId            = $item.Id
                Version           = $version
                Publishable       = $verdict.Publishable
                Reason            = $verdict.Reason
                LastEditor        = $editor
                Modified          = $modified
                CheckedOutTo      = if ($checkoutUser) { [string]$checkoutUser.LookupValue } else { '' }
                InChangeRecord    = $record.ContainsKey($url)
                SiteUrl           = $script:O365State.SiteUrl
            }
        }
    }
}
