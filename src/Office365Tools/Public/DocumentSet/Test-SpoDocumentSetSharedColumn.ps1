<#
.SYNOPSIS
    Checks that a Document Set's columns are actually wired up to sync
    downwards.
.DESCRIPTION
    Get-SpoDocumentSetMismatch tells you the metadata has drifted. This tells
    you why, and the why is nearly always one of these:

      - a column was added to the Document Set content type and never
        registered as a *shared* column, so SharePoint has never pushed it
        anywhere and never will
      - a shared column is not on the library at all, so the push has nowhere
        to land
      - a shared column is missing from a content type the Document Set allows
        inside it, so the value is stored on the document but never appears on
        its form -- users conclude the metadata is missing and re-enter it

    Repairing the drift without fixing this means doing it again next month.
    The configuration fix is one command per column:

        Set-PnPDocumentSetField -DocumentSet 'Projekt' -Field ProjectStatus -SetSharedField

    Registering a column as shared does not backfill existing contents --
    SharePoint pushes on the next save. Use Repair-SpoDocumentSetMetadata for
    what is already there.

    Read-only, and emits standard findings, so it composes with Export-SpoReport
    and can be filtered by RuleId like any other diagnostic.
.PARAMETER Library
    Check the Document Set content types used in this library. Omit to check
    every visible library on the site.
.PARAMETER SkipChildContentType
    Skip the check that each allowed child content type carries the shared
    columns. That check costs a request per content type, which is the slow
    part on a site with many of them.
.PARAMETER PageSize
    Items fetched per request when discovering which Document Sets are in use.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    Test-SpoDocumentSetSharedColumn -Library Projekte
    Reports every column that cannot sync, and why.
.EXAMPLE
    Test-SpoDocumentSetSharedColumn | Export-SpoReport -Path out/documentsets.html
    Checks every library on the site and writes one report.
.EXAMPLE
    Test-SpoDocumentSetSharedColumn -Library Projekte |
        Where-Object RuleId -eq 'DocumentSet.ColumnNotShared' |
        ForEach-Object { $_.Detail.Column }
    Lists the columns to register as shared.
.LINK
    Get-SpoDocumentSetMismatch
.LINK
    Repair-SpoDocumentSetMetadata
.LINK
    Get-SpoDocumentSet
