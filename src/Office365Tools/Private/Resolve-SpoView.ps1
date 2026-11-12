<#
.SYNOPSIS
    Internal: finds a stored view of a list by its title or its GUID.
.DESCRIPTION
    People know a view by the name in the view picker; SharePoint knows it by a
    GUID. This accepts either and always hands back both, so the name someone
    typed is mapped to the id in one place and everything after it works from
    the view itself.

    The views are read once and matched here rather than asked for one by one,
    so the title match is case-insensitive and an unknown name can be answered
    with the list of views that do exist -- which is what a typo needs.

    With no -Identity it returns the views a person would choose between: the
    stored ones, not the hidden ones and not another person's personal view,
    the list's default view first.
.PARAMETER List
    The list, as returned by Resolve-SpoList.
.PARAMETER Identity
    Title or GUID of the view. Omit to get every selectable view.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.ListView': Title, Id,
    DefaultView, Hidden, ViewFields and ViewQuery.
.EXAMPLE
    $view = Resolve-SpoView -List $list -Identity 'Open tasks'
.EXAMPLE
    Resolve-SpoView -List $list | Select-Object Title, Id
#>
function Resolve-SpoView {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        $List,

        [Parameter(Position = 1)]
        [string]$Identity
    )

    # A property SharePoint did not load throws when read; for the flags
    # that is the same as not set.
    $flag = {
        param($View, [string]$Name)
        try { return [bool]$View.$Name } catch { return $false }
    }

    $views = @(Get-PnPView -List $List | ForEach-Object {
            [pscustomobject]@{
                PSTypeName  = 'Office365Tools.ListView'
                Title       = [string]$_.Title
                Id          = [guid]$_.Id
                DefaultView = (& $flag $_ 'DefaultView')
                Hidden      = (& $flag $_ 'Hidden')
                Personal    = (& $flag $_ 'PersonalView')
                ViewFields  = @($_.ViewFields)
                ViewQuery   = [string]$_.ViewQuery
            }
        })

    $selectable = @($views |
            Where-Object { -not $_.Hidden -and -not $_.Personal } |
            Sort-Object @{ Expression = { -not $_.DefaultView } }, Title)

    if (-not $Identity) { return $selectable }

    $wanted = $Identity.Trim()
    $guid = [guid]::Empty

    # Wrapped as a whole: an if whose branch finds nothing gives $null, not an
    # empty array, and the count below would fail under strict mode.
    $found = @(if ([guid]::TryParse($wanted.Trim('{', '}'), [ref]$guid)) {
            $views | Where-Object { $_.Id -eq $guid }
        }
        else {
            $views | Where-Object { $_.Title -eq $wanted }
        })

    if ($found.Count -eq 0) {
        throw [System.InvalidOperationException]::new(
            (Get-O365String 'Pdf.Export.ViewNotFound' $Identity $List.Title (($selectable | ForEach-Object { $_.Title }) -join ', '))
        )
    }

    return $found[0]
}
