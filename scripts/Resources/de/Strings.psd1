@{
    # Meldungen der Skripte in scripts/, Deutsch. Ein Schlüssel pro Meldung,
    # nach dem Skript benannt: TestUpload.* und so weiter. Jeder Schlüssel steht
    # in beiden Sprachen (tests/Unit/Language.Tests.ps1 prüft das). {0}, {1} sind
    # Platzhalter und müssen in beiden Sprachen vorkommen. Ein Wert über mehrere
    # Zeilen wird Zeile für Zeile angezeigt.
    #
    # Diese Datei bleibt UTF-8 mit Byte-Order-Mark: Windows PowerShell 5.1 liest
    # sie sonst als ANSI und macht aus Umlauten Zeichensalat.

    # -- Test-Upload.ps1 -----------------------------------------------------
    'TestUpload.NextStep.Default'           = 'Führe danach denselben Befehl mit -Mode Verify aus, um zu bestätigen, dass alles angekommen ist.'
    'TestUpload.Size.Bytes'                 = '{0} Bytes'

    'TestUpload.Console.Clean'              = 'in Ordnung'
    'TestUpload.Console.Files'              = '{0} Datei(en)'
    'TestUpload.Console.More'               = '... und {0} weitere, siehe Bericht'

    'TestUpload.Choice.Prompt'              = 'Nummer [{0}]'
    'TestUpload.Choice.Invalid'             = 'Bitte tippe eine Zahl zwischen 1 und {0}.'

    'TestUpload.Remote.Question'            = 'Wohin in der Bibliothek sind die Dateien gegangen?'
    'TestUpload.Remote.Compare'             = 'Mit {0} selbst vergleichen'
    'TestUpload.Remote.Inside'              = 'In {0} hineinschauen'
    'TestUpload.Remote.Up'                  = 'Eine Ebene nach oben'

    'TestUpload.Destination.Title'          = 'Wohin in SharePoint sind die Dateien gegangen?'
    'TestUpload.Destination.Help'           = 'Öffne diesen Ordner in SharePoint, kopiere die Adresse aus deinem
Browser und füge sie hier ein. Mit Enter wählst du ihn stattdessen
nach der Anmeldung aus.'
    'TestUpload.Destination.Address'        = 'Adresse'
    'TestUpload.Destination.Says'           = 'Diese Adresse bedeutet:'
    'TestUpload.Destination.Line.Site'      = 'Site        {0}'
    'TestUpload.Destination.Line.Library'   = 'Bibliothek  {0}'
    'TestUpload.Destination.Line.Folder'    = 'Ordner      {0}'
    'TestUpload.Destination.NotNamed'       = '(nicht genannt -- du wirst gefragt)'
    'TestUpload.Destination.Top'            = '(zuoberst in der Bibliothek)'
    'TestUpload.Destination.Conflict'       = '-Destination nennt schon Site, Bibliothek und Ordner, darum kann -{0} nicht zusätzlich angegeben werden. Gib das eine oder das andere an.'

    'TestUpload.Library.NotFound'           = 'Auf {1} gibt es keine Bibliothek namens ''{0}''. {2}'
    'TestUpload.Library.Hint.List'          = 'Bibliotheken auf dieser Site: {0}.'
    'TestUpload.Library.Hint.None'          = 'Auf dieser Site ist keine Dokumentbibliothek sichtbar, es ist also wahrscheinlich die falsche Site.'
    'TestUpload.Library.NoneVisible'        = 'Auf {0} ist keine Dokumentbibliothek sichtbar.'
    'TestUpload.Library.Question'           = 'In welche Bibliothek hast du hochgeladen?'

    'TestUpload.Folder.Prompt'              = 'Welchen Ordner lädst du hoch?'
    'TestUpload.Folder.Label'               = 'Ordner'
    'TestUpload.Folder.NotFound'            = 'Den Ordner ''{0}'' gibt es nicht.'
    'TestUpload.Folder.Required'            = 'Welcher Ordner? Gib -LocalPath an, oder -Interactive, um gefragt zu werden.'

    'TestUpload.Mode.Question'              = 'Was möchtest du tun?'
    'TestUpload.Mode.Option1'               = 'Diesen Ordner prüfen, bevor ich ihn hochlade (ohne Anmeldung)'
    'TestUpload.Mode.Option2'               = 'Ich habe ihn schon hochgeladen -- prüfen, ob alles angekommen ist (mit Anmeldung)'
    'TestUpload.Mode.Option3'               = 'Beides: erst den Ordner prüfen, dann, was angekommen ist (mit Anmeldung)'
    'TestUpload.Mode.NeedsLibrary'          = '-Mode {0} vergleicht mit einer Bibliothek, darum ist -Destination oder -Library nötig.'
    'TestUpload.Mode.OfflineOnly'           = '-Offline gilt nur für -Mode PreFlight; {0} muss mit dem Tenant sprechen.'

    'TestUpload.Site.Question'              = 'Welche SharePoint-Site? Zum Beispiel:'
    'TestUpload.Site.Label'                 = 'Site'
    'TestUpload.SignIn.NeedsClientId'       = 'Für die Verbindung mit -SiteUrl braucht es auch -ClientId. Frag die Person, die das eingerichtet hat, nach der Anwendungs-ID.'
    'TestUpload.SignIn.Window'              = 'Jetzt öffnet sich ein Anmeldefenster. Melde dich mit deinem Geschäftskonto an.'
    'TestUpload.SignIn.Done'                = 'Angemeldet bei {0}'

    'TestUpload.PreFlight.Section'          = 'Vorabprüfung: {0}'
    'TestUpload.PreFlight.Count'            = '{0} Datei(en), {1}'
    'TestUpload.PreFlight.LeftOut'          = ', Unterordner ausgelassen'
    'TestUpload.PreFlight.Measured'         = 'Pfade gemessen gegen {0}'
    'TestUpload.PreFlight.NotMeasured'      = 'Pfadlänge nicht geprüft: Das Ziel ist nicht bekannt. Gib -Destination, -Library oder -TargetPathPrefix an.'
    'TestUpload.PreFlight.Activity'         = 'Vorabprüfung'
    'TestUpload.PreFlight.Status'           = '{0} von {1}'

    'TestUpload.Finding.PathWouldExceed'    = 'Wäre am Ziel {0} Zeichen lang, {1} über der Grenze von {2} Zeichen.'
    'TestUpload.Finding.PathNearLimit'      = 'Wäre am Ziel {0} Zeichen lang, nur {1} unter der Grenze von {2} Zeichen.'
    'TestUpload.Finding.EmptyFile'          = 'Die Datei ist leer; manche Upload-Wege überspringen leere Dateien, ohne es zu melden.'
    'TestUpload.Finding.TooLarge'           = 'Die Datei ist {0} gross; SharePoint lehnt alles über 250 GB ab.'
    'TestUpload.Finding.LargeFile'          = 'Die Datei ist {0} gross; grosse Uploads laufen bei langsamen Verbindungen ab und synchronisieren langsam.'
    'TestUpload.Finding.BlockedExtension'   = '''{0}'' steht auf der Liste gesperrter Endungen; der Upload wird abgelehnt.'
    'TestUpload.Finding.ExecutableFile'     = '''{0}'' wird häufig durch Tenant-Richtlinien, Mail-Gateways oder Virenscanner gesperrt. Prüfe es, bevor du dich darauf verlässt.'
    'TestUpload.Finding.JunkFile'           = 'Überbleibsel des lokalen Dateisystems, das in SharePoint nichts bedeutet.'
    'TestUpload.Finding.CaseCollision'      = '{0} lokale Dateien unterscheiden sich nur in der Gross-/Kleinschreibung und würden zu einer Datei: {1}'
    'TestUpload.Finding.MissingRemote'      = 'Lokal vorhanden, aber nicht in der Bibliothek: Diese Datei ist nicht angekommen.'
    'TestUpload.Finding.SizeDiffers'        = 'Die lokale Datei hat {0} Bytes, die hochgeladene Kopie {1}.'
    'TestUpload.Finding.MissingLocal'       = 'In der Bibliothek, aber nicht im lokalen Ordner: hier gelöscht, von einem früheren Upload übrig oder von jemand anderem hinzugefügt.'
    'TestUpload.Finding.LocalNewer'         = 'Die Kopie auf diesem Computer ist neuer ({0}, SharePoint hat {1}): nach dem Upload geändert, oder eine ältere Version wurde hochgeladen.'
    'TestUpload.Finding.RemoteNewer'        = 'Die Kopie in SharePoint ist neuer ({0}, dieser Computer hat {1}): dort seither bearbeitet, oder mit der Zeit eines Browser-Uploads versehen.'

    'TestUpload.Verdict.PreFlight.Errors'   = '{0} Problem(e), die vor dem Hochladen zu beheben sind'
    'TestUpload.Verdict.PreFlight.Warnings' = 'nichts Blockierendes, {0} Punkt(e) mit einem Blick wert'
    'TestUpload.Verdict.PreFlight.Clean'    = 'nichts zu beheben'
    'TestUpload.Verdict.Verify.Missing'     = '{0} Datei(en) nicht angekommen'
    'TestUpload.Verdict.Verify.Differs'     = 'alles angekommen, {0} Datei(en) unterscheiden sich'
    'TestUpload.Verdict.Verify.Arrived'     = 'alles angekommen'
    'TestUpload.Verdict.Verify.Extra'       = ', {0} Datei(en) nur in SharePoint'

    'TestUpload.Summary.FolderChecked'      = 'Geprüfter Ordner'
    'TestUpload.Summary.Files'              = 'Dateien'
    'TestUpload.Summary.UploadingTo'        = 'Hochladen nach'
    'TestUpload.Summary.NotGiven'           = 'nicht angegeben, darum wurden die Pfadlängen nicht geprüft'
    'TestUpload.Summary.Subfolders'         = 'Unterordner'
    'TestUpload.Summary.LeftOut'            = 'ausgelassen'
    'TestUpload.Summary.Included'           = 'eingeschlossen'
    'TestUpload.Summary.Result'             = 'Ergebnis'
    'TestUpload.Summary.PathLimit'          = 'Pfadgrenze'
    'TestUpload.Summary.PathLimitValue'     = '{0} Zeichen, Warnung ab {1} Zeichen Rest'
    'TestUpload.Summary.LargeFileFrom'      = 'Grosse Datei ab'
    'TestUpload.Summary.BlockedTypes'       = 'Gesperrte Typen'
    'TestUpload.Summary.NoneConfigured'     = 'keine eingerichtet'
    'TestUpload.Summary.Checked'            = 'Geprüft'
    'TestUpload.Summary.FolderOnComputer'   = 'Ordner auf diesem Computer'
    'TestUpload.Summary.ComparedWith'       = 'Verglichen mit'
    'TestUpload.Summary.Site'               = 'Site'
    'TestUpload.Summary.FilesCompared'      = 'Verglichene Dateien'
    'TestUpload.Summary.Synchronised'       = 'Abgeglichen'
    'TestUpload.Summary.Dates'              = 'Datum'
    'TestUpload.Summary.Sizes'              = 'Grössen'
    'TestUpload.Summary.Compared'           = 'verglichen'
    'TestUpload.Summary.DatesIgnored'       = 'ignoriert (ein Browser-Upload setzt seine eigene Zeit)'
    'TestUpload.Summary.SizesIgnored'       = 'ignoriert (Office-Dateien unterscheiden sich berechtigterweise)'

    'TestUpload.Report.Title.PreFlight'     = 'Vor dem Hochladen -- {0} Datei(en), {1}'
    'TestUpload.Report.Title.Verify'        = 'Nach dem Hochladen -- {0}'

    'TestUpload.Verify.Section'             = 'Vergleich: {0} -> {1}'
    'TestUpload.Verify.Failed.Title'        = 'Es wurde nichts verglichen, darum wurde kein Vergleichsbericht geschrieben.'
    'TestUpload.Verify.Failed.Hint'         = 'Korrigiere RemoteFolder in upload-check.xml, oder leere den Eintrag,
damit dir die vorhandenen Ordner angeboten werden.'
    'TestUpload.Verify.PreFlightKept'       = 'Der Bericht der Vorabprüfung liegt weiterhin in {0}'
    'TestUpload.Verify.Compared'            = '{0} Datei(en) verglichen'
    'TestUpload.Category.Synchronised'      = 'Abgeglichen'
    'TestUpload.Category.MissingRemote'     = 'Fehlt in SharePoint'
    'TestUpload.Category.MissingLocal'      = 'Fehlt auf diesem Computer'
    'TestUpload.Category.LocalNewer'        = 'Neuer auf diesem Computer'
    'TestUpload.Category.RemoteNewer'       = 'Neuer in SharePoint'
    'TestUpload.Category.SizeDiffers'       = 'Andere Grösse'

    'TestUpload.Result.Section'             = 'Ergebnis'
    'TestUpload.Result.Tally'               = '{0} Fehler, {1} Warnung(en), {2} Info'
    'TestUpload.Result.Nothing'             = 'Nichts zu beheben.'
    'TestUpload.Result.Ready'               = 'Bereit zum Hochladen.'
    'TestUpload.Result.FixErrors'           = 'Behebe zuerst die Fehler: SharePoint lehnt diese Dateien ab oder verändert sie.'
    'TestUpload.Result.Reports'             = 'Berichte: {0}'
    'TestUpload.Result.Open'                = 'Öffne {0} in einem Browser, um sie zu lesen.'
    'TestUpload.Result.NothingChanged'      = 'Es wurde nichts verändert, weder lokal noch in SharePoint.'

    'LibraryAudit.Connected'                = 'Verbunden mit {0}'

    'LibraryAudit.All'                      = 'Alle {0} sichtbaren Bibliotheken werden geprüft.'

    'LibraryAudit.Finding.Mismatch'         = 'Die eindeutigen Berechtigungen in Tiefe {0} weichen vom übergeordneten Ordner ab.'

    'LibraryAudit.Clean'                    = 'in Ordnung'

    'LibraryAudit.Findings'                 = '  {0} Befund(e) -- {1}'

    'LibraryAudit.ReportTitle'              = '{0} -- Zustandsbericht'

    'LibraryAudit.Failed'                   = 'Die Prüfung von ''{0}'' ist fehlgeschlagen: {1}'

    'LibraryAudit.ContentTypeHeading'       = '=== Inhaltstyp-Verknüpfungen (websiteweit) ==='

    'LibraryAudit.ContentTypeFindings'      = '  {0} Befund(e)'

    'LibraryAudit.ContentTypeFailed'        = 'Die Prüfung der Inhaltstypen ist fehlgeschlagen: {0}'

    'LibraryAudit.SummaryTitle'             = 'Zusammenfassung der Website-Prüfung'

    'LibraryAudit.SummaryHeading'           = '=== Zusammenfassung ==='

    'LibraryAudit.ReportsWritten'           = 'Berichte geschrieben nach: {0}'

    'LibraryAudit.NothingChanged'           = 'Es wurde nichts verändert. Wie du auf diese Befunde reagierst, steht in docs/sandbox/getting-started.md.'

    'DocSetSync.Connected'                  = 'Verbunden mit {0}'

    'DocSetSync.All'                        = 'Alle {0} sichtbaren Dokumentbibliotheken werden untersucht.'

    'DocSetSync.None'                       = '  keine Dokumentsätze -- übersprungen'

    'DocSetSync.Counts'                     = '  {0} Dokumentsatz/-sätze, {1} enthaltene(s) Element(e)'

    'DocSetSync.Unshared'                   = '  {0} davon geben überhaupt keine Spalten frei'

    'DocSetSync.Configuration'              = '  Konfiguration: {0} Befund(e), {1} Spalte(n) nicht als freigegeben eingetragen'

    'DocSetSync.Data'                       = '  Daten: {0} von {1} Element(en) nicht abgeglichen ({2}%)'

    'DocSetSync.ConfigurationTitle'         = '{0} -- Konfiguration der Dokumentsätze'

    'DocSetSync.Failed'                     = 'Die Prüfung von ''{0}'' ist fehlgeschlagen: {1}'

    'DocSetSync.DriftTitle'                 = 'Abweichende Metadaten der Dokumentsätze'

    'DocSetSync.ConfigurationSummaryTitle'  = 'Konfiguration der Dokumentsätze'

    'DocSetSync.SummaryHeading'             = '=== Zusammenfassung ==='

    'DocSetSync.ItemsOut'                   = '  nicht abgeglichene Elemente : {0}'

    'DocSetSync.ColumnDifferences'          = '  Spaltenunterschiede         : {0}'

    'DocSetSync.WorstColumns'               = '  Am stärksten betroffene Spalten:'

    'DocSetSync.ColumnItems'                = '    {0}: {1} Element(e)'

    'DocSetSync.Reasons'                    = '  Gründe:'

    'DocSetSync.ConfigurationFindings'      = '  Befunde zur Konfiguration:'

    'DocSetSync.ReportsWritten'             = 'Berichte geschrieben nach: {0}'

    'DocSetSync.NothingChanged'             = 'Es wurde nichts verändert.'

    'DocSetSync.PushDown'                   = 'Um die Werte der Dokumentsätze nach unten zu übertragen:'

    'DocSetSync.FixConfiguration'           = 'Behebe auch die Konfiguration, sonst kommt die Abweichung zurück. Siehe docs/sandbox/document-sets.md.'

    'DocSetRepair.Connected'                = 'Verbunden mit {0}'

    'DocSetRepair.All'                      = 'Alle {0} sichtbaren Dokumentbibliotheken werden untersucht.'

    'DocSetRepair.InSync'                   = '  abgeglichen -- nichts zu tun'

    'DocSetRepair.OutOfSync'                = '  {0} Element(e) nicht abgeglichen'

    'DocSetRepair.Target'                   = '{0} Element(e) in ''{1}'''

    'DocSetRepair.ActionSystem'             = ' (SystemUpdate: es wird keine Version angelegt)'

    'DocSetRepair.Action'                   = 'Metadaten der Dokumentsätze nach unten übertragen{0}'

    'DocSetRepair.Outcome'                  = '  repariert {0}, übersprungen {1}, fehlgeschlagen {2}'

    'DocSetRepair.Failed'                   = 'Die Reparatur von ''{0}'' ist fehlgeschlagen: {1}'

    'DocSetRepair.Before'                   = 'Zustand vor der Reparatur: {0}'

    'DocSetRepair.SummaryHeading'           = '=== Zusammenfassung ==='

    'DocSetRepair.WhatIf'                   = '  -WhatIf: Es wurde nichts verändert.'

    'DocSetRepair.WouldWrite'               = '  {0} Spaltenwert(e) auf {1} Element(en) würden geschrieben.'

    'DocSetRepair.NothingChanged'           = '  Es wurde nichts verändert.'

    'DocSetRepair.Failures'                 = '  Fehler:'

    'DocSetRepair.RerunLine1'               = 'Führe ./scripts/Test-DocumentSetSync.ps1 zur Bestätigung nochmals aus und prüfe die'

    'DocSetRepair.RerunLine2'               = 'Befunde zur Konfiguration dort, damit die Abweichung nicht einfach zurückkommt.'
}
