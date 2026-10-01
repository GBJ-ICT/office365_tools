<#
    The tools the double-click launcher (packaging/Office365-Tools.cmd) can run,
    and what build.ps1 -Task Package needs to know to hand one out.

    A launcher with no tool of its own goes straight into the only one listed
    here, or shows a menu when there are several. A launcher built for one tool
    (build.ps1 -Task Package -Tool <Name>) runs that one and never shows the
    rest, so a tool added later does not turn up on the desktop of someone who
    was only ever sent the first.

    Adding a tool: write its entry script and settings template, add an entry
    below, push. Launchers already handed out fetch this file on their next run.

    Every entry script takes
      -SettingsPath  the settings file beside the launcher
      -ReportFolder  where reports go, one subfolder per run
      -Folder        a folder dropped onto the launcher, when there was one
      -NoPrompt      never ask anything -- the package self-test uses it
    runs under Windows PowerShell 5.1, and exits 0 (nothing to report),
    1 (findings) or 2 (a setup problem). Copies of the launcher already handed
    out depend on that; tests/Unit/Launcher.Tests.ps1 holds every entry to it.

    This file is read as data, never run: plain values only.
#>
@{
    Tools = @(
        @{
            # Stable: launchers built for this tool are pinned to this name.
            Name        = 'UploadCheck'
            Title       = 'Upload checker'
            Description = 'Check a folder before uploading it to SharePoint, or check that an upload arrived.'

            Entry       = 'packaging/Start-UploadCheck.ps1'

            # The template. The copy people edit lives beside the launcher,
            # under the same file name.
            Settings    = 'packaging/upload-check.xml'

            ReadMe      = 'packaging/READ-ME-FIRST.txt'

            # What the launcher is called in a ZIP built for this tool alone.
            Launcher    = 'Check-Upload.cmd'

            # Filled in by build.ps1 -ProfileName from config/profiles.json:
            # element in the settings file = property of the profile.
            Prefill     = @{
                Destination = 'siteUrl'
                ClientId    = 'clientId'
            }
        }
    )
}
