@{
    # Meldungen des Moduls, Deutsch. Jeder Schlüssel steht in beiden Sprachen
    # (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind Platzhalter und
    # müssen in beiden Sprachen vorkommen.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Common.MessageUnavailable'      = 'Meldung nicht verfügbar ({0}).'

    'Language.Save.Action'           = 'Sprache "{0}" speichern'
    'Language.NotSaved'              = 'Die Sprache gilt für diese Sitzung, konnte aber nicht in {0} gespeichert werden.'

    'Language.Name.en'               = 'English'
    'Language.Name.de'               = 'Deutsch'
    'Language.Picker.Line'           = 'Sprache: {0}   (L = ändern / change)'
    'Language.Picker.Title'          = 'Welche Sprache?'
    'Language.Picker.Option1'        = '    1) English'
    'Language.Picker.Option2'        = '    2) Deutsch'
    'Language.Picker.Option3'        = '    3) Windows folgen'
    'Language.Picker.Prompt'         = 'Nummer, oder Enter zum Beibehalten'

    'Language.Follow'                = 'Windows folgen'

    'Report.Status.MissingRemote'    = 'Fehlt in SharePoint'
    'Report.Status.MissingLocal'     = 'Fehlt auf diesem Computer'
    'Report.Status.LocalNewer'       = 'Neuer auf diesem Computer'
    'Report.Status.RemoteNewer'      = 'Neuer in SharePoint'
    'Report.Status.SizeDiffers'      = 'Andere Grösse'
    'Report.Status.Match'            = 'Abgeglichen'
    'Report.Bytes'                   = '{0} Bytes'
    'Report.Meta.Generated'          = 'Erstellt {0}'
    'Report.Meta.Rows'               = '{0} Zeile(n)'
    'Report.Empty'                   = 'Nichts zu berichten. Alles oben Geprüfte war in Ordnung.'
    'Report.Hint.Untick'             = 'Entferne das Häkchen, um diese Dateien auszublenden.'
    'Report.Column.Status'           = 'Status'
    'Report.Column.File'             = 'Datei'
    'Report.Column.OnComputer'       = 'Auf diesem Computer'
    'Report.Column.InSharePoint'     = 'In SharePoint'
    'Report.Column.Size'             = 'Grösse'
    'Report.Column.Modified'         = 'Geändert'
    'Report.Column.Rule'             = 'Regel'
    'Report.Column.List'             = 'Liste'
    'Report.Column.Target'           = 'Ziel'
    'Report.Column.Message'          = 'Meldung'
    'Report.Severity.Error'          = 'Fehler'
    'Report.Severity.Warning'        = 'Warnung'
    'Report.Severity.Info'           = 'Info'
    'Report.Findings'                = '{0} Befund(e)'
    'Report.Wrote'                   = '{0}-Bericht mit {1} Zeile(n) nach ''{2}'' geschrieben.'

    'Rule.FileName.IllegalCharacter' = 'Der Name enthält Zeichen, die SharePoint nicht erlaubt: {0}'
    'Rule.FileName.LeadingSpace'     = 'Der Name beginnt mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingSpace'    = 'Der Name endet mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingPeriod'   = 'Der Name endet mit einem Punkt, den der OneDrive-Synchronisierungsclient ablehnt.'
    'Rule.FileName.ReservedName'     = '''{0}'' ist ein reservierter Name und kann nicht verwendet werden.'
    'Rule.FileName.ReservedPrefix'   = 'Der Name beginnt mit einem reservierten Präfix (~$ oder _vti_).'
    'Rule.FileName.TooLong'          = 'Der Name ist {0} Zeichen lang; die Grenze liegt bei 255.'
    'Rule.FileName.RiskyCharacter'   = 'Der Name enthält {0}; das ist erlaubt, bringt aber manche nachgelagerten Werkzeuge durcheinander.'
}
