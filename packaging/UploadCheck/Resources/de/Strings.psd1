@{
    # Meldungen des Starters der Upload-Prüfung, Deutsch. Jeder Schlüssel steht
    # in beiden Sprachen (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind
    # Platzhalter und müssen in beiden Sprachen vorkommen. Ein Wert über mehrere
    # Zeilen wird Zeile für Zeile angezeigt.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Upload.SignIn.Missing.Title'       = 'Um zu prüfen, was angekommen ist, muss ich mich anmelden, und mir fehlen dafür Angaben.'

    'Upload.SignIn.Missing.Needed'      = 'Es fehlt noch:
'

    'Upload.SignIn.Missing.Destination' = '    <Destination>   die Adresse des Ordners in SharePoint, aus dem
                    Browser kopiert (trage sie in upload-check.xml ein)'

    'Upload.SignIn.Missing.ClientId'    = '    Anwendungs-ID   die Anwendung, mit der sich deine Organisation anmeldet.
                    Gesucht wird in dieser Reihenfolge:
                      1. <ClientId> in upload-check.xml
                      2. die Umgebungsvariable gbj_client_id
                      3. das Standardprofil in config\profiles.json'

    'Upload.SignIn.Missing.Footer'      = '
Die Adresse kannst du selbst holen: Öffne den Ordner in SharePoint
und kopiere, was in der Adresszeile steht. Die Anwendungs-ID ist eine
einzelne Zeile, die die Person hat, die dir dieses Paket geschickt hat.
Bis dahin funktioniert Option 1 (den Ordner vor dem Hochladen prüfen)
ganz ohne das.'

    'Upload.ClientId.Found'             = 'Anwendungs-ID: {0}'
    'Upload.ClientId.From.Settings'     = 'aus upload-check.xml'
    'Upload.ClientId.From.Environment'  = 'aus der Umgebungsvariable gbj_client_id'
    'Upload.ClientId.From.Profile'      = 'aus dem Standardprofil in config\profiles.json'

    'Setup.Missing.Title'               = 'Ein Teil der Upload-Prüfung fehlt.'
    'Setup.Missing.Body'                = 'Nicht gefunden: {0}

Wenn du ein ZIP mit allem darin bekommen hast, wurde es wahrscheinlich
nur geöffnet statt entpackt: Entpacke den ganzen Ordner und starte die
Prüfung von dort. Sonst starte sie einfach nochmals; sie holt sich eine
frische Kopie.'

    'Settings.Unreadable.Title'         = '{0} konnte nicht gelesen werden.'
    'Settings.Unreadable.Body'          = '{0}

Etwas in der Datei ist fehlerhaft - meistens eine fehlende spitze Klammer
oder eine Einstellung, deren schliessendes Tag nicht zum öffnenden passt.
Öffne die Datei im Editor und suche danach, oder lösche sie: Beim nächsten
Start wird eine frische an ihrer Stelle angelegt.'

    'Settings.WrongFile.Title'          = '{0} ist keine Einstellungsdatei der Upload-Prüfung.'
    'Settings.WrongFile.Body'           = 'Die Datei muss mit <UploadCheck> beginnen und mit </UploadCheck> enden.'

    'Settings.Retired'                  = '{0} in {1} hat keine Wirkung mehr; du kannst diese Zeile löschen.'

    'Settings.Obsolete.Title'           = 'Diese Einstellungsdatei nennt das Ziel noch auf die alte Art.'
    'Settings.Obsolete.Body'            = 'Nicht mehr verwendet: {0}

Alle drei sind durch eine einzige Einstellung ersetzt worden, die du
nicht tippst, sondern kopierst:

    <Destination>  öffne den Ordner in SharePoint, kopiere die ganze
                   Adresse aus dem Browser und füge sie ein

Die Adresse nennt Site, Bibliothek und Ordner zusammen, die drei können
sich also nicht widersprechen - und sie enthält den Kanalordner, den eine
Teams-Site versteckt und den man beim Tippen vergisst.

Lösche diese Zeilen, ergänze eine <Destination>-Zeile und starte nochmals.
Eine frische upload-check.xml zeigt, wie sie aussieht: Benenne deine um,
dann legt der nächste Start eine neue daneben an.'

    'Settings.Unknown.Title'            = 'In der Datei steht eine Einstellung, die ich nicht kenne.'
    'Settings.Unknown.Body'             = 'Unbekannt: {0}

Bekannte Einstellungen: {1}
Prüfe die Schreibweise - Gross- und Kleinschreibung zählt.'

    'Settings.NotNumber.Title'          = 'Die Einstellung <{0}> muss eine ganze Zahl sein.'
    'Settings.NotBoolean.Title'         = 'Die Einstellung <{0}> muss true oder false sein.'
    'Settings.Mode.Title'               = 'Die Einstellung <Mode> muss PreFlight, Verify, Both oder ask sein.'
    'Settings.CurrentValue'             = 'Aktuell steht dort: {0}'

    'Settings.Language.Title'           = 'Die Sprache muss en, de oder auto sein.'
    'Settings.Language.Argument'        = 'Aktuell steht dort: {0}
Angegeben wurde sie mit -Language.'
    'Settings.Language.File'            = 'Aktuell steht dort: {0}
Festgelegt wird sie durch <Language> in upload-check.xml.'
}
