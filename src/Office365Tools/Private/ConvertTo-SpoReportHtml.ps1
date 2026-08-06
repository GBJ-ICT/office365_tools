<#
.SYNOPSIS
    Internal: renders objects as a self-contained HTML report.
.DESCRIPTION
    Produces a single file with no external references, so it survives being
    e-mailed or dropped on a file share. Findings get a summary and severity
    grouping; anything else falls back to a plain table.

    All values are HTML-encoded. Findings contain file names and paths straight
    from the tenant, and a file legitimately named 'Q1 <draft>.docx' would
    otherwise corrupt the page.
.PARAMETER Item
    Objects to render.
.PARAMETER Title
    Page heading.
.OUTPUTS
    System.String containing the complete HTML document.
#>
function ConvertTo-SpoReportHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Position = 1)]
        [string]$Title = 'office365_tools report'
    )

    $encode = { param($Value) [System.Net.WebUtility]::HtmlEncode([string]$Value) }

    $isFindingReport = $Item.Count -gt 0 -and ($Item[0].PSObject.TypeNames -contains 'Office365Tools.Finding')

    $style = @'
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
       margin: 0; padding: 2rem; line-height: 1.5;
       background: #ffffff; color: #1a1a1a; }
h1 { font-size: 1.6rem; margin: 0 0 .25rem; }
h2 { font-size: 1.15rem; margin: 2rem 0 .5rem; padding-bottom: .25rem;
     border-bottom: 2px solid #e5e5e5; }
.meta { color: #666; font-size: .875rem; margin-bottom: 1.5rem; }
table { border-collapse: collapse; width: 100%; margin-bottom: 1rem;
        font-size: .875rem; }
th, td { text-align: left; padding: .5rem .75rem; border-bottom: 1px solid #e5e5e5;
         vertical-align: top; }
th { background: #f5f5f5; font-weight: 600; white-space: nowrap; }
tr:hover td { background: #fafafa; }
td.wrap { word-break: break-all; }
.summary { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.card { border: 1px solid #e5e5e5; border-radius: 6px; padding: .75rem 1.25rem;
        min-width: 7rem; }
.card .n { font-size: 1.75rem; font-weight: 600; display: block; }
.card .l { font-size: .8rem; color: #666; text-transform: uppercase;
           letter-spacing: .04em; }
.sev { display: inline-block; padding: .1rem .5rem; border-radius: 3px;
       font-size: .75rem; font-weight: 600; text-transform: uppercase; }
.sev-Error { background: #fde8e8; color: #9b1c1c; }
.sev-Warning { background: #fdf6b2; color: #8e4b10; }
.sev-Info { background: #e1effe; color: #1e429f; }
.empty { padding: 2rem; text-align: center; color: #666;
         border: 1px dashed #d5d5d5; border-radius: 6px; }
code { font-family: "Cascadia Mono", Consolas, monospace; font-size: .85em; }
@media (prefers-color-scheme: dark) {
  body { background: #1a1a1a; color: #e5e5e5; }
  th { background: #262626; }
  th, td { border-bottom-color: #333; }
  tr:hover td { background: #222; }
  h2 { border-bottom-color: #333; }
  .card { border-color: #333; }
  .meta, .card .l, .empty { color: #999; }
  .sev-Error { background: #4a1010; color: #f8b4b4; }
  .sev-Warning { background: #4a3810; color: #fce96a; }
  .sev-Info { background: #102a4a; color: #a4cafe; }
}
'@

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine('<!DOCTYPE html>')
    [void]$builder.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    [void]$builder.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$builder.AppendLine("<title>$(& $encode $Title)</title>")
    [void]$builder.AppendLine("<style>$style</style>")
    [void]$builder.AppendLine('</head><body>')
    [void]$builder.AppendLine("<h1>$(& $encode $Title)</h1>")

    $site = if ($Item.Count -gt 0 -and $Item[0].PSObject.Properties.Name -contains 'SiteUrl') {
        $Item[0].SiteUrl
    }
    else {
        $script:O365State.SiteUrl
    }

    [void]$builder.AppendLine(
        "<p class=""meta"">Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &middot; " +
        "$(& $encode $site) &middot; $($Item.Count) row(s)</p>"
    )

    if ($Item.Count -eq 0) {
        [void]$builder.AppendLine('<div class="empty">Nothing to report. No findings were produced.</div>')
        [void]$builder.AppendLine('</body></html>')
        return $builder.ToString()
    }

    if ($isFindingReport) {
        $bySeverity = $Item | Group-Object Severity

        [void]$builder.AppendLine('<div class="summary">')
        foreach ($severity in 'Error', 'Warning', 'Info') {
            $count = @($bySeverity | Where-Object Name -eq $severity | Select-Object -ExpandProperty Count)
            $count = if ($count) { $count } else { 0 }
            [void]$builder.AppendLine(
                "<div class=""card""><span class=""n"">$count</span><span class=""l"">$severity</span></div>"
            )
        }
        [void]$builder.AppendLine('</div>')

        foreach ($severity in 'Error', 'Warning', 'Info') {
            $group = @($Item | Where-Object Severity -eq $severity)
            if ($group.Count -eq 0) { continue }

            [void]$builder.AppendLine(
                "<h2><span class=""sev sev-$severity"">$severity</span> &mdash; $($group.Count) finding(s)</h2>"
            )
            [void]$builder.AppendLine('<table><thead><tr><th>Rule</th><th>List</th><th>Target</th><th>Message</th></tr></thead><tbody>')

            foreach ($finding in ($group | Sort-Object RuleId, Target)) {
                [void]$builder.AppendLine(
                    '<tr>' +
                    "<td><code>$(& $encode $finding.RuleId)</code></td>" +
                    "<td>$(& $encode $finding.List)</td>" +
                    "<td class=""wrap"">$(& $encode $finding.Target)</td>" +
                    "<td>$(& $encode $finding.Message)</td>" +
                    '</tr>'
                )
            }

            [void]$builder.AppendLine('</tbody></table>')
        }
    }
    else {
        # Generic table: use the first object's properties as the columns.
        $columns = @($Item[0].PSObject.Properties.Name | Where-Object { $_ -ne 'PSTypeName' })

        [void]$builder.AppendLine('<table><thead><tr>')
        foreach ($column in $columns) {
            [void]$builder.AppendLine("<th>$(& $encode $column)</th>")
        }
        [void]$builder.AppendLine('</tr></thead><tbody>')

        foreach ($row in $Item) {
            [void]$builder.AppendLine('<tr>')
            foreach ($column in $columns) {
                [void]$builder.AppendLine("<td class=""wrap"">$(& $encode $row.$column)</td>")
            }
            [void]$builder.AppendLine('</tr>')
        }

        [void]$builder.AppendLine('</tbody></table>')
    }

    [void]$builder.AppendLine('</body></html>')
    return $builder.ToString()
}
