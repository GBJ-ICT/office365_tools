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
}