#>
function Test-SpoDocumentSetSharedColumn {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$SkipChildContentType,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null

        # Fields of an allowed child content type, resolved once each.
        $childFieldCache = @{}

        # Base content types never carry anybody's custom columns, and every
        # Document Set on earth allows Document. Reporting them would bury the
        # case worth seeing: a *custom* child content type missing the columns.
        $baseContentTypeIds = @('0x', '0x01', '0x0101', '0x010102', '0x0120', '0x0120D5', '0x0120D520')
    }

    process {
        $lists = if ($Library) {
            @(Resolve-SpoList -Identity $Library)
        }
        else {
            @(Get-PnPList | Where-Object { -not $_.Hidden -and $_.BaseTemplate -eq 101 })
        }

        foreach ($list in $lists) {
            $listFields = @{}
            foreach ($field in (Get-PnPField -List $list -ErrorAction SilentlyContinue)) {
                $listFields[$field.InternalName] = $field
            }

            $map = Get-SpoDocumentSetMap -List $list -PageSize $PageSize

            if (@($map.DocumentSet).Count -eq 0) {
                continue
            }

            # One finding set per content type, not per Document Set: a
            # misconfigured content type used by 200 Document Sets is one
            # problem with one fix, and reporting it 200 times hides everything
            # else.
            $contentTypes = @($map.DocumentSet |
                    Group-Object ContentTypeId |
                    ForEach-Object { $_.Group[0] })

            foreach ($documentSet in $contentTypes) {
                $template = Resolve-SpoDocumentSetTemplate `
                    -ContentTypeId $documentSet.ContentTypeId `
                    -ContentTypeName $documentSet.ContentTypeName

                $typeName  = if ($template.ContentTypeName) { $template.ContentTypeName } else { $documentSet.ContentTypeName }
                $target    = "$($list.Title) / $typeName"
                $instances = @($map.DocumentSet | Where-Object { $_.ContentTypeId -eq $documentSet.ContentTypeId }).Count

                if (-not $template.Resolved) {
                    $detail = @{
                        ContentTypeId = $documentSet.ContentTypeId
                        Instances     = $instances
                    }
                    New-SpoFinding -RuleId 'DocumentSet.TemplateUnreadable' -Severity Error -Scope ContentType `
                        -Target $target -List $list.Title `
                        -Message "Could not read the Document Set template for '$($documentSet.ContentTypeName)', so its shared columns cannot be verified." `
                        -Detail $detail
                    continue
                }

                $shared = @($template.SharedField)

                if ($shared.Count -eq 0) {
                    $detail = @{
                        ContentTypeId = $documentSet.ContentTypeId
                        Instances     = $instances
                    }
                    New-SpoFinding -RuleId 'DocumentSet.NoSharedColumn' -Severity Warning -Scope ContentType `
                        -Target $target -List $list.Title `
                        -Message "Document Set '$typeName' has no shared columns, so none of its metadata reaches the documents inside it." `
                        -Detail $detail
                }

                $candidates = @($template.ContentTypeField | Where-Object { Test-SpoSyncableColumn -Field $_ })

                foreach ($candidate in ($candidates | Where-Object { $_.InternalName -notin $shared })) {
                    $detail = @{
                        Column        = $candidate.InternalName
                        DisplayName   = $candidate.DisplayName
                        ContentTypeId = $documentSet.ContentTypeId
                        Instances     = $instances
                        Remedy        = "Set-PnPDocumentSetField -DocumentSet '$typeName' -Field '$($candidate.InternalName)' -SetSharedField"
                    }
                    New-SpoFinding -RuleId 'DocumentSet.ColumnNotShared' -Severity Warning -Scope Field `
                        -Target "$target / $($candidate.InternalName)" -List $list.Title `
                        -Message "Column '$($candidate.DisplayName)' is on Document Set '$typeName' but is not a shared column, so its value is never copied to the contents." `
                        -Detail $detail
                }

                foreach ($name in ($shared | Where-Object { -not $listFields.ContainsKey($_) })) {
                    $detail = @{
                        Column        = $name
                        ContentTypeId = $documentSet.ContentTypeId
                        Instances     = $instances
                    }
                    New-SpoFinding -RuleId 'DocumentSet.SharedColumnMissingFromLibrary' -Severity Error -Scope Field `
                        -Target "$target / $name" -List $list.Title `
                        -Message "Shared column '$name' does not exist on library '$($list.Title)', so its value cannot be stored on any item there." `
                        -Detail $detail
                }

                if ($SkipChildContentType -or $shared.Count -eq 0) {
                    continue
                }

                foreach ($allowed in @($template.AllowedContentType)) {
                    if ($allowed -in $baseContentTypeIds) {
                        continue
                    }

                    if (-not $childFieldCache.ContainsKey($allowed)) {
                        $childFieldCache[$allowed] = try {
                            $childType = Get-PnPContentType -Identity $allowed -ErrorAction Stop
                            @(Get-PnPProperty -ClientObject $childType -Property Fields -ErrorAction Stop |
                                    ForEach-Object { $_.InternalName })
                        }
                        catch {
                            Write-O365Log "Could not read columns of allowed content type '$allowed': $($_.Exception.Message)" 'Warning'
                            @()
                        }
                    }

                    $childFields = @($childFieldCache[$allowed])

                    if ($childFields.Count -eq 0) {
                        continue
                    }

                    $absent = @($shared | Where-Object { $_ -notin $childFields })

                    if ($absent.Count -eq 0) {
                        continue
                    }

                    $detail = @{
                        ChildContentTypeId = $allowed
                        MissingColumn      = $absent
                        ContentTypeId      = $documentSet.ContentTypeId
                    }
                    New-SpoFinding -RuleId 'DocumentSet.SharedColumnMissingFromChildContentType' -Severity Info -Scope ContentType `
                        -Target "$target -> $allowed" -List $list.Title `
                        -Message "Content type '$allowed' is allowed inside '$typeName' but lacks $($absent.Count) shared column(s): $($absent -join ', '). Values are stored but do not appear on the document's form." `
                        -Detail $detail
                }
            }
        }

        Write-O365Log 'Document Set shared column check complete.' 'Success'
    }
}
