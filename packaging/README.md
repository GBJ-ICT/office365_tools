# packaging/

Tools for people who do not use PowerShell: they double-click a file and get
asked questions.

```
packaging/
  Office365-Tools.cmd        the launcher -- one file, shared by every tool
  Start-Tool.ps1             what the launcher hands over to: the menu, the settings, starting the tool
  UploadCheck/               one folder per tool; the folder name is the tool's name
    tool.psd1                what the launcher and build.ps1 need to know
    Start-UploadCheck.ps1    the entry script the launcher hands over to
    upload-check.xml         the settings template
    READ-ME-FIRST.txt        what the recipient reads
```

## Handing a tool out

```bash
pwsh ./build.ps1 -Task Package -Tool UploadCheck
```

The ZIP holds the launcher -- renamed after the tool, `Check-Upload.cmd`, and
pinned to it -- with the settings template and the read-me. A launcher built
for one tool reads only that tool's folder, so a mistake in another tool's
`tool.psd1` cannot stop it.

## Releasing

The launcher runs the newest **release** on GitHub: the newest tag named
`vX.Y` -- `v1.4`; not `v1.4.2`, not `v2`, not a branch. `v0.10` is newer than
`v0.9`. A push reaches nobody until it is tagged:

```bash
pwsh ./build.ps1 -Task Release
pwsh ./build.ps1 -Task Release -Version v1.0
```

That refuses a working tree with uncommitted changes, runs the analyzer and
the tests, and only then tags the commit and pushes the tag. Without
`-Version` it takes the next one: the newest release with its minor number
raised.

Each release is downloaded once, into `%LOCALAPPDATA%\office365_tools\vX.Y`,
and never again: do not move a tag, tag the next version. When GitHub cannot
be reached, the newest release already downloaded runs. The launcher does
this wherever it is started from -- code beside it, as in a checkout, is not
used.

To try a change before tagging it, start the checkout's own `Start-Tool.ps1`,
which is what the launcher hands over to:

```bash
powershell -ExecutionPolicy Bypass -File packaging/Start-Tool.ps1
```

## Changing the launcher

A launcher on someone's machine never changes, so `Office365-Tools.cmd` does
as little as it can: it fetches the newest release and hands over to
`Start-Tool.ps1` in it. Everything after that -- reading the `tool.psd1`
files, the menu, the settings file beside the launcher, starting the tool --
is in `Start-Tool.ps1`, and a release reaches everyone who already has a
launcher.

So change `Start-Tool.ps1`, not the `.cmd`, wherever you can. Two things to
keep:

- **Its parameters are a contract.** `-Root`, `-LauncherPath`, `-Tool` and
  `-Dropped` are what every launcher handed out passes. Add parameters with a
  default that does what an older launcher expects; never rename or remove
  one. `tests/Unit/Launcher.Tests.ps1` checks this.
- **It runs under Windows PowerShell 5.1** and stays plain ASCII, like the
  entry scripts.

Unless the launcher is pinned to one tool, `Start-Tool.ps1` opens a window with a button for
each -- its `Title` in bold, its `Description` under it -- and starts the one
clicked. Close or Esc runs nothing. Where no window can open (PowerShell 7,
no desktop), it falls back to a numbered list in the console.

Setting the environment variable `OFFICE365TOOLS_CONSOLE` to anything gives
the numbered list instead of the window, so it can be driven with its input
piped in.

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
| `-NoPrompt` | never passed by the launcher; for scheduled runs, which must not stop to ask |

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
The same goes for the menu itself, for launchers that hand over to
`Start-Tool.ps1`.
