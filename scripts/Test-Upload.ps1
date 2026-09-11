<#
.SYNOPSIS
    Checks a folder before you upload it to SharePoint, and checks that the
    upload actually arrived afterwards.
.DESCRIPTION
    Two phases, one script, nothing changed on either side:

      PreFlight  Looks at the local folder only. Finds what makes an upload
                 fail or misbehave -- names SharePoint rejects, paths that
                 would go over the 400 character limit once the target folder
                 is prepended, names that collide when case stops mattering,
                 empty files, oversized files, junk. Needs no connection at
                 all; give it -Library and it connects only to look up the
                 real target path, which is what the path length check needs.

      Verify     Compares the local folder with the library after the upload
                 and reports what did not arrive.

    Both phases write an HTML report and a CSV to out/, so the result can be
    handed to someone who does not use PowerShell. The script exits non-zero
    when it found something that blocks the upload (tune with -FailOn), so it
    can also sit in a scheduled job.

    Rule reference: docs/health-rules.md.
.PARAMETER LocalPath
    The folder you are about to upload, or just uploaded. Scanned recursively.
    Required unless -Interactive, which asks for it.
.PARAMETER Destination
    Where the files go, as the address of the folder in SharePoint -- copied
    from the browser, pasted in whole. It settles -SiteUrl, -Library and
    -RemoteFolder together, so those three are not needed with it and are
    rejected alongside it.

    This is the reliable way to name a folder. A Teams site keeps its files
    under a channel folder, so the folder that reads as "Test" in the
    breadcrumb is really "General/Test" -- and the address carries that,
    while a person retyping it does not.
.PARAMETER Library
    Target library, when the destination is given piecemeal rather than as an
    address. Required for -Mode Verify and -Mode Both. In PreFlight it is
    optional: supply it and the path length check measures against the real
    target folder instead of being skipped.
.PARAMETER RemoteFolder
    Folder inside the library, relative to the library root. Omit to target the
    library root itself.
.PARAMETER Mode
    PreFlight (default), Verify, or Both.
.PARAMETER ProfileName
    Connection profile to use. Omit to use the default profile.
.PARAMETER SiteUrl
    Site to connect to, for a machine with no profile store -- which is the
    case for the packaged launcher. Needs -ClientId as well. Implied by
    -Destination.
.PARAMETER ClientId
    Entra ID application to sign in with. Goes with -SiteUrl.
.PARAMETER Interactive
    Ask for whatever is missing instead of failing: which folder, what to do,
    and -- once connected -- which library, chosen from the ones actually
    there. This is what the double-click launcher passes.
.PARAMETER TargetPathPrefix
    Server-relative path the files will land under, e.g.
    /sites/cds/Dokumente/2026. Lets the path length check run offline, on a
    machine that cannot reach the tenant. Overrides the -Library lookup.
.PARAMETER Offline
    Never connect, even if -Library was given. PreFlight only.
.PARAMETER CompareSize
    Verify phase: also compare file sizes. Off by default because SharePoint
    legitimately stores a different byte count for Office files it processed.
.PARAMETER IncludeRisky
    Also report names containing # or %, which are legal but break some
    downstream tools.
.PARAMETER PathLimit
    Server-relative path limit in characters. Defaults to 400, SharePoint
    Online's documented maximum.
.PARAMETER WarnAt
    Warn when a path comes within this many characters of the limit.
    Default 50.
.PARAMETER LargeFileMb
    Warn about files at or over this size. Default 250 MB.
.PARAMETER BlockedExtension
    Extensions your tenant blocks, e.g. '.exe', '.js'. Empty by default:
    SharePoint Online blocks nothing out of the box, the list is per tenant.
    Anything listed here is reported as an error. A single comma-separated
    string ('.exe,.js') is accepted too, because that is the only form that
    survives `pwsh -File`.
.PARAMETER OutputPath
    Directory for the reports. Defaults to out/upload-check-<timestamp>.
.PARAMETER FailOn
    Exit with code 1 when a finding of this severity or worse was reported.
    Error (default), Warning, or None.
.PARAMETER AlwaysReport
    Write the HTML report even when there is nothing to report. This is what
    the double-click launcher passes: a run that found nothing still has to
    leave a page saying what was checked, or there is no telling it apart from
    a run that never happened.
