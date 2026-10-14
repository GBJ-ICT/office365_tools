@{
    # Meldungen des Werkzeug-Menüs (packaging/Start-Tool.ps1), Deutsch. Jeder
    # Schlüssel steht in beiden Sprachen (tests/Unit/Language.Tests.ps1 prüft das).
    # {0}, {1} sind Platzhalter und müssen in beiden Sprachen vorkommen. Ein Wert
    # über mehrere Zeilen wird Zeile für Zeile angezeigt.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Menu.Heading'              = 'Was möchtest du tun?'
    'Menu.Explain'              = 'Klicke eines an, um es zu starten. Es läuft im Fenster dahinter.'
    'Menu.Close'                = 'Schliessen'
    'Menu.Language.Label'       = 'Language / Sprache:'
    'Menu.List.Prompt'          = 'Nummer [1]'
    'Menu.NothingChosen'        = 'Nichts gewählt, also wurde nichts ausgeführt.'
    'Menu.Window.Failed'        = '(Ein Fenster konnte nicht geöffnet werden: {0})'

    'Menu.From'                 = 'aus {0}'
    'Menu.NotRelease'           = '(kein Release)'

    'Menu.Created'              = '{0} wurde neben {1} angelegt. Deine Einstellungen kommen dort hinein;'
    'Menu.Created.Hint'         = 'öffne sie im Editor und trage sie ein. Bis dahin wirst du gefragt.'

    'Menu.ShowThis'             = 'Zeige dieses Fenster der Person, die dir diese Datei geschickt hat.'
    'Menu.Failed.Title'         = 'Das wurde unerwartet abgebrochen.'
    'Menu.None.Title'           = 'In {0} gibt es keine Werkzeuge, also gibt es nichts auszuführen.'
    'Menu.Pinned.Missing.Title' = 'Dieser Starter führt "{0}" aus, und die gefundene Kopie enthält das nicht.'
    'Menu.Pinned.Missing.Body'  = 'Es gibt kein {0} in
    {1}

Zeige dieses Fenster der Person, die dir diese Datei geschickt hat.'
}
