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
}
