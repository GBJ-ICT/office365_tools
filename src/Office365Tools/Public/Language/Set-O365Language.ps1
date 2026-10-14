<#
.SYNOPSIS
    Chooses the language the tools use from now on.
.DESCRIPTION
    Saves the choice in %APPDATA%\office365_tools\settings.json, for your Windows
    account. The launcher, the tool menu and the PowerShell commands all read the
    same file, so changing it here changes it everywhere.

    'auto' removes the preference and follows the Windows display language.

    If the file cannot be saved the choice still applies to the current session,
    and a warning says it was not saved.

    With -SessionOnly nothing is saved at all: the language applies to this
    PowerShell session only, and outranks every other source. This is what the
    -Language parameter of the scripts does, so one run can be in the other
    language without changing the saved choice.
.PARAMETER Language
    en, de, or auto.
.PARAMETER SessionOnly
    Apply the language to this session only. Nothing is written. 'auto' removes
    an earlier session choice.
.PARAMETER PassThru
    Return the resulting language, as Get-O365Language shows it.
.EXAMPLE
    Set-O365Language de

    Uses German from now on.
.EXAMPLE
    Set-O365Language en -SessionOnly

    English for this session; the saved choice is untouched.
.EXAMPLE
    Set-O365Language auto -PassThru

    Follows Windows again and shows what that means for this machine.
.LINK
    Get-O365Language
#>
function Set-O365Language {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('en', 'de', 'auto')]
        [string]$Language,

        [Parameter()]
        [switch]$SessionOnly,

        [Parameter()]
        [switch]$PassThru
    )

    if ($SessionOnly) {
        # Applies to this session and nothing else, so there is nothing to
        # preview and nothing to confirm.
        $script:O365State.LanguageOverride = $null
        if ($Language -ne 'auto') {
            $script:O365State.LanguageOverride = $Language
        }
        $script:O365State.Strings = $null

        if ($PassThru) {
            Get-O365Language
        }
        return
    }

    $path = Get-O365SettingsPath

    if ($PSCmdlet.ShouldProcess($path, (Get-O365String 'Language.Save.Action' $Language))) {
        $saved = Write-O365Setting -Name 'language' -Value $Language -Path $path

        # Drop the cache so the next message is in the new language, saved or not.
        $script:O365State.Strings = $null

        if (-not $saved) {
            # The choice cannot outlive this session, so apply it to it.
            $script:O365State.LanguageOverride = $null
            if ($Language -ne 'auto') {
                $script:O365State.LanguageOverride = $Language
            }

            Write-O365Log (Get-O365String 'Language.NotSaved' $path) 'Warning'
        }
    }

    if ($PassThru) {
        Get-O365Language
    }
}
