@{
    # Meldungen des Moduls, Deutsch. Jeder Schlüssel steht in beiden Sprachen
    # (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind Platzhalter und
    # müssen in beiden Sprachen vorkommen.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Common.MessageUnavailable'            = 'Meldung nicht verfügbar ({0}).'

    'Language.Save.Action'                 = 'Sprache "{0}" speichern'
    'Language.NotSaved'                    = 'Die Sprache gilt für diese Sitzung, konnte aber nicht in {0} gespeichert werden.'

    'Language.Name.en'                     = 'English'
    'Language.Name.de'                     = 'Deutsch'
    'Language.Picker.Line'                 = 'Sprache: {0}   (L = ändern / change)'
    'Language.Picker.Title'                = 'Welche Sprache?'
    'Language.Picker.Option1'              = '    1) English'
    'Language.Picker.Option2'              = '    2) Deutsch'
    'Language.Picker.Option3'              = '    3) Windows folgen'
    'Language.Picker.Prompt'               = 'Nummer, oder Enter zum Beibehalten'

    'Language.Follow'                      = 'Windows folgen'

    'Report.Status.MissingRemote'          = 'Fehlt in SharePoint'
    'Report.Status.MissingLocal'           = 'Fehlt auf diesem Computer'
    'Report.Status.LocalNewer'             = 'Neuer auf diesem Computer'
    'Report.Status.RemoteNewer'            = 'Neuer in SharePoint'
    'Report.Status.SizeDiffers'            = 'Andere Grösse'
    'Report.Status.Match'                  = 'Abgeglichen'
    'Report.Bytes'                         = '{0} Bytes'
    'Report.Meta.Generated'                = 'Erstellt {0}'
    'Report.Meta.Rows'                     = '{0} Zeile(n)'
    'Report.Empty'                         = 'Nichts zu berichten. Alles oben Geprüfte war in Ordnung.'
    'Report.Hint.Untick'                   = 'Entferne das Häkchen, um diese Dateien auszublenden.'
    'Report.Column.Status'                 = 'Status'
    'Report.Column.File'                   = 'Datei'
    'Report.Column.OnComputer'             = 'Auf diesem Computer'
    'Report.Column.InSharePoint'           = 'In SharePoint'
    'Report.Column.Size'                   = 'Grösse'
    'Report.Column.Modified'               = 'Geändert'
    'Report.Column.Rule'                   = 'Regel'
    'Report.Column.List'                   = 'Liste'
    'Report.Column.Target'                 = 'Ziel'
    'Report.Column.Message'                = 'Meldung'
    'Report.Severity.Error'                = 'Fehler'
    'Report.Severity.Warning'              = 'Warnung'
    'Report.Severity.Info'                 = 'Info'
    'Report.Findings'                      = '{0} Befund(e)'
    'Report.Wrote'                         = '{0}-Bericht mit {1} Zeile(n) nach ''{2}'' geschrieben.'

    'Rule.FileName.IllegalCharacter'       = 'Der Name enthält Zeichen, die SharePoint nicht erlaubt: {0}'
    'Rule.FileName.LeadingSpace'           = 'Der Name beginnt mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingSpace'          = 'Der Name endet mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingPeriod'         = 'Der Name endet mit einem Punkt, den der OneDrive-Synchronisierungsclient ablehnt.'
    'Rule.FileName.ReservedName'           = '''{0}'' ist ein reservierter Name und kann nicht verwendet werden.'
    'Rule.FileName.ReservedPrefix'         = 'Der Name beginnt mit einem reservierten Präfix (~$ oder _vti_).'
    'Rule.FileName.TooLong'                = 'Der Name ist {0} Zeichen lang; die Grenze liegt bei 255.'
    'Rule.FileName.RiskyCharacter'         = 'Der Name enthält {0}; das ist erlaubt, bringt aber manche nachgelagerten Werkzeuge durcheinander.'

    'Library.Compare.LocalMissing'         = 'Den lokalen Ordner ''{0}'' gibt es nicht.'

    'Library.Compare.Comparing'            = '''{0}'' wird mit ''{1}'' verglichen.'

    'Library.Compare.LocalFound'           = '{0} lokale Datei(en) gefunden.'

    'Library.Compare.NoFolder'             = 'In ''{1}'' gibt es keinen Ordner ''{0}'', also gab es nichts zum Vergleichen.'

    'Library.Compare.DidYouMean'           = ' Meintest du: {0}?'

    'Library.Compare.TopLevel'             = ' Ordner auf der obersten Ebene der Bibliothek: {0}.'

    'Library.Compare.NoFolders'            = ' Diese Bibliothek enthält überhaupt keine Ordner.'

    'Library.Compare.RemoteFound'          = '{0} Datei(en) in SharePoint unter ''{1}'' gefunden.'

    'Library.Compare.Done'                 = 'Vergleich abgeschlossen.'

    'Library.Address.NotAddress'           = '''{0}'' ist keine Webadresse. Öffne den Ordner in SharePoint und kopiere die ganze Adresse aus dem Browser, sie beginnt mit https://'

    'Library.Address.TeamsLink'            = 'Das ist ein Teams-Link, und er sagt nicht, wo die Dateien liegen. Öffne in Teams den Reiter Dateien, wähle "In SharePoint öffnen" und kopiere dort die Adresse aus dem Browser.'

    'Library.Address.SharingLink'          = 'Das ist ein Freigabelink ("Link kopieren"), und er nennt den Ordner nicht. Öffne den Ordner in SharePoint und kopiere stattdessen die Adresse aus der Adresszeile des Browsers.'

    'Library.Address.PageNotFolder'        = 'Diese Adresse ist eine SharePoint-Seite und kein Ordner. Öffne die Bibliothek, klicke dich in den Ordner mit den Dateien und kopiere dort die Adresse.'

    'Library.Draft.RecordCovers'           = 'Die Änderungsaufzeichnung umfasst {0} Element(e).'

    'Library.Draft.NoRecord'               = 'Es wurde keine Änderungsaufzeichnung geladen. Gib -ChangeRecord mit der before.csv an, die die Reparatur geschrieben hat, oder -IgnoreChangeRecord, um Entwürfe nur nach der Versionsregel zu beurteilen.'

    'Library.Publish.MissingProperty'      = 'Dem Eingabeobjekt fehlt die Eigenschaft ''{0}''. Leite die Ausgabe von Get-SpoFileDraft weiter.'

    'Library.Publish.SkipReason'           = '''{0}'' wird übersprungen: {1}.'

    'Library.Publish.ReadFailed'           = '''{0}'' konnte nicht nochmals gelesen werden: {1}'

    'Library.Publish.SkipChanged'          = '''{0}'' wird übersprungen: Die Version hat sich seit der Prüfung von {1} auf {2} geändert; jemand hat sie bearbeitet.'

    'Library.Publish.SkipCheckedOut'       = '''{0}'' wird übersprungen: Seit der Prüfung ist die Datei an {1} ausgecheckt.'

    'Library.Publish.Action'               = 'Entwurf {0} als Hauptversion veröffentlichen'

    'Library.Publish.Published'            = '''{0}'' veröffentlicht (war {1}).'

    'Library.Publish.Failed'               = '''{0}'' konnte nicht veröffentlicht werden: {1}'

    'Library.Publish.Done'                 = 'Veröffentlichung abgeschlossen: {0} veröffentlicht, {1} übersprungen, {2} fehlgeschlagen.'

    'Library.Names.Checking'               = 'Namen in ''{0}'' werden geprüft.'

    'Library.Names.Done'                   = 'Die Namensprüfung für ''{0}'' ist abgeschlossen.'

    'Library.Paths.Checking'               = 'Pfadlängen in ''{0}'' werden gegen die Grenze von {1} geprüft.'

    'Rule.PathLength.Exceeded'             = 'Der Pfad ist {0} Zeichen lang, {1} über der Grenze von {2} Zeichen.'

    'Rule.PathLength.NearLimit'            = 'Der Pfad ist {0} Zeichen lang, nur {1} unter der Grenze von {2} Zeichen.'

    'Library.Paths.Done'                   = 'Die Pfadlängenprüfung für ''{0}'' ist abgeschlossen.'

    'Library.Health.Running'               = 'Die Zustandsprüfung für ''{0}'' läuft mit den Regeln: {1}.'

    'Library.Health.Empty'                 = 'Die Bibliothek ''{0}'' ist leer.'

    'Rule.PathLength.Exceeded400'          = 'Der Pfad ist {0} Zeichen lang, {1} über der Grenze von 400 Zeichen.'

    'Rule.PathLength.NearLimit400'         = 'Der Pfad ist {0} Zeichen lang, nur {1} unter der Grenze von 400 Zeichen.'

    'Rule.File.CheckedOut'                 = 'Die Datei ist an {0} ausgecheckt; andere sehen den neuesten Inhalt vielleicht nicht.'

    'Rule.File.Large'                      = 'Die Datei ist {0} MB gross, über der Schwelle von {1} MB.'

    'Rule.File.VersionBloat'               = 'Der Versionsverlauf belegt {0} MB bei einer Datei von {1} MB.'

    'Rule.Item.RequiredFieldEmpty'         = 'Die Pflichtspalte ''{0}'' hat keinen Wert.'

    'Rule.Permission.DeepUniqueAssignment' = 'Eindeutige Berechtigungen in Tiefe {0}; dabei verliert man leicht den Überblick.'

    'Library.Health.PermissionReadFailed'  = 'Der Berechtigungsstand von ''{0}'' konnte nicht gelesen werden: {1}'

    'Rule.File.DuplicateName'              = '''{0}'' kommt {1}-mal in verschiedenen Ordnern vor.'

    'Rule.Folder.Empty'                    = 'Der Ordner enthält keine Elemente.'

    'Connection.NotConnectedHelp'          = 'Nicht mit SharePoint verbunden. Führe zuerst ''Connect-O365'' aus (zum Beispiel: Connect-O365 -Profile prod, oder Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId <guid>).'

    'Connection.NotConnected'              = 'Nicht mit SharePoint verbunden. Führe zuerst ''Connect-O365'' aus.'

    'Connection.PnpMissing'                = 'Dieser Befehl spricht mit SharePoint und braucht dafür das Modul PnP.PowerShell. Installiere es einmalig mit: Install-Module PnP.PowerShell -Scope CurrentUser -- oder benutze nur die Offline-Befehle (Test-SpoFileName, Get-SpoRecurringDate, Export-SpoReport und scripts/Test-Upload.ps1 ohne -Library), die nichts zusätzlich brauchen.'

    'Connection.ListsAvailable'            = 'Vorhandene Listen auf {0}: {1}'

    'Connection.ListsNone'                 = 'Auf der verbundenen Site wurden keine sichtbaren Listen gefunden. Prüfe, ob du mit der richtigen Site verbunden bist.'

    'Connection.ListNotFound'              = 'Die Liste oder Bibliothek ''{0}'' wurde nicht gefunden. {1}'

    'Connection.NoProfileStore'            = 'Unter ''{0}'' wurde keine Profildatei gefunden. Kopiere config/profiles.example.json nach config/profiles.json und trage deinen Tenant ein, oder verbinde dich ausdrücklich: Connect-O365 -SiteUrl <url> -ClientId <guid>.'

    'Connection.NoDefaultProfile'          = 'Es wurde kein Profil angegeben und in ''{0}'' ist kein ''defaultProfile'' gesetzt. Vorhandene Profile: {1}.'

    'Connection.ProfileUnknown'            = 'Das Profil ''{0}'' ist in ''{1}'' nicht definiert. Vorhandene Profile: {2}.'

    'Connection.Connecting'                = 'Verbindung zu ''{0}'' mit der Client-ID ''{1}'' wird aufgebaut.'

    'Connection.Failed'                    = 'Die Verbindung zu ''{0}'' ist fehlgeschlagen: {1} Prüfe, ob die Client-ID in diesem Tenant registriert ist und ob du Zugriff auf die Site hast. Siehe docs/sandbox/authentication.md.'

    'Connection.Connected'                 = 'Mit ''{0}'' verbunden.'

    'Connection.NothingToDisconnect'       = 'Es gibt keine aktive Verbindung, die getrennt werden könnte.'

    'Connection.DisconnectAction'          = 'Trennen'

    'Connection.DisconnectError'           = 'PnP meldete beim Trennen einen Fehler: {0}'

    'Connection.Disconnected'              = 'Von ''{0}'' getrennt.'

    'Connection.NotConnectedShort'         = 'Nicht verbunden. Führe ''Connect-O365'' aus, um dich zu verbinden.'

    'Connection.NoStoreShort'              = 'Unter ''{0}'' gibt es keine Profildatei. Kopiere config/profiles.example.json nach config/profiles.json, um eine anzulegen.'

    'Connection.ProfileMissing'            = 'Das Profil ''{0}'' gibt es nicht; es gibt nichts zu entfernen.'

    'Connection.RemoveProfileAction'       = 'Profil entfernen'

    'Connection.ProfileRemoved'            = 'Das Profil ''{0}'' wurde entfernt.'

    'Connection.UpdateProfileAction'       = 'Profil aktualisieren'

    'Connection.CreateProfileAction'       = 'Profil anlegen'

    'Connection.LogFooterFailed'           = 'Die Fusszeile des Protokolls konnte nicht geschrieben werden: {0}'
}
