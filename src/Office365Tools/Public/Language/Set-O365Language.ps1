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
.PARAMETER Language
    en, de, or auto.
.PARAMETER PassThru
    Return the resulting language, as Get-O365Language shows it.
.EXAMPLE
    Set-O365Language de

    Uses German from now on.
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
        [switch]$PassThru
    )

    $path = Get-O365SettingsPath

    if ($PSCmdlet.ShouldProcess($path, (Get-O365String 'Language.Save.Action' $Language))) {
        $saved = Write-O365Setting -Name 'language' -Value $Language -Path $path

        # Drop the cache so the next message is in the new language, saved or not.
        $script:O365State.Strings = $null

        if (-not $saved) {
            # The choice cannot outlive this session, so apply it to it: the
            # environment variable outranks the saved setting.
            if ($Language -eq 'auto') {
                Remove-Item Env:\O365_LANGUAGE -ErrorAction SilentlyContinue
            }
            else {
                $env:O365_LANGUAGE = $Language
            }

            Write-O365Log (Get-O365String 'Language.NotSaved' $path) 'Warning'
        }
    }

    if ($PassThru) {
        Get-O365Language
    }
}
