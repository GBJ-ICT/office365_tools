@{
    # Meldungen des Moduls, Deutsch. Jeder Schlüssel steht in beiden Sprachen
    # (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind Platzhalter und
    # müssen in beiden Sprachen vorkommen.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    'Common.MessageUnavailable'                                = 'Meldung nicht verfügbar ({0}).'

    'Language.Save.Action'                                     = 'Sprache "{0}" speichern'
    'Language.NotSaved'                                        = 'Die Sprache gilt für diese Sitzung, konnte aber nicht in {0} gespeichert werden.'

    'Language.Name.en'                                         = 'English'
    'Language.Name.de'                                         = 'Deutsch'
    'Language.Picker.Line'                                     = 'Sprache: {0}   (L = ändern / change)'
    'Language.Picker.Title'                                    = 'Welche Sprache?'
    'Language.Picker.Option1'                                  = '    1) English'
    'Language.Picker.Option2'                                  = '    2) Deutsch'
    'Language.Picker.Option3'                                  = '    3) Windows folgen'
    'Language.Picker.Prompt'                                   = 'Nummer, oder Enter zum Beibehalten'

    'Language.Follow'                                          = 'Windows folgen'

    'Report.Status.MissingRemote'                              = 'Fehlt in SharePoint'
    'Report.Status.MissingLocal'                               = 'Fehlt auf diesem Computer'
    'Report.Status.LocalNewer'                                 = 'Neuer auf diesem Computer'
    'Report.Status.RemoteNewer'                                = 'Neuer in SharePoint'
    'Report.Status.SizeDiffers'                                = 'Andere Grösse'
    'Report.Status.Match'                                      = 'Abgeglichen'
    'Report.Bytes'                                             = '{0} Bytes'
    'Report.Meta.Generated'                                    = 'Erstellt {0}'
    'Report.Meta.Rows'                                         = '{0} Zeile(n)'
    'Report.Empty'                                             = 'Nichts zu berichten. Alles oben Geprüfte war in Ordnung.'
    'Report.Hint.Untick'                                       = 'Entferne das Häkchen, um diese Dateien auszublenden.'
    'Report.Column.Status'                                     = 'Status'
    'Report.Column.File'                                       = 'Datei'
    'Report.Column.OnComputer'                                 = 'Auf diesem Computer'
    'Report.Column.InSharePoint'                               = 'In SharePoint'
    'Report.Column.Size'                                       = 'Grösse'
    'Report.Column.Modified'                                   = 'Geändert'
    'Report.Column.Rule'                                       = 'Regel'
    'Report.Column.List'                                       = 'Liste'
    'Report.Column.Target'                                     = 'Ziel'
    'Report.Column.Message'                                    = 'Meldung'
    'Report.Severity.Error'                                    = 'Fehler'
    'Report.Severity.Warning'                                  = 'Warnung'
    'Report.Severity.Info'                                     = 'Info'
    'Report.Findings'                                          = '{0} Befund(e)'
    'Report.Wrote'                                             = '{0}-Bericht mit {1} Zeile(n) nach ''{2}'' geschrieben.'

    'Rule.FileName.IllegalCharacter'                           = 'Der Name enthält Zeichen, die SharePoint nicht erlaubt: {0}'
    'Rule.FileName.LeadingSpace'                               = 'Der Name beginnt mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingSpace'                              = 'Der Name endet mit einem Leerzeichen, das manche Clients stillschweigend entfernen.'
    'Rule.FileName.TrailingPeriod'                             = 'Der Name endet mit einem Punkt, den der OneDrive-Synchronisierungsclient ablehnt.'
    'Rule.FileName.ReservedName'                               = '''{0}'' ist ein reservierter Name und kann nicht verwendet werden.'
    'Rule.FileName.ReservedPrefix'                             = 'Der Name beginnt mit einem reservierten Präfix (~$ oder _vti_).'
    'Rule.FileName.TooLong'                                    = 'Der Name ist {0} Zeichen lang; die Grenze liegt bei 255.'
    'Rule.FileName.RiskyCharacter'                             = 'Der Name enthält {0}; das ist erlaubt, bringt aber manche nachgelagerten Werkzeuge durcheinander.'

    'Library.Compare.LocalMissing'                             = 'Den lokalen Ordner ''{0}'' gibt es nicht.'

    'Library.Compare.Comparing'                                = '''{0}'' wird mit ''{1}'' verglichen.'

    'Library.Compare.LocalFound'                               = '{0} lokale Datei(en) gefunden.'

    'Library.Compare.NoFolder'                                 = 'In ''{1}'' gibt es keinen Ordner ''{0}'', also gab es nichts zum Vergleichen.'

    'Library.Compare.DidYouMean'                               = ' Meintest du: {0}?'

    'Library.Compare.TopLevel'                                 = ' Ordner auf der obersten Ebene der Bibliothek: {0}.'

    'Library.Compare.NoFolders'                                = ' Diese Bibliothek enthält überhaupt keine Ordner.'

    'Library.Compare.RemoteFound'                              = '{0} Datei(en) in SharePoint unter ''{1}'' gefunden.'

    'Library.Compare.Done'                                     = 'Vergleich abgeschlossen.'

    'Library.Address.NotAddress'                               = '''{0}'' ist keine Webadresse. Öffne den Ordner in SharePoint und kopiere die ganze Adresse aus dem Browser, sie beginnt mit https://'

    'Library.Address.TeamsLink'                                = 'Das ist ein Teams-Link, und er sagt nicht, wo die Dateien liegen. Öffne in Teams den Reiter Dateien, wähle "In SharePoint öffnen" und kopiere dort die Adresse aus dem Browser.'

    'Library.Address.SharingLink'                              = 'Das ist ein Freigabelink ("Link kopieren"), und er nennt den Ordner nicht. Öffne den Ordner in SharePoint und kopiere stattdessen die Adresse aus der Adresszeile des Browsers.'

    'Library.Address.PageNotFolder'                            = 'Diese Adresse ist eine SharePoint-Seite und kein Ordner. Öffne die Bibliothek, klicke dich in den Ordner mit den Dateien und kopiere dort die Adresse.'

    'Library.Draft.RecordCovers'                               = 'Die Änderungsaufzeichnung umfasst {0} Element(e).'

    'Library.Draft.NoRecord'                                   = 'Es wurde keine Änderungsaufzeichnung geladen. Gib -ChangeRecord mit der before.csv an, die die Reparatur geschrieben hat, oder -IgnoreChangeRecord, um Entwürfe nur nach der Versionsregel zu beurteilen.'

    'Library.Publish.MissingProperty'                          = 'Dem Eingabeobjekt fehlt die Eigenschaft ''{0}''. Leite die Ausgabe von Get-SpoFileDraft weiter.'

    'Library.Publish.SkipReason'                               = '''{0}'' wird übersprungen: {1}.'

    'Library.Publish.ReadFailed'                               = '''{0}'' konnte nicht nochmals gelesen werden: {1}'

    'Library.Publish.SkipChanged'                              = '''{0}'' wird übersprungen: Die Version hat sich seit der Prüfung von {1} auf {2} geändert; jemand hat sie bearbeitet.'

    'Library.Publish.SkipCheckedOut'                           = '''{0}'' wird übersprungen: Seit der Prüfung ist die Datei an {1} ausgecheckt.'

    'Library.Publish.Action'                                   = 'Entwurf {0} als Hauptversion veröffentlichen'

    'Library.Publish.Published'                                = '''{0}'' veröffentlicht (war {1}).'

    'Library.Publish.Failed'                                   = '''{0}'' konnte nicht veröffentlicht werden: {1}'

    'Library.Publish.Done'                                     = 'Veröffentlichung abgeschlossen: {0} veröffentlicht, {1} übersprungen, {2} fehlgeschlagen.'

    'Library.Names.Checking'                                   = 'Namen in ''{0}'' werden geprüft.'

    'Library.Names.Done'                                       = 'Die Namensprüfung für ''{0}'' ist abgeschlossen.'

    'Library.Paths.Checking'                                   = 'Pfadlängen in ''{0}'' werden gegen die Grenze von {1} geprüft.'

    'Rule.PathLength.Exceeded'                                 = 'Der Pfad ist {0} Zeichen lang, {1} über der Grenze von {2} Zeichen.'

    'Rule.PathLength.NearLimit'                                = 'Der Pfad ist {0} Zeichen lang, nur {1} unter der Grenze von {2} Zeichen.'

    'Library.Paths.Done'                                       = 'Die Pfadlängenprüfung für ''{0}'' ist abgeschlossen.'

    'Library.Health.Running'                                   = 'Die Zustandsprüfung für ''{0}'' läuft mit den Regeln: {1}.'

    'Library.Health.Empty'                                     = 'Die Bibliothek ''{0}'' ist leer.'

    'Rule.PathLength.Exceeded400'                              = 'Der Pfad ist {0} Zeichen lang, {1} über der Grenze von 400 Zeichen.'

    'Rule.PathLength.NearLimit400'                             = 'Der Pfad ist {0} Zeichen lang, nur {1} unter der Grenze von 400 Zeichen.'

    'Rule.File.CheckedOut'                                     = 'Die Datei ist an {0} ausgecheckt; andere sehen den neuesten Inhalt vielleicht nicht.'

    'Rule.File.Large'                                          = 'Die Datei ist {0} MB gross, über der Schwelle von {1} MB.'

    'Rule.File.VersionBloat'                                   = 'Der Versionsverlauf belegt {0} MB bei einer Datei von {1} MB.'

    'Rule.Item.RequiredFieldEmpty'                             = 'Die Pflichtspalte ''{0}'' hat keinen Wert.'

    'Rule.Permission.DeepUniqueAssignment'                     = 'Eindeutige Berechtigungen in Tiefe {0}; dabei verliert man leicht den Überblick.'

    'Library.Health.PermissionReadFailed'                      = 'Der Berechtigungsstand von ''{0}'' konnte nicht gelesen werden: {1}'

    'Rule.File.DuplicateName'                                  = '''{0}'' kommt {1}-mal in verschiedenen Ordnern vor.'

    'Rule.Folder.Empty'                                        = 'Der Ordner enthält keine Elemente.'

    'Connection.NotConnectedHelp'                              = 'Nicht mit SharePoint verbunden. Führe zuerst ''Connect-O365'' aus (zum Beispiel: Connect-O365 -Profile prod, oder Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/team -ClientId <guid>).'

    'Connection.NotConnected'                                  = 'Nicht mit SharePoint verbunden. Führe zuerst ''Connect-O365'' aus.'

    'Connection.PnpMissing'                                    = 'Dieser Befehl spricht mit SharePoint und braucht dafür das Modul PnP.PowerShell. Installiere es einmalig mit: Install-Module PnP.PowerShell -Scope CurrentUser -- oder benutze nur die Offline-Befehle (Test-SpoFileName, Get-SpoRecurringDate, Export-SpoReport und scripts/Test-Upload.ps1 ohne -Library), die nichts zusätzlich brauchen.'

    'Connection.ListsAvailable'                                = 'Vorhandene Listen auf {0}: {1}'

    'Connection.ListsNone'                                     = 'Auf der verbundenen Site wurden keine sichtbaren Listen gefunden. Prüfe, ob du mit der richtigen Site verbunden bist.'

    'Connection.ListNotFound'                                  = 'Die Liste oder Bibliothek ''{0}'' wurde nicht gefunden. {1}'

    'Connection.NoProfileStore'                                = 'Unter ''{0}'' wurde keine Profildatei gefunden. Kopiere config/profiles.example.json nach config/profiles.json und trage deinen Tenant ein, oder verbinde dich ausdrücklich: Connect-O365 -SiteUrl <url> -ClientId <guid>.'

    'Connection.NoDefaultProfile'                              = 'Es wurde kein Profil angegeben und in ''{0}'' ist kein ''defaultProfile'' gesetzt. Vorhandene Profile: {1}.'

    'Connection.ProfileUnknown'                                = 'Das Profil ''{0}'' ist in ''{1}'' nicht definiert. Vorhandene Profile: {2}.'

    'Connection.Connecting'                                    = 'Verbindung zu ''{0}'' mit der Client-ID ''{1}'' wird aufgebaut.'

    'Connection.Failed'                                        = 'Die Verbindung zu ''{0}'' ist fehlgeschlagen: {1} Prüfe, ob die Client-ID in diesem Tenant registriert ist und ob du Zugriff auf die Site hast. Siehe docs/sandbox/authentication.md.'

    'Connection.Connected'                                     = 'Mit ''{0}'' verbunden.'

    'Connection.NothingToDisconnect'                           = 'Es gibt keine aktive Verbindung, die getrennt werden könnte.'

    'Connection.DisconnectAction'                              = 'Trennen'

    'Connection.DisconnectError'                               = 'PnP meldete beim Trennen einen Fehler: {0}'

    'Connection.Disconnected'                                  = 'Von ''{0}'' getrennt.'

    'Connection.NotConnectedShort'                             = 'Nicht verbunden. Führe ''Connect-O365'' aus, um dich zu verbinden.'

    'Connection.NoStoreShort'                                  = 'Unter ''{0}'' gibt es keine Profildatei. Kopiere config/profiles.example.json nach config/profiles.json, um eine anzulegen.'

    'Connection.ProfileMissing'                                = 'Das Profil ''{0}'' gibt es nicht; es gibt nichts zu entfernen.'

    'Connection.RemoveProfileAction'                           = 'Profil entfernen'

    'Connection.ProfileRemoved'                                = 'Das Profil ''{0}'' wurde entfernt.'

    'Connection.UpdateProfileAction'                           = 'Profil aktualisieren'

    'Connection.CreateProfileAction'                           = 'Profil anlegen'

    'Connection.LogFooterFailed'                               = 'Die Fusszeile des Protokolls konnte nicht geschrieben werden: {0}'

    'ContentType.AddToList.NotFound'                           = 'Der Website-Inhaltstyp ''{0}'' wurde nicht gefunden. Vorhanden: {1}'

    'ContentType.AddToList.EnableAction'                       = 'Inhaltstypverwaltung aktivieren'

    'ContentType.AddToList.Enabled'                            = 'Die Inhaltstypverwaltung wurde für ''{0}'' aktiviert.'

    'ContentType.AddToList.AddAction'                          = 'Inhaltstyp ''{0}'' hinzufügen'

    'ContentType.AddToList.Added'                              = '''{0}'' wurde zu ''{1}'' hinzugefügt.'

    'ContentType.AddToList.Failed'                             = '''{0}'' konnte nicht zu ''{1}'' hinzugefügt werden: {2}'

    'ContentType.AddToList.RemoveBuiltinAction'                = 'Eingebauten Inhaltstyp ''{0}'' entfernen'

    'ContentType.AddToList.RemovedBuiltin'                     = 'Der eingebaute Inhaltstyp ''{0}'' wurde aus ''{1}'' entfernt.'

    'ContentType.AddToList.RemoveBuiltinFailed'                = 'Der eingebaute Inhaltstyp konnte nicht entfernt werden: {0}'

    'ContentType.AddToList.NoBuiltin'                          = 'In ''{0}'' gibt es keinen eingebauten Inhaltstyp Dokument; es gibt nichts zu entfernen.'

    'ContentType.AddField.WhereList'                           = 'der Liste ''{0}'''

    'ContentType.AddField.WhereSite'                           = 'dieser Website'

    'ContentType.AddField.NotFound'                            = 'Der Inhaltstyp ''{0}'' wurde auf {1} nicht gefunden. Mit Get-SpoContentType siehst du, was es gibt.'

    'ContentType.AddField.Sealed'                              = 'Der Inhaltstyp ''{0}'' ist versiegelt und kann nicht geändert werden. Hebe die Versiegelung zuerst in den Websiteeinstellungen auf, oder leite einen neuen Inhaltstyp davon ab.'

    'ContentType.AddField.AlreadyThere'                        = '''{0}'' ist bereits in ''{1}''; übersprungen.'

    'ContentType.AddField.NoSiteColumn'                        = 'Die Websitespalte ''{0}'' gibt es nicht. Lege sie mit New-SpoField an, oder prüfe den internen Namen mit Get-SpoField.'

    'ContentType.AddField.Action'                              = 'Spalte ''{0}'' hinzufügen'

    'ContentType.AddField.Added'                               = '''{0}'' wurde zu ''{1}'' hinzugefügt.'

    'ContentType.AddField.Failed'                              = '''{0}'' konnte nicht zu ''{1}'' hinzugefügt werden: {2}'

    'ContentType.AddField.Done'                                = 'Spaltenänderungen abgeschlossen: {0} hinzugefügt, {1} waren schon vorhanden.'

    'ContentType.AddField.ChildrenNotUpdated'                  = 'Bestehende Listenkopien dieses Inhaltstyps wurden nicht aktualisiert. Führe den Befehl nochmals mit -UpdateChildren aus, oder nimm Sync-SpoContentType, um die Änderung nach unten zu geben.'

    'ContentType.AddListField.SchemaMissing'                   = 'Bei -Schema fehlt ''{0}''. Es erwartet die Ausgabe von Get-SpoListFieldSchema; um stattdessen eine Spalte zu beschreiben, nimm die Parameter -DisplayName und -Type.'

    'ContentType.AddListField.Unportable'                      = '''{0}'' ({1}) wird übersprungen: {2} Gib -AllowUnportableType an, um sie trotzdem anzulegen.'

    'ContentType.AddListField.NoInternalName'                  = 'Aus ''{0}'' liess sich kein gültiger interner Name ableiten. Interne Namen müssen mit einem Buchstaben beginnen und dürfen nur Buchstaben, Ziffern und Unterstriche enthalten. Gib -InternalName ausdrücklich an.'

    'ContentType.AddListField.NeedsChoice'                     = 'Eine Spalte vom Typ {0} braucht ihre Optionen. Gib -Choice an, zum Beispiel: -Choice ''Offen'', ''Geschlossen'''

    'ContentType.AddListField.AlreadyThere'                    = 'Die Spalte ''{0}'' ist bereits in ''{1}''; sie bleibt, wie sie ist.'

    'ContentType.AddListField.Action'                          = 'Listenspalte hinzufügen'

    'ContentType.AddListField.Added'                           = 'Die Spalte ''{0}'' wurde zu ''{1}'' hinzugefügt.'

    'ContentType.AddListField.Failed'                          = 'Die Spalte ''{0}'' konnte nicht zu ''{1}'' hinzugefügt werden: {2}'

    'ContentType.AddListField.NoDefaultView'                   = 'Die Liste ''{0}'' hat keine Standardansicht; ''{1}'' wurde keiner Ansicht hinzugefügt.'

    'ContentType.AddListField.AddedToView'                     = '''{0}'' wurde zur Ansicht ''{1}'' hinzugefügt.'

    'ContentType.AddListField.ViewFailed'                      = 'Die Spalte ''{0}'' wurde angelegt, aber das Hinzufügen zur Standardansicht ist fehlgeschlagen: {1}'

    'ContentType.AddListField.Done'                            = '{0} Spalte(n) hinzugefügt; {1} übersprungen.'

    'ContentType.Find.ScopeList'                               = 'der Liste ''{0}'''

    'ContentType.Find.ScopeSite'                               = 'der Website'

    'ContentType.Find.Searching'                               = '{0} Inhaltstyp(en) in {1} werden nach der Spalte ''{2}'' durchsucht.'

    'ContentType.New.Exists'                                   = 'Einen Website-Inhaltstyp namens ''{0}'' gibt es schon (ID {1}). Ändere ihn mit Add-SpoFieldToContentType, oder wähle einen anderen Namen.'

    'ContentType.New.NoParent'                                 = 'Der übergeordnete Inhaltstyp ''{0}'' wurde nicht gefunden. Üblich sind ''Item'' (für Listen) und ''Document'' (für Bibliotheken). Mit Get-SpoContentType -IncludeBuiltIn siehst du, was es gibt.'

    'ContentType.New.Action'                                   = 'Inhaltstyp {0} anlegen'

    'ContentType.New.Created'                                  = 'Der Inhaltstyp ''{0}'' wurde in der Gruppe ''{1}'' angelegt.'

    'ContentType.New.Failed'                                   = 'Der Inhaltstyp ''{0}'' konnte nicht angelegt werden: {1}'

    'ContentType.NewField.NoInternalName'                      = 'Aus ''{0}'' liess sich kein gültiger interner Name ableiten. Interne Namen müssen mit einem Buchstaben beginnen und dürfen nur Buchstaben, Ziffern und Unterstriche enthalten. Gib -InternalName ausdrücklich an.'

    'ContentType.NewField.NeedsChoice'                         = 'Eine Spalte vom Typ {0} braucht ihre Optionen. Gib -Choice an, zum Beispiel: -Choice ''Offen'', ''Geschlossen'''

    'ContentType.NewField.Exists'                              = 'Eine Websitespalte mit dem internen Namen ''{0}'' gibt es schon (Anzeigename ''{1}'', Gruppe ''{2}''). Interne Namen sind dauerhaft und müssen eindeutig sein -- wähle einen anderen -InternalName, oder verwende die vorhandene Spalte mit Add-SpoFieldToContentType.'

    'ContentType.NewField.Action'                              = 'Websitespalte {0} anlegen'

    'ContentType.NewField.Created'                             = 'Die Websitespalte ''{0}'' wurde angelegt (interner Name ''{1}'').'

    'ContentType.NewField.Failed'                              = 'Die Websitespalte ''{0}'' konnte nicht angelegt werden: {1}'

    'ContentType.RemoveFromList.NotAttached'                   = 'Der Inhaltstyp ''{0}'' ist nicht an ''{1}'' angehängt; es gibt nichts zu entfernen.'

    'ContentType.RemoveFromList.InUse'                         = '{0} Element(e) in ''{1}'' verwenden den Inhaltstyp ''{2}'' noch. Ändere diese Elemente zuerst auf einen anderen Inhaltstyp, oder führe den Befehl nochmals mit -Force aus, damit der Server den Vorgang selbst ablehnt.'

    'ContentType.RemoveFromList.Action'                        = 'Inhaltstyp ''{0}'' entfernen'

    'ContentType.RemoveFromList.Removed'                       = '''{0}'' wurde aus ''{1}'' entfernt.'

    'ContentType.RemoveFromList.Failed'                        = '''{0}'' konnte nicht aus ''{1}'' entfernt werden: {2}'

    'ContentType.RemoveField.Action'                           = 'Feld ''{0}'' entfernen'

    'ContentType.RemoveField.Removed'                          = '''{0}'' wurde aus ''{1}'' entfernt.'

    'ContentType.RemoveField.Failed'                           = '''{0}'' konnte nicht aus ''{1}'' entfernt werden: {2}'

    'ContentType.RemoveField.Done'                             = 'Entfernen der Felder abgeschlossen: {0} entfernt, {1} fehlgeschlagen.'

    'ContentType.Sync.NotFound'                                = 'Der Website-Inhaltstyp ''{0}'' wurde nicht gefunden.'

    'ContentType.Sync.Syncing'                                 = '''{0}'' wird in {1} infrage kommende Liste(n) abgeglichen.'

    'ContentType.Sync.AlreadyInSync'                           = '''{0}'' ist bereits abgeglichen.'

    'ContentType.Sync.Action'                                  = 'Feld ''{0}'' hinzufügen'

    'ContentType.Sync.Added'                                   = '''{0}'' wurde zu ''{1}'' hinzugefügt.'

    'ContentType.Sync.Failed'                                  = '''{0}'' konnte nicht zu ''{1}'' hinzugefügt werden: {2}'

    'ContentType.Sync.Done'                                    = 'Abgleich abgeschlossen: {0} Feld(er) hinzugefügt.'

    'ContentType.Link.Checking'                                = '{0} Liste(n) werden gegen {1} Website-Inhaltstyp(en) geprüft.'

    'Rule.ContentType.OrphanedListCopy'                        = 'Der Listen-Inhaltstyp ''{0}'' hat keinen passenden Website-Inhaltstyp; sein übergeordneter wurde wohl gelöscht.'

    'Rule.ContentType.NameDrift'                               = 'Die Listenkopie heisst ''{0}'', stammt aber vom Website-Inhaltstyp ''{1}'' ab.'

    'Rule.ContentType.FieldMissingOnListCopy'                  = 'Der Listenkopie fehlen {0} Feld(er), die der übergeordnete ''{1}'' hat: {2}.'

    'Rule.ContentType.FieldOnlyOnListCopy'                     = 'Die Listenkopie hat {0} Feld(er), die der übergeordnete ''{1}'' nicht hat: {2}.'

    'ContentType.Link.Done'                                    = 'Die Prüfung der Inhaltstyp-Verknüpfungen ist abgeschlossen.'

    'DocumentSet.Mismatch.None'                                = 'In ''{0}'' wurden keine Dokumentsätze gefunden.'

    'DocumentSet.Mismatch.Activity'                            = 'Metadaten der Dokumentsätze in {0} werden geprüft'

    'DocumentSet.Mismatch.NoShared'                            = 'Der Dokumentsatz ''{0}'' hat keine freigegebenen Spalten; es gibt nichts zu vergleichen. Mit Test-SpoDocumentSetSharedColumn siehst du, warum.'

    'DocumentSet.Mismatch.Done'                                = 'Die Prüfung der Dokumentsatz-Metadaten in ''{0}'' ist abgeschlossen.'

    'DocumentSet.Register.ColumnNotWritable'                   = 'Die Spalte ''{0}'' ist keine beschreibbare Spalte der Liste ''{1}''. Beachte: Es muss der interne Name sein, nicht der Anzeigetitel. Führe aus: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'DocumentSet.Register.ContentTypeNotOnList'                = 'Der Inhaltstyp ''{0}'', der der Bibliothek ''{1}'' zugeordnet ist, ist nicht in der Liste ''{2}''. Vorhanden: {3}. Füge ihn zuerst zur Liste hinzu, oder korrigiere -ContentTypeMap.'

    'DocumentSet.Register.Matching'                            = 'Register ''{0}'': {1} Spalte(n) werden nach Namen zugeordnet, Schlüssel ist ''{2}''.'

    'DocumentSet.Register.ItemNoKey'                           = 'Der Registereintrag {0} hat in ''{1}'' keinen Wert; er lässt sich nicht zuordnen und wird möglicherweise doppelt angelegt.'

    'DocumentSet.Register.ItemsShareKey'                       = 'Die Registereinträge {0} und {1} haben in ''{3}'' denselben Schlüssel ''{2}''.'

    'DocumentSet.Register.Holds'                               = 'Das Register ''{0}'' enthält {1} Eintrag/Einträge, {2} mit brauchbarem Schlüssel.'

    'DocumentSet.Register.NotInMap'                            = 'Die Bibliothek ''{0}'' steht nicht in -ContentTypeMap; ihre Einträge bekommen den Standardinhaltstyp von ''{1}''.'

    'DocumentSet.Register.MissingColumns'                      = 'Die Bibliothek ''{0}'' hat die Spalte(n) {1} nicht; diese Registerspalten bleiben leer.'

    'DocumentSet.Register.NoDocumentId'                        = 'Die Bibliothek ''{0}'' hat keine Spalte für die Dokument-ID. Aktiviere den Dokument-ID-Dienst auf der Website, sonst bleibt ''{1}'' im Register leer.'

    'DocumentSet.Register.Read'                                = '{0} Element(e) aus ''{1}'' gelesen.'

    'DocumentSet.Register.SetNoKey'                            = 'Der Dokumentsatz ''{0}'' hat keinen Wert in der Schlüsselspalte; er wird übersprungen, statt ein Duplikat zu riskieren.'

    'DocumentSet.Register.AnotherRow'                          = 'einer anderen Registerzeile'

    'DocumentSet.Register.SharesKey'                           = 'Der Dokumentsatz ''{0}'' teilt den Schlüssel ''{1}'' mit {2} und dem Registereintrag {3}. Er lässt sich von ihnen nicht unterscheiden und bleibt darum unberührt. Nimm -KeyField mit der Verweisspalte, wenn jede Kopie eine eigene Zeile braucht.'

    'DocumentSet.Register.OutOfStep'                           = 'Der Registereintrag {0} (''{1}'') stimmt mit ''{2}'' nicht überein: {3}.'

    'DocumentSet.Repair.MissingProperty'                       = 'Dem Eingabeobjekt fehlt die Eigenschaft {0}. Leite die Ausgabe von Get-SpoDocumentSetMismatch weiter.'

    'DocumentSet.Repair.ColumnNotOnLibrary'                    = 'Die Spalte ''{0}'' ist nicht in der Bibliothek ''{1}''; sie kann nicht geschrieben werden. Füge sie zuerst zur Bibliothek hinzu.'

    'DocumentSet.Repair.SkipEmpty'                             = '{0} leere Spalte(n) auf ''{1}'' werden übersprungen: Der Dokumentsatz hat keinen Wert zum Übertragen. Mit -ClearEmpty löschst du sie trotzdem.'

    'DocumentSet.Repair.ReadFailed'                            = 'Das Dokumentsatz-Element {0} in ''{1}'' konnte nicht gelesen werden: {2}'

    'DocumentSet.Repair.Action'                                = '{0} aus dem Dokumentsatz ''{1}'' setzen'

    'DocumentSet.Repair.Updated'                               = '{0} auf ''{1}'' aktualisiert.'

    'DocumentSet.Repair.Failed'                                = '''{0}'' konnte nicht aktualisiert werden: {1}'

    'DocumentSet.Repair.Done'                                  = 'Reparatur der Dokumentsatz-Metadaten abgeschlossen: {0} aktualisiert, {1} übersprungen, {2} fehlgeschlagen.'

    'Rule.DocumentSet.TemplateUnreadable'                      = 'Die Dokumentsatzvorlage für ''{0}'' konnte nicht gelesen werden, darum lassen sich ihre freigegebenen Spalten nicht prüfen.'

    'Rule.DocumentSet.NoSharedColumn'                          = 'Der Dokumentsatz ''{0}'' hat keine freigegebenen Spalten, darum erreichen seine Metadaten keines der Dokumente darin.'

    'Rule.DocumentSet.ColumnNotShared'                         = 'Die Spalte ''{0}'' gehört zum Dokumentsatz ''{1}'', ist aber keine freigegebene Spalte, darum wird ihr Wert nie auf den Inhalt übertragen.'

    'Rule.DocumentSet.SharedColumnMissingFromLibrary'          = 'Die freigegebene Spalte ''{0}'' gibt es in der Bibliothek ''{1}'' nicht, darum kann ihr Wert dort auf keinem Element gespeichert werden.'

    'DocumentSet.Shared.ReadFailed'                            = 'Die Spalten des erlaubten Inhaltstyps ''{0}'' konnten nicht gelesen werden: {1}'

    'Rule.DocumentSet.SharedColumnMissingFromChildContentType' = 'Der Inhaltstyp ''{0}'' ist in ''{1}'' erlaubt, aber ihm fehlen {2} freigegebene Spalte(n): {3}. Die Werte werden gespeichert, erscheinen aber nicht im Formular des Dokuments.'

    'DocumentSet.Shared.Done'                                  = 'Die Prüfung der freigegebenen Dokumentsatz-Spalten ist abgeschlossen.'

    'ListItem.Add.UnknownFields'                               = 'Feld(er) in der Liste ''{0}'' nicht gefunden: {1}. Beachte: Es müssen interne Namen sein, nicht Anzeigetitel. Führe aus: Get-PnPField -List ''{0}'' | Select-Object InternalName, Title'

    'ListItem.Add.NoTitle'                                     = '(ohne Titel)'

    'ListItem.Add.Action'                                      = 'Listenelement hinzufügen'

    'ListItem.Add.Added'                                       = 'Element {0} wurde zu ''{1}'' hinzugefügt.'

    'ListItem.Add.Failed'                                      = 'Das Element konnte nicht zu ''{0}'' hinzugefügt werden: {1}'

    'ListItem.Add.Done'                                        = '{0} Element(e) hinzugefügt.'

    'ListItem.Export.Exporting'                                = '{0} Feld(er) aus ''{1}'' werden exportiert.'

    'ListItem.Export.Done'                                     = 'Der Export von ''{0}'' ist abgeschlossen.'

    'ListItem.Import.FileMissing'                              = 'Die Datei ''{0}'' gibt es nicht.'

    'ListItem.Import.UnsupportedType'                          = 'Der Dateityp ''{0}'' wird nicht unterstützt. Nimm .csv, .tsv oder .json.'

    'ListItem.Import.NoRows'                                   = 'Die Datei ''{0}'' enthält keine Zeilen; es gibt nichts zu importieren.'

    'ListItem.Import.UnknownColumns'                           = 'Spalte(n) in ''{0}'' passen zu keinem beschreibbaren Feld der Liste ''{1}'': {2}. Feldnamen müssen interne Namen sein. Führe aus: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title. Mit -Mapping ordnest du Spaltennamen zu.'

    'ListItem.Import.RequiredMissing'                          = 'Die Liste ''{0}'' hat Pflichtfeld(er), die in der Datei fehlen: {1}. Der Server weist Zeilen möglicherweise ab.'

    'ListItem.Import.Validated'                                = '{0} Zeile(n) gegen ''{1}'' geprüft. Spalten: {2}.'

    'ListItem.Import.Action'                                   = '{0} Element(e) aus ''{1}'' anlegen'

    'ListItem.Import.Activity'                                 = 'Import nach {0}'

    'ListItem.Import.RowEmpty'                                 = 'Zeile {0} ist leer; übersprungen.'

    'ListItem.Import.RowFailed'                                = 'Zeile {0} ist fehlgeschlagen: {1}'

    'ListItem.Import.Stopped'                                  = '{0} Der Import wurde nach {1} erfolgreichen Zeile(n) gestoppt, weil -StopOnError angegeben war.'

    'ListItem.Import.Done'                                     = 'Import abgeschlossen: {0} angelegt, {1} fehlgeschlagen, von {2} Zeile(n).'

    'ListItem.Update.Nothing'                                  = 'Auf Element {0} in ''{1}'' gibt es nichts zu aktualisieren: -Values ist leer und -ContentType wurde nicht angegeben. Gib die zu setzenden Felder an, einen Inhaltstyp, auf den das Element umgestellt wird, oder beides.'

    'ListItem.Update.ChangeFields'                             = 'Felder: {0}'

    'ListItem.Update.ChangeContentType'                        = 'Inhaltstyp: {0}'

    'ListItem.Update.Action'                                   = 'Element {0} aktualisieren ({1})'

    'ListItem.Update.Updated'                                  = 'Element {0} in ''{1}'' aktualisiert.'

    'ListItem.Update.Failed'                                   = 'Element {0} in ''{1}'' konnte nicht aktualisiert werden: {2}'

    'ListItem.Update.Done'                                     = '{0} Element(e) aktualisiert.'

    'ListItem.LinkText.ColumnNotFound'                         = 'Die Spalte ''{0}'' wurde in der Liste ''{1}'' nicht gefunden. Beachte: Es muss der interne Name sein, nicht der Anzeigetitel. Führe aus: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'ListItem.LinkText.NotUrl'                                 = 'Die Spalte ''{0}'' der Liste ''{1}'' hat den Typ ''{2}'', nicht URL. Nur eine Hyperlink-Spalte hat einen Anzeigetext zum Setzen; für alles andere nimm Update-SpoListItem.'

    'ListItem.LinkText.TextColumnNotFound'                     = 'Die Spalte ''{0}'' wurde in der Liste ''{1}'' nicht gefunden. Führe aus: Get-PnPField -List ''{1}'' | Select-Object InternalName, Title'

    'ListItem.LinkText.Considering'                            = '{0} Element(e) in ''{1}'' werden für den Linktext aus ''{2}'' betrachtet.'

    'ListItem.LinkText.NoUrl'                                  = 'Element {0} hat in ''{1}'' keine URL; es gibt keinen Link zu beschriften.'

    'ListItem.LinkText.NoText'                                 = 'Element {0} hat in ''{1}'' keinen Wert; der Linktext bleibt unberührt, statt geleert zu werden.'

    'ListItem.LinkText.Action'                                 = 'Text von ''{0}'' auf ''{1}'' setzen'

    'ListItem.LinkText.Set'                                    = 'Der Text von ''{0}'' auf Element {1} wurde auf ''{2}'' gesetzt.'

    'ListItem.LinkText.Failed'                                 = 'Der Text von ''{0}'' auf Element {1} konnte nicht gesetzt werden: {2}'

    'ListItem.LinkText.FailedIn'                               = 'Der Text von ''{0}'' auf Element {1} in ''{2}'' konnte nicht gesetzt werden: {3}'

    'ListItem.LinkText.Done'                                   = 'Linktext-Durchgang abgeschlossen: {0} aktualisiert, {1} bereits richtig, {2} übersprungen, {3} fehlgeschlagen.'

    'Schedule.NeedsWeekday'                                    = '-WeekOfMonth braucht einen Wochentag zum Zählen: der "erste" was? Gib -DayOfWeek an, zum Beispiel: -WeekOfMonth First -DayOfWeek Sunday'

    'Schedule.UntilBeforeStart'                                = '-Until ({0}) liegt vor -Start ({1}).'

    'Permission.Grant.NoRole'                                  = 'Die Rolle ''{0}'' gibt es auf dieser Website nicht. Vorhandene Rollen: {1}'

    'Permission.Grant.Inherits'                                = '''{0}'' erbt seine Berechtigungen derzeit. Um hier etwas zu vergeben, muss die Vererbung unterbrochen werden; das ändert das Sicherheitsmodell für alles darunter. Führe den Befehl nochmals mit -BreakInheritance (und normalerweise -CopyExisting) aus, wenn du das möchtest.'

    'Permission.Grant.BreakAction'                             = 'Berechtigungsvererbung unterbrechen (bestehende kopieren: {0})'

    'Permission.Grant.Broke'                                   = 'Die Vererbung auf ''{0}'' wurde unterbrochen.'

    'Permission.Grant.Action'                                  = '''{0}'' an ''{1}'' vergeben'

    'Permission.Grant.Granted'                                 = '''{0}'' wurde an ''{1}'' auf ''{2}'' vergeben.'

    'Permission.Grant.Failed'                                  = '''{0}'' konnte ''{1}'' auf ''{2}'' nicht vergeben werden: {3}'

    'Permission.Repair.MissingProperty'                        = 'Dem Eingabeobjekt fehlt die Eigenschaft ''{0}''. Leite die Ausgabe von Get-SpoPermissionMismatch weiter.'

    'Permission.Repair.Action'                                 = 'Eindeutige Berechtigungen verwerfen und vom Überobjekt erben'

    'Permission.Repair.Reset'                                  = 'Die Vererbung auf ''{0}'' wurde zurückgesetzt.'

    'Permission.Repair.Failed'                                 = 'Die Vererbung auf ''{0}'' konnte nicht zurückgesetzt werden: {1}'

    'Permission.Repair.Done'                                   = 'Reparatur abgeschlossen: {0} repariert, {1} fehlgeschlagen.'

    'Permission.Revoke.Inherits'                               = '''{0}'' erbt seine Berechtigungen, darum gibt es hier nichts zu entziehen. Entziehe sie stattdessen auf der Ebene, auf der sie vergeben wurden.'

    'Permission.Revoke.ActionRole'                             = '''{0}'' von ''{1}'' entziehen'

    'Permission.Revoke.ActionAll'                              = 'Alle Rollen von ''{0}'' entziehen'

    'Permission.Revoke.AllAtListLevel'                         = 'Alle Rollen auf Listenebene zu entziehen wird nicht unterstützt; gib -Role an.'

    'Permission.Revoke.Done'                                   = '{0} auf ''{1}''.'

    'Permission.Revoke.Failed'                                 = 'Das Entziehen auf ''{0}'' ist fehlgeschlagen: {1}'

    'Permission.Orphaned.CheckingGroups'                       = 'Websitegruppen werden auf verwaiste Mitglieder geprüft.'

    'Rule.Permission.EmptyGroup'                               = 'Die SharePoint-Gruppe ''{0}'' hat keine Mitglieder, hält aber möglicherweise noch Berechtigungen.'

    'Rule.Permission.OrphanedPrincipalInGroup'                 = 'Der Benutzer ''{0}'' in der Gruppe ''{1}'' entspricht keinem aktiven Konto.'

    'Permission.Orphaned.CheckingList'                         = 'Eindeutige Zuweisungen in ''{0}'' werden geprüft.'

    'Rule.Permission.OrphanedPrincipal'                        = 'Das Element gewährt ''{0}'' Zugriff, was keinem aktiven Konto entspricht.'

    'Permission.Mismatch.Scanning'                             = '''{0}'' wird auf abweichende Berechtigungen durchsucht.'

    'Permission.Mismatch.Empty'                                = 'Die Bibliothek ''{0}'' enthält keine Elemente.'

    'Permission.Mismatch.Checking'                             = '{0} Element(e) werden geprüft.'

    'Permission.Mismatch.Activity'                             = 'Berechtigungen in {0} werden geprüft'

    'Permission.Mismatch.ReadFailed'                           = 'Der Berechtigungsstand von ''{0}'' konnte nicht gelesen werden: {1}'

    'Permission.Mismatch.ParentFailed'                         = 'Die Berechtigungen des Überobjekts von ''{0}'' konnten nicht gelesen werden; stattdessen wird mit der Bibliothek verglichen.'

    'Permission.Mismatch.Done'                                 = 'Die Suche in ''{0}'' ist abgeschlossen.'

    'Permission.Report.Building'                               = 'Der Berechtigungsbericht für ''{0}'' wird erstellt.'

    'Permission.Report.ExpandFailed'                           = 'Die Gruppe ''{0}'' konnte nicht aufgelöst werden: {1}'

    'Permission.Report.Activity'                               = 'Berechtigungen in {0} werden berichtet'

    'Permission.Report.ReadFailed'                             = 'Der Berechtigungsstand von ''{0}'' konnte nicht gelesen werden: {1}'

    'Permission.Report.Done'                                   = 'Der Berechtigungsbericht für ''{0}'' ist abgeschlossen.'

    'Pdf.Export.ViewNotFound'                                  = 'Die Ansicht ''{0}'' wurde in ''{1}'' nicht gefunden. Ansichten dieser Liste: {2}'

    'Pdf.Export.ItemLinkNotColumn'                             = '-ItemLink nennt ''{0}'', das keine der gedruckten Spalten ist: {1}'

    'Pdf.Export.DisplayFormFailed'                             = 'Die Adresse des Anzeigeformulars von ''{0}'' konnte nicht gelesen werden: {1}'

    'Pdf.Export.GroupNotColumn'                                = 'Die Gruppierungsspalte ''{0}'' gehört nicht zu den gedruckten Spalten; sie steht über jeder Gruppe, erscheint aber nicht als Spalte.'

    'Pdf.Export.Action'                                        = '{0} Zeile(n) und {1} Spalte(n) als PDF drucken'

    'Pdf.Export.Unverified'                                    = '''{0}'' wurde geschrieben, ohne es zu prüfen.'

    'Pdf.Export.Wrote'                                         = '''{0}'' geschrieben: {1} Zeile(n), {2} Spalte(n), {3} Seite(n), {4} Prüffehler.'

    'Rule.Pdf.Missing'                                         = 'Das PDF gibt es nicht, darum lässt sich über seinen Inhalt nichts prüfen.'

    'Rule.Pdf.NothingToCheck'                                  = 'Es wurden keine Zeilen angegeben, darum wurde das PDF gegen nichts geprüft.'

    'Pdf.Test.Sampling'                                        = 'Geprüft wird eine Stichprobe von {0} Zeile(n) aus {1}.'

    'Rule.Pdf.NotAPdf'                                         = 'Die Datei ist kein PDF, der Export hat also nicht das erzeugt, was er gemeldet hat.'

    'Rule.Pdf.NoPages'                                         = 'Das PDF enthält keine Seiten.'

    'Rule.Pdf.NoTextLayer'                                     = 'Aus dem PDF liess sich kein Text lesen, darum wurde sein Inhalt nicht geprüft. Die Datei selbst kann trotzdem in Ordnung sein.'

    'Rule.Pdf.TruncatedDocument'                               = 'Die abschliessende Bestätigungszeile steht nicht im PDF, das Dokument reicht also nicht bis zum Ende der Daten.'

    'Rule.Pdf.RowCountMismatch'                                = 'Das PDF bestätigt {0} Zeile(n), exportiert wurden aber {1}.'

    'Rule.Pdf.ExtractionSuspect'                               = '{0} von {1} Werten wurden nicht gefunden; meistens heisst das, dass sich der Text des PDFs nicht richtig lesen liess, und nicht, dass die Werte fehlen. Öffne das PDF oder installiere pdftotext, bevor du auf die Befunde unten reagierst.'

    'Rule.Pdf.MissingValue'                                    = 'Zeile {0}, Spalte ''{1}'': Der gedruckte Wert steht nicht im PDF.'

    'Rule.Pdf.MoreMissingValues'                               = '{0} weitere(r) Wert(e) fehlten ebenfalls und sind nicht einzeln aufgeführt.'

    'Rule.Pdf.WrappedValue'                                    = 'Zeile {0}, Spalte ''{1}'': gedruckt, aber über mehrere Zeilen umbrochen.'

    'Rule.Pdf.WrappedValues'                                   = '{0} von {1} Wert(en) wurden über einen Zeilenumbruch gedruckt und ohne Rücksicht auf Leerräume zugeordnet. Mit -ReportWrapped werden sie aufgelistet.'

    'Rule.Pdf.MissingLink'                                     = '{0}: Die Zelle wurde gedruckt, trägt im PDF aber keinen anklickbaren Link.'

    'Rule.Pdf.MoreMissingLinks'                                = '{0} weitere(r) Link(s) fehlten ebenfalls und sind nicht einzeln aufgeführt.'

    'Rule.Pdf.NoLinks'                                         = '{0} Link(s) wurden dargestellt, das PDF enthält aber überhaupt keine Link-Anmerkungen. Der Browser hat den Text ohne die Links gedruckt.'

    'Pdf.Test.Checked'                                         = '{0} Wert(e) gegen ''{1}'' geprüft: {2} fehlend, {3} umbrochen{4}'

    'Pdf.Test.LinksMissing'                                    = ', {0} Link(s) fehlen.'
}
