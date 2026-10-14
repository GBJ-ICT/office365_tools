@{
    # Messages of the tool menu (packaging/Start-Tool.ps1), English. One key per
    # message; every key exists in both languages (tests/Unit/Language.Tests.ps1
    # checks that). {0}, {1} are placeholders and must appear in both languages.
    # A value of several lines is shown one line to a line.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Menu.Heading'              = 'What would you like to do?'
    'Menu.Explain'              = 'Click one to start it. It runs in the window behind this one.'
    'Menu.Close'                = 'Close'
    'Menu.Language.Label'       = 'Language / Sprache:'
    'Menu.List.Prompt'          = 'Number [1]'
    'Menu.NothingChosen'        = 'Nothing chosen, so nothing was run.'
    'Menu.Window.Failed'        = '(Could not open a window: {0})'

    'Menu.From'                 = 'from {0}'
    'Menu.NotRelease'           = '(not a release)'

    'Menu.Created'              = 'Created {0} beside {1}. Your settings go in there;'
    'Menu.Created.Hint'         = 'open it in Notepad to fill them in. Until then, you are asked.'

    'Menu.ShowThis'             = 'Show this window to whoever sent you this file.'
    'Menu.Failed.Title'         = 'This stopped unexpectedly.'
    'Menu.None.Title'           = 'There are no tools in {0}, so there is nothing to run.'
    'Menu.Pinned.Missing.Title' = 'This launcher runs "{0}", and the copy it found does not have that.'
    'Menu.Pinned.Missing.Body'  = 'There is no {0} in
    {1}

Show this window to whoever sent you this file.'
}
