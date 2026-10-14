@{
    # Messages for the module, English. One key per message; every key exists in
    # both languages (tests/Unit/Language.Tests.ps1 checks that). {0}, {1} are
    # placeholders and must appear in both languages.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Common.MessageUnavailable'                                = 'Message unavailable ({0}).'

    'Language.Save.Action'                                     = 'Save the language "{0}"'
    'Language.NotSaved'                                        = 'The language applies to this session but could not be saved to {0}.'

    'Language.Name.en'                                         = 'English'
    'Language.Name.de'                                         = 'Deutsch'
    'Language.Picker.Line'                                     = 'Language: {0}   (L = change / ändern)'
    'Language.Picker.Title'                                    = 'Which language?'
    'Language.Picker.Option1'                                  = '    1) English'
    'Language.Picker.Option2'                                  = '    2) Deutsch'
    'Language.Picker.Option3'                                  = '    3) Follow Windows'
    'Language.Picker.Prompt'                                   = 'Number, or Enter to keep it'

    'Language.Follow'                                          = 'Follow Windows'

    'Report.Status.MissingRemote'                              = 'Missing in SharePoint'
    'Report.Status.MissingLocal'                               = 'Missing on this computer'
    'Report.Status.LocalNewer'                                 = 'Newer on this computer'
    'Report.Status.RemoteNewer'                                = 'Newer in SharePoint'
    'Report.Status.SizeDiffers'                                = 'Different size'
    'Report.Status.Match'                                      = 'Synchronised'
    'Report.Bytes'                                             = '{0} bytes'
    'Report.Meta.Generated'                                    = 'Generated {0}'
    'Report.Meta.Rows'                                         = '{0} row(s)'
    'Report.Empty'                                             = 'Nothing to report. Everything checked above was fine.'
    'Report.Hint.Untick'                                       = 'Untick a box to hide those files.'
    'Report.Column.Status'                                     = 'Status'
    'Report.Column.File'                                       = 'File'
    'Report.Column.OnComputer'                                 = 'On this computer'
    'Report.Column.InSharePoint'                               = 'In SharePoint'
    'Report.Column.Size'                                       = 'Size'
    'Report.Column.Modified'                                   = 'Modified'
    'Report.Column.Rule'                                       = 'Rule'
    'Report.Column.List'                                       = 'List'
    'Report.Column.Target'                                     = 'Target'
    'Report.Column.Message'                                    = 'Message'
    'Report.Severity.Error'                                    = 'Error'
    'Report.Severity.Warning'                                  = 'Warning'
    'Report.Severity.Info'                                     = 'Info'
    'Report.Findings'                                          = '{0} finding(s)'
    'Report.Wrote'                                             = 'Wrote {0} report with {1} row(s) to ''{2}''.'

    'Rule.FileName.IllegalCharacter'                           = 'Name contains character(s) SharePoint does not permit: {0}'
    'Rule.FileName.LeadingSpace'                               = 'Name begins with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingSpace'                              = 'Name ends with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingPeriod'                             = 'Name ends with a period, which the OneDrive sync client rejects.'
    'Rule.FileName.ReservedName'                               = '''{0}'' is a reserved name and cannot be used.'
    'Rule.FileName.ReservedPrefix'                             = 'Name starts with a reserved prefix (~$ or _vti_).'
    'Rule.FileName.TooLong'                                    = 'Name is {0} characters; the limit is 255.'
    'Rule.FileName.RiskyCharacter'                             = 'Name contains {0}, which is legal but breaks some downstream tools.'

    'Library.Compare.LocalMissing'                             = 'Local folder ''{0}'' does not exist.'

    'Library.Compare.Comparing'                                = 'Comparing ''{0}'' with ''{1}''.'

    'Library.Compare.LocalFound'                               = 'Found {0} local file(s).'

    'Library.Compare.NoFolder'                                 = 'There is no folder ''{0}'' in ''{1}'', so there was nothing to compare against.'

    'Library.Compare.DidYouMean'                               = ' Did you mean: {0}?'

    'Library.Compare.TopLevel'                                 = ' Folders at the top level of the library: {0}.'

    'Library.Compare.NoFolders'                                = ' That library has no folders in it at all.'

    'Library.Compare.RemoteFound'                              = 'Found {0} remote file(s) under ''{1}''.'

    'Library.Compare.Done'                                     = 'Comparison complete.'

    'Library.Address.NotAddress'                               = '''{0}'' is not a web address. Open the folder in SharePoint and copy the whole address from the browser, starting with https://'

    'Library.Address.TeamsLink'                                = 'That is a Teams link, and it does not say where the files are. In Teams, open the Files tab, choose "Open in SharePoint", and copy the address from the browser there.'

    'Library.Address.SharingLink'                              = 'That is a sharing link ("Copy link"), which does not name the folder. Open the folder in SharePoint and copy the address out of the browser address bar instead.'

    'Library.Address.PageNotFolder'                            = 'That address is a SharePoint page rather than a folder. Open the library, click into the folder the files are in, and copy the address from there.'

    'Library.Draft.RecordCovers'                               = 'Change record covers {0} item(s).'

    'Library.Draft.NoRecord'                                   = 'No change record was loaded. Pass -ChangeRecord with the before.csv written by the repair, or -IgnoreChangeRecord to judge drafts on the version rule alone.'

    'Library.Publish.MissingProperty'                          = 'Input object is missing the ''{0}'' property. Pipe output from Get-SpoFileDraft.'

    'Library.Publish.SkipReason'                               = 'Skipping ''{0}'': {1}.'

    'Library.Publish.ReadFailed'                               = 'Could not re-read ''{0}'': {1}'

    'Library.Publish.SkipChanged'                              = 'Skipping ''{0}'': version changed from {1} to {2} since the scan; somebody has edited it.'

    'Library.Publish.SkipCheckedOut'                           = 'Skipping ''{0}'': checked out to {1} since the scan.'

    'Library.Publish.Action'                                   = 'Publish draft {0} as a major version'

    'Library.Publish.Published'                                = 'Published ''{0}'' (was {1}).'

    'Library.Publish.Failed'                                   = 'Failed to publish ''{0}'': {1}'

    'Library.Publish.Done'                                     = 'Publish complete: {0} published, {1} skipped, {2} failed.'

    'Library.Names.Checking'                                   = 'Checking names in ''{0}''.'

    'Library.Names.Done'                                       = 'Name check for ''{0}'' complete.'

    'Library.Paths.Checking'                                   = 'Checking path lengths in ''{0}'' against a limit of {1}.'

    'Rule.PathLength.Exceeded'                                 = 'Path is {0} characters, {1} over the {2} character limit.'

    'Rule.PathLength.NearLimit'                                = 'Path is {0} characters, only {1} short of the {2} character limit.'

    'Library.Paths.Done'                                       = 'Path length check for ''{0}'' complete.'

    'Library.Health.Running'                                   = 'Running health check on ''{0}'' with rules: {1}.'

    'Library.Health.Empty'                                     = 'Library ''{0}'' is empty.'

    'Rule.PathLength.Exceeded400'                              = 'Path is {0} characters, {1} over the 400 character limit.'

    'Rule.PathLength.NearLimit400'                             = 'Path is {0} characters, only {1} short of the 400 character limit.'

    'Rule.File.CheckedOut'                                     = 'File is checked out to {0}; other users may not see the latest content.'

    'Rule.File.Large'                                          = 'File is {0} MB, over the {1} MB threshold.'

    'Rule.File.VersionBloat'                                   = 'Version history occupies {0} MB for a {1} MB file.'

    'Rule.Item.RequiredFieldEmpty'                             = 'Required column ''{0}'' has no value.'

    'Rule.Permission.DeepUniqueAssignment'                     = 'Unique permissions at depth {0}; this is easy to lose track of.'

    'Library.Health.PermissionReadFailed'                      = 'Could not read permission state of ''{0}'': {1}'

    'Rule.File.DuplicateName'                                  = '''{0}'' appears {1} times in different folders.'

    'Rule.Folder.Empty'                                        = 'Folder contains no items.'

    'Connection.NotConnectedHelp'                              = 'Not connected to SharePoint. Run ''Connect-O365'' first (for example: Connect-O365 -Profile prod, or Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId <guid>).'

    'Connection.NotConnected'                                  = 'Not connected to SharePoint. Run ''Connect-O365'' first.'

    'Connection.PnpMissing'                                    = 'This command talks to SharePoint, which needs the PnP.PowerShell module. Install it once with: Install-Module PnP.PowerShell -Scope CurrentUser -- or use only the offline commands (Test-SpoFileName, Get-SpoRecurringDate, Export-SpoReport, and scripts/Test-Upload.ps1 without -Library), which need nothing extra.'

    'Connection.ListsAvailable'                                = 'Available lists on {0}: {1}'

    'Connection.ListsNone'                                     = 'No visible lists were found on the connected site. Check that you connected to the right site.'

    'Connection.ListNotFound'                                  = 'List or library ''{0}'' was not found. {1}'

    'Connection.NoProfileStore'                                = 'No profile store found at ''{0}''. Copy config/profiles.example.json to config/profiles.json and fill in your tenant, or connect explicitly: Connect-O365 -SiteUrl <url> -ClientId <guid>.'

    'Connection.NoDefaultProfile'                              = 'No profile specified and no ''defaultProfile'' set in ''{0}''. Available profiles: {1}.'

    'Connection.ProfileUnknown'                                = 'Profile ''{0}'' is not defined in ''{1}''. Available profiles: {2}.'

    'Connection.Connecting'                                    = 'Connecting to ''{0}'' with client ID ''{1}''.'

    'Connection.Failed'                                        = 'Failed to connect to ''{0}'': {1} Check that the client ID is registered in this tenant and that you have access to the site. See docs/sandbox/authentication.md.'

    'Connection.Connected'                                     = 'Connected to ''{0}''.'

    'Connection.NothingToDisconnect'                           = 'No active connection to disconnect.'

    'Connection.DisconnectAction'                              = 'Disconnect'

    'Connection.DisconnectError'                               = 'PnP reported an error while disconnecting: {0}'

    'Connection.Disconnected'                                  = 'Disconnected from ''{0}''.'

    'Connection.NotConnectedShort'                             = 'Not connected. Run ''Connect-O365'' to connect.'

    'Connection.NoStoreShort'                                  = 'No profile store at ''{0}''. Copy config/profiles.example.json to config/profiles.json to create one.'

    'Connection.ProfileMissing'                                = 'Profile ''{0}'' does not exist; nothing to remove.'

    'Connection.RemoveProfileAction'                           = 'Remove profile'

    'Connection.ProfileRemoved'                                = 'Removed profile ''{0}''.'

    'Connection.UpdateProfileAction'                           = 'Update profile'

    'Connection.CreateProfileAction'                           = 'Create profile'

    'Connection.LogFooterFailed'                               = 'Could not write log footer: {0}'

    'ContentType.AddToList.NotFound'                           = 'Site content type ''{0}'' was not found. Available: {1}'

    'ContentType.AddToList.EnableAction'                       = 'Enable content type management'

    'ContentType.AddToList.Enabled'                            = 'Enabled content type management on ''{0}''.'

    'ContentType.AddToList.AddAction'                          = 'Add content type ''{0}'''

    'ContentType.AddToList.Added'                              = 'Added ''{0}'' to ''{1}''.'

    'ContentType.AddToList.Failed'                             = 'Failed to add ''{0}'' to ''{1}'': {2}'

    'ContentType.AddToList.RemoveBuiltinAction'                = 'Remove built-in content type ''{0}'''

    'ContentType.AddToList.RemovedBuiltin'                     = 'Removed built-in ''{0}'' from ''{1}''.'

    'ContentType.AddToList.RemoveBuiltinFailed'                = 'Could not remove built-in content type: {0}'

    'ContentType.AddToList.NoBuiltin'                          = 'No built-in Document content type on ''{0}''; nothing to remove.'

    'ContentType.AddField.WhereList'                           = 'list ''{0}'''

    'ContentType.AddField.WhereSite'                           = 'this site'

    'ContentType.AddField.NotFound'                            = 'Content type ''{0}'' was not found on {1}. Run Get-SpoContentType to see what exists.'

    'ContentType.AddField.Sealed'                              = 'Content type ''{0}'' is sealed and cannot be modified. Unseal it in the site settings first, or inherit a new content type from it.'

    'ContentType.AddField.AlreadyThere'                        = '''{0}'' is already on ''{1}''; skipped.'

    'ContentType.AddField.NoSiteColumn'                        = 'Site column ''{0}'' does not exist. Create it with New-SpoField, or check the internal name with Get-SpoField.'

    'ContentType.AddField.Action'                              = 'Add column ''{0}'''

    'ContentType.AddField.Added'                               = 'Added ''{0}'' to ''{1}''.'

    'ContentType.AddField.Failed'                              = 'Failed to add ''{0}'' to ''{1}'': {2}'

    'ContentType.AddField.Done'                                = 'Column changes complete: {0} added, {1} already present.'

    'ContentType.AddField.ChildrenNotUpdated'                  = 'Existing list copies of this content type were not updated. Re-run with -UpdateChildren, or use Sync-SpoContentType, to push the change down.'

    'ContentType.AddListField.SchemaMissing'                   = '-Schema is missing ''{0}''. It expects output from Get-SpoListFieldSchema; to describe a column instead, use the -DisplayName and -Type parameters.'

    'ContentType.AddListField.Unportable'                      = 'Skipping ''{0}'' ({1}): {2} Pass -AllowUnportableType to create it anyway.'

    'ContentType.AddListField.NoInternalName'                  = 'Could not derive a valid internal name from ''{0}''. Internal names must start with a letter and contain only letters, digits and underscores. Supply -InternalName explicitly.'

    'ContentType.AddListField.NeedsChoice'                     = 'A {0} column needs its options. Supply -Choice, for example: -Choice ''Open'', ''Closed'''

    'ContentType.AddListField.AlreadyThere'                    = 'Column ''{0}'' is already on ''{1}''; leaving it as it is.'

    'ContentType.AddListField.Action'                          = 'Add list column'

    'ContentType.AddListField.Added'                           = 'Added column ''{0}'' to ''{1}''.'

    'ContentType.AddListField.Failed'                          = 'Failed to add column ''{0}'' to ''{1}'': {2}'

    'ContentType.AddListField.NoDefaultView'                   = 'List ''{0}'' has no default view; ''{1}'' was not added to one.'

    'ContentType.AddListField.AddedToView'                     = 'Added ''{0}'' to view ''{1}''.'

    'ContentType.AddListField.ViewFailed'                      = 'Column ''{0}'' was created but adding it to the default view failed: {1}'

    'ContentType.AddListField.Done'                            = 'Added {0} column(s); skipped {1}.'

    'ContentType.Find.ScopeList'                               = 'list ''{0}'''

    'ContentType.Find.ScopeSite'                               = 'the site'

    'ContentType.Find.Searching'                               = 'Searching {0} content type(s) in {1} for column ''{2}''.'

    'ContentType.New.Exists'                                   = 'A site content type named ''{0}'' already exists (ID {1}). Use Add-SpoFieldToContentType to change it, or pick a different name.'

    'ContentType.New.NoParent'                                 = 'Parent content type ''{0}'' was not found. Common parents are ''Item'' (for lists) and ''Document'' (for libraries). Run Get-SpoContentType -IncludeBuiltIn to see what is available.'

    'ContentType.New.Action'                                   = 'Create content type {0}'

    'ContentType.New.Created'                                  = 'Created content type ''{0}'' in group ''{1}''.'

    'ContentType.New.Failed'                                   = 'Failed to create content type ''{0}'': {1}'

    'ContentType.NewField.NoInternalName'                      = 'Could not derive a valid internal name from ''{0}''. Internal names must start with a letter and contain only letters, digits and underscores. Supply -InternalName explicitly.'

    'ContentType.NewField.NeedsChoice'                         = 'A {0} column needs its options. Supply -Choice, for example: -Choice ''Open'', ''Closed'''

    'ContentType.NewField.Exists'                              = 'A site column with internal name ''{0}'' already exists (display name ''{1}'', group ''{2}''). Internal names are permanent and must be unique -- choose a different -InternalName, or reuse the existing column with Add-SpoFieldToContentType.'

    'ContentType.NewField.Action'                              = 'Create site column {0}'

    'ContentType.NewField.Created'                             = 'Created site column ''{0}'' (internal name ''{1}'').'

    'ContentType.NewField.Failed'                              = 'Failed to create site column ''{0}'': {1}'

    'ContentType.RemoveFromList.NotAttached'                   = 'Content type ''{0}'' is not attached to ''{1}''; nothing to remove.'

    'ContentType.RemoveFromList.InUse'                         = '{0} item(s) in ''{1}'' still use content type ''{2}''. Change those items to a different content type first, or re-run with -Force to let the server reject the operation itself.'

    'ContentType.RemoveFromList.Action'                        = 'Remove content type ''{0}'''

    'ContentType.RemoveFromList.Removed'                       = 'Removed ''{0}'' from ''{1}''.'

    'ContentType.RemoveFromList.Failed'                        = 'Failed to remove ''{0}'' from ''{1}'': {2}'

    'ContentType.RemoveField.Action'                           = 'Remove field ''{0}'''

    'ContentType.RemoveField.Removed'                          = 'Removed ''{0}'' from ''{1}''.'

    'ContentType.RemoveField.Failed'                           = 'Failed to remove ''{0}'' from ''{1}'': {2}'

    'ContentType.RemoveField.Done'                             = 'Field removal complete: {0} removed, {1} failed.'

    'ContentType.Sync.NotFound'                                = 'Site content type ''{0}'' was not found.'

    'ContentType.Sync.Syncing'                                 = 'Syncing ''{0}'' into {1} candidate list(s).'

    'ContentType.Sync.AlreadyInSync'                           = '''{0}'' is already in sync.'

    'ContentType.Sync.Action'                                  = 'Add field ''{0}'''

    'ContentType.Sync.Added'                                   = 'Added ''{0}'' to ''{1}''.'

    'ContentType.Sync.Failed'                                  = 'Failed to add ''{0}'' to ''{1}'': {2}'

    'ContentType.Sync.Done'                                    = 'Sync complete: {0} field(s) added.'

    'ContentType.Link.Checking'                                = 'Checking {0} list(s) against {1} site content type(s).'

    'Rule.ContentType.OrphanedListCopy'                        = 'List content type ''{0}'' has no matching site content type; its parent was probably deleted.'

    'Rule.ContentType.NameDrift'                               = 'List copy is named ''{0}'' but descends from site content type ''{1}''.'

    'Rule.ContentType.FieldMissingOnListCopy'                  = 'List copy is missing {0} field(s) present on parent ''{1}'': {2}.'

    'Rule.ContentType.FieldOnlyOnListCopy'                     = 'List copy has {0} field(s) the parent ''{1}'' does not: {2}.'

    'ContentType.Link.Done'                                    = 'Content type link check complete.'

    'DocumentSet.Mismatch.None'                                = 'No Document Sets found in ''{0}''.'

    'DocumentSet.Mismatch.Activity'                            = 'Checking Document Set metadata in {0}'

    'DocumentSet.Mismatch.NoShared'                            = 'Document Set ''{0}'' has no shared columns; nothing to compare. Run Test-SpoDocumentSetSharedColumn to see why.'

    'DocumentSet.Mismatch.Done'                                = 'Finished checking Document Set metadata in ''{0}''.'

    'DocumentSet.Register.ColumnNotWritable'                   = 'Column ''{0}'' is not a writable column on list ''{1}''. Note this must be the internal name, not the display title. Run: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'DocumentSet.Register.ContentTypeNotOnList'                = 'Content type ''{0}'', mapped from library ''{1}'', is not on list ''{2}''. Available: {3}. Add it to the list first, or correct -ContentTypeMap.'

    'DocumentSet.Register.Matching'                            = 'Register ''{0}'': matching {1} column(s) by name, keyed on ''{2}''.'

    'DocumentSet.Register.ItemNoKey'                           = 'Register item {0} has no value in ''{1}''; it cannot be matched and may be duplicated.'

    'DocumentSet.Register.ItemsShareKey'                       = 'Register items {0} and {1} share the key ''{2}'' in ''{3}''.'

    'DocumentSet.Register.Holds'                               = 'Register ''{0}'' holds {1} item(s), {2} with a usable key.'

    'DocumentSet.Register.NotInMap'                            = 'Library ''{0}'' is not in -ContentTypeMap; its entries get the default content type of ''{1}''.'

    'DocumentSet.Register.MissingColumns'                      = 'Library ''{0}'' has no column(s) {1}; those register columns stay empty.'

    'DocumentSet.Register.NoDocumentId'                        = 'Library ''{0}'' has no Document ID column. Enable the Document ID service on the site, or the register''s ''{1}'' stays empty.'

    'DocumentSet.Register.Read'                                = 'Read {0} item(s) from ''{1}''.'

    'DocumentSet.Register.SetNoKey'                            = 'Document Set ''{0}'' has no value for the key column; skipped rather than risk a duplicate.'

    'DocumentSet.Register.AnotherRow'                          = 'another register row'

    'DocumentSet.Register.SharesKey'                           = 'Document Set ''{0}'' shares the key ''{1}'' with {2} and register item {3}. It cannot be told apart from them, so it is left alone. Use -KeyField with the reference column if each copy needs its own row.'

    'DocumentSet.Register.OutOfStep'                           = 'Register item {0} (''{1}'') is out of step with ''{2}'': {3}.'

    'DocumentSet.Repair.MissingProperty'                       = 'Input object is missing the {0} property. Pipe output from Get-SpoDocumentSetMismatch.'

    'DocumentSet.Repair.ColumnNotOnLibrary'                    = 'Column ''{0}'' is not on library ''{1}''; it cannot be written. Add it to the library first.'

    'DocumentSet.Repair.SkipEmpty'                             = 'Skipping {0} empty column(s) on ''{1}'': the Document Set has no value to push. Use -ClearEmpty to clear them anyway.'

    'DocumentSet.Repair.ReadFailed'                            = 'Could not read Document Set item {0} in ''{1}'': {2}'

    'DocumentSet.Repair.Action'                                = 'Set {0} from Document Set ''{1}'''

    'DocumentSet.Repair.Updated'                               = 'Updated {0} on ''{1}''.'

    'DocumentSet.Repair.Failed'                                = 'Failed to update ''{0}'': {1}'

    'DocumentSet.Repair.Done'                                  = 'Document Set metadata repair complete: {0} updated, {1} skipped, {2} failed.'

    'Rule.DocumentSet.TemplateUnreadable'                      = 'Could not read the Document Set template for ''{0}'', so its shared columns cannot be verified.'

    'Rule.DocumentSet.NoSharedColumn'                          = 'Document Set ''{0}'' has no shared columns, so none of its metadata reaches the documents inside it.'

    'Rule.DocumentSet.ColumnNotShared'                         = 'Column ''{0}'' is on Document Set ''{1}'' but is not a shared column, so its value is never copied to the contents.'

    'Rule.DocumentSet.SharedColumnMissingFromLibrary'          = 'Shared column ''{0}'' does not exist on library ''{1}'', so its value cannot be stored on any item there.'

    'DocumentSet.Shared.ReadFailed'                            = 'Could not read columns of allowed content type ''{0}'': {1}'

    'Rule.DocumentSet.SharedColumnMissingFromChildContentType' = 'Content type ''{0}'' is allowed inside ''{1}'' but lacks {2} shared column(s): {3}. Values are stored but do not appear on the document''s form.'

    'DocumentSet.Shared.Done'                                  = 'Document Set shared column check complete.'

    'ListItem.Add.UnknownFields'                               = 'Field(s) not found on list ''{0}'': {1}. Note these must be internal names, not display titles. Run: Get-PnPField -List ''{0}'' | Select-Object InternalName, Title'

    'ListItem.Add.NoTitle'                                     = '(no title)'

    'ListItem.Add.Action'                                      = 'Add list item'

    'ListItem.Add.Added'                                       = 'Added item {0} to ''{1}''.'

    'ListItem.Add.Failed'                                      = 'Failed to add item to ''{0}'': {1}'

    'ListItem.Add.Done'                                        = 'Added {0} item(s).'

    'ListItem.Export.Exporting'                                = 'Exporting {0} field(s) from ''{1}''.'

    'ListItem.Export.Done'                                     = 'Export of ''{0}'' complete.'

    'ListItem.Import.FileMissing'                              = 'File ''{0}'' does not exist.'

    'ListItem.Import.UnsupportedType'                          = 'Unsupported file type ''{0}''. Use .csv, .tsv, or .json.'

    'ListItem.Import.NoRows'                                   = 'File ''{0}'' contains no rows; nothing to import.'

    'ListItem.Import.UnknownColumns'                           = 'Column(s) in ''{0}'' do not match any writable field on list ''{1}'': {2}. Field names must be internal names. Run: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title. Use -Mapping to translate column names.'

    'ListItem.Import.RequiredMissing'                          = 'List ''{0}'' has required field(s) not present in the file: {1}. Rows may be rejected by the server.'

    'ListItem.Import.Validated'                                = 'Validated {0} row(s) against ''{1}''. Columns: {2}.'

    'ListItem.Import.Action'                                   = 'Create {0} item(s) from ''{1}'''

    'ListItem.Import.Activity'                                 = 'Importing into {0}'

    'ListItem.Import.RowEmpty'                                 = 'Row {0} is empty; skipped.'

    'ListItem.Import.RowFailed'                                = 'Row {0} failed: {1}'

    'ListItem.Import.Stopped'                                  = '{0} Import stopped after {1} successful row(s) because -StopOnError was specified.'

    'ListItem.Import.Done'                                     = 'Import complete: {0} created, {1} failed, out of {2} row(s).'

    'ListItem.Update.Nothing'                                  = 'Nothing to update on item {0} in ''{1}'': -Values is empty and -ContentType was not given. Supply the fields to set, a content type to reclassify the item as, or both.'

    'ListItem.Update.ChangeFields'                             = 'fields: {0}'

    'ListItem.Update.ChangeContentType'                        = 'content type: {0}'

    'ListItem.Update.Action'                                   = 'Update item {0} ({1})'

    'ListItem.Update.Updated'                                  = 'Updated item {0} in ''{1}''.'

    'ListItem.Update.Failed'                                   = 'Failed to update item {0} in ''{1}'': {2}'

    'ListItem.Update.Done'                                     = 'Updated {0} item(s).'

    'ListItem.LinkText.ColumnNotFound'                         = 'Column ''{0}'' was not found on list ''{1}''. Note this must be the internal name, not the display title. Run: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'ListItem.LinkText.NotUrl'                                 = 'Column ''{0}'' on list ''{1}'' is of type ''{2}'', not URL. Only a hyperlink column has display text to set; use Update-SpoListItem for anything else.'

    'ListItem.LinkText.TextColumnNotFound'                     = 'Column ''{0}'' was not found on list ''{1}''. Run: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'ListItem.LinkText.Considering'                            = 'Considering {0} item(s) in ''{1}'' for link text from ''{2}''.'

    'ListItem.LinkText.NoUrl'                                  = 'Item {0} has no URL in ''{1}''; there is no link to label.'

    'ListItem.LinkText.NoText'                                 = 'Item {0} has no value in ''{1}''; leaving the link text alone rather than blanking it.'

    'ListItem.LinkText.Action'                                 = 'Set ''{0}'' text to ''{1}'''

    'ListItem.LinkText.Set'                                    = 'Set ''{0}'' text on item {1} to ''{2}''.'

    'ListItem.LinkText.Failed'                                 = 'Failed to set ''{0}'' text on item {1}: {2}'

    'ListItem.LinkText.FailedIn'                               = 'Failed to set ''{0}'' text on item {1} in ''{2}'': {3}'

    'ListItem.LinkText.Done'                                   = 'Link text pass complete: {0} updated, {1} already correct, {2} skipped, {3} failed.'

    'Schedule.NeedsWeekday'                                    = '-WeekOfMonth needs a weekday to count: ''first'' what? Add -DayOfWeek, for example: -WeekOfMonth First -DayOfWeek Sunday'

    'Schedule.UntilBeforeStart'                                = '-Until ({0}) is before -Start ({1}).'

    'Permission.Grant.NoRole'                                  = 'Role ''{0}'' does not exist on this site. Available roles: {1}'

    'Permission.Grant.Inherits'                                = '''{0}'' currently inherits its permissions. Granting here requires breaking inheritance, which changes the security model for everything below it. Re-run with -BreakInheritance (and normally -CopyExisting) if that is what you want.'

    'Permission.Grant.BreakAction'                             = 'Break permission inheritance (copy existing: {0})'

    'Permission.Grant.Broke'                                   = 'Broke inheritance on ''{0}''.'

    'Permission.Grant.Action'                                  = 'Grant ''{0}'' to ''{1}'''

    'Permission.Grant.Granted'                                 = 'Granted ''{0}'' to ''{1}'' on ''{2}''.'

    'Permission.Grant.Failed'                                  = 'Failed to grant ''{0}'' to ''{1}'' on ''{2}'': {3}'

    'Permission.Repair.MissingProperty'                        = 'Input object is missing the ''{0}'' property. Pipe output from Get-SpoPermissionMismatch.'

    'Permission.Repair.Action'                                 = 'Discard unique permissions and inherit from parent'

    'Permission.Repair.Reset'                                  = 'Reset inheritance on ''{0}''.'

    'Permission.Repair.Failed'                                 = 'Failed to reset inheritance on ''{0}'': {1}'

    'Permission.Repair.Done'                                   = 'Repair complete: {0} repaired, {1} failed.'

    'Permission.Revoke.Inherits'                               = '''{0}'' inherits its permissions, so there is nothing to revoke here. Revoke at the level where the permission was granted instead.'

    'Permission.Revoke.ActionRole'                             = 'Revoke ''{0}'' from ''{1}'''

    'Permission.Revoke.ActionAll'                              = 'Revoke all roles from ''{0}'''

    'Permission.Revoke.AllAtListLevel'                         = 'Revoking all roles at list level is not supported; specify -Role.'

    'Permission.Revoke.Done'                                   = '{0} on ''{1}''.'

    'Permission.Revoke.Failed'                                 = 'Failed to revoke on ''{0}'': {1}'

    'Permission.Orphaned.CheckingGroups'                       = 'Checking site groups for orphaned members.'

    'Rule.Permission.EmptyGroup'                               = 'SharePoint group ''{0}'' has no members but may still hold permissions.'

    'Rule.Permission.OrphanedPrincipalInGroup'                 = 'User ''{0}'' in group ''{1}'' does not resolve to an active account.'

    'Permission.Orphaned.CheckingList'                         = 'Checking unique assignments in ''{0}''.'

    'Rule.Permission.OrphanedPrincipal'                        = 'Item grants access to ''{0}'', which does not resolve to an active account.'

    'Permission.Mismatch.Scanning'                             = 'Scanning ''{0}'' for permission mismatches.'

    'Permission.Mismatch.Empty'                                = 'Library ''{0}'' contains no items.'

    'Permission.Mismatch.Checking'                             = 'Checking {0} item(s).'

    'Permission.Mismatch.Activity'                             = 'Checking permissions in {0}'

    'Permission.Mismatch.ReadFailed'                           = 'Could not read permission state of ''{0}'': {1}'

    'Permission.Mismatch.ParentFailed'                         = 'Could not read parent permissions for ''{0}''; comparing against the library instead.'

    'Permission.Mismatch.Done'                                 = 'Finished scanning ''{0}''.'

    'Permission.Report.Building'                               = 'Building permission report for ''{0}''.'

    'Permission.Report.ExpandFailed'                           = 'Could not expand group ''{0}'': {1}'

    'Permission.Report.Activity'                               = 'Reporting permissions in {0}'

    'Permission.Report.ReadFailed'                             = 'Could not read permission state of ''{0}'': {1}'

    'Permission.Report.Done'                                   = 'Permission report for ''{0}'' complete.'

    'Pdf.Export.ViewNotFound'                                  = 'View ''{0}'' was not found on ''{1}''. Views on this list: {2}'

    'Pdf.Export.ItemLinkNotColumn'                             = '-ItemLink names ''{0}'', which is not one of the printed columns: {1}'

    'Pdf.Export.DisplayFormFailed'                             = 'Could not read the display form URL of ''{0}'': {1}'

    'Pdf.Export.GroupNotColumn'                                = 'Grouping column ''{0}'' is not among the printed columns; it will head each group but not appear as a column.'

    'Pdf.Export.Action'                                        = 'Print {0} row(s) and {1} column(s) to PDF'

    'Pdf.Export.Unverified'                                    = 'Wrote ''{0}'' without verifying it.'

    'Pdf.Export.Wrote'                                         = 'Wrote ''{0}'': {1} row(s), {2} column(s), {3} page(s), {4} verification error(s).'

    'Rule.Pdf.Missing'                                         = 'The PDF does not exist, so nothing about its contents can be checked.'

    'Rule.Pdf.NothingToCheck'                                  = 'No rows were supplied, so the PDF was not checked against anything.'

    'Pdf.Test.Sampling'                                        = 'Checking a sample of {0} row(s) out of {1}.'

    'Rule.Pdf.NotAPdf'                                         = 'The file is not a PDF, so the export did not produce what it reported.'

    'Rule.Pdf.NoPages'                                         = 'The PDF contains no pages.'

    'Rule.Pdf.NoTextLayer'                                     = 'No text could be read from the PDF, so its contents were not verified. The file itself may still be correct.'

    'Rule.Pdf.TruncatedDocument'                               = 'The closing attestation line is not in the PDF, so the document does not run to the end of the data.'

    'Rule.Pdf.RowCountMismatch'                                = 'The PDF attests to {0} row(s) but {1} were exported.'

    'Rule.Pdf.ExtractionSuspect'                               = '{0} of {1} values were not found, which usually means the PDF''s text could not be read correctly rather than that the values are absent. Open the PDF, or install pdftotext, before acting on the findings below.'

    'Rule.Pdf.MissingValue'                                    = 'Row {0}, column ''{1}'': the printed value is not in the PDF.'

    'Rule.Pdf.MoreMissingValues'                               = '{0} further value(s) were also missing and are not listed individually.'

    'Rule.Pdf.WrappedValue'                                    = 'Row {0}, column ''{1}'': printed, but broken across lines.'

    'Rule.Pdf.WrappedValues'                                   = '{0} of {1} value(s) were printed across a line break and were matched with spacing ignored. Pass -ReportWrapped to list them.'

    'Rule.Pdf.MissingLink'                                     = '{0}: the cell was printed but carries no clickable link in the PDF.'

    'Rule.Pdf.MoreMissingLinks'                                = '{0} further link(s) were also missing and are not listed individually.'

    'Rule.Pdf.NoLinks'                                         = '{0} link(s) were rendered but the PDF carries no link annotations at all. The browser printed the text without the links.'

    'Pdf.Test.Checked'                                         = 'Checked {0} value(s) against ''{1}'': {2} missing, {3} wrapped{4}'

    'Pdf.Test.LinksMissing'                                    = ', {0} link(s) missing.'

    'Helper.FieldXml.NotWellFormed'                            = 'SchemaXml is not well-formed XML: {0}'

    'Helper.FieldXml.NotField'                                 = 'Expected a <Field> element, got <{0}>.'

    'Helper.Browser.NotFound'                                  = 'No Chromium-based browser was found, and one is what renders the PDF. Looked for msedge.exe and chrome.exe under ''{0}'', ''{1}'' and ''{2}'', then on PATH. Pass -BrowserPath with the full path to msedge.exe or chrome.exe.'

    'Helper.ProfileStore.NotJson'                              = 'Profile file ''{0}'' is not valid JSON: {1}. Compare it against config/profiles.example.json.'

    'Helper.ProfileStore.Saved'                                = 'Saved profile store to ''{0}''.'

    'Helper.Pdf.PdftotextFailed'                               = 'pdftotext failed, falling back to the built-in reader: {0}'

    'Helper.Print.NoBrowserAt'                                 = 'No browser at ''{0}''. Point -BrowserPath at msedge.exe or chrome.exe, or omit it to search the usual locations.'

    'Helper.Print.Printing'                                    = 'Printing with {0} ({1}).'

    'Helper.Print.Timeout'                                     = 'The browser did not finish printing within {0} seconds. Raise -TimeoutSecond, or print fewer rows per file.'

    'Helper.Print.NoPdf'                                       = '{0} produced no PDF (exit {1}). {2}'

    'Helper.Print.Failed'                                      = '''{0}'' exited without writing ''{1}'' in either headless mode. Run the same command by hand without --headless to see what it says, or pass -KeepHtml and print the HTML from a browser.'

    'Helper.DocSetMap.Reading'                                 = 'Reading items of ''{0}''.'

    'Helper.DocSetMap.Read'                                    = 'Read {0} item(s) from ''{1}''.'

    'Helper.DocSetMap.Found'                                   = 'Found {0} Document Set(s) in ''{1}''.'

    'Helper.DocSetTemplate.ColumnsFailed'                      = 'Could not read columns of content type ''{0}'': {1}'

    'Helper.DocSetTemplate.PropertyFailed'                     = 'Could not read {0} of Document Set template ''{1}'': {2}'

    'Helper.DocSetTemplate.NotResolved'                        = 'No Document Set template resolved for content type ''{0}''. Tried: {1}.'
}