.PARAMETER ShowFirst
    How many example files to list per rule on the console. Default 10; the
    reports always contain every one.
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload

    The quickest check: everything that can be judged from the files alone.
    No connection, no profile, nothing to configure.
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Library Dokumente -RemoteFolder 2026

    Same, plus path lengths measured against the real target folder.
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Mode Verify -ClientId <app id> -Destination 'https://contoso.sharepoint.com/sites/team/Shared Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FGeneral%2FTest'

    After the upload, with the target named the way it can be got hold of:
    open the folder in SharePoint, copy the address, paste it in. Site,
    library and folder all come out of it.
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Library Dokumente -Mode Verify

    The same thing spelled out, for a machine with a connection profile.
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Library Dokumente -Mode Both -CompareSize
.EXAMPLE
    ./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -TargetPathPrefix /sites/cds/Dokumente/2026

    Offline, with the target path supplied by hand -- for a machine that
    cannot reach the tenant.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                throw "Local folder '$_' does not exist."
            }
            $true
        })]
    [string]$LocalPath,

    [Parameter()]
    [Alias('Address', 'Target')]
    [string]$Destination,

    [Parameter(Position = 1)]
    [Alias('List', 'LibraryName')]
    [string]$Library,

    [Parameter(Position = 2)]
    [string]$RemoteFolder,

    [Parameter()]
    [ValidateSet('PreFlight', 'Verify', 'Both')]
    [string]$Mode = 'PreFlight',

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$SiteUrl,

    [Parameter()]
    [string]$ClientId,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$TargetPathPrefix,

    [Parameter()]
    [switch]$Offline,

    [Parameter()]
    [switch]$CompareSize,

    [Parameter()]
    [switch]$IncludeRisky,

    [Parameter()]
    [ValidateRange(100, 400)]
    [int]$PathLimit = 400,

    [Parameter()]
    [ValidateRange(0, 200)]
    [int]$WarnAt = 50,

    [Parameter()]
    [ValidateRange(1, 262144)]
    [int]$LargeFileMb = 250,

    [Parameter()]
    [string[]]$BlockedExtension = @(),

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('Error', 'Warning', 'None')]
    [string]$FailOn = 'Error',

    [Parameter()]
    [switch]$AlwaysReport,

    [Parameter()]
    [ValidateRange(0, 1000)]
    [int]$ShowFirst = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../src/Office365Tools/Office365Tools.psd1') -Force

# A caller that arrives through `pwsh -File` -- which is what the double-click
# launcher and any scheduled task use -- cannot pass an array: PowerShell hands
# -File arguments over as plain strings, so '.exe,.msi' turns up as a single
# element and matches nothing. Splitting here makes both forms work, and
# forgives an extension written without its leading dot.
$BlockedExtension = @(
    $BlockedExtension |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        ForEach-Object { if ($_.StartsWith('.')) { $_ } else { ".$_" } })

$script:SeverityRank  = @{ Error = 0; Warning = 1; Info = 2 }
$script:SeverityColor = @{ Error = 'Red'; Warning = 'Yellow'; Info = 'DarkGray' }

# Extensions that tenants, mail gateways and AV commonly refuse. Reported as
# Info rather than Error because whether they are blocked is a tenant setting,
# not a SharePoint rule -- put your tenant's actual list in -BlockedExtension.
$script:ExecutableExtension = @(
    '.exe', '.msi', '.dll', '.bat', '.cmd', '.com', '.scr', '.vbs', '.jar', '.ps1'
)

# Files that exist for the local file system and mean nothing in SharePoint.
$script:JunkName = @('Thumbs.db', '.DS_Store')

function New-UploadFinding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Constructs an in-memory object; nothing outside this process changes.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$RuleId,

        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', 'Info')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [hashtable]$Detail,

        [Parameter()]
        [string]$Scope = 'Item'
    )

    # Same shape as the module's own findings, so Export-SpoReport formats
    # these exactly like the output of Test-SpoLibraryHealth and friends.
    [pscustomobject]@{
        PSTypeName = 'Office365Tools.Finding'
        RuleId     = $RuleId
        Severity   = $Severity
        Scope      = $Scope
        List       = $script:TargetLibrary
        Target     = $Target
        Message    = $Message
        Detail     = if ($Detail) { [pscustomobject]$Detail } else { $null }
        SiteUrl    = $script:TargetSiteUrl
        DetectedAt = Get-Date
    }
}

function Format-Size {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

function Format-Target {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter()]
        [int]$Width = 96
    )

    # Keep the tail: the file name and its immediate folder are what identifies
    # the finding, and a deep path would otherwise wrap over three lines.
    if ($Text.Length -le $Width) { return $Text }
    return '...' + $Text.Substring($Text.Length - ($Width - 3))
}

