<#
    SharePoint list to PDF, as the double-click launcher sees it. The folder's
    name, ListToPdf, is the tool's name: launchers built for this tool are
    pinned to it, so it stays.

    File names are relative to this folder. What a tool.psd1 holds, and what
    the entry script has to accept, is in packaging/README.md.

    Read as data, never run: plain values only.
#>
@{
    Title       = 'SharePoint list to PDF'
    Description = 'Print a SharePoint list, or one of its views, to a PDF with all the text, links and people on it.'

    Entry       = 'Start-ListToPdf.ps1'

    # The template. The copy people edit lives beside the launcher, under the
    # same file name.
    Settings    = 'list-to-pdf.xml'

    ReadMe      = 'READ-ME-FIRST.txt'

    # What the launcher is called in a ZIP built for this tool.
    Launcher    = 'List-To-Pdf.cmd'

    # Filled in by build.ps1 -ProfileName from config/profiles.json:
    # element in the settings file = property of the profile.
    Prefill     = @{
        SiteUrl  = 'siteUrl'
        ClientId = 'clientId'
    }
}
