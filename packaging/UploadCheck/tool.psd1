<#
    The upload checker, as the double-click launcher sees it. The folder's
    name, UploadCheck, is the tool's name: launchers built for this tool are
    pinned to it, so it stays.

    File names are relative to this folder. What a tool.psd1 holds, and what
    the entry script has to accept, is in packaging/README.md.

    Read as data, never run: plain values only.
#>
@{
    Title       = 'Upload checker'
    Description = 'Check a folder before uploading it to SharePoint, or check that an upload arrived.'

    Entry       = 'Start-UploadCheck.ps1'

    # The template. The copy people edit lives beside the launcher, under the
    # same file name.
    Settings    = 'upload-check.xml'

    ReadMe      = 'READ-ME-FIRST.txt'

    # What the launcher is called in a ZIP built for this tool.
    Launcher    = 'Check-Upload.cmd'

    # Filled in by build.ps1 -ProfileName from config/profiles.json:
    # element in the settings file = property of the profile.
    Prefill     = @{
        Destination = 'siteUrl'
        ClientId    = 'clientId'
    }
}
