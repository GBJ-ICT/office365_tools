<#
.SYNOPSIS
    Lists the stored views of a list, or finds one by its name or id.
.DESCRIPTION
    A view is a stored selection: which columns, in which order, filtered and
    sorted how. This lists the ones a person can choose between, so a tool can
    offer them, and maps the name someone typed to the view's id.

    Hidden views and other people's personal views are left out. The list's
    default view comes first.
.PARAMETER Library
    Title, URL name, or GUID of the list.
.PARAMETER View
    Title or GUID of one view. Omit to list them all.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.ListView': Title, Id,
    DefaultView, Hidden, ViewFields and ViewQuery.
.EXAMPLE
    Get-SpoListView -Library 'Aufgaben und Dienste'
    The views a person can pick from, the default one first.
.EXAMPLE
    Get-SpoListView -Library Dienste -View 'Saison 2026/27' | Select-Object Title, Id
    Maps a view's name to its id.
.LINK
    Export-SpoListPdf
#>
function Get-SpoListView {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter(Position = 1)]
        [string]$View
    )

    Assert-SpoConnection | Out-Null

    $list = Resolve-SpoList -Identity $Library

    Resolve-SpoView -List $list -Identity $View
}
