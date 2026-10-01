# packaging/

Tools for people who do not use PowerShell: they double-click a file and get
asked questions.

```
packaging/
  Office365-Tools.cmd        the launcher -- one file, shared by every tool
  UploadCheck/               one folder per tool; the folder name is the tool's name
    tool.psd1                what the launcher and build.ps1 need to know
    Start-UploadCheck.ps1    the entry script the launcher hands over to
    upload-check.xml         the settings template
    READ-ME-FIRST.txt        what the recipient reads
```

## Handing a tool out

```bash
pwsh ./build.ps1 -Task Package -Tool UploadCheck
pwsh ./build.ps1 -Task Package -Tool UploadCheck -Ref v0.7.0
pwsh ./build.ps1 -Task Package -Tool UploadCheck -IncludeCode
```

The ZIP holds the launcher -- renamed after the tool, `Check-Upload.cmd`, and
pinned to it -- with the settings template and the read-me. The launcher
downloads this repository from GitHub (`-Ref`, default `master`) each time it
runs and starts the tool from it. `-IncludeCode` puts the code in the ZIP
instead, for machines that cannot reach GitHub.

Each tool keeps its own copy of the download, in
`%LOCALAPPDATA%\office365_tools\<tool>\<ref>`. Tools do not share code on the
recipient's machine: a push that breaks one tool leaves every other tool on
the copy it already has. A launcher built for one tool also reads only that
tool's folder, so a mistake in another tool's `tool.psd1` cannot stop it.
With `-Ref` set to a tag, a tool stays on that version while the others
follow `master`.

## Adding a tool

Make a folder here named after the tool -- letters, digits and hyphens,
starting with a letter, never renamed afterwards, because launchers built
for the tool are pinned to that name. Put four files in it:

**`tool.psd1`** -- read as data, never run, so plain values only. File names
are relative to the folder.

```powershell
@{
    Title       = 'Create a team'                    # window title, menu entry
    Description = 'Create a Microsoft Team from a template.'
    Entry       = 'Start-CreateTeam.ps1'
    Settings    = 'create-team.xml'                  # template; the copy people edit sits beside the launcher
    ReadMe      = 'READ-ME-FIRST.txt'
    Launcher    = 'Create-Team.cmd'                  # what the launcher is called in this tool's ZIP
    Prefill     = @{ ClientId = 'clientId' }         # optional: settings element = config/profiles.json property
}
```

**The entry script** runs under Windows PowerShell 5.1 -- no ternaries, no
`??`, no `-Parallel` -- so it can say PowerShell 7 is missing instead of
failing to start. It takes:

| Parameter | What the launcher passes |
|---|---|
| `-SettingsPath` | the settings file beside the launcher |
| `-ReportFolder` | `Reports\` beside the launcher; one subfolder per run |
| `-Folder` | a folder dropped onto the launcher, when there was one |
| `-NoPrompt` | never passed by the launcher; `build.ps1 -IncludeCode` runs every tool with it as a self-test |

It exits 0 (nothing to report), 1 (findings) or 2 (a setup problem). The repository
root is two levels up from the entry script. `Start-UploadCheck.ps1` is a
worked example: how to read the settings, report a problem in plain language,
check for PowerShell 7 and PnP.PowerShell, and hand over to a script under
`scripts/`.

**The settings template** and **the read-me** are what the recipient sees.
Settings file names have to differ between tools: the ZIP without `-Tool`
puts all of them side by side.

`tests/Unit/Launcher.Tests.ps1` checks every tool folder against this:
launchers already handed out depend on it, and changing it breaks all of
them at once. A push is all it takes to ship a new tool to people who
already have `Office365-Tools.cmd`; to anyone else, send them its ZIP.
