@{
    # Messages of the scripts in scripts/, English. One key per message, named
    # for its script: TestUpload.*, and so on. Every key exists in both
    # languages (tests/Unit/Language.Tests.ps1 checks that). {0}, {1} are
    # placeholders and must appear in both languages. A value of several lines
    # is shown one line to a line.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    # -- Test-Upload.ps1 -----------------------------------------------------
    'TestUpload.NextStep.Default'           = 'Afterwards, run the same command with -Mode Verify to confirm it arrived.'
    'TestUpload.Size.Bytes'                 = '{0} bytes'

    'TestUpload.Console.Clean'              = 'clean'
    'TestUpload.Console.Files'              = '{0} file(s)'
    'TestUpload.Console.More'               = '... and {0} more, see the report'

    'TestUpload.Choice.Prompt'              = 'Number [{0}]'
    'TestUpload.Choice.Invalid'             = 'Please type a number between 1 and {0}.'

    'TestUpload.Remote.Question'            = 'Where in the library did the files go?'
    'TestUpload.Remote.Compare'             = 'Compare against {0} itself'
    'TestUpload.Remote.Inside'              = 'Look inside {0}'
    'TestUpload.Remote.Up'                  = 'Go back up one level'

    'TestUpload.Destination.Title'          = 'Where in SharePoint did the files go?'
    'TestUpload.Destination.Help'           = 'Open that folder in SharePoint, copy the address out of your
browser, and paste it here. Press Enter to pick it after signing
in instead.'
    'TestUpload.Destination.Address'        = 'Address'
    'TestUpload.Destination.Says'           = 'That address says:'
    'TestUpload.Destination.Line.Site'      = 'Site     {0}'
    'TestUpload.Destination.Line.Library'   = 'Library  {0}'
    'TestUpload.Destination.Line.Folder'    = 'Folder   {0}'
    'TestUpload.Destination.NotNamed'       = '(not named -- you will be asked)'
    'TestUpload.Destination.Top'            = '(the top of the library)'
    'TestUpload.Destination.Conflict'       = '-Destination already says the site, the library and the folder, so -{0} cannot be given as well. Pass one or the other.'

    'TestUpload.Library.NotFound'           = 'There is no library called ''{0}'' on {1}. {2}'
    'TestUpload.Library.Hint.List'          = 'Libraries on this site: {0}.'
    'TestUpload.Library.Hint.None'          = 'No document libraries are visible on this site, so this is probably the wrong site.'
    'TestUpload.Library.NoneVisible'        = 'No document libraries are visible on {0}.'
    'TestUpload.Library.Question'           = 'Which library did you upload into?'

    'TestUpload.Folder.Prompt'              = 'Which folder are you uploading?'
    'TestUpload.Folder.Label'               = 'Folder'
    'TestUpload.Folder.NotFound'            = 'Folder ''{0}'' does not exist.'
    'TestUpload.Folder.Required'            = 'Which folder? Pass -LocalPath, or -Interactive to be asked.'

    'TestUpload.Mode.Question'              = 'What would you like to do?'
    'TestUpload.Mode.Option1'               = 'Check this folder before I upload it (no sign-in needed)'
    'TestUpload.Mode.Option2'               = 'I already uploaded it -- check that everything arrived (sign-in needed)'
    'TestUpload.Mode.Option3'               = 'Both: check the folder, then check what arrived (sign-in needed)'
    'TestUpload.Mode.NeedsLibrary'          = '-Mode {0} compares against a library, so -Destination or -Library is required.'
    'TestUpload.Mode.OfflineOnly'           = '-Offline only applies to -Mode PreFlight; {0} has to talk to the tenant.'

    'TestUpload.Site.Question'              = 'Which SharePoint site? For example:'
    'TestUpload.Site.Label'                 = 'Site'
    'TestUpload.SignIn.NeedsClientId'       = 'Connecting with -SiteUrl also needs -ClientId. Ask whoever set this up for the application ID.'
    'TestUpload.SignIn.Window'              = 'A sign-in window will open now. Sign in with your work account.'
    'TestUpload.SignIn.Done'                = 'Signed in to {0}'

    'TestUpload.PreFlight.Section'          = 'Pre-flight: {0}'
    'TestUpload.PreFlight.Count'            = '{0} file(s), {1}'
    'TestUpload.PreFlight.LeftOut'          = ', subfolders left out'
    'TestUpload.PreFlight.Measured'         = 'Paths measured against {0}'
    'TestUpload.PreFlight.NotMeasured'      = 'Path length not checked: no target known. Pass -Destination, -Library or -TargetPathPrefix.'
    'TestUpload.PreFlight.Activity'         = 'Pre-flight'
    'TestUpload.PreFlight.Status'           = '{0} of {1}'

    'TestUpload.Finding.PathWouldExceed'    = 'Would be {0} characters at the target, {1} over the {2} character limit.'
    'TestUpload.Finding.PathNearLimit'      = 'Would be {0} characters at the target, only {1} short of the {2} character limit.'
    'TestUpload.Finding.EmptyFile'          = 'File is empty; some upload paths skip zero-byte files without reporting it.'
    'TestUpload.Finding.TooLarge'           = 'File is {0}; SharePoint rejects anything over 250 GB.'
    'TestUpload.Finding.LargeFile'          = 'File is {0}; large uploads time out on slow links and are slow to sync.'
    'TestUpload.Finding.BlockedExtension'   = '''{0}'' is on the blocked extension list; the upload will be refused.'
    'TestUpload.Finding.ExecutableFile'     = '''{0}'' is commonly blocked by tenant policy, mail gateways or AV. Check before relying on it.'
    'TestUpload.Finding.JunkFile'           = 'Local file system artefact that means nothing in SharePoint.'
    'TestUpload.Finding.CaseCollision'      = '{0} local files differ only in capitalisation and would become one file: {1}'
    'TestUpload.Finding.MissingRemote'      = 'Present locally but not in the library: this file did not arrive.'
    'TestUpload.Finding.SizeDiffers'        = 'Local file is {0} bytes, the uploaded copy is {1}.'
    'TestUpload.Finding.MissingLocal'       = 'In the library but not in the local folder: deleted here, left over from an earlier upload, or added by someone else.'
    'TestUpload.Finding.LocalNewer'         = 'The copy on this computer is newer ({0}, SharePoint has {1}): changed after the upload, or an older version went up.'
    'TestUpload.Finding.RemoteNewer'        = 'The copy in SharePoint is newer ({0}, this computer has {1}): edited there since, or stamped with the time of a browser upload.'

    'TestUpload.Verdict.PreFlight.Errors'   = '{0} problem(s) to fix before uploading'
    'TestUpload.Verdict.PreFlight.Warnings' = 'nothing blocking, {0} thing(s) worth a look'
    'TestUpload.Verdict.PreFlight.Clean'    = 'nothing to fix'
    'TestUpload.Verdict.Verify.Missing'     = '{0} file(s) did not arrive'
    'TestUpload.Verdict.Verify.Differs'     = 'everything arrived, {0} file(s) differ'
    'TestUpload.Verdict.Verify.Arrived'     = 'everything arrived'
    'TestUpload.Verdict.Verify.Extra'       = ', {0} file(s) only in SharePoint'

    'TestUpload.Summary.FolderChecked'      = 'Folder checked'
    'TestUpload.Summary.Files'              = 'Files'
    'TestUpload.Summary.UploadingTo'        = 'Uploading to'
    'TestUpload.Summary.NotGiven'           = 'not given, so path lengths were not checked'
    'TestUpload.Summary.Subfolders'         = 'Subfolders'
    'TestUpload.Summary.LeftOut'            = 'left out'
    'TestUpload.Summary.Included'           = 'included'
    'TestUpload.Summary.Result'             = 'Result'
    'TestUpload.Summary.PathLimit'          = 'Path limit'
    'TestUpload.Summary.PathLimitValue'     = '{0} characters, warning below {1} left'
    'TestUpload.Summary.LargeFileFrom'      = 'Large file from'
    'TestUpload.Summary.BlockedTypes'       = 'Blocked types'
    'TestUpload.Summary.NoneConfigured'     = 'none configured'
    'TestUpload.Summary.Checked'            = 'Checked'
    'TestUpload.Summary.FolderOnComputer'   = 'Folder on this computer'
    'TestUpload.Summary.ComparedWith'       = 'Compared with'
    'TestUpload.Summary.Site'               = 'Site'
    'TestUpload.Summary.FilesCompared'      = 'Files compared'
    'TestUpload.Summary.Synchronised'       = 'Synchronised'
    'TestUpload.Summary.Dates'              = 'Dates'
    'TestUpload.Summary.Sizes'              = 'Sizes'
    'TestUpload.Summary.Compared'           = 'compared'
    'TestUpload.Summary.DatesIgnored'       = 'ignored (a browser upload stamps its own time)'
    'TestUpload.Summary.SizesIgnored'       = 'ignored (Office files legitimately differ)'

    'TestUpload.Report.Title.PreFlight'     = 'Before uploading -- {0} file(s), {1}'
    'TestUpload.Report.Title.Verify'        = 'After uploading -- {0}'

    'TestUpload.Verify.Section'             = 'Verify: {0} -> {1}'
    'TestUpload.Verify.Failed.Title'        = 'Nothing was compared, so no verify report was written.'
    'TestUpload.Verify.Failed.Hint'         = 'Correct RemoteFolder in upload-check.xml, or empty it to be
offered the folders that exist.'
    'TestUpload.Verify.PreFlightKept'       = 'The pre-flight report is still in {0}'
    'TestUpload.Verify.Compared'            = '{0} file(s) compared'
    'TestUpload.Category.Synchronised'      = 'Synchronised'
    'TestUpload.Category.MissingRemote'     = 'Missing in SharePoint'
    'TestUpload.Category.MissingLocal'      = 'Missing on this computer'
    'TestUpload.Category.LocalNewer'        = 'Newer on this computer'
    'TestUpload.Category.RemoteNewer'       = 'Newer in SharePoint'
    'TestUpload.Category.SizeDiffers'       = 'Different size'

    'TestUpload.Result.Section'             = 'Result'
    'TestUpload.Result.Tally'               = '{0} error(s), {1} warning(s), {2} info'
    'TestUpload.Result.Nothing'             = 'Nothing to fix.'
    'TestUpload.Result.Ready'               = 'Ready to upload.'
    'TestUpload.Result.FixErrors'           = 'Fix the errors first: SharePoint will refuse or mangle those files.'
    'TestUpload.Result.Reports'             = 'Reports: {0}'
    'TestUpload.Result.Open'                = 'Open {0} in a browser to read them.'
    'TestUpload.Result.NothingChanged'      = 'Nothing was changed, locally or in SharePoint.'

    'LibraryAudit.Connected'                = 'Connected to {0}'

    'LibraryAudit.All'                      = 'Auditing all {0} visible libraries.'

    'LibraryAudit.Finding.Mismatch'         = 'Unique permissions at depth {0} differ from the parent folder.'

    'LibraryAudit.Clean'                    = 'clean'

    'LibraryAudit.Findings'                 = '  {0} finding(s) -- {1}'

    'LibraryAudit.ReportTitle'              = '{0} -- health report'

    'LibraryAudit.Failed'                   = 'Audit of ''{0}'' failed: {1}'

    'LibraryAudit.ContentTypeHeading'       = '=== Content type links (site-wide) ==='

    'LibraryAudit.ContentTypeFindings'      = '  {0} finding(s)'

    'LibraryAudit.ContentTypeFailed'        = 'Content type check failed: {0}'

    'LibraryAudit.SummaryTitle'             = 'Site audit summary'

    'LibraryAudit.SummaryHeading'           = '=== Summary ==='

    'LibraryAudit.ReportsWritten'           = 'Reports written to: {0}'

    'LibraryAudit.NothingChanged'           = 'Nothing was changed. To act on these findings, see docs/sandbox/getting-started.md.'

    'DocSetSync.Connected'                  = 'Connected to {0}'

    'DocSetSync.All'                        = 'Examining all {0} visible document libraries.'

    'DocSetSync.None'                       = '  no Document Sets -- skipped'

    'DocSetSync.Counts'                     = '  {0} Document Set(s), {1} contained item(s)'

    'DocSetSync.Unshared'                   = '  {0} of them share no columns at all'

    'DocSetSync.Configuration'              = '  configuration: {0} finding(s), {1} column(s) not registered as shared'

    'DocSetSync.Data'                       = '  data: {0} of {1} item(s) out of sync ({2}%)'

    'DocSetSync.ConfigurationTitle'         = '{0} -- Document Set configuration'

    'DocSetSync.Failed'                     = 'Check of ''{0}'' failed: {1}'

    'DocSetSync.DriftTitle'                 = 'Document Set metadata drift'

    'DocSetSync.ConfigurationSummaryTitle'  = 'Document Set configuration'

    'DocSetSync.SummaryHeading'             = '=== Summary ==='

    'DocSetSync.ItemsOut'                   = '  items out of sync : {0}'

    'DocSetSync.ColumnDifferences'          = '  column differences: {0}'

    'DocSetSync.WorstColumns'               = '  Worst columns:'

    'DocSetSync.ColumnItems'                = '    {0}: {1} item(s)'

    'DocSetSync.Reasons'                    = '  Reasons:'

    'DocSetSync.ConfigurationFindings'      = '  Configuration findings:'

    'DocSetSync.ReportsWritten'             = 'Reports written to: {0}'

    'DocSetSync.NothingChanged'             = 'Nothing was changed.'

    'DocSetSync.PushDown'                   = 'To push the Document Set values down:'

    'DocSetSync.FixConfiguration'           = 'Fix the configuration too, or the drift comes back. See docs/sandbox/document-sets.md.'

    'DocSetRepair.Connected'                = 'Connected to {0}'

    'DocSetRepair.All'                      = 'Examining all {0} visible document libraries.'

    'DocSetRepair.InSync'                   = '  in sync -- nothing to do'

    'DocSetRepair.OutOfSync'                = '  {0} item(s) out of sync'

    'DocSetRepair.Target'                   = '{0} item(s) in ''{1}'''

    'DocSetRepair.ActionSystem'             = ' (SystemUpdate: no version created)'

    'DocSetRepair.Action'                   = 'Push Document Set metadata down{0}'

    'DocSetRepair.Outcome'                  = '  repaired {0}, skipped {1}, failed {2}'

    'DocSetRepair.Failed'                   = 'Repair of ''{0}'' failed: {1}'

    'DocSetRepair.Before'                   = 'State before the repair: {0}'

    'DocSetRepair.SummaryHeading'           = '=== Summary ==='

    'DocSetRepair.WhatIf'                   = '  -WhatIf: nothing was changed.'

    'DocSetRepair.WouldWrite'               = '  {0} column value(s) on {1} item(s) would be written.'

    'DocSetRepair.NothingChanged'           = '  nothing was changed.'

    'DocSetRepair.Failures'                 = '  Failures:'

    'DocSetRepair.RerunLine1'               = 'Re-run ./scripts/Test-DocumentSetSync.ps1 to confirm, and check the'

    'DocSetRepair.RerunLine2'               = 'configuration findings there so the drift does not simply return.'

    'DocSetRegister.Connected'              = 'Connected to {0}'

    'DocSetRegister.PlanningHeading'        = '=== Planning ==='

    'DocSetRegister.NothingToDo'            = 'Nothing to do: ''{0}'' is in step with every Document Set in {1}.'

    'DocSetRegister.PlanRow'                = '  {0,-24} {1,-8} {2,4} row(s)'

    'DocSetRegister.Moved'                  = '  {0} row(s) belong to a Document Set that has moved library:'

    'DocSetRegister.MovedRow'               = '    {0,-6} {1} -- {2} -> {3}'

    'DocSetRegister.Columns'                = '  register columns: {0}'

    'DocSetRegister.PlanWritten'            = 'Plan written to: {0}'

    'DocSetRegister.NothingChanged'         = 'Nothing was changed.'

    'DocSetRegister.ReadIt'                 = 'Read it, edit the values you want different, then:'

    'DocSetRegister.PlanNotFound'           = 'Plan file ''{0}'' was not found. Run the script without -Plan to generate one.'

    'DocSetRegister.PlanEmpty'              = 'Plan ''{0}'' has no rows.'

    'DocSetRegister.PlanNoColumns'          = 'Plan ''{0}'' has rows to create but no register columns, only provenance ones ({1}). It is probably the wrong file.'

    'DocSetRegister.PlanNoColumn'           = 'Plan ''{0}'' has no ''{1}'' column. Generate a plan by running this script without -Plan, rather than writing one by hand.'

    'DocSetRegister.WritingHeading'         = '=== Writing entries ==='

    'DocSetRegister.RowsFrom'               = '  {0} row(s) from {1}'

    'DocSetRegister.ValueColumns'           = '  columns: {0}'

    'DocSetRegister.AlreadyHolds'           = '  ''{0}'' already holds {1} row(s) with a Document ID'

    'DocSetRegister.SkippedAction'          = '  skipped {0} -- Action ''{1}'' is not one this script writes'

    'DocSetRegister.NoRow'                  = 'No row in ''{0}'' for Document ID ''{1}''. It may have been deleted since the plan was written; re-plan.'

    'DocSetRegister.Missing'                = '  MISSING {0} -- no such row any more; re-plan'

    'DocSetRegister.Ok'                     = '  ok      {0,-6} {1} -- already {2}'

    'DocSetRegister.WouldUpdate'            = '  would update   {0,-6} {1} -- {2}'

    'DocSetRegister.Updated'                = '  updated {0,-6} {1} -- {2} -> {3}'

    'DocSetRegister.Failed'                 = '  FAILED  {0} -- {1}'

    'DocSetRegister.SkippedPresent'         = '  skipped {0,-6} {1} -- already in the register'

    'DocSetRegister.DefaultContentType'     = 'default content type'

    'DocSetRegister.WouldCreate'            = '  would create   {0} -- {1}'

    'DocSetRegister.Created'                = '  created {0,-6} {1}'

    'DocSetRegister.SkipLinkText'           = 'Skipping the link text pass (-SkipLinkText).'

    'DocSetRegister.PassTwoWould'           = 'Pass two would set ''{0}'' text from ''{1}'' on the rows created above.'

    'DocSetRegister.NoLinkText'             = 'Nothing was written, so there is no link text to set.'

    'DocSetRegister.LinkTextHeading'        = '=== Setting link text ==='

    'DocSetRegister.SummaryHeading'         = '=== Summary ==='

    'DocSetRegister.SumCreated'             = '  entries created  : {0}'

    'DocSetRegister.SumUpdated'             = '  entries updated  : {0}'

    'DocSetRegister.SumPresent'             = '  already present  : {0}'

    'DocSetRegister.SumCorrect'             = '  already correct  : {0}'

    'DocSetRegister.SumNotFound'            = '  rows not found   : {0}'

    'DocSetRegister.SumFailed'              = '  entries failed   : {0}'

    'DocSetRegister.SumLabelled'            = '  links labelled   : {0}'

    'DocSetRegister.ReportsWritten'         = 'Reports written to: {0}'

    'DocSetRegister.SomeFailed1'            = 'Some rows failed. written.csv has the reason for each. Fix the plan and re-run the same'

    'DocSetRegister.SomeFailed2'            = 'file: rows that succeeded are matched by Document ID and will not be written twice.'

    'ListToPdf.Printing'                    = 'Printing ''{0}'' ...'

    'ListToPdf.WouldPrint'                  = 'Would print {0} row(s) and {1} column(s) to {2}'

    'ListToPdf.Counts'                      = '  {0} row(s), {1} column(s), {2} page(s), digest {3}'

    'ListToPdf.Links'                       = '  {0} clickable link(s)'

    'ListToPdf.Columns'                     = '  columns: {0}'

    'ListToPdf.NotVerified'                 = '  not verified (-SkipVerification)'

    'ListToPdf.ReportTitle'                 = 'Verification of {0} row(s) in {1}'

    'ListToPdf.Verified'                    = '  Verified: every printed value was found in the PDF.'

    'ListToPdf.NotFullyVerified'            = '  Not fully verified. See verification.html -- the PDF may still be correct.'

    'ListToPdf.Failed'                      = '  {0} value(s) or check(s) failed. The PDF is missing data:'

    'ListToPdf.More'                        = '    ... and {0} more'

    'ListToPdf.UsualCause'                  = '  Usual cause: too many columns for the paper. Lower -FontSize, use -PaperSize A3, or print fewer columns.'

    'ListToPdf.ReportIn'                    = '  Report and log in {0}'

    'FieldValue.ListNotFound'               = 'List or library ''{0}'' was not found on {1}.'

    'FieldValue.Blank'                      = '(blank)'

    'FieldValue.Found'                      = '''{0}'': {1} item(s) with {2} = {3} -> ''{4}''.'

    'FieldValue.Action'                     = 'Set {0} = ''{1}'' (was {2}) on item {3}'

    'FieldValue.Failed'                     = 'Failed to update item {0} in ''{1}'': {2}'

    'FieldValue.Done'                       = 'Done. {0} item(s) updated, {1} failed.'

    'ListSchema.Reading'                    = '''{0}'' wird gelesen ...'

    'ListSchema.NoSourceView'               = 'Source list ''{0}'' has no default view; -CopyDefaultView will be skipped.'

    'ListSchema.ReadOnly'                   = 'Read {0} column(s) from ''{1}''. Nothing written.'

    'ListSchema.SchemaWritten'              = 'Schema written to {0}'

    'ListSchema.RerunApply'                 = 'Re-run with -Apply to create these columns on the target.'

    'ListSchema.Writing'                    = 'Writing to ''{0}'' ...'

    'ListSchema.NoTargetView'               = 'Target list ''{0}'' has no default view.'

    'ListSchema.ViewAction'                 = 'Set view columns to {0}'

    'ListSchema.ViewNow'                    = 'Default view now shows: {0}'

    'ListSchema.Done'                       = 'Done. Log and schema in {0}'

    'Register.NeedsSiteUrl'                 = '-ProfileName requires -SiteUrl so the profile knows which site to connect to.'

    'Register.Installing'                   = 'Installing PnP.PowerShell...'

    'Register.Action'                       = 'Register Entra ID application ''{0}'' with {1}'

    'Register.Registering'                  = 'Registering ''{0}'' in {1}...'

    'Register.BrowserWillOpen'              = 'A browser window will open for sign-in and consent.'

    'Register.Complete'                     = 'Registration complete.'

    'Register.ClientId'                     = '  Client ID: {0}'

    'Register.Consent1'                     = 'Consent can take a few minutes to propagate. If the first connection'

    'Register.Consent2'                     = 'fails with an authorisation error, wait and retry.'

    'Register.ProfileDescription'           = 'Registered by Register-PnPApplication.ps1 on {0}'

    'Register.ProfileSaved'                 = 'Saved profile ''{0}''. Connect with: Connect-O365 -ProfileName {0}'

    'Register.SaveAsProfile'                = 'Save it as a profile with:'

    'DateSeries.DefaultNotJson'             = '-Default could not be read as JSON: {0} From a shell, pass it as JSON: -Default ''{{"Status":"terminiert"}}''. From a PowerShell prompt, a hashtable works: -Default @{{ Status = ''terminiert'' }}'

    'DateSeries.DefaultNotObject'           = '-Default must be a JSON object, for example: -Default ''{"Status":"terminiert"}'''

    'DateSeries.DefaultWrongType'           = '-Default must be a hashtable or a JSON object, not {0}.'

    'DateSeries.NeedsEnd'                   = 'Give the series an end: either -Until <date> or -Count <n>.'

    'DateSeries.NoDates'                    = 'That recurrence matches no dates. Nothing to plan.'

    'DateSeries.Planned'                    = 'Planned {0} entry(s) for ''{1}''.'

    'DateSeries.PlanPath'                   = 'Plan: {0}'

    'DateSeries.ReadIt'                     = 'Read it, edit it, then write it:'

    'DateSeries.PlanNotFound'               = 'Plan file ''{0}'' was not found.'

    'DateSeries.PlanEmpty'                  = 'Plan ''{0}'' has no rows.'

    'DateSeries.ReadingColumns'             = 'Reading the columns of ''{0}'' ...'

    'DateSeries.ListNotFound'               = 'List ''{0}'' was not found. This site has: {1}'

    'DateSeries.AmbiguousColumn'            = '''{0}'' is the display name of more than one column on ''{1}'': {2}. Name it by its internal name instead.'

    'DateSeries.DateFieldUnknown'           = '-DateField ''{0}'' matches no column on ''{1}''. Its columns are: {2}'

    'DateSeries.PlanColumnUnknown'          = 'The plan column ''{0}'' matches no column on ''{1}''. Its columns are: {2}. Display names and internal names are both accepted; to keep a column in the plan without writing it, rename it with a leading underscore.'

    'DateSeries.PlanNoDateColumn'           = 'The plan has no ''{0}'' column. Its value columns are: {1}. Pass -DateField with the name the plan actually uses.'

    'DateSeries.KeyLeftOut'                 = '  ''{0}'' is not a column here; leaving it out of the duplicate check.'

    'DateSeries.KeyUnknown'                 = '-DuplicateKey names ''{0}'', which matches no column on ''{1}''. Its columns are: {2}'

    'DateSeries.NoKeyColumns'               = 'None of the -DuplicateKey columns exist on ''{0}''. Pass -AllowDuplicate to write without the check.'

    'DateSeries.DuplicateCheck'             = '  duplicate check: {0}'

    'DateSeries.KeyNotPlanned'              = 'The duplicate check uses {0}, which the plan has no column for. A plan row is empty there, so it can only match an entry that is empty there too -- in practice nothing will be recognised as a duplicate.'

    'DateSeries.ReadingEntries'             = 'Reading existing entries from ''{0}'' ...'

    'DateSeries.ExistingKeys'               = '  {0} existing entry key(s).'

    'DateSeries.NotADate'                   = 'Row ''{0}'' is not a date this can read; skipping it.'

    'DateSeries.Skip'                       = '  skip {0} -- already on the list'

    'DateSeries.Created'                    = '  created {0}'

    'DateSeries.WouldCreate'                = 'Would create {0} entry(s); {1} skipped.'

    'DateSeries.Done'                       = 'Created {0} entry(s); {1} skipped.'

    'DateSeries.Log'                        = 'Log: {0}'
}
