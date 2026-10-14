@{
    # Messages for the module, English. One key per message; every key exists in
    # both languages (tests/Unit/Language.Tests.ps1 checks that). {0}, {1} are
    # placeholders and must appear in both languages.
    #
    # Keep this file UTF-8 with a byte order mark: Windows PowerShell 5.1 reads
    # a file without one as ANSI and turns an umlaut into garbage.

    'Common.MessageUnavailable'      = 'Message unavailable ({0}).'

    'Language.Save.Action'           = 'Save the language "{0}"'
    'Language.NotSaved'              = 'The language applies to this session but could not be saved to {0}.'

    'Language.Name.en'               = 'English'
    'Language.Name.de'               = 'Deutsch'
    'Language.Picker.Line'           = 'Language: {0}   (L = change / ändern)'
    'Language.Picker.Title'          = 'Which language?'
    'Language.Picker.Option1'        = '    1) English'
    'Language.Picker.Option2'        = '    2) Deutsch'
    'Language.Picker.Option3'        = '    3) Follow Windows'
    'Language.Picker.Prompt'         = 'Number, or Enter to keep it'

    'Language.Follow'                = 'Follow Windows'

    'Report.Status.MissingRemote'    = 'Missing in SharePoint'
    'Report.Status.MissingLocal'     = 'Missing on this computer'
    'Report.Status.LocalNewer'       = 'Newer on this computer'
    'Report.Status.RemoteNewer'      = 'Newer in SharePoint'
    'Report.Status.SizeDiffers'      = 'Different size'
    'Report.Status.Match'            = 'Synchronised'
    'Report.Bytes'                   = '{0} bytes'
    'Report.Meta.Generated'          = 'Generated {0}'
    'Report.Meta.Rows'               = '{0} row(s)'
    'Report.Empty'                   = 'Nothing to report. Everything checked above was fine.'
    'Report.Hint.Untick'             = 'Untick a box to hide those files.'
    'Report.Column.Status'           = 'Status'
    'Report.Column.File'             = 'File'
    'Report.Column.OnComputer'       = 'On this computer'
    'Report.Column.InSharePoint'     = 'In SharePoint'
    'Report.Column.Size'             = 'Size'
    'Report.Column.Modified'         = 'Modified'
    'Report.Column.Rule'             = 'Rule'
    'Report.Column.List'             = 'List'
    'Report.Column.Target'           = 'Target'
    'Report.Column.Message'          = 'Message'
    'Report.Severity.Error'          = 'Error'
    'Report.Severity.Warning'        = 'Warning'
    'Report.Severity.Info'           = 'Info'
    'Report.Findings'                = '{0} finding(s)'
    'Report.Wrote'                   = 'Wrote {0} report with {1} row(s) to ''{2}''.'

    'Rule.FileName.IllegalCharacter' = 'Name contains character(s) SharePoint does not permit: {0}'
    'Rule.FileName.LeadingSpace'     = 'Name begins with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingSpace'    = 'Name ends with whitespace, which some clients strip silently.'
    'Rule.FileName.TrailingPeriod'   = 'Name ends with a period, which the OneDrive sync client rejects.'
    'Rule.FileName.ReservedName'     = '''{0}'' is a reserved name and cannot be used.'
    'Rule.FileName.ReservedPrefix'   = 'Name starts with a reserved prefix (~$ or _vti_).'
    'Rule.FileName.TooLong'          = 'Name is {0} characters; the limit is 255.'
    'Rule.FileName.RiskyCharacter'   = 'Name contains {0}, which is legal but breaks some downstream tools.'
}
