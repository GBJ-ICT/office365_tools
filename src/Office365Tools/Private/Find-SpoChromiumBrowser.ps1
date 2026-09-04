<#
.SYNOPSIS
    Internal: locates a Chromium-based browser that can print to PDF.
.DESCRIPTION
    Looks where Edge and Chrome install on Windows, then falls back to the
    PATH, which is what finds them on Linux and macOS. Fails with the list of
    places it looked, because 'browser not found' on a machine that plainly has
    a browser is otherwise an unhelpful thing to be told.
.OUTPUTS
    System.String, the full path to the executable.
.EXAMPLE
    $browser = Find-SpoChromiumBrowser
#>
function Find-SpoChromiumBrowser {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $candidates = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) {
        if (-not $root) { continue }
        $candidates.Add((Join-Path $root 'Microsoft\Edge\Application\msedge.exe'))
        $candidates.Add((Join-Path $root 'Google\Chrome\Application\chrome.exe'))
        $candidates.Add((Join-Path $root 'Chromium\Application\chrome.exe'))
        $candidates.Add((Join-Path $root 'BraveSoftware\Brave-Browser\Application\brave.exe'))
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    foreach ($name in 'msedge', 'chrome', 'chromium', 'google-chrome', 'chromium-browser', 'brave') {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }

    throw [System.IO.FileNotFoundException]::new(
        'No Chromium-based browser was found, and one is what renders the PDF. Looked for msedge.exe and chrome.exe under ' +
        "'$env:ProgramFiles', '${env:ProgramFiles(x86)}' and '$env:LOCALAPPDATA', then on PATH. " +
        'Pass -BrowserPath with the full path to msedge.exe or chrome.exe.'
    )
}
