<#
.SYNOPSIS
    Internal: applies SharePoint's name restrictions to a single name.
.DESCRIPTION
    The one implementation of the naming rules. Test-SpoFileName exposes it
    directly; Test-SpoLibraryHealth calls it during its single pass over the
    library so a health scan does not have to fetch every item twice.

    Having exactly one copy is the point: the two commands can never disagree
    about whether a name is acceptable.
.PARAMETER Name
    The leaf name to validate, e.g. 'Q1 report.docx'.
.PARAMETER Target
    What to report as the finding's target -- usually the item's
    server-relative URL, or the name itself in offline mode.
.PARAMETER List
    Owning list title, if any.
.PARAMETER IncludeRisky
    Also apply the FileName.RiskyCharacter rule (# and %), which is legal in
    modern SharePoint but breaks some downstream tools.
.OUTPUTS
    Zero or more findings. No output means the name is acceptable.
#>
function Test-SpoNameRule {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Target,

        [Parameter()]
        [AllowNull()]
        [string]$List,

        [Parameter()]
        [switch]$IncludeRisky
    )

    if ([string]::IsNullOrEmpty($Name)) {
        return
    }

    $illegalCharacters = '"', '*', ':', '<', '>', '?', '/', '\', '|'
    $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', '.lock', 'desktop.ini')
    $reservedNames += @(0..9 | ForEach-Object { "COM$_" })
    $reservedNames += @(0..9 | ForEach-Object { "LPT$_" })

    $stem = try { [System.IO.Path]::GetFileNameWithoutExtension($Name) } catch { $Name }

    $found = @($illegalCharacters | Where-Object { $Name.Contains($_) })
    if ($found.Count -gt 0) {
        New-SpoFinding -RuleId 'FileName.IllegalCharacter' -Severity Error -Scope Item `
            -Target $Target -List $List `
            -Message "Name contains character(s) SharePoint does not permit: $($found -join ' ')" `
            -Detail @{ Name = $Name; Characters = $found }
    }

    if ($Name -ne $Name.TrimStart()) {
        New-SpoFinding -RuleId 'FileName.LeadingSpace' -Severity Warning -Scope Item `
            -Target $Target -List $List `
            -Message 'Name begins with whitespace, which some clients strip silently.' `
            -Detail @{ Name = $Name }
    }

    if ($Name -ne $Name.TrimEnd()) {
        New-SpoFinding -RuleId 'FileName.TrailingSpace' -Severity Warning -Scope Item `
            -Target $Target -List $List `
            -Message 'Name ends with whitespace, which some clients strip silently.' `
            -Detail @{ Name = $Name }
    }

    if ($Name.TrimEnd().EndsWith('.')) {
        New-SpoFinding -RuleId 'FileName.TrailingPeriod' -Severity Error -Scope Item `
            -Target $Target -List $List `
            -Message 'Name ends with a period, which the OneDrive sync client rejects.' `
            -Detail @{ Name = $Name }
    }

    if ($stem -in $reservedNames -or $Name -in $reservedNames) {
        New-SpoFinding -RuleId 'FileName.ReservedName' -Severity Error -Scope Item `
            -Target $Target -List $List `
            -Message "'$Name' is a reserved name and cannot be used." `
            -Detail @{ Name = $Name }
    }

    if ($Name.StartsWith('~$') -or $Name.StartsWith('_vti_')) {
        New-SpoFinding -RuleId 'FileName.ReservedPrefix' -Severity Error -Scope Item `
            -Target $Target -List $List `
            -Message 'Name starts with a reserved prefix (~$ or _vti_).' `
            -Detail @{ Name = $Name }
    }

    if ($Name.Length -gt 255) {
        New-SpoFinding -RuleId 'FileName.TooLong' -Severity Error -Scope Item `
            -Target $Target -List $List `
            -Message "Name is $($Name.Length) characters; the limit is 255." `
            -Detail @{ Name = $Name; Length = $Name.Length }
    }

    if ($IncludeRisky) {
        $risky = @('#', '%') | Where-Object { $Name.Contains($_) }
        if ($risky.Count -gt 0) {
            New-SpoFinding -RuleId 'FileName.RiskyCharacter' -Severity Info -Scope Item `
                -Target $Target -List $List `
                -Message "Name contains $($risky -join ' '), which is legal but breaks some downstream tools." `
                -Detail @{ Name = $Name; Characters = $risky }
        }
    }
}