function Write-Section {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Show-FindingSummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$Finding,

        [Parameter()]
        [int]$First = 10
    )

    if (-not $Finding -or $Finding.Count -eq 0) {
        Write-Host '  clean' -ForegroundColor Green
        return
    }

    $groups = $Finding |
        Group-Object RuleId |
        Sort-Object @{ Expression = { $script:SeverityRank[$_.Group[0].Severity] } }, Name

    foreach ($group in $groups) {
        $severity = $group.Group[0].Severity
        $colour   = $script:SeverityColor[$severity]

        Write-Host ('  {0,-7} {1,-26} {2} file(s)' -f $severity, $group.Name, $group.Count) -ForegroundColor $colour

        foreach ($item in ($group.Group | Select-Object -First $First)) {
            Write-Host "          $(Format-Target -Text $item.Target)" -ForegroundColor DarkGray
        }

        if ($group.Count -gt $First) {
            Write-Host "          ... and $($group.Count - $First) more, see the report" -ForegroundColor DarkGray
        }
    }
}

# -- Fill in what is missing, if we are allowed to ask -----------------------
function Read-Choice {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Question,

        [Parameter(Mandatory)]
        [string[]]$Option,

        [Parameter()]
        [int]$Default = 1
    )

    Write-Host ''
    Write-Host "  $Question" -ForegroundColor Cyan

    for ($i = 0; $i -lt $Option.Count; $i++) {
        Write-Host ("    {0}) {1}" -f ($i + 1), $Option[$i])
    }

    while ($true) {
        Write-Host ''
        $answer = (Read-Host "  Number [$Default]").Trim()

        if (-not $answer) { return $Default }

        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Option.Count) {
            return $number
        }

        Write-Host "  Please type a number between 1 and $($Option.Count)." -ForegroundColor Yellow
    }
}

function Select-RemoteFolder {
    <#
        Walks the library one level at a time instead of asking someone to type
        a path. Typing is where this goes wrong: a Teams site shows
        "Freigegebene Dokumente/General/Test" in the address bar, and the
        General nobody thinks of is the part that gets left out.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RootUrl,

        [Parameter(Mandatory)]
        [string]$LibraryTitle
    )

    $relative = ''

    while ($true) {
        $currentUrl = if ($relative) { "$RootUrl/$relative" } else { $RootUrl }
        $here = if ($relative) { "$LibraryTitle/$relative" } else { $LibraryTitle }

        $folder = Get-PnPFolder -Url $currentUrl -ErrorAction Stop
        $children = @(Get-PnPProperty -ClientObject $folder -Property Folders |
                Where-Object { $_.Name -ne 'Forms' } |
                Sort-Object Name)

        $options = @("Compare against $here itself")
        $options += $children | ForEach-Object { "Look inside $($_.Name)" }
        if ($relative) { $options += 'Go back up one level' }

        $choice = Read-Choice -Question 'Where in the library did the files go?' -Option $options

        if ($choice -eq 1) { return $relative }

        if ($choice -le ($children.Count + 1)) {
            $name = $children[$choice - 2].Name
            $relative = if ($relative) { "$relative/$name" } else { $name }
            continue
        }

        $relative = @($relative -split '/' | Select-Object -SkipLast 1) -join '/'
    }
}

