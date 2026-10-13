@{
    # Messages of the upload checker's launcher, English. One key per message;
    # every key exists in both languages (tests/Unit/Language.Tests.ps1 checks
    # that). {0}, {1} are placeholders and must appear in both languages. A
    # value of several lines is shown one line to a line.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Upload.SignIn.Missing.Title'        = 'Checking what arrived means signing in, and I am missing the details for that.'

    'Upload.SignIn.Missing.Needed'       = 'Still needed:
'

    'Upload.SignIn.Missing.Destination'  = '    <Destination>   the address of the folder in SharePoint, copied
                    from your browser (put it in upload-check.xml)'

    'Upload.SignIn.Missing.ClientId'     = '    Application ID  the application your organisation uses to sign in.
                    Looked for, in this order:
                      1. <ClientId> in upload-check.xml
                      2. the environment variable gbj_client_id
                      3. the default profile in config\profiles.json'

    'Upload.SignIn.Missing.Footer'       = '
The address you can fetch yourself: open the folder in SharePoint
and copy what is in the address bar. The application ID is one line
that whoever sent you this package has. Until then, option 1 (checking
the folder before uploading) works without any of it.'

    'Upload.ClientId.Found'              = 'Application ID: {0}'
    'Upload.ClientId.From.Settings'      = 'from upload-check.xml'
    'Upload.ClientId.From.Environment'   = 'from the environment variable gbj_client_id'
    'Upload.ClientId.From.Profile'       = 'from the default profile in config\profiles.json'

    'Setup.Missing.Title'                = 'Part of the upload checker is missing.'
    'Setup.Missing.Body'                 = 'Not found: {0}

If you were sent a ZIP with everything in it, it was probably opened
rather than extracted: extract the whole folder and start it from
there. Otherwise just start it again; it fetches a fresh copy.'

    'Settings.Unreadable.Title'          = '{0} could not be read.'
    'Settings.Unreadable.Body'           = '{0}

Something in the file is malformed - usually a missing angle bracket,
or a setting whose closing tag does not match its opening tag.
Open it in Notepad and look for that, or delete the file: the next
run puts a fresh one in its place.'

    'Settings.WrongFile.Title'           = '{0} is not an upload checker settings file.'
    'Settings.WrongFile.Body'            = 'It has to start with <UploadCheck> and end with </UploadCheck>.'

    'Settings.Retired'                   = '{0} in {1} does nothing any more; you can delete that line.'

    'Settings.Obsolete.Title'            = 'This settings file names the target the old way.'
    'Settings.Obsolete.Body'             = 'No longer used: {0}

All three have been replaced by one setting, which you fill in by
copying rather than by typing:

    <Destination>  open the folder in SharePoint, copy the whole
                   address out of your browser, paste it in

The address says the site, the library and the folder together, so
they cannot disagree with each other -- and it carries the channel
folder a Teams site hides, which is what typing gets wrong.

Delete those lines, add a <Destination> line, and run this again.
A fresh upload-check.xml shows the shape of it: rename yours, and
the next run puts a new one beside it.'

    'Settings.Unknown.Title'             = 'There is a setting in the file that I do not recognise.'
    'Settings.Unknown.Body'              = 'Unknown: {0}

Known settings: {1}
Check the spelling - the names are case-sensitive.'

    'Settings.NotNumber.Title'           = 'The setting <{0}> has to be a whole number.'
    'Settings.NotBoolean.Title'          = 'The setting <{0}> has to be true or false.'
    'Settings.Mode.Title'                = 'The setting <Mode> has to be PreFlight, Verify, Both or ask.'
    'Settings.CurrentValue'              = 'It currently says: {0}'

    'Settings.Language.Title'            = 'The language has to be en, de or auto.'
    'Settings.Language.Argument'         = 'It currently says: {0}
It was given with -Language.'
    'Settings.Language.File'             = 'It currently says: {0}
It is set by <Language> in upload-check.xml.'

    'Prompt.YesNo.DefaultYes'            = '[Y/n]'
    'Prompt.YesNo.DefaultNo'             = '[y/N]'

    'Upload.Heading'                     = 'Upload checker'
    'Upload.Folder.Intro'                = 'A window will open. Pick the folder you are uploading.'
    'Upload.Folder.Question'             = 'Which folder are you uploading to SharePoint?'
    'Upload.Folder.Shown'                = 'Folder:  {0}'
    'Upload.Folder.None.Title'           = 'No folder was chosen, so there is nothing to check.'
    'Upload.Folder.None.Body'            = 'Start it again and pick a folder, or drag a folder onto it.'
    'Upload.Folder.Missing.Title'        = 'That folder does not exist.'
    'Upload.Folder.Missing.Body'         = 'Looked for: {0}

If you typed it, check for a typo. If you pasted it, make sure the
whole path came along.'

    'Upload.Menu.Title'                  = 'What would you like to do?'
    'Upload.Menu.Option1'                = '    1) Check this folder before I upload it        (no sign-in)'
    'Upload.Menu.Option2'                = '    2) I uploaded it already - did everything arrive?  (sign-in)'
    'Upload.Menu.Option3'                = '    3) Both'
    'Upload.Menu.Prompt'                 = 'Number [1]'

    'Upload.NextStep.FromFile'           = 'Once it is uploaded, set Mode in upload-check.xml to ask and start this again to check that everything arrived.'
    'Upload.NextStep.FromMenu'           = 'Once it is uploaded, start this again and choose 2 to check that everything arrived.'

    'Upload.Destination.Shown'           = 'Destination: {0}'

    'Upload.Pwsh.Missing.Title'          = 'PowerShell 7 is not installed on this computer.'
    'Upload.Pwsh.Missing.Body'           = 'It is a free Microsoft download, and it is the only thing missing.

Install it once: open the Start menu, type cmd, press Enter, and paste

    winget install --id Microsoft.PowerShell

or download it from https://aka.ms/powershell-release
Then start this again.'

    'Upload.Pnp.Title'                   = 'Signing in needs one more component: PnP.PowerShell.'
    'Upload.Pnp.Body'                    = 'It is a Microsoft-published PowerShell module, about 100 MB,
installed once for your account only. It needs internet access.'
    'Upload.Pnp.Question'                = 'Install it now? (takes a few minutes)'
    'Upload.Pnp.Declined.Title'          = 'Cannot check what arrived without signing in.'
    'Upload.Pnp.Declined.Body'           = 'Option 1 - checking the folder before you upload - still works,
and needs nothing extra. Start this again and pick it.

To install the component later, from PowerShell 7:

    Install-Module PnP.PowerShell -Scope CurrentUser'
    'Upload.Pnp.Installing'              = 'Installing. This takes a few minutes and says nothing while it works...'
    'Upload.Pnp.Failed.Title'            = 'The component could not be installed.'
    'Upload.Pnp.Failed.Body'             = 'This is usually no internet access, or a company policy that
blocks installing PowerShell modules. Show this to whoever sent
you the package.

Option 1 - checking the folder before you upload - still works.'
    'Upload.Pnp.Installed'               = 'Installed.'

    'Common.Ok'                          = 'OK'
    'Common.Cancel'                      = 'Cancel'

    'Upload.Window.Failed'               = '(Could not open a window: {0})'
    'Upload.FolderWindow.Failed'         = '(Could not open a folder window: {0})'
    'Upload.Folder.Console.Prompt'       = 'Folder'

    'Upload.Address.Title'               = 'Where in SharePoint did the files go?'
    'Upload.Address.Explain'             = 'Open that folder in SharePoint, copy the address out of your browser''s
address bar, and paste it here. Not the "Copy link" button: that link
names no folder.'
    'Upload.Address.Problem.Empty'       = 'Paste the address first. Cancel stops the run; nothing is checked and nothing is changed.'
    'Upload.Address.Problem.NotAddress'  = 'That does not look like a web address. It has to start with https://'
    'Upload.Address.Problem.SharingLink' = 'That is a sharing link, and it names no folder. Use the browser address bar.'
    'Upload.Address.Console.Help'        = 'Copy the address out of your browser and paste it here.
Right-click pastes into this window.'
    'Upload.Address.Console.Prompt'      = 'Address'

    'Language.Name.en'                   = 'English'
    'Language.Name.de'                   = 'Deutsch'
    'Language.Picker.Line'               = 'Language: {0}   (L = change / ändern)'
    'Language.Picker.Title'              = 'Which language?'
    'Language.Picker.Option1'            = '    1) English'
    'Language.Picker.Option2'            = '    2) Deutsch'
    'Language.Picker.Option3'            = '    3) Follow Windows'
    'Language.Picker.Prompt'             = 'Number, or Enter to keep it'
}
