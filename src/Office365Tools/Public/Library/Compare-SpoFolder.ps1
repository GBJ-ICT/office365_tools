<#
.SYNOPSIS
    Compares a local folder with a SharePoint folder.
.DESCRIPTION
    Answers "did the upload actually complete?" -- the job the old
    verify_upload.ps1 did, generalised.

    Walks both sides and emits one object per file, the way a directory
    synchronisation tool lists them. Status is one of:

      Match          on both sides, and equal by whatever was compared
      MissingRemote  only on this computer -- it did not arrive
      MissingLocal   only in SharePoint
      SizeDiffers    on both sides, byte counts disagree      (-CompareSize)
      LocalNewer     on both sides, the local copy is newer    (-CompareDate)
      RemoteNewer    on both sides, SharePoint's copy is newer (-CompareDate)

    Emitting every file rather than only problems means the output doubles as
    an inventory, and `Where-Object Status -ne 'Match'` gets you the exception
    list.

    By default a file counts as matching when it exists on both sides: names
    only, dates ignored. Both refinements are opt-in, and for the same reason
    -- an upload changes them without anything being wrong. SharePoint may
    store a different byte count for an Office file it has processed, and an
    upload through the browser stamps the file with the time of the upload
    rather than the time it was last edited.
.PARAMETER LocalPath
    Local folder to compare. Scanned recursively.
.PARAMETER Library
    SharePoint library holding the remote folder.
.PARAMETER RemoteFolder
    Folder inside the library, relative to the library root. Omit to compare
    against the library root itself. Naming a folder that does not exist is an
    error, not an empty comparison: otherwise a wrong path is indistinguishable
    from an upload where nothing arrived.
.PARAMETER CompareSize
    Also compare file sizes, reporting SizeDiffers when they disagree.
.PARAMETER CompareDate
    Also compare modification dates, reporting LocalNewer or RemoteNewer when
    they are further apart than -DateTolerance. A date difference takes
    precedence over a size difference, since the newer copy is what explains
    the other.
.PARAMETER DateTolerance
    Seconds two modification dates may differ by and still count as equal.
    Default 2: FAT and some network drives keep times to two seconds, and
    SharePoint keeps them to one.
.PARAMETER TopLevelOnly
    Compare only the files directly in the folder, not those in its
    subfolders, on both sides.
.PARAMETER DifferencesOnly
    Emit only files whose Status is not Match.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.FolderComparison'.
.EXAMPLE
    Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports
.EXAMPLE
    Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports -DifferencesOnly
    Lists only what does not line up.
.EXAMPLE
    Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports -CompareDate -TopLevelOnly
    Only the files directly in Reports, and says which side has the newer
    copy -- worth it when the files were copied by something that keeps
    dates, such as the OneDrive client.
.EXAMPLE
    $result = Compare-SpoFolder -LocalPath C:\Reports -Library Documents -RemoteFolder Reports
    $result | Group-Object Status | Select-Object Name, Count
.LINK
    Test-SpoLibraryHealth
