<#
.SYNOPSIS
    Internal: builds the URL that opens a folder inside its library's view.
.DESCRIPTION
    A hyperlink to a Document Set is not a link to the folder's own URL. That
    address renders a bare folder listing with none of the library's columns,
    views, or Document Set welcome page. What SharePoint's own breadcrumbs use
    is the library's default view page with the folder passed as ?id=, and that
    is what a person following the link expects to land on.

    The id value is the folder's *server-relative* URL, percent-encoded whole
    -- separators included, so /sites/x/Lib/A B becomes %2Fsites%2Fx%2FLib%2FA%20B.
    EscapeDataString is the right encoder here rather than EscapeUriString:
    SharePoint round-trips parentheses and apostrophes in the encoded form, and
    a folder called "AVOR (Teil 6)" has both.

    Pure string handling on purpose, so the URL shape is unit testable without
    a tenant.
.PARAMETER SiteUrl
    Any absolute URL on the target tenant. Only its scheme and host are used,
    so the connected site URL is fine even for a library on another web.
.PARAMETER ViewUrl
    The library's default view page. Server-relative
    (/sites/cds/Management/Forms/Alle.aspx) or absolute; both are accepted
    because Get-PnPList reports the first and callers often hold the second.
.PARAMETER ServerRelativeUrl
    The Document Set folder's server-relative URL.
.OUTPUTS
    System.String
.EXAMPLE
    New-SpoDocumentSetReference -SiteUrl 'https://contoso.sharepoint.com/sites/cds' `
        -ViewUrl '/sites/cds/Management/Forms/AllItems.aspx' `
        -ServerRelativeUrl '/sites/cds/Management/Budget 2026'
#>
function New-SpoDocumentSetReference {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds a string. Nothing outside this process is touched.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteUrl,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$ViewUrl,

        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRelativeUrl
    )

    $view = if ($ViewUrl -match '^https?://') {
        $ViewUrl.TrimEnd('/')
    }
    else {
        $authority = ([uri]$SiteUrl).GetLeftPart([System.UriPartial]::Authority)
        '{0}/{1}' -f $authority.TrimEnd('/'), $ViewUrl.TrimStart('/')
    }

    '{0}?id={1}' -f $view, [uri]::EscapeDataString($ServerRelativeUrl)
}
