<#
.SYNOPSIS
    Returns the text for a message key, in the language in use.
.DESCRIPTION
    Every message a person reads comes through here, so the language is chosen
    in one place. English is loaded first and the chosen language on top, so a
    text that has not been translated shows in English rather than not at all.

    The module's own texts are always there. A script that has texts of its own
    passes the folder they are in with -ResourcePath, which holds one subfolder
    per language ('en', 'de') with a Strings.psd1 in each; its texts are laid
    over the module's.

    A key that is missing from the English table is a bug. The user sees a
    neutral "Message unavailable" line, never the raw key; the key goes to the
    log so it can be found. tests/Unit/Language.Tests.ps1 fails the build before
    that can ship.

    The tables are cached for the session. Set-O365Language and
    Get-O365Language refresh them.
.PARAMETER Key
    The message key, for example 'Language.NotSaved'.
.PARAMETER ResourcePath
    Folders of string tables to use besides the module's, for example the
    Resources folder next to a script.
.PARAMETER FormatArguments
    Values for the {0}, {1} placeholders in the text. Passed as the remaining
    positional arguments.
.OUTPUTS
    The text, with its placeholders filled in.
.EXAMPLE
    Get-O365String 'Language.NotSaved' $path
.EXAMPLE
    Get-O365String -ResourcePath (Join-Path $PSScriptRoot 'Resources') 'TestUpload.Done' 3
.LINK
    Get-O365Language
#>
function Get-O365String {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter()]
        [string[]]$ResourcePath = @(),

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    # The language first: it may change what the cache holds.
    $active = Get-O365Language

    if (-not $script:O365State.Strings) {
        $script:O365State.Strings = @{}
    }

    # One merged table per set of folders, so a script's own texts are read once.
    $roots = @(Join-Path $script:O365ModuleRoot 'Resources') + @($ResourcePath)
    $cacheKey = $roots -join '|'

    if (-not $script:O365State.Strings.ContainsKey($cacheKey)) {
        $script:O365State.Strings[$cacheKey] = Import-O365StringTable -Path $roots -Language $active.Language
    }

    $table = $script:O365State.Strings[$cacheKey]

    if (-not $table.ContainsKey($Key)) {
        Write-O365Log "Missing text for key '$Key'." 'Warning'
    }

    Format-O365String -Table $table -Key $Key -FormatArguments $FormatArguments -WarningAction SilentlyContinue
}
