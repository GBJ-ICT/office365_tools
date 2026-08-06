<#
.SYNOPSIS
    Runs a set of sanity checks against a library and reports what it finds.
.DESCRIPTION
    One command, many rules, one output shape. Everything it emits is a finding
    object with a stable RuleId, so you can filter, group, suppress, diff
    between runs, and feed the whole thing to Export-SpoReport.

    Rule groups (select with -Rule, default is all of them):

      Naming        Illegal characters, reserved names, stray whitespace.
      PathLength    Items at or approaching the 400-character URL limit.
      CheckedOut    Files checked out -- often invisible to everyone else.
      EmptyFolder   Folders with no content.
      Duplicate     The same file name appearing in more than one place.
      LargeFile     Files over -LargeFileThresholdMb.
      VersionBloat  Items whose version history dwarfs the current file.
      RequiredField Items missing a value in a required column.
      Permission    Unique permissions nested deeper than -MaxPermissionDepth.
      ContentType   Broken or drifted content type links.

    The scan makes one pass over the library and evaluates every selected rule
    against each item, rather than a pass per rule.
.PARAMETER Library
    Library or list to check.
.PARAMETER Rule
    Which rule groups to run. Defaults to all.
.PARAMETER LargeFileThresholdMb
    Size at which a file is reported by the LargeFile rule. Default 250 MB.
.PARAMETER VersionBloatRatio
    Report when total stored size exceeds current file size by this factor.
    Default 10, i.e. versions occupy ten times what the live file does.
.PARAMETER MaxPermissionDepth
    Report unique permissions at or below this depth. Depth 1 is the library
    root. Default 2, so a restricted top-level folder is not a finding but a
    restricted file three levels down is.
.PARAMETER MinimumSeverity
    Suppress findings below this severity. Info < Warning < Error.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents
    Runs every rule and prints a grouped report.
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents -Rule Naming, PathLength
    Runs only the two cheapest rule groups.
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents -MinimumSeverity Error |
        Export-SpoReport -Path out/health.html -Title 'Documents health'
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents | Group-Object RuleId |
        Sort-Object Count -Descending
    Shows which problems dominate.
.LINK
    Test-SpoFileName
.LINK
    Test-SpoContentTypeLink
.LINK
    Export-SpoReport
