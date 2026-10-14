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
}
