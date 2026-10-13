<#
.SYNOPSIS
    Internal: language resolution, string tables and the saved language setting.
.DESCRIPTION
    This file is shared on purpose. The module dot-sources it with the rest of
    Private/, and the double-click launcher -- which runs under Windows
    PowerShell 5.1, before the module or PowerShell 7 is involved -- dot-sources
    the very same file. One implementation means the two cannot drift.

    So it has two rules that the rest of the module does not:

      - Windows PowerShell 5.1 syntax only: no ternary, no ??, no ?., no
        && or ||, no -Parallel. tests/Unit/Language.Tests.ps1 checks this.
      - ASCII only. 5.1 reads a file without a byte order mark as the ANSI
        code page, so a single umlaut in a comment would be read wrongly.

    It also takes everything it needs as parameters and reads no module state,
    so it works without the module. The module's own wrappers
    (Get-O365String, Get-O365Language) add the caching.

    Design: docs/dev/multilanguage.md.
#>

function Get-O365SupportedLanguage {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    # The one list. -Language validation, the picker and the culture mapping
    # all read it, so adding a language starts here.
    return @('en', 'de')
}

function Get-O365SettingsPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Per Windows user, outside the repository and outside any package, so
    # pulling code or unpacking a new ZIP never resets a choice. The override
    # exists for tests.
    if ($env:O365_SETTINGS_PATH) {
        return $env:O365_SETTINGS_PATH
    }

    $base = $env:APPDATA
    if (-not $base) {
        $base = [Environment]::GetFolderPath('ApplicationData')
    }

    return (Join-Path (Join-Path $base 'office365_tools') 'settings.json')
}

function Read-O365Setting {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Path = (Get-O365SettingsPath)
    )

    # A missing or unreadable file is the same as "not set". A broken settings
    # file must never stop a tool from starting.
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $text = [System.IO.File]::ReadAllText($Path)
        if (-not $text.Trim()) {
            return $null
        }
        $data = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    if ($null -eq $data) {
        return $null
    }

    $property = $data.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Write-O365Setting {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [string]$Path = (Get-O365SettingsPath)
    )

    # Returns $true when the value was saved. A failure is never fatal: the
    # choice still applies to the current run, and the caller says it was not
    # saved.
    try {
        # Keep every key that is already there, so a setting another tool added
        # is not erased by saving this one.
        $document = [ordered]@{}

        if (Test-Path -LiteralPath $Path) {
            try {
                $text = [System.IO.File]::ReadAllText($Path)
                if ($text.Trim()) {
                    $existing = $text | ConvertFrom-Json -ErrorAction Stop
                    foreach ($property in $existing.PSObject.Properties) {
                        $document[$property.Name] = $property.Value
                    }
                }
            }
            catch {
                # An unreadable file is replaced rather than preserved.
                $document = [ordered]@{}
            }
        }

        $document[$Name] = $Value

        $directory = Split-Path -Parent $Path
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $json = $document | ConvertTo-Json -Depth 5

        # Written beside the target and moved into place, so a crash halfway
        # never leaves a half-written settings file behind. No byte order mark:
        # JSON does not want one.
        $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($temp, $json, $encoding)

        Move-Item -LiteralPath $temp -Destination $Path -Force -ErrorAction Stop

        return $true
    }
    catch {
        return $false
    }
}

function ConvertTo-O365LanguageCode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Culture
    )

    # de-CH, de-AT and de-DE are all German. The culture API answers that, so
    # unusual tags such as zh-Hans are .NET's problem and not ours to parse.
    # Anything we do not have a table for is English.
    if (-not $Culture) {
        return 'en'
    }

    try {
        $code = [System.Globalization.CultureInfo]::new($Culture).TwoLetterISOLanguageName
    }
    catch {
        return 'en'
    }

    if ((Get-O365SupportedLanguage) -contains $code) {
        return $code
    }

    return 'en'
}

