<#
.SYNOPSIS
    Internal: the text helper every script in scripts/ uses.
.DESCRIPTION
    Dot-sourced by each script, after the module is imported:

        . (Join-Path $PSScriptRoot 'Shared/ScriptLanguage.ps1')

    It defines Get-ScriptString, which looks a message up in the language in use:
    the texts in scripts\Resources, laid over the module's own. Each script
    applies its -Language parameter before this, with

        Set-O365Language -Language $Language -SessionOnly

    so the language holds for that run and the saved choice is left alone.

    Not a script a person runs, which is why it sits in its own folder.
#>

# Worked out here, while $PSScriptRoot is this file's folder.
$script:ScriptResources = Join-Path (Split-Path -Parent $PSScriptRoot) 'Resources'

function Get-ScriptString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]]$FormatArguments = @()
    )

    Get-O365String -ResourcePath $script:ScriptResources $Key @FormatArguments
}