#>
function Test-SpoLibraryHealth {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [ValidateSet('Naming', 'PathLength', 'CheckedOut', 'EmptyFolder', 'Duplicate',
            'LargeFile', 'VersionBloat', 'RequiredField', 'Permission', 'ContentType')]
        [string[]]$Rule = @('Naming', 'PathLength', 'CheckedOut', 'EmptyFolder', 'Duplicate',
            'LargeFile', 'VersionBloat', 'RequiredField', 'Permission', 'ContentType'),

        [Parameter()]
        [ValidateRange(1, 100000)]
        [int]$LargeFileThresholdMb = 250,

        [Parameter()]
        [ValidateRange(2, 1000)]
        [int]$VersionBloatRatio = 10,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MaxPermissionDepth = 2,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$MinimumSeverity = 'Info',

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
        $severityRank = @{ Info = 0; Warning = 1; Error = 2 }
        $threshold    = $severityRank[$MinimumSeverity]
    }

    process {
        $list    = Resolve-SpoList -Identity $Library
        $root    = Get-PnPProperty -ClientObject $list -Property RootFolder
        $rootUrl = $root.ServerRelativeUrl

        Write-O365Log "Running health check on '$($list.Title)' with rules: $($Rule -join ', ')." 'Info'

        # Findings are collected, then filtered by severity on the way out, so
        # every rule can emit freely and the filter lives in one place.
        $findings = [System.Collections.Generic.List[object]]::new()

        # -- Rules that do not need the item pass ---------------------------

        if ('ContentType' -in $Rule) {
            foreach ($finding in (Test-SpoContentTypeLink -Library $list.Title)) {
                $findings.Add($finding)
            }
        }

        $requiredFields = @()
        if ('RequiredField' -in $Rule) {
            $requiredFields = @(Get-PnPField -List $list |
                    Where-Object { $_.Required -and -not $_.Hidden -and -not $_.ReadOnlyField } |
                    Select-Object InternalName, Title)
        }

        # -- Single pass over the library -----------------------------------

        $items = @(Get-PnPListItem -List $list -PageSize $PageSize)

        if ($items.Count -eq 0) {
            Write-O365Log "Library '$($list.Title)' is empty." 'Warning'
        }

        $nameIndex        = @{}   # leaf name -> list of URLs, for the Duplicate rule
        $folderChildCount = @{}   # folder URL -> child count, for the EmptyFolder rule
        $folderUrls       = [System.Collections.Generic.List[string]]::new()
        $index            = 0

        foreach ($item in $items) {
            $index++
            $url  = $item.FieldValues['FileRef']
            $leaf = $item.FieldValues['FileLeafRef']
            if (-not $url) { continue }

            Write-Progress -Activity "Checking $($list.Title)" -Status $leaf `
                -PercentComplete (($index / [Math]::Max($items.Count, 1)) * 100)

            $isFolder = $item.FileSystemObjectType -eq 'Folder'
            $pathInfo = Get-SpoRelativePath -ServerRelativeUrl $url -RootUrl $rootUrl

            # Track structure for the folder-level rules.
            if ($isFolder) {
                $folderUrls.Add($url)
                if (-not $folderChildCount.ContainsKey($url)) {
                    $folderChildCount[$url] = 0
                }
            }
            $parent = $pathInfo.ParentUrl
            if ($folderChildCount.ContainsKey($parent)) {
                $folderChildCount[$parent]++
            }
            else {
                $folderChildCount[$parent] = 1
            }

            # --- Naming ---
            if ('Naming' -in $Rule) {
                foreach ($finding in (Test-SpoNameRule -Name $leaf -Target $url -List $list.Title)) {
                    $findings.Add($finding)
                }
            }

            # --- PathLength ---
            if ('PathLength' -in $Rule) {
                $remaining = 400 - $url.Length
                if ($remaining -lt 0) {
                    $findings.Add((New-SpoFinding -RuleId 'PathLength.Exceeded' -Severity Error -Scope Item `
                                -Target $url -List $list.Title `
                                -Message "Path is $($url.Length) characters, $([Math]::Abs($remaining)) over the 400 character limit." `
                                -Detail @{ Length = $url.Length; Remaining = $remaining }))
                }
                elseif ($remaining -le 50) {
                    $findings.Add((New-SpoFinding -RuleId 'PathLength.NearLimit' -Severity Warning -Scope Item `
                                -Target $url -List $list.Title `
                                -Message "Path is $($url.Length) characters, only $remaining short of the 400 character limit." `
                                -Detail @{ Length = $url.Length; Remaining = $remaining }))
                }
            }

            # --- Duplicate ---
            if ('Duplicate' -in $Rule -and -not $isFolder) {
                if (-not $nameIndex.ContainsKey($leaf)) {
                    $nameIndex[$leaf] = [System.Collections.Generic.List[string]]::new()
                }
                $nameIndex[$leaf].Add($url)
            }

            # --- CheckedOut ---
            if ('CheckedOut' -in $Rule -and -not $isFolder) {
                $checkoutUser = $item.FieldValues['CheckoutUser']
                if ($checkoutUser) {
                    $who = if ($checkoutUser.LookupValue) { $checkoutUser.LookupValue } else { $checkoutUser }
                    $findings.Add((New-SpoFinding -RuleId 'File.CheckedOut' -Severity Warning -Scope Item `
                                -Target $url -List $list.Title `
                                -Message "File is checked out to $who; other users may not see the latest content." `
                                -Detail @{ CheckedOutTo = "$who"; ItemId = $item.Id }))
                }
            }

            # --- LargeFile / VersionBloat ---
            if (-not $isFolder) {
                $size = 0L
                if ($item.FieldValues.ContainsKey('File_x0020_Size') -and $item.FieldValues['File_x0020_Size']) {
                    [long]::TryParse($item.FieldValues['File_x0020_Size'].ToString(), [ref]$size) | Out-Null
                }

                if ('LargeFile' -in $Rule -and $size -gt ($LargeFileThresholdMb * 1MB)) {
                    $findings.Add((New-SpoFinding -RuleId 'File.Large' -Severity Info -Scope Item `
                                -Target $url -List $list.Title `
                                -Message "File is $([Math]::Round($size / 1MB, 1)) MB, over the $LargeFileThresholdMb MB threshold." `
                                -Detail @{ SizeBytes = $size; SizeMb = [Math]::Round($size / 1MB, 1) }))
                }

                if ('VersionBloat' -in $Rule -and $size -gt 0) {
                    $totalSize = 0L
                    if ($item.FieldValues.ContainsKey('SMTotalSize') -and $item.FieldValues['SMTotalSize']) {
                        $raw = $item.FieldValues['SMTotalSize']
                        $value = if ($raw.PSObject.Properties.Name -contains 'LookupId') { $raw.LookupId } else { $raw }
                        [long]::TryParse("$value", [ref]$totalSize) | Out-Null
                    }

                    if ($totalSize -gt ($size * $VersionBloatRatio)) {
                        $detail = @{
                            SizeBytes      = $size
                            TotalSizeBytes = $totalSize
                            Ratio          = [Math]::Round($totalSize / $size, 1)
                        }
                        $message = "Version history occupies $([Math]::Round($totalSize / 1MB, 1)) MB for a $([Math]::Round($size / 1MB, 1)) MB file."
                        $findings.Add((New-SpoFinding -RuleId 'File.VersionBloat' -Severity Info -Scope Item `
                                    -Target $url -List $list.Title -Message $message -Detail $detail))
                    }
                }
            }

            # --- RequiredField ---
            if ('RequiredField' -in $Rule -and -not $isFolder) {
                foreach ($field in $requiredFields) {
                    $value = $item.FieldValues[$field.InternalName]
                    if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
                        $findings.Add((New-SpoFinding -RuleId 'Item.RequiredFieldEmpty' -Severity Warning -Scope Item `
                                    -Target $url -List $list.Title `
                                    -Message "Required column '$($field.Title)' has no value." `
                                    -Detail @{ Field = $field.InternalName; Title = $field.Title; ItemId = $item.Id }))
                    }
                }
            }

            # --- Permission ---
            if ('Permission' -in $Rule -and $pathInfo.Depth -ge $MaxPermissionDepth) {
                try {
                    if (Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments) {
                        $findings.Add((New-SpoFinding -RuleId 'Permission.DeepUniqueAssignment' -Severity Warning -Scope Item `
                                    -Target $url -List $list.Title `
                                    -Message "Unique permissions at depth $($pathInfo.Depth); this is easy to lose track of." `
                                    -Detail @{ Depth = $pathInfo.Depth; ItemId = $item.Id }))
                    }
                }
                catch {
                    Write-O365Log "Could not read permission state of '$url': $($_.Exception.Message)" 'Warning'
                }
            }
        }

        Write-Progress -Activity "Checking $($list.Title)" -Completed

        # -- Rules that need the completed pass ------------------------------

        if ('Duplicate' -in $Rule) {
            foreach ($entry in $nameIndex.GetEnumerator()) {
                if ($entry.Value.Count -gt 1) {
                    $findings.Add((New-SpoFinding -RuleId 'File.DuplicateName' -Severity Info -Scope List `
                                -Target $entry.Key -List $list.Title `
                                -Message "'$($entry.Key)' appears $($entry.Value.Count) times in different folders." `
                                -Detail @{ Count = $entry.Value.Count; Paths = @($entry.Value) }))
                }
            }
        }

        if ('EmptyFolder' -in $Rule) {
            foreach ($folderUrl in $folderUrls) {
                if ($folderChildCount[$folderUrl] -eq 0) {
                    $findings.Add((New-SpoFinding -RuleId 'Folder.Empty' -Severity Info -Scope Folder `
                                -Target $folderUrl -List $list.Title `
                                -Message 'Folder contains no items.' `
                                -Detail @{}))
                }
            }
        }

        # -- Emit ------------------------------------------------------------

        $emitted = 0
        foreach ($finding in $findings) {
            if ($severityRank[$finding.Severity] -ge $threshold) {
                $finding
                $emitted++
            }
        }

        Write-O365Log "Health check complete: $emitted finding(s) at or above $MinimumSeverity." 'Success'
    }
}
