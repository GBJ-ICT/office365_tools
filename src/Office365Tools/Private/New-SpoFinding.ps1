<#
.SYNOPSIS
    Internal: builds a finding object in the module's standard shape.
.DESCRIPTION
    Every diagnostic command (Test-SpoLibraryHealth, Test-SpoFileName,
    Test-SpoContentTypeLink, Find-SpoOrphanedPermission, ...) emits findings in
    this one shape. Because the shape is shared, Export-SpoReport can format
    output from any of them, and users can pipe findings between commands.

    The PSTypeName drives the default table view in
    Office365Tools.Format.ps1xml.
.PARAMETER RuleId
    Stable dotted identifier, e.g. 'FileName.IllegalCharacter'. Stable means
    users can filter on it and suppress specific rules over time.
.PARAMETER Severity
    Error   - broken now, or will break sync/open for a user.
    Warning - works, but is a latent problem or violates convention.
    Info    - observation worth surfacing, no action implied.
.PARAMETER Target
    What the finding is about: a server-relative URL, list title, or content
    type name.
.PARAMETER Message
    One sentence describing the problem, written for someone who did not run
    the scan.
.PARAMETER Scope
    The kind of object Target refers to.
.PARAMETER List
    Owning list or library title, when applicable.
.PARAMETER Detail
    Free-form hashtable of rule-specific extras (measured values, thresholds,
    related IDs). Kept separate so the core columns stay uniform.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    New-SpoFinding -RuleId 'PathLength.Exceeded' -Severity Error `
        -Scope Item -Target $url -Message 'Server-relative path exceeds 400 characters.'
#>
function New-SpoFinding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Constructs an in-memory object. Nothing outside this process is changed, so -WhatIf would be meaningless.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RuleId,

        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', 'Info')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateSet('Site', 'List', 'Folder', 'Item', 'ContentType', 'Field', 'Principal')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [string]$List,

        [Parameter()]
        [hashtable]$Detail
    )

    [pscustomobject]@{
        PSTypeName = 'Office365Tools.Finding'
        RuleId     = $RuleId
        Severity   = $Severity
        Scope      = $Scope
        List       = $List
        Target     = $Target
        Message    = $Message
        Detail     = if ($Detail) { [pscustomobject]$Detail } else { $null }
        SiteUrl    = $script:O365State.SiteUrl
        DetectedAt = Get-Date
    }
}