#>
function Compare-SpoFolder {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'DifferencesOnly',
        Justification = 'Used inside the $emit script block, which the analyzer does not trace into.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                    throw "Local folder '$_' does not exist."
                }
                $true
            })]
        [string]$LocalPath,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 2)]
        [string]$RemoteFolder,

        [Parameter()]
        [switch]$CompareSize,

        [Parameter()]
        [switch]$CompareDate,

        [Parameter()]
        [ValidateRange(0, 86400)]
        [int]$DateTolerance = 2,

        [Parameter()]
        [switch]$TopLevelOnly,

        [Parameter()]
        [switch]$DifferencesOnly,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    Assert-SpoConnection | Out-Null

    $list    = Resolve-SpoList -Identity $Library
    $root    = Get-PnPProperty -ClientObject $list -Property RootFolder
    $rootUrl = $root.ServerRelativeUrl

    $scopeUrl = if ($RemoteFolder) {
        "$rootUrl/$($RemoteFolder.Trim('/'))"
    }
    else {
        $rootUrl
    }

    Write-O365Log "Comparing '$LocalPath' with '$scopeUrl'." 'Info'

    # -- Local side ---------------------------------------------------------
    $localRoot  = (Resolve-Path -LiteralPath $LocalPath).Path.TrimEnd('\')
    $localFiles = @{}

    foreach ($file in (Get-ChildItem -LiteralPath $localRoot -File -Recurse:(-not $TopLevelOnly))) {
        $relative = $file.FullName.Substring($localRoot.Length).TrimStart('\').Replace('\', '/')
        $localFiles[$relative] = $file
    }

    Write-O365Log "Found $($localFiles.Count) local file(s)." 'Info'

    # -- Remote side --------------------------------------------------------
    # One paged call over the whole library, filtered to the scope, beats
    # walking folder by folder: it is a single round trip per page instead of
    # one per folder.
    $remoteFiles   = @{}
    $remoteFolders = [System.Collections.Generic.List[string]]::new()

    foreach ($item in (Get-PnPListItem -List $list -PageSize $PageSize)) {
        $url = $item.FieldValues['FileRef']
        if (-not $url) { continue }

        # Folders are kept rather than skipped: they are what tells a folder
        # that is empty apart from a folder that is not there.
        if ($item.FileSystemObjectType -eq 'Folder') {
            $remoteFolders.Add($url)
            continue
        }

        if (-not $url.StartsWith("$scopeUrl/", [System.StringComparison]::OrdinalIgnoreCase)) { continue }

        $relative = $url.Substring($scopeUrl.Length).TrimStart('/')

        # Decided on the path rather than by asking for one level: the whole
        # library comes back in one paged call either way.
        if ($TopLevelOnly -and $relative.Contains('/')) { continue }

        $size = 0L
        if ($item.FieldValues['File_x0020_Size']) {
            [long]::TryParse($item.FieldValues['File_x0020_Size'].ToString(), [ref]$size) | Out-Null
        }

        # CSOM hands dates back in UTC without always saying so: a value whose
        # Kind is Unspecified is UTC, and reading it as local time would shift
        # every file by the time zone.
        $modified = $item.FieldValues['Modified']
        $modifiedUtc = $null
        if ($modified -is [datetime]) {
            $modifiedUtc = if ($modified.Kind -eq [System.DateTimeKind]::Local) {
                $modified.ToUniversalTime()
            }
            else {
                [datetime]::SpecifyKind($modified, [System.DateTimeKind]::Utc)
            }
        }

        $remoteFiles[$relative] = [pscustomobject]@{
            Url      = $url
            Size     = $size
            Modified = $modifiedUtc
            Id       = $item.Id
        }
    }

    # A folder that does not exist and an upload that never arrived look
    # identical from the file list alone -- both produce nothing. Without this,
    # a mistyped RemoteFolder reports every local file as missing, which is the
    # most alarming possible way of saying "wrong path".
    # Files found under the scope prove the folder is there whatever the folder
    # listing says, so the question is only ever asked about an empty result.
    if ($RemoteFolder -and $remoteFiles.Count -eq 0 -and -not ($remoteFolders -contains $scopeUrl)) {
        $wanted = $RemoteFolder.Trim('/')
        $leaf = @($wanted -split '/')[-1]

        $existing = @($remoteFolders |
                ForEach-Object { $_.Substring($rootUrl.Length).TrimStart('/') } |
                Where-Object { $_ -and $_ -notmatch '^Forms(/|$)' } |
                Sort-Object)

        # A Teams site keeps channel files under 'General', so the folder
        # someone reads off the address bar is usually one level deeper than
        # the one they type. Matching on the last segment finds it.
        $near = @($existing |
                Where-Object {
                    $_.EndsWith("/$wanted", [System.StringComparison]::OrdinalIgnoreCase) -or
                    @($_ -split '/')[-1] -eq $leaf
                } |
                Select-Object -First 5)

        $message = "There is no folder '$wanted' in '$($list.Title)', so there was nothing to compare against."

        if ($near.Count -gt 0) {
            $message += " Did you mean: $($near -join ', ')?"
        }
        elseif ($existing.Count -gt 0) {
            $top = @($existing | Where-Object { $_ -notmatch '/' } | Select-Object -First 10)
            $message += " Folders at the top level of the library: $($top -join ', ')."
        }
        else {
            $message += ' That library has no folders in it at all.'
        }

        throw $message
    }

    Write-O365Log "Found $($remoteFiles.Count) remote file(s) under '$scopeUrl'." 'Info'

    # -- Compare ------------------------------------------------------------
    # Paths are compared case-insensitively, matching SharePoint's own
    # behaviour; a local filesystem that distinguishes case would otherwise
    # produce phantom differences.
    $emit = {
        param($record)
        if (-not $DifferencesOnly -or $record.Status -ne 'Match') {
            $record
        }
    }

    $seenRemote = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($relative in ($localFiles.Keys | Sort-Object)) {
        $local = $localFiles[$relative]

        # PowerShell hashtables key strings case-insensitively, which is what
        # we want: SharePoint treats 'Report.docx' and 'report.docx' as the
        # same path, so a case-sensitive lookup would invent differences.
        $remote = if ($remoteFiles.ContainsKey($relative)) { $remoteFiles[$relative] } else { $null }

        if (-not $remote) {
            & $emit ([pscustomobject]@{
                    PSTypeName     = 'Office365Tools.FolderComparison'
                    RelativePath   = $relative
                    Status         = 'MissingRemote'
                    LocalPath      = $local.FullName
                    RemoteUrl      = $null
                    LocalSize      = $local.Length
                    RemoteSize     = $null
                    LocalModified  = $local.LastWriteTimeUtc
                    RemoteModified = $null
                    List           = $list.Title
                })
            continue
        }

        [void]$seenRemote.Add($relative)

        $status = 'Match'

        # A file with no date on the SharePoint side cannot be called older or
        # newer, so it is left to the other comparisons.
        if ($CompareDate -and $null -ne $remote.Modified) {
            $drift = ($local.LastWriteTimeUtc - $remote.Modified).TotalSeconds

            if ($drift -gt $DateTolerance) {
                $status = 'LocalNewer'
            }
            elseif ($drift -lt -$DateTolerance) {
                $status = 'RemoteNewer'
            }
        }

        if ($status -eq 'Match' -and $CompareSize -and $local.Length -ne $remote.Size) {
            $status = 'SizeDiffers'
        }

        & $emit ([pscustomobject]@{
                PSTypeName     = 'Office365Tools.FolderComparison'
                RelativePath   = $relative
                Status         = $status
                LocalPath      = $local.FullName
                RemoteUrl      = $remote.Url
                LocalSize      = $local.Length
                RemoteSize     = $remote.Size
                LocalModified  = $local.LastWriteTimeUtc
                RemoteModified = $remote.Modified
                List           = $list.Title
            })
    }

    foreach ($relative in ($remoteFiles.Keys | Sort-Object)) {
        if ($seenRemote.Contains($relative)) { continue }

        & $emit ([pscustomobject]@{
                PSTypeName     = 'Office365Tools.FolderComparison'
                RelativePath   = $relative
                Status         = 'MissingLocal'
                LocalPath      = $null
                RemoteUrl      = $remoteFiles[$relative].Url
                LocalSize      = $null
                RemoteSize     = $remoteFiles[$relative].Size
                LocalModified  = $null
                RemoteModified = $remoteFiles[$relative].Modified
                List           = $list.Title
            })
    }

    Write-O365Log 'Comparison complete.' 'Success'
}
