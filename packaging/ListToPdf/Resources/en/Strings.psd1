@{
    # Messages of "SharePoint list to PDF", English: the launch stub
    # (Start-ListToPdf.ps1) and the script that prints (Invoke-ListToPdf.ps1).
    # One key per message; every key exists in both languages
    # (tests/Unit/Language.Tests.ps1 checks that). {0}, {1} are placeholders and
    # must appear in both languages. A value of several lines is shown one line
    # to a line.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Tool.ListToPdf.Title'               = 'SharePoint list to PDF'
    'Tool.ListToPdf.Description'         = 'Print a SharePoint list, or one of its views, to a PDF with all the text, links and people on it.'

    # -- Start-ListToPdf.ps1 ---------------------------------------------------
    'ListPdf.Prompt.YesNo.DefaultYes'    = '[Y/n]'
    'ListPdf.Prompt.YesNo.DefaultNo'     = '[y/N]'

    'ListPdf.Setup.Missing.Title'        = 'Part of the tool is missing.'
    'ListPdf.Setup.Missing.Body'         = 'Not found: {0}

If you were sent a ZIP with everything in it, it was probably opened
rather than extracted: extract the whole folder and start it from
there. Otherwise just start it again; it fetches a fresh copy.'

    'ListPdf.Settings.Unreadable.Title'  = '{0} could not be read.'
    'ListPdf.Settings.Unreadable.Body'   = '{0}

Something in the file is malformed - usually a missing angle bracket,
or a setting whose closing tag does not match its opening tag.
Open it in Notepad and look for that, or delete the file: the next
run puts a fresh one in its place.'

    'ListPdf.Settings.WrongFile.Title'   = '{0} is not a settings file of this tool.'
    'ListPdf.Settings.WrongFile.Body'    = 'It has to start with <ListToPdf> and end with </ListToPdf>.'

    'ListPdf.Settings.Unknown.Title'     = 'There is a setting in the file that I do not recognise.'
    'ListPdf.Settings.Unknown.Body'      = 'Unknown: {0}

Known settings: {1}
Check the spelling - the names are case-sensitive.'

    'ListPdf.Settings.Choice.Title'      = 'The setting <{0}> has to be one of: {1}.'
    'ListPdf.Settings.CurrentValue'      = 'It currently says: {0}'

    'ListPdf.Settings.Language.Title'    = 'The language has to be en, de or auto.'
    'ListPdf.Settings.Language.Argument' = 'It currently says: {0}
It was given with -Language.'
    'ListPdf.Settings.Language.File'     = 'It currently says: {0}
It is set by <Language> in list-to-pdf.xml.'

    'ListPdf.Site.Question'              = 'Which SharePoint site is the list on?'
    'ListPdf.Site.Help'                  = 'Copy the address out of your browser and paste it here. It can be the
address of the site (https://contoso.sharepoint.com/sites/team) or of a
page in it, such as the list you want: the site is taken from it, and the
list too if it names one. Right-click pastes into this window.'
    'ListPdf.Site.Prompt'                = 'Address'
    'ListPdf.Site.Shown'                 = 'Site:  {0}'

    'ListPdf.SignIn.Missing.Title'       = 'Printing a list means signing in, and I am missing the details for that.'
    'ListPdf.SignIn.Missing.Needed'      = 'Still needed:
'
    'ListPdf.SignIn.Missing.SiteUrl'     = '    <SiteUrl>       the address of the SharePoint site, starting with
                    https:// (put it in list-to-pdf.xml)'
    'ListPdf.SignIn.Missing.ClientId'    = '    Application ID  the application your organisation uses to sign in.
                    Looked for, in this order:
                      1. <ClientId> in list-to-pdf.xml
                      2. the environment variable gbj_client_id
                      3. the default profile in config\profiles.json'
    'ListPdf.SignIn.Missing.Footer'      = '
The address you can fetch yourself: open the site in your browser and
copy what is in the address bar. The application ID is one line that
whoever sent you this package has.'

    'ListPdf.ClientId.Found'             = 'Application ID: {0}'
    'ListPdf.ClientId.From.Settings'     = 'from list-to-pdf.xml'
    'ListPdf.ClientId.From.Environment'  = 'from the environment variable gbj_client_id'
    'ListPdf.ClientId.From.Profile'      = 'from the default profile in config\profiles.json'

    'ListPdf.Pwsh.Missing.Title'         = 'PowerShell 7 is not installed on this computer.'
    'ListPdf.Pwsh.Missing.Body'          = 'It is a free Microsoft download, and it is the only thing missing.

Install it once: open the Start menu, type cmd, press Enter, and paste

    winget install --id Microsoft.PowerShell

or download it from https://aka.ms/powershell-release
Then start this again.'

    'ListPdf.Pnp.Title'                  = 'Signing in needs one more component: PnP.PowerShell.'
    'ListPdf.Pnp.Body'                   = 'It is a Microsoft-published PowerShell module, about 100 MB,
installed once for your account only. It needs internet access.'
    'ListPdf.Pnp.Question'               = 'Install it now? (takes a few minutes)'
    'ListPdf.Pnp.Declined.Title'         = 'Cannot print a list without signing in.'
    'ListPdf.Pnp.Declined.Body'          = 'To install the component later, from PowerShell 7:

    Install-Module PnP.PowerShell -Scope CurrentUser'
    'ListPdf.Pnp.Installing'             = 'Installing. This takes a few minutes and says nothing while it works...'
    'ListPdf.Pnp.Failed.Title'           = 'The component could not be installed.'
    'ListPdf.Pnp.Failed.Body'            = 'This is usually no internet access, or a company policy that
blocks installing PowerShell modules. Show this to whoever sent
you the package.'
    'ListPdf.Pnp.Installed'              = 'Installed.'

    # -- Invoke-ListToPdf.ps1 --------------------------------------------------
    'ListPdf.Run.Choice.Prompt'          = 'Number [{0}]'
    'ListPdf.Run.Choice.Invalid'         = 'Please type a number between 1 and {0}.'

    'ListPdf.Run.Folder.Title'           = 'The PDF cannot be written to {0}.'
    'ListPdf.Run.Folder.Hint'            = 'Choose another folder with <OutputFolder> in list-to-pdf.xml, or check that you may write there.'

    'ListPdf.Run.Connecting'             = 'Signing in to {0} ...'

    'ListPdf.Run.Address.Site'           = 'The address is inside the site {0}, which is what is signed in to.'

    'ListPdf.Run.Address.List'           = 'It also names the list ''{0}'', so you are not asked which list.'

    'ListPdf.Run.Address.Sharing'        = 'That is a sharing link, which does not say which list. The site {0} is taken from it, and you are asked for the list. To skip that, paste the address of the list itself from your browser.'

    'ListPdf.Run.List.None.Title'        = 'There is no list to print on {0}.'
    'ListPdf.Run.List.Missing.Title'     = 'No list is named, and I may not ask. Put its name in <List> in list-to-pdf.xml.'
    'ListPdf.Run.List.Question'          = 'Which list should be printed?'

    'ListPdf.Run.View.Default'           = '(default view)'
    'ListPdf.Run.View.Question'          = 'Which view of "{0}" should be printed?'
    'ListPdf.Run.View.None'              = 'This list has no stored view to choose from; all its columns are printed.'

    'ListPdf.Run.Reason.Prompt'          = 'Why are you exporting this? It is printed on the first page. Enter leaves it out'

    'ListPdf.Run.Printing'               = 'Printing {0} ...'

    'ListPdf.Run.Empty.Title'            = '{0} has no rows, so no PDF was written.'
    'ListPdf.Run.Empty.Hint'             = 'Choose another view, or check the filter of this one in SharePoint.'

    'ListPdf.Run.Unverified.Title'       = 'The PDF was written, but {0} value(s) could not be found in it.'
    'ListPdf.Run.Unverified.More'        = '... and {0} more.'
    'ListPdf.Run.Unverified.File'        = 'Do not rely on this file: {0}'

    'ListPdf.Run.Done'                   = 'Done: {0} row(s), {1} column(s), {2} page(s).'
    'ListPdf.Run.NotFullyVerified'       = 'The PDF could not be read back to check it, so it is not confirmed that everything is on it.'

    'ListPdf.Run.Failed.Title'           = 'The list could not be printed.'

    'ListPdf.Run.Step.Connect'           = 'signing in'

    'ListPdf.Run.Step.Lists'             = 'reading the lists of the site'

    'ListPdf.Run.Step.Views'             = 'reading the views of ''{0}'''

    'ListPdf.Run.Step.Print'             = 'printing ''{0}'''

    'ListPdf.Run.Failed.Step'            = 'It happened while: {0}'

    'ListPdf.Run.Failed.Where'           = 'Kind of error: {0}. Where, from the inside out:'
}