function Resolve-O365Language {
    <#
    .SYNOPSIS
        Internal: picks the language for this run and says where it came from.
    .DESCRIPTION
        The first source that gives a value other than 'auto' wins:

          1. Parameter     -Language
          2. Environment   O365_LANGUAGE
          3. SavedSetting  settings.json, key 'language'
          4. Windows       the Windows display language ($PSUICulture)
          5. Default       English

        'auto' is valid in every source and means "ask the next one". An invalid
        parameter is an error. An invalid environment variable or saved value
        is ignored with a warning, so a typo in a file never stops a tool.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Language,

        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Environment = $env:O365_LANGUAGE,

        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Saved = (Read-O365Setting -Name 'language'),

        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$UICulture = $PSUICulture
    )

    $supported = Get-O365SupportedLanguage

    if ($Language -and $Language -ne 'auto') {
        if ($supported -notcontains $Language) {
            throw "Language '$Language' is not supported. Use one of: $($supported -join ', '), auto."
        }
        return [pscustomobject]@{ Language = $Language; Source = 'Parameter' }
    }

    $candidates = @(
        @{ Value = $Environment; Source = 'Environment'; Label = 'the environment variable O365_LANGUAGE' }
        @{ Value = $Saved; Source = 'SavedSetting'; Label = 'the saved language setting' }
    )

    foreach ($candidate in $candidates) {
        $value = $candidate.Value
        if (-not $value -or $value -eq 'auto') {
            continue
        }

        if ($supported -contains $value) {
            return [pscustomobject]@{ Language = $value; Source = $candidate.Source }
        }

        Write-Warning "Ignoring $($candidate.Label): '$value' is not one of $($supported -join ', '), auto."
    }

    if ($UICulture) {
        return [pscustomobject]@{
            Language = (ConvertTo-O365LanguageCode -Culture $UICulture)
            Source   = 'Windows'
        }
    }

    return [pscustomobject]@{ Language = 'en'; Source = 'Default' }
}

function Import-O365StringTable {
    <#
    .SYNOPSIS
        Internal: loads the strings for a language, with English underneath.
    .DESCRIPTION
        English is loaded first and is the base. The chosen language is loaded
        over it, key by key. A key that exists only in English therefore still
        resolves, and a missing file for the chosen language falls back to
        English without an error.

        -Path takes several Resources folders (the module's, a tool's). They are
        merged in the order given, each with English first, so a later folder
        may override an earlier one.

        The files are PowerShell data files, read with Import-PowerShellDataFile:
        literals only, no code runs.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [string]$Language
    )

    $table = @{}

    foreach ($root in $Path) {
        $codes = @('en')
        if ($Language -ne 'en') {
            $codes += $Language
        }

        foreach ($code in $codes) {
            $file = Join-Path (Join-Path $root $code) 'Strings.psd1'

            if (-not (Test-Path -LiteralPath $file)) {
                continue
            }

            $loaded = Import-PowerShellDataFile -LiteralPath $file
            foreach ($key in $loaded.Keys) {
                $table[$key] = $loaded[$key]
            }
        }
    }

    return $table
}

function Format-O365String {
    <#
    .SYNOPSIS
        Internal: looks a key up in a table and fills in its placeholders.
    .DESCRIPTION
        Never returns an empty string and never exposes a raw key. If the key is
        not in the table -- a bug on our side, which tests/Unit/Language.Tests.ps1
        exists to catch before a release -- the text is a neutral "Message
        unavailable" line, and a warning names the key so it can be found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter()]
        [object[]]$FormatArguments = @()
    )

    if (-not $Table.ContainsKey($Key)) {
        Write-Warning "Missing text for key '$Key'."

        if ($Table.ContainsKey('Common.MessageUnavailable')) {
            return ([string]$Table['Common.MessageUnavailable']) -f $Key
        }

        return "Message unavailable ($Key)"
    }

    $text = [string]$Table[$Key]

    if ($FormatArguments.Count -eq 0) {
        return $text
    }

    return ($text -f $FormatArguments)
}
