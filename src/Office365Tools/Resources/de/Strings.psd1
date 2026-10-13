@{
    # Meldungen des Moduls, Deutsch. Jeder Schlüssel steht in beiden Sprachen
    # (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind Platzhalter und
    # müssen in beiden Sprachen vorkommen.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Common.MessageUnavailable' = 'Meldung nicht verfügbar ({0}).'

    'Language.Save.Action'      = 'Sprache "{0}" speichern'
    'Language.NotSaved'         = 'Die Sprache gilt für diese Sitzung, konnte aber nicht in {0} gespeichert werden.'

    'Language.Name.en'          = 'English'
    'Language.Name.de'          = 'Deutsch'
    'Language.Picker.Line'      = 'Sprache: {0}   (L = ändern / change)'
    'Language.Picker.Title'     = 'Welche Sprache?'
    'Language.Picker.Option1'   = '    1) English'
    'Language.Picker.Option2'   = '    2) Deutsch'
    'Language.Picker.Option3'   = '    3) Windows folgen'
    'Language.Picker.Prompt'    = 'Nummer, oder Enter zum Beibehalten'
}
