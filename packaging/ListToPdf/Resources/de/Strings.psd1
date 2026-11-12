@{
    # Texte von "SharePoint-Liste als PDF", Deutsch: der Startteil
    # (Start-ListToPdf.ps1) und das Skript, das druckt (Invoke-ListToPdf.ps1).
    # Ein Schlüssel pro Text; jeder Schlüssel gibt es in beiden Sprachen
    # (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind Platzhalter und
    # müssen in beiden Sprachen vorkommen. Ein Text über mehrere Zeilen wird
    # Zeile für Zeile gezeigt.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # eine Datei ohne sie als ANSI und macht aus einem Umlaut Zeichensalat.

    'Tool.ListToPdf.Title'               = 'SharePoint-Liste als PDF'
    'Tool.ListToPdf.Description'         = 'Druckt eine SharePoint-Liste oder eine ihrer Ansichten als PDF, mit allem Text, den Links und den Personen.'

    # -- Start-ListToPdf.ps1 ---------------------------------------------------
    'ListPdf.Prompt.YesNo.DefaultYes'    = '[J/n]'
    'ListPdf.Prompt.YesNo.DefaultNo'     = '[j/N]'

    'ListPdf.Setup.Missing.Title'        = 'Ein Teil des Tools fehlt.'
    'ListPdf.Setup.Missing.Body'         = 'Nicht gefunden: {0}

Wenn du ein ZIP mit allem darin bekommen hast, wurde es wahrscheinlich
nur geöffnet statt entpackt: Entpacke den ganzen Ordner und starte es von
dort. Sonst starte es einfach nochmals; es holt sich eine frische Kopie.'

    'ListPdf.Settings.Unreadable.Title'  = '{0} konnte nicht gelesen werden.'
    'ListPdf.Settings.Unreadable.Body'   = '{0}

In der Datei stimmt etwas nicht - meistens fehlt eine spitze Klammer, oder
das schliessende Tag einer Einstellung passt nicht zum öffnenden.
Öffne die Datei im Editor und suche danach, oder lösche sie: Beim
nächsten Start wird eine frische angelegt.'

    'ListPdf.Settings.WrongFile.Title'   = '{0} ist keine Einstellungsdatei dieses Tools.'
    'ListPdf.Settings.WrongFile.Body'    = 'Die Datei muss mit <ListToPdf> beginnen und mit </ListToPdf> enden.'

    'ListPdf.Settings.Unknown.Title'     = 'In der Datei steht eine Einstellung, die ich nicht kenne.'
    'ListPdf.Settings.Unknown.Body'      = 'Unbekannt: {0}

Bekannte Einstellungen: {1}
Prüfe die Schreibweise - Gross- und Kleinschreibung zählt.'

    'ListPdf.Settings.Choice.Title'      = 'Die Einstellung <{0}> muss eine dieser sein: {1}.'
    'ListPdf.Settings.CurrentValue'      = 'Aktuell steht da: {0}'

    'ListPdf.Settings.Language.Title'    = 'Die Sprache muss en, de oder auto sein.'
    'ListPdf.Settings.Language.Argument' = 'Aktuell steht da: {0}
Angegeben wurde sie mit -Language.'
    'ListPdf.Settings.Language.File'     = 'Aktuell steht da: {0}
Festgelegt wird sie mit <Language> in list-to-pdf.xml.'

    'ListPdf.Site.Question'              = 'Auf welcher SharePoint-Website liegt die Liste?'
    'ListPdf.Site.Help'                  = 'Kopiere die Adresse aus deinem Browser und füge sie hier ein. Es kann die
Adresse der Website sein (https://contoso.sharepoint.com/sites/team) oder
einer Seite darin, etwa der gewünschten Liste: Daraus wird die Website
genommen, und die Liste auch, wenn sie genannt ist. Rechtsklick fügt in
dieses Fenster ein.'
    'ListPdf.Site.Prompt'                = 'Adresse'
    'ListPdf.Site.Shown'                 = 'Website:  {0}'

    'ListPdf.SignIn.Missing.Title'       = 'Zum Drucken einer Liste musst du dich anmelden, und mir fehlen dafür Angaben.'
    'ListPdf.SignIn.Missing.Needed'      = 'Es fehlt noch:
'
    'ListPdf.SignIn.Missing.SiteUrl'     = '    <SiteUrl>       die Adresse der SharePoint-Website, beginnend mit
                    https:// (trage sie in list-to-pdf.xml ein)'
    'ListPdf.SignIn.Missing.ClientId'    = '    Anwendungs-ID   die Anwendung, mit der sich deine Organisation anmeldet.
                    Gesucht wird in dieser Reihenfolge:
                      1. <ClientId> in list-to-pdf.xml
                      2. die Umgebungsvariable gbj_client_id
                      3. das Standardprofil in config\profiles.json'
    'ListPdf.SignIn.Missing.Footer'      = '
Die Adresse kannst du selbst holen: Öffne die Website im Browser und
kopiere, was in der Adressleiste steht. Die Anwendungs-ID ist eine Zeile,
die hat, wer dir dieses Paket geschickt hat.'

    'ListPdf.ClientId.Found'             = 'Anwendungs-ID: {0}'
    'ListPdf.ClientId.From.Settings'     = 'aus list-to-pdf.xml'
    'ListPdf.ClientId.From.Environment'  = 'aus der Umgebungsvariable gbj_client_id'
    'ListPdf.ClientId.From.Profile'      = 'aus dem Standardprofil in config\profiles.json'

    'ListPdf.Pwsh.Missing.Title'         = 'PowerShell 7 ist auf diesem Computer nicht installiert.'
    'ListPdf.Pwsh.Missing.Body'          = 'Es ist ein kostenloser Download von Microsoft und das Einzige, was fehlt.

Installiere es einmal: Öffne das Startmenü, tippe cmd, drücke Enter und füge ein

    winget install --id Microsoft.PowerShell

oder lade es von https://aka.ms/powershell-release herunter.
Starte dann dieses Tool nochmals.'

    'ListPdf.Pnp.Title'                  = 'Zum Anmelden fehlt noch eine Komponente: PnP.PowerShell.'
    'ListPdf.Pnp.Body'                   = 'Es ist ein von Microsoft veröffentlichtes PowerShell-Modul, etwa 100 MB,
das einmal nur für dein Konto installiert wird. Es braucht Internet.'
    'ListPdf.Pnp.Question'               = 'Jetzt installieren? (dauert ein paar Minuten)'
    'ListPdf.Pnp.Declined.Title'         = 'Ohne Anmeldung kann keine Liste gedruckt werden.'
    'ListPdf.Pnp.Declined.Body'          = 'Um die Komponente später zu installieren, in PowerShell 7:

    Install-Module PnP.PowerShell -Scope CurrentUser'
    'ListPdf.Pnp.Installing'             = 'Installiere. Das dauert ein paar Minuten und sagt nichts, solange es arbeitet ...'
    'ListPdf.Pnp.Failed.Title'           = 'Die Komponente konnte nicht installiert werden.'
    'ListPdf.Pnp.Failed.Body'            = 'Meistens fehlt der Internetzugang, oder eine Vorgabe der Firma verbietet
das Installieren von PowerShell-Modulen. Zeige das, wer dir das Paket
geschickt hat.'
    'ListPdf.Pnp.Installed'              = 'Installiert.'

    # -- Invoke-ListToPdf.ps1 --------------------------------------------------
    'ListPdf.Run.Choice.Prompt'          = 'Nummer [{0}]'
    'ListPdf.Run.Choice.Invalid'         = 'Bitte tippe eine Nummer zwischen 1 und {0}.'

    'ListPdf.Run.Folder.Title'           = 'Das PDF kann nicht nach {0} geschrieben werden.'
    'ListPdf.Run.Folder.Hint'            = 'Wähle mit <OutputFolder> in list-to-pdf.xml einen anderen Ordner, oder prüfe, ob du dort schreiben darfst.'

    'ListPdf.Run.Connecting'             = 'Melde mich an bei {0} ...'

    'ListPdf.Run.Address.Site'           = 'Die Adresse liegt in der Website {0}; dort wird angemeldet.'

    'ListPdf.Run.Address.List'           = 'Die Adresse nennt auch die Liste ''{0}'', darum wirst du nicht nach der Liste gefragt.'

    'ListPdf.Run.Address.Sharing'        = 'Das ist ein Freigabelink, der nicht sagt, welche Liste gemeint ist. Daraus wird die Website {0} genommen, und du wirst nach der Liste gefragt. Um das zu überspringen, füge die Adresse der Liste selbst aus deinem Browser ein.'

    'ListPdf.Run.List.None.Title'        = 'Auf {0} gibt es keine Liste zum Drucken.'
    'ListPdf.Run.List.Missing.Title'     = 'Es ist keine Liste genannt, und ich darf nicht fragen. Trage ihren Namen bei <List> in list-to-pdf.xml ein.'
    'ListPdf.Run.List.Question'          = 'Welche Liste soll gedruckt werden?'

    'ListPdf.Run.View.Default'           = '(Standardansicht)'
    'ListPdf.Run.View.Question'          = 'Welche Ansicht von "{0}" soll gedruckt werden?'
    'ListPdf.Run.View.None'              = 'Diese Liste hat keine gespeicherte Ansicht zur Auswahl; alle ihre Spalten werden gedruckt.'

    'ListPdf.Run.Reason.Prompt'          = 'Warum exportierst du das? Es steht auf der ersten Seite. Enter lässt es weg'

    'ListPdf.Run.Printing'               = 'Drucke {0} ...'

    'ListPdf.Run.Empty.Title'            = '{0} hat keine Zeilen, darum wurde kein PDF geschrieben.'
    'ListPdf.Run.Empty.Hint'             = 'Wähle eine andere Ansicht, oder prüfe den Filter dieser Ansicht in SharePoint.'

    'ListPdf.Run.Unverified.Title'       = 'Das PDF wurde geschrieben, aber {0} Wert(e) darin nicht gefunden.'
    'ListPdf.Run.Unverified.More'        = '... und {0} weitere.'
    'ListPdf.Run.Unverified.File'        = 'Verlass dich nicht auf diese Datei: {0}'

    'ListPdf.Run.Done'                   = 'Fertig: {0} Zeile(n), {1} Spalte(n), {2} Seite(n).'
    'ListPdf.Run.NotFullyVerified'       = 'Das PDF konnte nicht zurückgelesen und geprüft werden, darum ist nicht bestätigt, dass alles darauf steht.'

    'ListPdf.Run.Failed.Title'           = 'Die Liste konnte nicht gedruckt werden.'

    'ListPdf.Run.Step.Connect'           = 'Anmelden'

    'ListPdf.Run.Step.Lists'             = 'Lesen der Listen der Website'

    'ListPdf.Run.Step.Views'             = 'Lesen der Ansichten von ''{0}'''

    'ListPdf.Run.Step.Print'             = 'Drucken von ''{0}'''

    'ListPdf.Run.Failed.Step'            = 'Es passierte beim: {0}'

    'ListPdf.Run.Failed.Where'           = 'Art des Fehlers: {0}. Wo, von innen nach aussen:'
}
