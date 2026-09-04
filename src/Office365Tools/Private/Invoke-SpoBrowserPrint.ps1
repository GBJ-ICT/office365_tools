<#
.SYNOPSIS
    Internal: prints a local HTML file to PDF with headless Edge or Chrome.
.DESCRIPTION
    The conversion step. Everything about it is chosen to make the output a
    function of the document and nothing else:

      * '--force-device-scale-factor=1' pins the zoom. This is the reason a
        hand-printed list comes out differently every time: the browser prints
        at the window's zoom, and nobody remembers what theirs is set to.
      * '--headless' has no window, so there is no viewport width to lay out
        against either -- the '@page' rule in the document decides the sheet.
      * '--user-data-dir' points at a scratch directory, so the print does not
        inherit a profile's print settings, extensions, or a signed-in state.
      * '--no-pdf-header-footer' removes the browser's own header line, which
        otherwise stamps the file:/// path across the top of every page.
        -PageFooter leaves it on, and it is the only way to get page numbers:
        Chromium implements no CSS counter for them.

    Edge is preferred simply because it is present on every Windows install.
    Chrome, Chromium and Brave take the same switches and are tried after it.

    Chromium's headless mode was reimplemented ('--headless=new'), and the old
    mode is what older Edge builds have. The new one is tried first and the old
    one is the fallback, because the failure is silent: the process exits 0 and
    writes no file.
.PARAMETER HtmlPath
    The document to print. A local path -- it is converted to a file:/// URL.
.PARAMETER Path
    Where to write the PDF. Overwritten if it exists.
.PARAMETER BrowserPath
    Full path to a Chromium-based browser, when it is somewhere unusual or a
    specific one is wanted.
.PARAMETER TimeoutSecond
    How long to wait before killing the browser and failing.
.PARAMETER PageFooter
    Keep the browser's own header and footer, which carry the title, the date,
    and 'page n of m'.
.OUTPUTS
    PSCustomObject with Path, Browser, HeadlessMode, ExitCode and Duration.
.EXAMPLE
    Invoke-SpoBrowserPrint -HtmlPath ./out/list.html -Path ./out/list.pdf
#>
function Invoke-SpoBrowserPrint {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$HtmlPath,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [string]$BrowserPath,

        [Parameter()]
        [ValidateRange(5, 3600)]
        [int]$TimeoutSecond = 120,

        [Parameter()]
        [switch]$PageFooter
    )

    $browser = if ($BrowserPath) {
        if (-not (Test-Path -LiteralPath $BrowserPath)) {
            throw [System.IO.FileNotFoundException]::new(
                "No browser at '$BrowserPath'. Point -BrowserPath at msedge.exe or chrome.exe, or omit it to search the usual locations."
            )
        }
        (Resolve-Path -LiteralPath $BrowserPath).Path
    }
    else {
        Find-SpoChromiumBrowser
    }

    $htmlFull = (Resolve-Path -LiteralPath $HtmlPath).Path
    $pdfFull  = [System.IO.Path]::GetFullPath($Path)

    if (Test-Path -LiteralPath $pdfFull) {
        Remove-Item -LiteralPath $pdfFull -Force
    }

    $scratch = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-print-$([guid]::NewGuid())"
    $null = New-Item -ItemType Directory -Path $scratch -Force

    try {
        foreach ($mode in '--headless=new', '--headless') {
            $arguments = [System.Collections.Generic.List[string]]::new()
            $arguments.Add($mode)
            $arguments.Add('--disable-gpu')
            $arguments.Add('--no-first-run')
            $arguments.Add('--no-default-browser-check')
            $arguments.Add('--disable-extensions')
            $arguments.Add('--disable-background-networking')
            $arguments.Add('--disable-sync')
            $arguments.Add('--hide-scrollbars')
            $arguments.Add('--force-device-scale-factor=1')
            $arguments.Add('--run-all-compositor-stages-before-draw')
            $arguments.Add('--virtual-time-budget=10000')
            $arguments.Add("--user-data-dir=$scratch")
            $arguments.Add("--crash-dumps-dir=$scratch")

            if (-not $PageFooter) {
                # Two spellings of the same switch across Chromium versions.
                # An unrecognised switch is ignored, so both can be passed.
                $arguments.Add('--no-pdf-header-footer')
                $arguments.Add('--print-to-pdf-no-header')
            }

            $arguments.Add("--print-to-pdf=$pdfFull")
            $arguments.Add(([uri]$htmlFull).AbsoluteUri)

            $stdout = Join-Path $scratch 'stdout.txt'
            $stderr = Join-Path $scratch 'stderr.txt'

            Write-O365Log "Printing with $browser ($mode)." 'Info'
            $started = Get-Date

            $process = Start-Process -FilePath $browser -ArgumentList $arguments -PassThru -NoNewWindow `
                -RedirectStandardOutput $stdout -RedirectStandardError $stderr

            if (-not $process.WaitForExit($TimeoutSecond * 1000)) {
                try { $process.Kill($true) } catch { Write-Verbose "Browser had already exited: $($_.Exception.Message)" }
                throw [System.TimeoutException]::new(
                    "The browser did not finish printing within $TimeoutSecond seconds. Raise -TimeoutSecond, or print fewer rows per file."
                )
            }

            $duration = (Get-Date) - $started

            if ((Test-Path -LiteralPath $pdfFull) -and (Get-Item -LiteralPath $pdfFull).Length -gt 0) {
                return [pscustomobject]@{
                    Path         = $pdfFull
                    Browser      = $browser
                    HeadlessMode = $mode
                    ExitCode     = $process.ExitCode
                    Duration     = $duration
                }
            }

            $diagnostic = @(
                if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw }
            ) -join ''

            Write-O365Log "$mode produced no PDF (exit $($process.ExitCode)). $($diagnostic.Trim())" 'Warning'
        }

        throw [System.InvalidOperationException]::new(
            "'$browser' exited without writing '$pdfFull' in either headless mode. " +
            'Run the same command by hand without --headless to see what it says, or pass -KeepHtml and print the HTML from a browser.'
        )
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}
