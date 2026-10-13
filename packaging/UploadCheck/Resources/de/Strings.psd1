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

    'Prompt.YesNo.DefaultYes'           = '[J/n]'
    'Prompt.YesNo.DefaultNo'            = '[j/N]'

    'Upload.Heading'                    = 'Upload-Prüfung'
    'Upload.Folder.Intro'               = 'Es öffnet sich ein Fenster. Wähle den Ordner, den du hochlädst.'
    'Upload.Folder.Question'            = 'Welchen Ordner lädst du nach SharePoint hoch?'
    'Upload.Folder.Shown'               = 'Ordner:  {0}'
    'Upload.Folder.None.Title'          = 'Es wurde kein Ordner gewählt, also gibt es nichts zu prüfen.'
    'Upload.Folder.None.Body'           = 'Starte die Prüfung nochmals und wähle einen Ordner, oder ziehe einen Ordner darauf.'
    'Upload.Folder.Missing.Title'       = 'Diesen Ordner gibt es nicht.'
    'Upload.Folder.Missing.Body'        = 'Gesucht wurde: {0}

Wenn du den Pfad getippt hast, prüfe ihn auf Tippfehler. Wenn du ihn
eingefügt hast, stelle sicher, dass der ganze Pfad mitgekommen ist.'

    'Upload.Menu.Title'                 = 'Was möchtest du tun?'
    'Upload.Menu.Option1'               = '    1) Diesen Ordner prüfen, bevor ich ihn hochlade     (ohne Anmeldung)'
    'Upload.Menu.Option2'               = '    2) Ich habe ihn schon hochgeladen - ist alles angekommen?  (mit Anmeldung)'
    'Upload.Menu.Option3'               = '    3) Beides'
    'Upload.Menu.Prompt'                = 'Nummer [1]'

    'Upload.NextStep.FromFile'          = 'Sobald alles hochgeladen ist, setze Mode in upload-check.xml auf ask und starte die Prüfung nochmals, um zu prüfen, ob alles angekommen ist.'
    'Upload.NextStep.FromMenu'          = 'Sobald alles hochgeladen ist, starte die Prüfung nochmals und wähle 2, um zu prüfen, ob alles angekommen ist.'

    'Upload.Destination.Shown'          = 'Ziel: {0}'

    'Upload.Pwsh.Missing.Title'         = 'PowerShell 7 ist auf diesem Computer nicht installiert.'
    'Upload.Pwsh.Missing.Body'          = 'Es ist ein kostenloser Download von Microsoft und das Einzige, was fehlt.

Installiere es einmalig: Öffne das Startmenü, tippe cmd, drücke die
Eingabetaste und füge Folgendes ein:

    winget install --id Microsoft.PowerShell

oder lade es von https://aka.ms/powershell-release herunter.
Starte danach die Prüfung nochmals.'

    'Upload.Pnp.Title'                  = 'Für die Anmeldung fehlt noch eine Komponente: PnP.PowerShell.'
    'Upload.Pnp.Body'                   = 'Es ist ein von Microsoft veröffentlichtes PowerShell-Modul, rund 100 MB gross,
das einmalig nur für dein Konto installiert wird. Es braucht Internet.'
    'Upload.Pnp.Question'               = 'Jetzt installieren? (dauert ein paar Minuten)'
    'Upload.Pnp.Declined.Title'         = 'Ohne Anmeldung kann nicht geprüft werden, was angekommen ist.'
    'Upload.Pnp.Declined.Body'          = 'Option 1 - den Ordner vor dem Hochladen prüfen - funktioniert weiterhin
und braucht nichts zusätzlich. Starte die Prüfung nochmals und wähle sie.

Um die Komponente später zu installieren, in PowerShell 7:

    Install-Module PnP.PowerShell -Scope CurrentUser'
    'Upload.Pnp.Installing'             = 'Wird installiert. Das dauert ein paar Minuten und zeigt währenddessen nichts an...'
    'Upload.Pnp.Failed.Title'           = 'Die Komponente konnte nicht installiert werden.'
    'Upload.Pnp.Failed.Body'            = 'Meistens fehlt der Internetzugang, oder eine Firmenrichtlinie verhindert das
Installieren von PowerShell-Modulen. Zeige diese Meldung der Person, die dir
das Paket geschickt hat.

Option 1 - den Ordner vor dem Hochladen prüfen - funktioniert weiterhin.'
    'Upload.Pnp.Installed'              = 'Installiert.'
}