function Read-Destination {
    <#
        Asks for the one thing the person actually has: the browser tab they
        uploaded into. Site, library and folder all come out of the address, so
        this replaces three questions that each had to be answered exactly.

        Returns an empty string when they would rather click their way to it,
        and keeps asking as long as they keep pasting something unusable --
        a bad address is worth a second attempt, not an abandoned run.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    while ($true) {
        Write-Host ''
        Write-Host '  Where in SharePoint did the files go?' -ForegroundColor Cyan
        Write-Host '  Open that folder in SharePoint, copy the address out of your' -ForegroundColor Gray
        Write-Host '  browser, and paste it here. Press Enter to pick it after signing' -ForegroundColor Gray
        Write-Host '  in instead.' -ForegroundColor Gray

        $answer = (Read-Host '  Address').Trim()

        if (-not $answer) { return $null }

        try {
            return ConvertFrom-SpoAddress $answer
        }
        catch {
            Write-Host ''
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Show-Destination {
    <#
        Reads the address back in the three parts it was understood as. An
        address that parsed into the wrong thing -- a link to a page, a site
        with a library-shaped name -- is invisible until it is spelled out,
        and by then the report says every file is missing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target
    )

    Write-Host ''
    Write-Host '  That address says:' -ForegroundColor Cyan
    Write-Host "    Site     $($Target.SiteUrl)"
    Write-Host "    Library  $(if ($Target.Library) { $Target.Library } else { '(not named -- you will be asked)' })"
    Write-Host "    Folder   $(if ($Target.RemoteFolder) { $Target.RemoteFolder } elseif ($Target.FolderIsCertain) { '(the top of the library)' } else { '(not named -- you will be asked)' })"
}

function Resolve-TargetList {
    <#
        Get-PnPList -Identity matches a library by title or GUID, but not by
        the folder name its URL is built from -- and the URL name is the only
        one an address bar ever shows. On a localised tenant those differ: the
        library addressed as "Freigegebene Dokumente" is titled "Dokumente".
        So an address that is entirely correct fails to resolve unless the URL
        name is matched too.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $list = Get-PnPList -Identity $Name -ErrorAction SilentlyContinue
    if ($list) { return $list }

    $byUrlName = @(Get-PnPList -ErrorAction SilentlyContinue |
            Where-Object { ($_.RootFolder.ServerRelativeUrl -split '/')[-1] -eq $Name })

    if ($byUrlName.Count -gt 0) { return $byUrlName[0] }

    $visible = @(Get-PnPList -ErrorAction SilentlyContinue |
            Where-Object { -not $_.Hidden -and $_.BaseTemplate -eq 101 } |
            Sort-Object Title |
            Select-Object -ExpandProperty Title)

    $hint = if ($visible.Count -gt 0) {
        "Libraries on this site: $($visible -join ', ')."
    }
    else {
        'No document libraries are visible on this site, so this is probably the wrong site.'
    }

    throw "There is no library called '$Name' on $($script:TargetSiteUrl). $hint"
}

if ($Interactive -and -not $LocalPath) {
    Write-Host ''
    Write-Host '  Which folder are you uploading?' -ForegroundColor Cyan
    $LocalPath = (Read-Host '  Folder').Trim().Trim('"').TrimEnd('\')

    if (-not (Test-Path -LiteralPath $LocalPath -PathType Container)) {
        throw "Folder '$LocalPath' does not exist."
    }
}

if (-not $LocalPath) {
    throw 'Which folder? Pass -LocalPath, or -Interactive to be asked.'
}

if ($Interactive -and -not $PSBoundParameters.ContainsKey('Mode')) {
    $choice = Read-Choice -Question 'What would you like to do?' -Option @(
        'Check this folder before I upload it (no sign-in needed)',
        'I already uploaded it -- check that everything arrived (sign-in needed)',
        'Both: check the folder, then check what arrived (sign-in needed)')

    $Mode = @('PreFlight', 'Verify', 'Both')[$choice - 1]
}

# -- Where the files go ------------------------------------------------------
# One pasted address instead of three fields that each have to be right. It is
# resolved here, before anything asks whether a connection is needed, because
# it is what decides that.
$script:FolderIsCertain = $false

# Server-relative URL of the library root. A pasted address states it outright;
# otherwise it takes a connection to find out, and stays null in an offline run
# -- which is what makes the path length check skip itself rather than measure
# against nothing.
$script:TargetRootUrl = $null

if ($Destination) {
    $conflict = @('SiteUrl', 'Library', 'RemoteFolder') |
        Where-Object { $PSBoundParameters.ContainsKey($_) }

    if ($conflict) {
        throw ("-Destination already says the site, the library and the folder, so " +
            "-$($conflict -join ', -') cannot be given as well. Pass one or the other.")
    }
}
elseif ($Interactive -and $Mode -ne 'PreFlight' -and -not $SiteUrl -and -not $Library -and -not $ProfileName) {
    $pasted = Read-Destination
    if ($pasted) { $Destination = $pasted.Address }
}

if ($Destination) {
    # Throws with an explanation of what to copy instead when the address is
    # one that cannot name a folder -- a sharing link, a Teams link, a page.
    $target = ConvertFrom-SpoAddress $Destination

    Show-Destination -Target $target

    $SiteUrl                = $target.SiteUrl
    $Library                = $target.Library
    $RemoteFolder           = $target.RemoteFolder
    $script:FolderIsCertain = $target.FolderIsCertain

    # Known without asking the tenant, so a pre-flight check measures path
    # lengths against the real destination and still signs in to nothing.
    $script:TargetRootUrl = $target.LibraryPath
}

# -- Argument combinations the parameter block cannot express ----------------
if ($Mode -ne 'PreFlight' -and -not $Library -and -not $Interactive) {
    throw "-Mode $Mode compares against a library, so -Destination or -Library is required."
}

if ($Offline -and $Mode -ne 'PreFlight') {
    throw "-Offline only applies to -Mode PreFlight; $Mode has to talk to the tenant."
}

$script:TargetLibrary = $Library

# Whatever the site is known to be before connecting -- from an address, or
# from -SiteUrl. Replaced by what the connection reports once there is one, and
# left as it is for an offline run, so its report still names the target.
$script:TargetSiteUrl = $SiteUrl

# -- Connect, but only when there is something to connect for ----------------
# PreFlight connects for one reason: to find out where the library actually is,
# so path lengths can be measured against it. An address said so already, and a
# check that promises no sign-in should not then ask for one.
$needsConnection = ($Mode -ne 'PreFlight') -or (
    $Library -and -not $TargetPathPrefix -and -not $script:TargetRootUrl -and -not $Offline)

if ($needsConnection) {
    if ($Interactive -and -not $ProfileName -and -not $SiteUrl) {
        Write-Host ''
        Write-Host '  Which SharePoint site? For example:' -ForegroundColor Cyan
        Write-Host '    https://contoso.sharepoint.com/sites/team' -ForegroundColor Gray
        $SiteUrl = (Read-Host '  Site').Trim()
    }

    if ($SiteUrl) {
        if (-not $ClientId) {
            throw 'Connecting with -SiteUrl also needs -ClientId. Ask whoever set this up for the application ID.'
        }

        Write-Host ''
        Write-Host '  A sign-in window will open now. Sign in with your work account.' -ForegroundColor Cyan

        # -Interactive is what opens the browser window. Without it PnP tries a
        # silent token first, which fails on a tenant that requires consent --
        # and fails with a message about tokens, not about signing in.
        Connect-O365 -SiteUrl $SiteUrl -ClientId $ClientId -Interactive
    }
    elseif ($ProfileName) {
        Connect-O365 -ProfileName $ProfileName
    }
    else {
        Connect-O365
    }

    $connection = Get-O365Connection
    if ($connection) {
        $script:TargetSiteUrl = $connection.SiteUrl
        Write-Host ''
        Write-Host "  Signed in to $($connection.SiteUrl)" -ForegroundColor Green
    }

    # Now that there is a connection, the library can be chosen from the ones
    # that actually exist rather than typed and mistyped.
    if ($Interactive -and -not $Library) {
        $libraries = @(Get-PnPList |
                Where-Object { -not $_.Hidden -and $_.BaseTemplate -eq 101 } |
                Sort-Object Title)

        if ($libraries.Count -eq 0) {
            throw "No document libraries are visible on $($connection.SiteUrl)."
        }

        $choice  = Read-Choice -Question 'Which library did you upload into?' -Option $libraries.Title
        $Library = $libraries[$choice - 1].Title

        $script:TargetLibrary = $Library
    }

    # Resolved once, here, so the library named in an address -- which is its
    # URL name, not its title -- becomes the real list before anything is
    # compared against it or reported under it.
    if ($Library) {
        $targetList           = Resolve-TargetList -Name $Library
        $Library              = $targetList.Title
        $script:TargetLibrary = $Library

        $targetRoot           = Get-PnPProperty -ClientObject $targetList -Property RootFolder
        $script:TargetRootUrl = $targetRoot.ServerRelativeUrl.TrimEnd('/')
    }

    # Asked separately from the library, so that settings which name a library
    # but leave the folder open still get the picker rather than the root. An
    # address that stated the folder -- including stating it as the top of the
    # library -- has answered this already.
    if ($Interactive -and $Library -and -not $RemoteFolder -and -not $script:FolderIsCertain) {
        $RemoteFolder = Select-RemoteFolder -RootUrl $script:TargetRootUrl -LibraryTitle $Library
    }
}

# -- Work out where the files will land --------------------------------------
# The path length check is only meaningful against the real prefix: a name that
# is fine at the library root breaks three folders down.
$prefix = $null

if ($TargetPathPrefix) {
    $prefix = '/' + $TargetPathPrefix.Trim('/')
}
elseif ($script:TargetRootUrl) {
    $prefix = $script:TargetRootUrl
}

if ($prefix -and $RemoteFolder) {
    $prefix = "$prefix/$($RemoteFolder.Trim('/'))"
}

# -- Prepare output ----------------------------------------------------------
if (-not $OutputPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = Join-Path $PSScriptRoot "../out/upload-check-$timestamp"
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Start-O365Log -Path (Join-Path $OutputPath 'upload-check.log') | Out-Null

$allFindings = [System.Collections.Generic.List[object]]::new()

# -- Phase 1: pre-flight -----------------------------------------------------
if ($Mode -in 'PreFlight', 'Both') {
    Write-Section "Pre-flight: $LocalPath"

    $localRoot = (Resolve-Path -LiteralPath $LocalPath).Path.TrimEnd('\')
    $files = @(Get-ChildItem -LiteralPath $localRoot -File -Recurse -Force)
    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    if (-not $totalSize) { $totalSize = 0 }

    Write-Host "  $($files.Count) file(s), $(Format-Size -Bytes $totalSize)"

    if ($prefix) {
        Write-Host "  Paths measured against $prefix" -ForegroundColor DarkGray
    }
    else {
        Write-Host '  Path length not checked: no target known. Pass -Destination, -Library or -TargetPathPrefix.' -ForegroundColor Yellow
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    $folderSeen = @{}

    # PowerShell hashtables key case-insensitively, which is exactly how
    # SharePoint compares paths -- so one bucket collects every local spelling.
    $pathBucket = @{}

    $maxBytes = 250GB
    $largeBytes = [long]$LargeFileMb * 1MB
    $processed = 0

    foreach ($file in $files) {
        $processed++
        if ($files.Count -gt 200 -and $processed % 100 -eq 0) {
            Write-Progress -Activity 'Pre-flight' -Status "$processed of $($files.Count)" `
                -PercentComplete (100 * $processed / $files.Count)
        }

        $relative = $file.FullName.Substring($localRoot.Length).TrimStart('\').Replace('\', '/')
        $segments = $relative.Split('/')
        $leaf = $segments[-1]

        # -- Names. The module owns the rules, so a name this accepts is a name
        #    Test-SpoFileName and Test-SpoLibraryHealth also accept.
        foreach ($finding in (Test-SpoFileName -Name $leaf -IncludeRisky:$IncludeRisky)) {
            $finding.Target = $relative
            $finding.List = $script:TargetLibrary
            $findings.Add($finding)
        }

        # A bad folder name breaks the upload just as thoroughly, and would
        # otherwise be reported once per file inside it.
        for ($i = 0; $i -lt $segments.Count - 1; $i++) {
            $folderPath = ($segments[0..$i] -join '/')
            if ($folderSeen.ContainsKey($folderPath)) { continue }
            $folderSeen[$folderPath] = $true

            foreach ($finding in (Test-SpoFileName -Name $segments[$i] -IncludeRisky:$IncludeRisky)) {
                $finding.Target = $folderPath
                $finding.List = $script:TargetLibrary
                $finding.Scope = 'Folder'
                $findings.Add($finding)
            }
        }

        # -- Case collisions: two files differing only in case become one file
        #    in SharePoint, and the second one silently wins.
        if (-not $pathBucket.ContainsKey($relative)) {
            $pathBucket[$relative] = [System.Collections.Generic.List[string]]::new()
        }
        if ($pathBucket[$relative] -notcontains $relative) {
            $pathBucket[$relative].Add($relative)
        }

        # -- Predicted path length
        if ($prefix) {
            $predicted = "$prefix/$relative"
            $remaining = $PathLimit - $predicted.Length

            if ($remaining -lt 0) {
                $findings.Add((New-UploadFinding -RuleId 'Upload.PathWouldExceed' -Severity Error -Target $relative `
                            -Message "Would be $($predicted.Length) characters at the target, $([Math]::Abs($remaining)) over the $PathLimit character limit." `
                            -Detail @{ PredictedUrl = $predicted; Length = $predicted.Length; Limit = $PathLimit; Remaining = $remaining }))
            }
            elseif ($remaining -le $WarnAt) {
                $findings.Add((New-UploadFinding -RuleId 'Upload.PathNearLimit' -Severity Warning -Target $relative `
                            -Message "Would be $($predicted.Length) characters at the target, only $remaining short of the $PathLimit character limit." `
                            -Detail @{ PredictedUrl = $predicted; Length = $predicted.Length; Limit = $PathLimit; Remaining = $remaining }))
            }
        }

        # -- Size
        if ($file.Length -eq 0) {
            $findings.Add((New-UploadFinding -RuleId 'Upload.EmptyFile' -Severity Warning -Target $relative `
                        -Message 'File is empty; some upload paths skip zero-byte files without reporting it.' `
                        -Detail @{ LocalPath = $file.FullName }))
        }
        elseif ($file.Length -gt $maxBytes) {
            $findings.Add((New-UploadFinding -RuleId 'Upload.TooLarge' -Severity Error -Target $relative `
                        -Message "File is $(Format-Size -Bytes $file.Length); SharePoint rejects anything over 250 GB." `
                        -Detail @{ LocalPath = $file.FullName; Bytes = $file.Length }))
        }
        elseif ($file.Length -ge $largeBytes) {
            $findings.Add((New-UploadFinding -RuleId 'Upload.LargeFile' -Severity Warning -Target $relative `
                        -Message "File is $(Format-Size -Bytes $file.Length); large uploads time out on slow links and are slow to sync." `
                        -Detail @{ LocalPath = $file.FullName; Bytes = $file.Length }))
        }

        # -- Extensions
        $extension = $file.Extension

        if ($extension -and ($BlockedExtension -contains $extension)) {
            $findings.Add((New-UploadFinding -RuleId 'Upload.BlockedExtension' -Severity Error -Target $relative `
                        -Message "'$extension' is on the blocked extension list; the upload will be refused." `
                        -Detail @{ Extension = $extension }))
        }
        elseif ($extension -and ($script:ExecutableExtension -contains $extension)) {
            $findings.Add((New-UploadFinding -RuleId 'Upload.ExecutableFile' -Severity Info -Target $relative `
                        -Message "'$extension' is commonly blocked by tenant policy, mail gateways or AV. Check before relying on it." `
                        -Detail @{ Extension = $extension }))
        }

        if (($script:JunkName -contains $leaf) -or $extension -eq '.tmp') {
            $findings.Add((New-UploadFinding -RuleId 'Upload.JunkFile' -Severity Info -Target $relative `
                        -Message 'Local file system artefact that means nothing in SharePoint.' `
                        -Detail @{ LocalPath = $file.FullName }))
        }
    }

    Write-Progress -Activity 'Pre-flight' -Completed

    foreach ($key in $pathBucket.Keys) {
        $variants = $pathBucket[$key]
        if ($variants.Count -le 1) { continue }

        $findings.Add((New-UploadFinding -RuleId 'Upload.CaseCollision' -Severity Error -Target $variants[0] `
                    -Message "$($variants.Count) local files differ only in capitalisation and would become one file: $($variants -join ', ')" `
                    -Detail @{ Paths = $variants.ToArray() }))
    }

    Show-FindingSummary -Finding $findings.ToArray() -First $ShowFirst

    foreach ($finding in $findings) {
        $allFindings.Add($finding)
    }

    if ($findings.Count -gt 0 -or $AlwaysReport) {
        # A report of no findings is a blank page, and a blank page looks
        # exactly like a tool that did not run. The summary is what tells the
        # reader that 312 files were examined and were fine.
        $errorsHere   = @($findings | Where-Object Severity -eq 'Error').Count
        $warningsHere = @($findings | Where-Object Severity -eq 'Warning').Count

        $verdict = if ($errorsHere -gt 0) {
            "$errorsHere problem(s) to fix before uploading"
        }
        elseif ($warningsHere -gt 0) {
            "nothing blocking, $warningsHere thing(s) worth a look"
        }
        else {
            'nothing to fix'
        }

        $summary = [ordered]@{
            'Folder checked'  = $localRoot
            'Files'           = "$($files.Count), $(Format-Size -Bytes $totalSize)"
            'Uploading to'    = if ($prefix) { $prefix } else { 'not given, so path lengths were not checked' }
            'Result'          = $verdict
            'Path limit'      = "$PathLimit characters, warning below $WarnAt left"
            'Large file from' = "$LargeFileMb MB"
            'Blocked types'   = if ($BlockedExtension.Count -gt 0) { $BlockedExtension -join ', ' } else { 'none configured' }
            'Checked'         = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }

        $findings | Export-SpoReport -Path (Join-Path $OutputPath 'preflight.html') `
            -Title "Before uploading -- $($files.Count) file(s), $verdict" -Summary $summary
    }
}

# -- Phase 2: verify ---------------------------------------------------------
if ($Mode -in 'Verify', 'Both') {
    $scope = if ($RemoteFolder) { "$Library/$RemoteFolder" } else { $Library }
    Write-Section "Verify: $LocalPath -> $scope"

    try {
        $comparison = @(Compare-SpoFolder -LocalPath $LocalPath -Library $Library -RemoteFolder $RemoteFolder -CompareSize:$CompareSize)
    }
    catch {
        # Nothing was compared, so there is no result to report -- saying so is
        # the whole point. Reporting it as findings would claim an upload
        # failed when what actually happened is that we looked in the wrong
        # place.
        Write-Host ''
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ''
        Write-Host '  Nothing was compared, so no verify report was written.' -ForegroundColor Yellow
        Write-Host '  Correct RemoteFolder in upload-check.xml, or empty it to be' -ForegroundColor Gray
        Write-Host '  offered the folders that exist.' -ForegroundColor Gray
        Write-Verbose $_.ScriptStackTrace

        if ($allFindings.Count -gt 0) {
            $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'findings.csv')
            Write-Host ''
            Write-Host "  The pre-flight report is still in $((Resolve-Path $OutputPath).Path)" -ForegroundColor Gray
        }

        Stop-O365Log | Out-Null
        exit 2
    }

    $matched = @($comparison | Where-Object Status -eq 'Match').Count
    Write-Host "  $($comparison.Count) file(s) compared, $matched matched"

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($row in $comparison) {
        switch ($row.Status) {
            'MissingRemote' {
                $findings.Add((New-UploadFinding -RuleId 'Upload.MissingRemote' -Severity Error -Target $row.RelativePath `
                            -Message 'Present locally but not in the library: this file did not arrive.' `
                            -Detail @{ LocalPath = $row.LocalPath; LocalSize = $row.LocalSize }))
            }
            'SizeDiffers' {
                $findings.Add((New-UploadFinding -RuleId 'Upload.SizeDiffers' -Severity Warning -Target $row.RelativePath `
                            -Message "Local file is $($row.LocalSize) bytes, the uploaded copy is $($row.RemoteSize)." `
                            -Detail @{ LocalSize = $row.LocalSize; RemoteSize = $row.RemoteSize; RemoteUrl = $row.RemoteUrl }))
            }
            'MissingLocal' {
                $findings.Add((New-UploadFinding -RuleId 'Upload.ExtraRemote' -Severity Info -Target $row.RelativePath `
                            -Message 'In the library but not in the local folder. Left over from an earlier upload, or added by someone else.' `
                            -Detail @{ RemoteUrl = $row.RemoteUrl; RemoteSize = $row.RemoteSize }))
            }
        }
    }

    Show-FindingSummary -Finding $findings.ToArray() -First $ShowFirst

    foreach ($finding in $findings) {
        $allFindings.Add($finding)
    }

    $comparison | Export-Csv -Path (Join-Path $OutputPath 'comparison.csv') -NoTypeInformation -Encoding utf8

    if ($findings.Count -gt 0 -or $AlwaysReport) {
        $missing = @($findings | Where-Object RuleId -eq 'Upload.MissingRemote').Count

        $verdict = if ($missing -gt 0) {
            "$missing file(s) did not arrive"
        }
        else {
            'everything arrived'
        }

        $summary = [ordered]@{
            'Folder on this computer' = (Resolve-Path -LiteralPath $LocalPath).Path
            'Compared with'           = $scope
            'Site'                    = $script:TargetSiteUrl
            'Files compared'          = $comparison.Count
            'Matched'                 = $matched
            'Result'                  = $verdict
            'Sizes compared'          = if ($CompareSize) { 'yes' } else { 'no (Office files legitimately differ)' }
            'Checked'                 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }

        $findings | Export-SpoReport -Path (Join-Path $OutputPath 'verify.html') `
            -Title "After uploading -- $verdict" -Summary $summary
    }
}

# -- Result ------------------------------------------------------------------
if ($allFindings.Count -gt 0) {
    $allFindings | Export-SpoReport -Path (Join-Path $OutputPath 'findings.csv')
}

Stop-O365Log | Out-Null

$errorCount = @($allFindings | Where-Object Severity -eq 'Error').Count
$warningCount = @($allFindings | Where-Object Severity -eq 'Warning').Count

Write-Section 'Result'

if ($errorCount -eq 0 -and $warningCount -eq 0) {
    Write-Host '  Nothing to fix.' -ForegroundColor Green
}
else {
    Write-Host "  $errorCount error(s), $warningCount warning(s)" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Yellow' })
}

if ($Mode -eq 'PreFlight') {
    if ($errorCount -eq 0) {
        Write-Host '  Ready to upload.' -ForegroundColor Green
        Write-Host '  Afterwards, run the same command with -Mode Verify to confirm it arrived.' -ForegroundColor Gray
    }
    else {
        Write-Host '  Fix the errors first: SharePoint will refuse or mangle those files.' -ForegroundColor Red
    }
}

Write-Host ''
Write-Host "  Reports: $((Resolve-Path $OutputPath).Path)" -ForegroundColor Green

# Nothing opens the report by itself, so the one worth reading is named here
# rather than left to be picked out of a folder of three files.
$mainReport = Join-Path $OutputPath $(if ($Mode -eq 'PreFlight') { 'preflight.html' } else { 'verify.html' })
if (Test-Path -LiteralPath $mainReport) {
    Write-Host "  Open $(Split-Path -Leaf $mainReport) in a browser to read them." -ForegroundColor Gray
}

Write-Host '  Nothing was changed, locally or in SharePoint.' -ForegroundColor Gray

$failed = switch ($FailOn) {
    'Error' { $errorCount -gt 0 }
    'Warning' { ($errorCount + $warningCount) -gt 0 }
    default { $false }
}

if ($failed) {
    exit 1
}

# Explicit, so a scheduled job sees 0 rather than whatever ran before.
exit 0
