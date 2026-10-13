<#
.SYNOPSIS
    Shows which language the tools use, and why.
.DESCRIPTION
    The language is the first of these that is set to something other than
    'auto':

      Parameter     a -Language argument
      Environment   the O365_LANGUAGE environment variable
      SavedSetting  the choice saved by Set-O365Language or the launcher
      Windows       the Windows display language
      Default       English

    Use this when a tool is not in the language you expected: Source says which
    setting won.
.OUTPUTS
    PSCustomObject with Language ('en' or 'de'), Source, and SettingsPath.
.EXAMPLE
    Get-O365Language

    Language Source
    -------- ------
    de       SavedSetting
.LINK
    Set-O365Language
#>
function Get-O365Language {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $resolved = Resolve-O365Language

    # Anything cached under another language is stale.
    if ($script:O365State.Language -ne $resolved.Language) {
        $script:O365State.Strings = $null
    }
    $script:O365State.Language = $resolved.Language

    [pscustomobject]@{
        Language     = $resolved.Language
        Source       = $resolved.Source
        SettingsPath = Get-O365SettingsPath
    }
}
