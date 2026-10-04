<#
.SYNOPSIS
    Internal: renders objects as a self-contained HTML report.
.DESCRIPTION
    Produces a single file with no external references, so it survives being
    e-mailed or dropped on a file share. Findings get a summary and severity
    grouping; folder comparisons get a synchronisation view, every file with
    its status and a tick box per status to show or hide it; anything else
    falls back to a plain table.

    The tick boxes filter with CSS alone (:has), so they work in a page whose
    scripts a mail client or a locked-down browser would block.

    All values are HTML-encoded. Findings contain file names and paths straight
    from the tenant, and a file legitimately named 'Q1 <draft>.docx' would
    otherwise corrupt the page.
.PARAMETER Item
    Objects to render.
.PARAMETER Title
    Page heading.
.PARAMETER Summary
    Ordered name/value pairs describing the run, rendered under the heading.
    A report with no findings is otherwise a blank page that cannot be told
    apart from a broken tool -- this is what says *what was checked*.
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
        [string]$Title = 'office365_tools report',

        [Parameter()]
        [System.Collections.IDictionary]$Summary
    )

    $encode = { param($Value) [System.Net.WebUtility]::HtmlEncode([string]$Value) }

    $isFindingReport = $Item.Count -gt 0 -and ($Item[0].PSObject.TypeNames -contains 'Office365Tools.Finding')
    $isComparisonReport = $Item.Count -gt 0 -and ($Item[0].PSObject.TypeNames -contains 'Office365Tools.FolderComparison')

    # How each comparison status reads, in the order the tick boxes appear.
    # The arrows are a synchronisation tool's: which way a copy would go to
    # put it right.
    $comparisonStatus = [ordered]@{
        MissingRemote = @{ Symbol = '&rarr;'; Label = 'Missing in SharePoint' }
        MissingLocal  = @{ Symbol = '&larr;'; Label = 'Missing on this computer' }
        LocalNewer    = @{ Symbol = '&rarr;'; Label = 'Newer on this computer' }
        RemoteNewer   = @{ Symbol = '&larr;'; Label = 'Newer in SharePoint' }
        SizeDiffers   = @{ Symbol = '&ne;'; Label = 'Different size' }
        Match         = @{ Symbol = '='; Label = 'Synchronised' }
    }

    $formatSize = {
        param($Bytes)
        if ($null -eq $Bytes) { return '' }
        if ($Bytes -lt 1KB) { return "$Bytes B" }
        if ($Bytes -lt 1MB) { return '{0:N1} KB' -f ($Bytes / 1KB) }
        if ($Bytes -lt 1GB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
        return '{0:N2} GB' -f ($Bytes / 1GB)
    }

    # Rounded for reading, exact on hover -- and exact outright on a row that
    # is there because the sizes differ, which rounding would hide: 5,242,880
    # and 5,251,072 bytes are both "5.0 MB".
    $sizeCell = {
        param($Bytes, [bool]$Exact)
        if ($null -eq $Bytes) { return '<td class="num"></td>' }
        $shown = if ($Exact) { '{0:N0} B' -f $Bytes } else { & $formatSize $Bytes }
        "<td class=""num"" title=""$('{0:N0}' -f $Bytes) bytes"">$(& $encode $shown)</td>"
    }

    # Stored in UTC, shown in the reader's own time.
    $formatDate = {
        param($Value)
        if ($Value -isnot [datetime]) { return '' }
        $Value.ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    }

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

.runsummary { border-collapse: collapse; margin: 1rem 0 1.5rem; }
.runsummary th { text-align: left; padding: 0.2rem 1.5rem 0.2rem 0; font-weight: 600; vertical-align: top; white-space: nowrap; }
.runsummary td { padding: 0.2rem 0; }

.toggles { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
.toggle { cursor: pointer; user-select: none; border-left-width: 4px; }
.toggle input { margin: 0 .4rem 0 0; vertical-align: middle; }
.hint { color: #666; font-size: .8rem; margin: 0 0 1.5rem; }
.st { display: inline-block; padding: .1rem .5rem; border-radius: 3px;
      font-size: .8rem; font-weight: 600; white-space: nowrap; }
td.num { text-align: right; white-space: nowrap; }
td.date { white-space: nowrap; }
th.side { text-align: center; }
.st-Match { background: #def7ec; color: #03543f; border-color: #31c48d; }
.st-MissingRemote, .st-MissingLocal { background: #fde8e8; color: #9b1c1c; border-color: #f05252; }
.st-RemoteNewer { background: #e1effe; color: #1e429f; border-color: #3f83f8; }
.st-LocalNewer, .st-SizeDiffers { background: #fdf6b2; color: #8e4b10; border-color: #e3a008; }
.toggle.st-Match, .toggle.st-MissingRemote, .toggle.st-MissingLocal,
.toggle.st-RemoteNewer, .toggle.st-LocalNewer, .toggle.st-SizeDiffers { background: transparent; color: inherit; }
@media (prefers-color-scheme: dark) {
  .hint { color: #999; }
  .st-Match { background: #0f3d2b; color: #84e1bc; }
  .st-MissingRemote, .st-MissingLocal { background: #4a1010; color: #f8b4b4; }
  .st-RemoteNewer { background: #102a4a; color: #a4cafe; }
  .st-LocalNewer, .st-SizeDiffers { background: #4a3810; color: #fce96a; }
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

    if ($Summary -and $Summary.Count -gt 0) {
        [void]$builder.AppendLine('<table class="runsummary">')
        foreach ($key in $Summary.Keys) {
            [void]$builder.AppendLine(
                "<tr><th>$(& $encode $key)</th><td>$(& $encode $Summary[$key])</td></tr>")
        }
        [void]$builder.AppendLine('</table>')
    }

    if ($Item.Count -eq 0) {
        [void]$builder.AppendLine('<div class="empty">Nothing to report. Everything checked above was fine.</div>')
        [void]$builder.AppendLine('</body></html>')
        return $builder.ToString()
    }

    if ($isComparisonReport) {
        $counts = @{}
        foreach ($row in $Item) {
            $counts[$row.Status] = 1 + [int]$counts[$row.Status]
        }

        # The three a reader always wants a number for, even when it is 0 --
        # "0 missing" is the answer, not an absence of one. The others only
        # exist when their comparison was switched on.
        $shown = @($comparisonStatus.Keys | Where-Object {
                $_ -in 'Match', 'MissingRemote', 'MissingLocal' -or $counts[$_]
            })

        $filter = [System.Text.StringBuilder]::new()
        [void]$builder.AppendLine('<div class="toggles">')
        foreach ($status in $shown) {
            $look = $comparisonStatus[$status]
            $count = [int]$counts[$status]
            [void]$builder.AppendLine(
                "<label class=""card toggle st-$status""><span class=""n"">$count</span>" +
                "<span class=""l""><input type=""checkbox"" id=""show-$status"" checked>" +
                "$($look.Symbol) $($look.Label)</span></label>")
            [void]$filter.Append("body:has(#show-${status}:not(:checked)) tr.st-$status { display: none; } ")
        }
        [void]$builder.AppendLine('</div>')
        [void]$builder.AppendLine("<style>$($filter.ToString())</style>")
        [void]$builder.AppendLine('<p class="hint">Untick a box to hide those files.</p>')

        [void]$builder.AppendLine(
            '<table><thead>' +
            '<tr><th rowspan="2">Status</th><th rowspan="2">File</th>' +
            '<th class="side" colspan="2">On this computer</th><th class="side" colspan="2">In SharePoint</th></tr>' +
            '<tr><th>Size</th><th>Modified</th><th>Size</th><th>Modified</th></tr>' +
            '</thead><tbody>')

        # Sorted by path, so a folder's files sit together as they do in a
        # file manager, whatever their status.
        $ordered = $Item | Sort-Object { $_.RelativePath }

        foreach ($row in $ordered) {
            $look = $comparisonStatus[[string]$row.Status]
            $badge = if ($look) { "$($look.Symbol) $($look.Label)" } else { & $encode $row.Status }
            $exact = $row.Status -eq 'SizeDiffers'

            [void]$builder.AppendLine(
                "<tr class=""st-$(& $encode $row.Status)"">" +
                "<td><span class=""st st-$(& $encode $row.Status)"">$badge</span></td>" +
                "<td class=""wrap"">$(& $encode $row.RelativePath)</td>" +
                (& $sizeCell $row.LocalSize $exact) +
                "<td class=""date"">$(& $encode (& $formatDate $row.LocalModified))</td>" +
                (& $sizeCell $row.RemoteSize $exact) +
                "<td class=""date"">$(& $encode (& $formatDate $row.RemoteModified))</td>" +
                '</tr>')
        }

        [void]$builder.AppendLine('</tbody></table>')
    }
    elseif ($isFindingReport) {
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
