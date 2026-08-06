<#
.SYNOPSIS
    Internal: decides whether a draft file may be published, and says why not
    when it may not.
.DESCRIPTION
    Publishing a draft makes it the version every reader sees. Doing that to a
    draft that contains somebody's unfinished work is the one outcome that must
    never happen, so this errs towards refusing.

    The reasoning rests on how minor versions work: with them enabled, *every*
    save creates its own version. So a file sitting at 'x.1' has had exactly one
    save since its last published version. If that one save is provably ours --
    the right account, in the right time window, and the file appears in the
    record of what we changed -- then there is nothing else in it. A user edit
    before ours would have made it x.2, and so would one after.

    The checks are ordered so the reported reason is the most useful one rather
    than the first one that happens to match.

    Deliberately not used as evidence: file size. SharePoint promotes column
    values into the document itself, so a metadata-only change alters the bytes
    of an Office file (one .pptx here grew by 5.7 KB with no content edit).
    "Same size" would have been a plausible-looking test that is simply wrong.

    What this cannot see is a user's unsaved co-authoring session being folded
    into our version. SharePoint refuses metadata writes on a file locked for
    co-authoring -- which is what protects us -- so any file that took the write
    was not being edited at the time. Files that errored during the change must
    still be excluded by the caller, via the record.
.PARAMETER VersionLabel
    The file's current version, e.g. '3.1'.
.PARAMETER LastEditor
    Login or e-mail of whoever made the current version.
.PARAMETER Modified
    When the current version was made. Compared against Since/Until.
.PARAMETER CheckedOut
    Whether the file is checked out to anybody.
.PARAMETER Author
    The account whose change may be published. Omit to skip the check.
.PARAMETER Since
    Earliest acceptable timestamp for the current version. Omit for unbounded.
.PARAMETER Until
    Latest acceptable timestamp for the current version. Omit for unbounded.
.PARAMETER InChangeRecord
    Whether the file appears in the record of what we changed.
.PARAMETER RequireChangeRecord
    Refuse anything absent from that record. This is the strongest check --
    it replaces inference with a whitelist -- so it is on by default.
.OUTPUTS
    PSCustomObject with Publishable and Reason.
.EXAMPLE
    Test-SpoDraftPublishable -VersionLabel '3.1' -LastEditor 'admin@contoso.com' `
        -Modified $when -CheckedOut $false -InChangeRecord $true -Author 'admin@contoso.com'
#>
function Test-SpoDraftPublishable {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$VersionLabel,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$LastEditor,

        [Parameter()]
        [AllowNull()]
        $Modified,

        [Parameter()]
        [bool]$CheckedOut,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Author,

        [Parameter()]
        [AllowNull()]
        $Since,

        [Parameter()]
        [AllowNull()]
        $Until,

        [Parameter()]
        [bool]$InChangeRecord,

        [Parameter()]
        [bool]$RequireChangeRecord = $true
    )

    $verdict = {
        param([bool]$Ok, [string]$Why)
        [pscustomobject]@{
            PSTypeName  = 'Office365Tools.DraftVerdict'
            Publishable = $Ok
            Reason      = $Why
        }
    }

    if ([string]::IsNullOrWhiteSpace($VersionLabel)) {
        return & $verdict $false 'UnknownVersion'
    }

    if ($VersionLabel -match '^[1-9][0-9]*\.0$') {
        return & $verdict $false 'AlreadyPublished'
    }

    if ($CheckedOut) {
        return & $verdict $false 'CheckedOut'
    }

    # 0.x means the file has never had a published version. Publishing it would
    # not restore anything -- it would expose content for the first time, which
    # is the author's decision and not ours.
    if ($VersionLabel -match '^0\.') {
        return & $verdict $false 'NeverPublished'
    }

    if ($VersionLabel -notmatch '^[1-9][0-9]*\.1$') {
        # More than one save since the last published version: somebody else's
        # work is in there with ours.
        return & $verdict $false 'MultipleMinorVersions'
    }

    if ($RequireChangeRecord -and -not $InChangeRecord) {
        return & $verdict $false 'NotInChangeRecord'
    }

    if ($Author -and $LastEditor -ne $Author) {
        return & $verdict $false 'LastEditedBySomeoneElse'
    }

    if ($Since -or $Until) {
        if ($Modified -isnot [datetime]) {
            return & $verdict $false 'UnknownModifiedTime'
        }

        $when = [datetime]::SpecifyKind($Modified, 'Utc')

        if ($Since -is [datetime] -and $when -lt [datetime]::SpecifyKind($Since, 'Utc')) {
            return & $verdict $false 'OutsideWindow'
        }
        if ($Until -is [datetime] -and $when -gt [datetime]::SpecifyKind($Until, 'Utc')) {
            return & $verdict $false 'OutsideWindow'
        }
    }

    return & $verdict $true 'Publishable'
}
