<#
.SYNOPSIS
    Turns a SharePoint address copied from the browser into a site, a library
    and a folder.
.DESCRIPTION
    Nobody knows the server-relative path of the folder they just uploaded to.
    What they have is a browser tab. This takes the address out of that tab and
    works out the three things the commands here need:

        SiteUrl       https://contoso.sharepoint.com/sites/team
        Library       Freigegebene Dokumente
        RemoteFolder  General/Test

    The folder comes out of the view's id= parameter when there is one, which
    is the reason to prefer this over asking someone to type the path: on a
    Teams site the files live under a channel folder, so what reads as "Test"
    in the breadcrumb is really "General/Test", and that is the segment people
    leave out. The address always carries it.

    Nothing is contacted. This is string work, so it runs offline and before
    sign-in -- which is what lets the launcher show the target back to someone
    before they authenticate.

    An address it cannot make sense of is an error rather than a half-filled
    result, because a half-filled result is how a check ends up run against the
    wrong folder and reports every file as missing.

    Subsites cannot be recognised from the address alone: /sites/team/finance
    is a subsite on one tenant and a library named "finance" on another. Such
    an address parses as a library, and the library lookup after sign-in is
    what reports it.
.PARAMETER Address
    The address, as copied from the browser. Accepts a modern or classic
    library view, a folder path, or a bare site URL.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Address'.
.EXAMPLE
    ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fteam%2FShared%20Documents%2FGeneral%2FTest'

    SiteUrl      : https://contoso.sharepoint.com/sites/team
    Library      : Shared Documents
    RemoteFolder : General/Test
.EXAMPLE
    $target = ConvertFrom-SpoAddress $url
    Compare-SpoFolder -LocalPath C:\ToUpload -Library $target.Library -RemoteFolder $target.RemoteFolder
.LINK
    Compare-SpoFolder
#>
function ConvertFrom-SpoAddress {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Url', 'Destination')]
        [string]$Address
    )

    process {
        # Pasting from Explorer, Outlook or a chat window brings punctuation
        # along: quotes around the whole thing, angle brackets from a mail
        # client, a trailing full stop from a sentence.
        $text = $Address.Trim().Trim('"', "'", '<', '>').Trim()

        $uri = $null
        if (-not [uri]::TryCreate($text, [System.UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -notin 'http', 'https') {

            throw [System.ArgumentException]::new(
                "'$text' is not a web address. Open the folder in SharePoint and copy the whole " +
                'address from the browser, starting with https://')
        }

        if ($uri.Host -like '*teams.microsoft.com') {
            throw [System.ArgumentException]::new(
                'That is a Teams link, and it does not say where the files are. In Teams, open the ' +
                'Files tab, choose "Open in SharePoint", and copy the address from the browser there.')
        }

        # Sharing links -- https://contoso.sharepoint.com/:f:/s/team/Ex4kQ... --
        # are opaque tokens. Only the tenant can say what one points at, so the
        # honest answer is to ask for the other address rather than to guess.
        if ($uri.AbsolutePath -match '^/:[a-z]:/' -or $uri.AbsolutePath -like '*/guestaccess.aspx') {
            throw [System.ArgumentException]::new(
                'That is a sharing link ("Copy link"), which does not name the folder. Open the ' +
                'folder in SharePoint and copy the address out of the browser address bar instead.')
        }

        # The view's id= holds the real folder, fully spelled out. RootFolder=
        # is the same thing in the classic view. Either beats the visible path,
        # which stops at the library.
        $query = @{}
        foreach ($pair in ($uri.Query.TrimStart('?') -split '&')) {
            if (-not $pair) { continue }
            $split = $pair -split '=', 2
            if ($split.Count -eq 2) {
                $query[$split[0].ToLowerInvariant()] = $split[1]
            }
        }

        $raw = $null
        foreach ($name in 'id', 'rootfolder') {
            if ($query.ContainsKey($name) -and $query[$name]) {
                $raw = $query[$name]
                break
            }
        }

        $fromQuery = $null -ne $raw
        if (-not $fromQuery) { $raw = $uri.AbsolutePath }

        # %20 in the path, %2F between segments in the query. Both forms of
        # escaping come off the same way.
        $path = [uri]::UnescapeDataString($raw).Replace('\', '/').Trim('/')

        $segments = @($path -split '/' | Where-Object { $_ })

        # /Forms/AllItems.aspx is the view, not a folder in the library. It
        # only turns up when the address had no id=, i.e. the library root.
        $formsAt = [array]::IndexOf($segments, 'Forms')
        if ($formsAt -ge 0) {
            $segments = @($segments[0..($formsAt - 1)])
        }

        if ($segments -contains '_layouts') {
            throw [System.ArgumentException]::new(
                'That address is a SharePoint page rather than a folder. Open the library, click ' +
                'into the folder the files are in, and copy the address from there.')
        }

        # A page is never a folder, so a trailing .aspx is view machinery left
        # over from a URL that carried no id=.
        if ($segments.Count -gt 0 -and $segments[-1] -like '*.aspx') {
            $segments = @($segments[0..($segments.Count - 2)])
        }

        # Site collections live under /sites/, /teams/ (an older Teams-created
        # site) or /personal/ (OneDrive). Anything else is the root site, whose
        # libraries sit directly under the host.
        $siteDepth = if ($segments.Count -ge 2 -and $segments[0] -in 'sites', 'teams', 'personal') { 2 } else { 0 }

        $sitePath = if ($siteDepth -gt 0) { '/' + ($segments[0..($siteDepth - 1)] -join '/') } else { '' }
        $rest     = @($segments | Select-Object -Skip $siteDepth)

        $library      = if ($rest.Count -gt 0) { $rest[0] } else { $null }
        $remoteFolder = if ($rest.Count -gt 1) { ($rest | Select-Object -Skip 1) -join '/' } else { '' }

        [pscustomobject]@{
            PSTypeName         = 'Office365Tools.Address'
            Address            = $text
            SiteUrl            = "$($uri.Scheme)://$($uri.Authority)$sitePath"
            Library            = $library
            RemoteFolder       = $remoteFolder
            # The library root and the folder, server-relative. Between them
            # they are the target path a length check measures against -- known
            # from the address alone, with nothing signed in to ask.
            LibraryPath        = if ($library) { "$sitePath/$library" } else { $null }
            ServerRelativePath = if ($segments.Count -gt 0) { '/' + ($segments -join '/') } else { '/' }
            FolderIsCertain    = $fromQuery
        }
    }
}
