@{
    # Messages for the module, English. One key per message; every key exists in
    # both languages (tests/Unit/Language.Tests.ps1 checks that). {0}, {1} are
    # placeholders and must appear in both languages.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Common.MessageUnavailable'            = 'Message unavailable ({0}).'

    'Language.Save.Action'                 = 'Save the language "{0}"'
    'Language.NotSaved'                    = 'The language applies to this session but could not be saved to {0}.'

    'Language.Name.en'                     = 'English'
    'Language.Name.de'                     = 'Deutsch'
    'Language.Picker.Line'                 = 'Language: {0}   (L = change / ändern)'
    'Language.Picker.Title'                = 'Which language?'
    'Language.Picker.Option1'              = '    1) English'
    'Language.Picker.Option2'              = '    2) Deutsch'
    'Language.Picker.Option3'              = '    3) Follow Windows'
    'Language.Picker.Prompt'               = 'Number, or Enter to keep it'

    'Language.Follow'                      = 'Follow Windows'

    'Report.Status.MissingRemote'          = 'Missing in SharePoint'
    'Report.Status.MissingLocal'           = 'Missing on this computer'
    'Report.Status.LocalNewer'             = 'Newer on this computer'
    'Report.Status.RemoteNewer'            = 'Newer in SharePoint'
    'Report.Status.SizeDiffers'            = 'Different size'
    'Report.Status.Match'                  = 'Synchronised'
    'Report.Bytes'                         = '{0} bytes'
    'Report.Meta.Generated'                = 'Generated {0}'
    'Report.Meta.Rows'                     = '{0} row(s)'
    'Report.Empty'                         = 'Nothing to report. Everything checked above was fine.'
    'Report.Hint.Untick'                   = 'Untick a box to hide those files.'
    'Report.Column.Status'                 = 'Status'
    'Report.Column.File'                   = 'File'
    'Report.Column.OnComputer'             = 'On this computer'
    'Report.Column.InSharePoint'           = 'In SharePoint'
    'Report.Column.Size'                   = 'Size'
    'Report.Column.Modified'               = 'Modified'
    'Report.Column.Rule'                   = 'Rule'
    'Report.Column.List'                   = 'List'
    'Report.Column.Target'                 = 'Target'
    'Report.Column.Message'                = 'Message'
    'Report.Severity.Error'                = 'Error'
    'Report.Severity.Warning'              = 'Warning'
    'Report.Severity.Info'                 = 'Info'
    'Report.Findings'                      = '{0} finding(s)'
    'Report.Wrote'                         = 'Wrote {0} report with {1} row(s) to ''{2}''.'

    'Rule.FileName.IllegalCharacter'       = 'Name contains character(s) SharePoint does not permit: {0}'
    'Rule.FileName.LeadingSpace'           = 'Name begins with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingSpace'          = 'Name ends with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingPeriod'         = 'Name ends with a period, which the OneDrive sync client rejects.'
    'Rule.FileName.ReservedName'           = '''{0}'' is a reserved name and cannot be used.'
    'Rule.FileName.ReservedPrefix'         = 'Name starts with a reserved prefix (~$ or _vti_).'
    'Rule.FileName.TooLong'                = 'Name is {0} characters; the limit is 255.'
    'Rule.FileName.RiskyCharacter'         = 'Name contains {0}, which is legal but breaks some downstream tools.'

    'Library.Compare.LocalMissing'         = 'Local folder ''{0}'' does not exist.'

    'Library.Compare.Comparing'            = 'Comparing ''{0}'' with ''{1}''.'

    'Library.Compare.LocalFound'           = 'Found {0} local file(s).'

    'Library.Compare.NoFolder'             = 'There is no folder ''{0}'' in ''{1}'', so there was nothing to compare against.'

    'Library.Compare.DidYouMean'           = ' Did you mean: {0}?'

    'Library.Compare.TopLevel'             = ' Folders at the top level of the library: {0}.'

    'Library.Compare.NoFolders'            = ' That library has no folders in it at all.'

    'Library.Compare.RemoteFound'          = 'Found {0} remote file(s) under ''{1}''.'

    'Library.Compare.Done'                 = 'Comparison complete.'

    'Library.Address.NotAddress'           = '''{0}'' is not a web address. Open the folder in SharePoint and copy the whole address from the browser, starting with https://'

    'Library.Address.TeamsLink'            = 'That is a Teams link, and it does not say where the files are. In Teams, open the Files tab, choose "Open in SharePoint", and copy the address from the browser there.'

    'Library.Address.SharingLink'          = 'That is a sharing link ("Copy link"), which does not name the folder. Open the folder in SharePoint and copy the address out of the browser address bar instead.'

    'Library.Address.PageNotFolder'        = 'That address is a SharePoint page rather than a folder. Open the library, click into the folder the files are in, and copy the address from there.'

    'Library.Draft.RecordCovers'           = 'Change record covers {0} item(s).'

    'Library.Draft.NoRecord'               = 'No change record was loaded. Pass -ChangeRecord with the before.csv written by the repair, or -IgnoreChangeRecord to judge drafts on the version rule alone.'

    'Library.Publish.MissingProperty'      = 'Input object is missing the ''{0}'' property. Pipe output from Get-SpoFileDraft.'

    'Library.Publish.SkipReason'           = 'Skipping ''{0}'': {1}.'

    'Library.Publish.ReadFailed'           = 'Could not re-read ''{0}'': {1}'

    'Library.Publish.SkipChanged'          = 'Skipping ''{0}'': version changed from {1} to {2} since the scan; somebody has edited it.'

    'Library.Publish.SkipCheckedOut'       = 'Skipping ''{0}'': checked out to {1} since the scan.'

    'Library.Publish.Action'               = 'Publish draft {0} as a major version'

    'Library.Publish.Published'            = 'Published ''{0}'' (was {1}).'

    'Library.Publish.Failed'               = 'Failed to publish ''{0}'': {1}'

    'Library.Publish.Done'                 = 'Publish complete: {0} published, {1} skipped, {2} failed.'

    'Library.Names.Checking'               = 'Checking names in ''{0}''.'

    'Library.Names.Done'                   = 'Name check for ''{0}'' complete.'

    'Library.Paths.Checking'               = 'Checking path lengths in ''{0}'' against a limit of {1}.'

    'Rule.PathLength.Exceeded'             = 'Path is {0} characters, {1} over the {2} character limit.'

    'Rule.PathLength.NearLimit'            = 'Path is {0} characters, only {1} short of the {2} character limit.'

    'Library.Paths.Done'                   = 'Path length check for ''{0}'' complete.'

    'Library.Health.Running'               = 'Running health check on ''{0}'' with rules: {1}.'

    'Library.Health.Empty'                 = 'Library ''{0}'' is empty.'

    'Rule.PathLength.Exceeded400'          = 'Path is {0} characters, {1} over the 400 character limit.'

    'Rule.PathLength.NearLimit400'         = 'Path is {0} characters, only {1} short of the 400 character limit.'

    'Rule.File.CheckedOut'                 = 'File is checked out to {0}; other users may not see the latest content.'

    'Rule.File.Large'                      = 'File is {0} MB, over the {1} MB threshold.'

    'Rule.File.VersionBloat'               = 'Version history occupies {0} MB for a {1} MB file.'

    'Rule.Item.RequiredFieldEmpty'         = 'Required column ''{0}'' has no value.'

    'Rule.Permission.DeepUniqueAssignment' = 'Unique permissions at depth {0}; this is easy to lose track of.'

    'Library.Health.PermissionReadFailed'  = 'Could not read permission state of ''{0}'': {1}'

    'Rule.File.DuplicateName'              = '''{0}'' appears {1} times in different folders.'

    'Rule.Folder.Empty'                    = 'Folder contains no items.'

    'Connection.NotConnectedHelp'          = 'Not connected to SharePoint. Run ''Connect-O365'' first (for example: Connect-O365 -Profile prod, or Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId <guid>).'

    'Connection.NotConnected'              = 'Not connected to SharePoint. Run ''Connect-O365'' first.'

    'Connection.PnpMissing'                = 'This command talks to SharePoint, which needs the PnP.PowerShell module. Install it once with: Install-Module PnP.PowerShell -Scope CurrentUser -- or use only the offline commands (Test-SpoFileName, Get-SpoRecurringDate, Export-SpoReport, and scripts/Test-Upload.ps1 without -Library), which need nothing extra.'

    'Connection.ListsAvailable'            = 'Available lists on {0}: {1}'

    'Connection.ListsNone'                 = 'No visible lists were found on the connected site. Check that you connected to the right site.'

    'Connection.ListNotFound'              = 'List or library ''{0}'' was not found. {1}'

    'Connection.NoProfileStore'            = 'No profile store found at ''{0}''. Copy config/profiles.example.json to config/profiles.json and fill in your tenant, or connect explicitly: Connect-O365 -SiteUrl <url> -ClientId <guid>.'

    'Connection.NoDefaultProfile'          = 'No profile specified and no ''defaultProfile'' set in ''{0}''. Available profiles: {1}.'

    'Connection.ProfileUnknown'            = 'Profile ''{0}'' is not defined in ''{1}''. Available profiles: {2}.'

    'Connection.Connecting'                = 'Connecting to ''{0}'' with client ID ''{1}''.'

    'Connection.Failed'                    = 'Failed to connect to ''{0}'': {1} Check that the client ID is registered in this tenant and that you have access to the site. See docs/sandbox/authentication.md.'

    'Connection.Connected'                 = 'Connected to ''{0}''.'

    'Connection.NothingToDisconnect'       = 'No active connection to disconnect.'

    'Connection.DisconnectAction'          = 'Disconnect'

    'Connection.DisconnectError'           = 'PnP reported an error while disconnecting: {0}'

    'Connection.Disconnected'              = 'Disconnected from ''{0}''.'

    'Connection.NotConnectedShort'         = 'Not connected. Run ''Connect-O365'' to connect.'

    'Connection.NoStoreShort'              = 'No profile store at ''{0}''. Copy config/profiles.example.json to config/profiles.json to create one.'

    'Connection.ProfileMissing'            = 'Profile ''{0}'' does not exist; nothing to remove.'

    'Connection.RemoveProfileAction'       = 'Remove profile'

    'Connection.ProfileRemoved'            = 'Removed profile ''{0}''.'

    'Connection.UpdateProfileAction'       = 'Update profile'

    'Connection.CreateProfileAction'       = 'Create profile'

    'Connection.LogFooterFailed'           = 'Could not write log footer: {0}'
}
