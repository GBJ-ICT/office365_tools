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
}
