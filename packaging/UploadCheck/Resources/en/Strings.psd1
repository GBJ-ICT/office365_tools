@{
    # Messages of the upload checker's launcher, English. One key per message;
    # every key exists in both languages (tests/Unit/Language.Tests.ps1 checks
    # that). {0}, {1} are placeholders and must appear in both languages. A
    # value of several lines is shown one line to a line.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Upload.SignIn.Missing.Title'       = 'Checking what arrived means signing in, and I am missing the details for that.'

    'Upload.SignIn.Missing.Needed'      = 'Still needed:
'

    'Upload.SignIn.Missing.Destination' = '    <Destination>   the address of the folder in SharePoint, copied
                    from your browser (put it in upload-check.xml)'

    'Upload.SignIn.Missing.ClientId'    = '    Application ID  the application your organisation uses to sign in.
                    Looked for, in this order:
                      1. <ClientId> in upload-check.xml
                      2. the environment variable gbj_client_id
                      3. the default profile in config\profiles.json'

    'Upload.SignIn.Missing.Footer'      = '
The address you can fetch yourself: open the folder in SharePoint
and copy what is in the address bar. The application ID is one line
that whoever sent you this package has. Until then, option 1 (checking
the folder before uploading) works without any of it.'

    'Upload.ClientId.Found'             = 'Application ID: {0}'
    'Upload.ClientId.From.Settings'     = 'from upload-check.xml'
    'Upload.ClientId.From.Environment'  = 'from the environment variable gbj_client_id'
    'Upload.ClientId.From.Profile'      = 'from the default profile in config\profiles.json'

    'Setup.Missing.Title'               = 'Part of the upload checker is missing.'
    'Setup.Missing.Body'                = 'Not found: {0}

If you were sent a ZIP with everything in it, it was probably opened
rather than extracted: extract the whole folder and start it from
there. Otherwise just start it again; it fetches a fresh copy.'

    'Settings.Unreadable.Title'         = '{0} could not be read.'
    'Settings.Unreadable.Body'          = '{0}

Something in the file is malformed - usually a missing angle bracket,
or a setting whose closing tag does not match its opening tag.
Open it in Notepad and look for that, or delete the file: the next
run puts a fresh one in its place.'

    'Settings.WrongFile.Title'          = '{0} is not an upload checker settings file.'
    'Settings.WrongFile.Body'           = 'It has to start with <UploadCheck> and end with </UploadCheck>.'

    'Settings.Retired'                  = '{0} in {1} does nothing any more; you can delete that line.'

    'Settings.Obsolete.Title'           = 'This settings file names the target the old way.'
    'Settings.Obsolete.Body'            = 'No longer used: {0}

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

    'Settings.Unknown.Title'            = 'There is a setting in the file that I do not recognise.'
    'Settings.Unknown.Body'             = 'Unknown: {0}

Known settings: {1}
Check the spelling - the names are case-sensitive.'

    'Settings.NotNumber.Title'          = 'The setting <{0}> has to be a whole number.'
    'Settings.NotBoolean.Title'         = 'The setting <{0}> has to be true or false.'
    'Settings.Mode.Title'               = 'The setting <Mode> has to be PreFlight, Verify, Both or ask.'
    'Settings.CurrentValue'             = 'It currently says: {0}'

    'Settings.Language.Title'           = 'The language has to be en, de or auto.'
    'Settings.Language.Argument'        = 'It currently says: {0}
It was given with -Language.'
    'Settings.Language.File'            = 'It currently says: {0}
It is set by <Language> in upload-check.xml.'
}
