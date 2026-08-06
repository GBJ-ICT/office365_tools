<#
.SYNOPSIS
    Writes findings or any other command output to an HTML, CSV, or JSON report.
.DESCRIPTION
    Because every diagnostic command in this module emits the same finding
    shape, one exporter serves all of them. Pipe the output of
    Test-SpoLibraryHealth, Test-SpoContentTypeLink, Test-SpoFileName,
    Find-SpoOrphanedPermission, or anything else, and get a file you can send
    to someone who does not use PowerShell.

    The HTML report is self-contained -- no external CSS or scripts -- so it
    opens correctly from a file share or an e-mail attachment. Findings are
    grouped by severity and then by rule, with a summary table at the top.

    Format is inferred from the file extension unless -As is given.
.PARAMETER InputObject
    Objects to report. Findings get the rich HTML treatment; anything else is
    rendered as a plain table.
.PARAMETER Path
    Output file. Parent directories are created if needed.
.PARAMETER As
    Force a format instead of inferring it from the extension.
.PARAMETER Title
    Report heading. Defaults to a generated title.
.PARAMETER PassThru
    Emit the input objects as well, so the exporter can sit mid-pipeline.
.OUTPUTS
    None by default. With -PassThru, the input objects.
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents | Export-SpoReport -Path out/health.html
.EXAMPLE
    Test-SpoContentTypeLink | Export-SpoReport -Path out/ct.csv
.EXAMPLE
    Test-SpoLibraryHealth -Library Documents |
        Export-SpoReport -Path out/health.html -PassThru |
        Where-Object Severity -eq 'Error'
    Writes the report and keeps working with the findings.
.LINK
    Test-SpoLibraryHealth
#>
function Export-SpoReport {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Html', 'Csv', 'Json')]
        [string]$As,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($null -ne $InputObject) {
            $collected.Add($InputObject)
            if ($PassThru) {
                $InputObject
            }
        }
    }

    end {
        if (-not $As) {
            $As = switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
                '.html' { 'Html' }
                '.htm' { 'Html' }
                '.csv' { 'Csv' }
                '.json' { 'Json' }
                default { 'Html' }
            }
        }

        $directory = Split-Path -Parent $Path
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            if ($PSCmdlet.ShouldProcess($directory, 'Create directory')) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
        }

        if (-not $PSCmdlet.ShouldProcess($Path, "Write $As report with $($collected.Count) row(s)")) {
            return
        }

        switch ($As) {
            'Csv' {
                # Detail is a nested object; flatten it to JSON so the column
                # holds something readable rather than a type name.
                $flattened = $collected | ForEach-Object {
                    $record = [ordered]@{}
                    foreach ($property in $_.PSObject.Properties) {
                        $record[$property.Name] = if ($property.Value -is [pscustomobject] -or $property.Value -is [hashtable]) {
                            $property.Value | ConvertTo-Json -Compress -Depth 5
                        }
                        else {
                            $property.Value
                        }
                    }
                    [pscustomobject]$record
                }
                $flattened | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
            }

            'Json' {
                $collected | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
            }

            'Html' {
                $reportTitle = if ($Title) { $Title } else { 'office365_tools report' }
                $html = ConvertTo-SpoReportHtml -Item $collected -Title $reportTitle
                Set-Content -LiteralPath $Path -Value $html -Encoding utf8
            }
        }

        Write-O365Log "Wrote $As report with $($collected.Count) row(s) to '$Path'." 'Success'
    }
}
