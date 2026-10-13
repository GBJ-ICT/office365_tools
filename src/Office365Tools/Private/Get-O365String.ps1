<#
.SYNOPSIS
    Internal: the text for a message key, in the active language.
.DESCRIPTION
    Every message a person reads comes through here, so the language is chosen
    in one place. English is loaded first and the chosen language on top, so a
    text that has not been translated shows in English rather than not at all.

    A key that is missing from the English table is a bug. The user sees a
    neutral "Message unavailable" line, never the raw key; the key goes to the
    log so it can be found. tests/Unit/Language.Tests.ps1 fails the build before
    that can ship.

    The table is cached for the session. Set-O365Language and Get-O365Language
    refresh it.
.PARAMETER Key
    The message key, for example 'Language.NotSaved'.
.PARAMETER FormatArguments
    Values for the {0}, {1} placeholders in the text. Passed as the remaining
    positional arguments.
.EXAMPLE
    Get-O365String 'Language.NotSaved' $path
#>
function Get-O365String {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    if (-not $script:O365State.Strings) {
        $active = Get-O365Language
        $script:O365State.Strings = Import-O365StringTable `
            -Path (Join-Path $script:O365ModuleRoot 'Resources') -Language $active.Language
    }

    $table = $script:O365State.Strings

    if (-not $table.ContainsKey($Key)) {
        Write-O365Log "Missing text for key '$Key'." 'Warning'
    }

    Format-O365String -Table $table -Key $Key -FormatArguments $FormatArguments -WarningAction SilentlyContinue
}
