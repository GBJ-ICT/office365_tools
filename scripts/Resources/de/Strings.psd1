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

    'DocSetRegister.Connected'              = 'Verbunden mit {0}'

    'DocSetRegister.PlanningHeading'        = '=== Planung ==='

    'DocSetRegister.NothingToDo'            = 'Nichts zu tun: ''{0}'' stimmt mit jedem Dokumentsatz in {1} überein.'

    'DocSetRegister.PlanRow'                = '  {0,-24} {1,-8} {2,4} Zeile(n)'

    'DocSetRegister.Moved'                  = '  {0} Zeile(n) gehören zu einem Dokumentsatz, der in eine andere Bibliothek verschoben wurde:'

    'DocSetRegister.MovedRow'               = '    {0,-6} {1} -- {2} -> {3}'

    'DocSetRegister.Columns'                = '  Registerspalten: {0}'

    'DocSetRegister.PlanWritten'            = 'Plan geschrieben nach: {0}'

    'DocSetRegister.NothingChanged'         = 'Es wurde nichts verändert.'

    'DocSetRegister.ReadIt'                 = 'Lies ihn, ändere die Werte, die anders sein sollen, und dann:'

    'DocSetRegister.PlanNotFound'           = 'Die Plandatei ''{0}'' wurde nicht gefunden. Führe das Skript ohne -Plan aus, um eine zu erzeugen.'

    'DocSetRegister.PlanEmpty'              = 'Der Plan ''{0}'' hat keine Zeilen.'

    'DocSetRegister.PlanNoColumns'          = 'Der Plan ''{0}'' hat Zeilen zum Anlegen, aber keine Registerspalten, nur Herkunftsspalten ({1}). Es ist wohl die falsche Datei.'

    'DocSetRegister.PlanNoColumn'           = 'Dem Plan ''{0}'' fehlt die Spalte ''{1}''. Erzeuge einen Plan, indem du das Skript ohne -Plan ausführst, statt ihn von Hand zu schreiben.'

    'DocSetRegister.WritingHeading'         = '=== Einträge werden geschrieben ==='

    'DocSetRegister.RowsFrom'               = '  {0} Zeile(n) aus {1}'

    'DocSetRegister.ValueColumns'           = '  Spalten: {0}'

    'DocSetRegister.AlreadyHolds'           = '  ''{0}'' enthält bereits {1} Zeile(n) mit einer Dokument-ID'

    'DocSetRegister.SkippedAction'          = '  {0} übersprungen -- die Aktion ''{1}'' schreibt dieses Skript nicht'

    'DocSetRegister.NoRow'                  = 'In ''{0}'' gibt es keine Zeile für die Dokument-ID ''{1}''. Die Zeile wurde seit dem Schreiben des Plans vielleicht gelöscht; plane neu.'

    'DocSetRegister.Missing'                = '  FEHLT {0} -- diese Zeile gibt es nicht mehr; plane neu'

    'DocSetRegister.Ok'                     = '  ok      {0,-6} {1} -- bereits {2}'

    'DocSetRegister.WouldUpdate'            = '  würde aktualisieren {0,-6} {1} -- {2}'

    'DocSetRegister.Updated'                = '  aktualisiert {0,-6} {1} -- {2} -> {3}'

    'DocSetRegister.Failed'                 = '  FEHLGESCHLAGEN  {0} -- {1}'

    'DocSetRegister.SkippedPresent'         = '  übersprungen {0,-6} {1} -- bereits im Register'

    'DocSetRegister.DefaultContentType'     = 'Standardinhaltstyp'

    'DocSetRegister.WouldCreate'            = '  würde anlegen   {0} -- {1}'

    'DocSetRegister.Created'                = '  angelegt {0,-6} {1}'

    'DocSetRegister.SkipLinkText'           = 'Der Durchgang für den Linktext wird übersprungen (-SkipLinkText).'

    'DocSetRegister.PassTwoWould'           = 'Der zweite Durchgang würde den Text von ''{0}'' aus ''{1}'' auf den oben angelegten Zeilen setzen.'

    'DocSetRegister.NoLinkText'             = 'Es wurde nichts geschrieben, darum gibt es keinen Linktext zu setzen.'

    'DocSetRegister.LinkTextHeading'        = '=== Linktext wird gesetzt ==='

    'DocSetRegister.SummaryHeading'         = '=== Zusammenfassung ==='

    'DocSetRegister.SumCreated'             = '  angelegte Einträge     : {0}'

    'DocSetRegister.SumUpdated'             = '  aktualisierte Einträge : {0}'

    'DocSetRegister.SumPresent'             = '  schon vorhanden        : {0}'

    'DocSetRegister.SumCorrect'             = '  schon richtig          : {0}'

    'DocSetRegister.SumNotFound'            = '  nicht gefundene Zeilen : {0}'

    'DocSetRegister.SumFailed'              = '  fehlgeschlagene Einträge: {0}'

    'DocSetRegister.SumLabelled'            = '  beschriftete Links     : {0}'

    'DocSetRegister.ReportsWritten'         = 'Berichte geschrieben nach: {0}'

    'DocSetRegister.SomeFailed1'            = 'Einige Zeilen sind fehlgeschlagen. written.csv nennt den Grund für jede. Korrigiere den Plan und führe dieselbe'

    'DocSetRegister.SomeFailed2'            = 'Datei nochmals aus: Erfolgreiche Zeilen werden über die Dokument-ID erkannt und nicht zweimal geschrieben.'

    'ListToPdf.Printing'                    = '''{0}'' wird gedruckt ...'

    'ListToPdf.WouldPrint'                  = '{0} Zeile(n) und {1} Spalte(n) würden nach {2} gedruckt'

    'ListToPdf.Counts'                      = '  {0} Zeile(n), {1} Spalte(n), {2} Seite(n), Prüfsumme {3}'

    'ListToPdf.Links'                       = '  {0} anklickbare(r) Link(s)'

    'ListToPdf.Columns'                     = '  Spalten: {0}'

    'ListToPdf.NotVerified'                 = '  nicht geprüft (-SkipVerification)'

    'ListToPdf.ReportTitle'                 = 'Prüfung von {0} Zeile(n) in {1}'

    'ListToPdf.Verified'                    = '  Geprüft: Jeder gedruckte Wert wurde im PDF gefunden.'

    'ListToPdf.NotFullyVerified'            = '  Nicht vollständig geprüft. Siehe verification.html -- das PDF kann trotzdem in Ordnung sein.'

    'ListToPdf.Failed'                      = '  {0} Wert(e) oder Prüfung(en) sind fehlgeschlagen. Dem PDF fehlen Daten:'

    'ListToPdf.More'                        = '    ... und {0} weitere'

    'ListToPdf.UsualCause'                  = '  Übliche Ursache: zu viele Spalten für das Papier. Verkleinere -FontSize, nimm -PaperSize A3 oder drucke weniger Spalten.'

    'ListToPdf.ReportIn'                    = '  Bericht und Protokoll in {0}'

    'FieldValue.ListNotFound'               = 'Die Liste oder Bibliothek ''{0}'' wurde auf {1} nicht gefunden.'

    'FieldValue.Blank'                      = '(leer)'

    'FieldValue.Found'                      = '''{0}'': {1} Element(e) mit {2} = {3} -> ''{4}''.'

    'FieldValue.Action'                     = '{0} = ''{1}'' setzen (war {2}) auf Element {3}'

    'FieldValue.Failed'                     = 'Element {0} in ''{1}'' konnte nicht aktualisiert werden: {2}'

    'FieldValue.Done'                       = 'Fertig. {0} Element(e) aktualisiert, {1} fehlgeschlagen.'

    'ListSchema.Reading'                    = '''{0}'' wird gelesen ...'

    'ListSchema.NoSourceView'               = 'Die Quellliste ''{0}'' hat keine Standardansicht; -CopyDefaultView wird übersprungen.'

    'ListSchema.ReadOnly'                   = '{0} Spalte(n) aus ''{1}'' gelesen. Es wurde nichts geschrieben.'

    'ListSchema.SchemaWritten'              = 'Schema geschrieben nach {0}'

    'ListSchema.RerunApply'                 = 'Führe das Skript nochmals mit -Apply aus, um diese Spalten im Ziel anzulegen.'

    'ListSchema.Writing'                    = 'Es wird nach ''{0}'' geschrieben ...'

    'ListSchema.NoTargetView'               = 'Die Zielliste ''{0}'' hat keine Standardansicht.'

    'ListSchema.ViewAction'                 = 'Ansichtsspalten auf {0} setzen'

    'ListSchema.ViewNow'                    = 'Die Standardansicht zeigt jetzt: {0}'

    'ListSchema.Done'                       = 'Fertig. Protokoll und Schema in {0}'

    'Register.NeedsSiteUrl'                 = '-ProfileName braucht -SiteUrl, damit das Profil weiss, mit welcher Site es sich verbinden soll.'

    'Register.Installing'                   = 'PnP.PowerShell wird installiert...'

    'Register.Action'                       = 'Entra-ID-Anwendung ''{0}'' mit {1} registrieren'

    'Register.Registering'                  = '''{0}'' wird in {1} registriert...'

    'Register.BrowserWillOpen'              = 'Ein Browserfenster öffnet sich für Anmeldung und Zustimmung.'

    'Register.Complete'                     = 'Registrierung abgeschlossen.'

    'Register.ClientId'                     = '  Client-ID: {0}'

    'Register.Consent1'                     = 'Die Zustimmung braucht einige Minuten, bis sie überall gilt. Schlägt die erste Verbindung'

    'Register.Consent2'                     = 'mit einem Berechtigungsfehler fehl, warte kurz und versuche es nochmals.'

    'Register.ProfileDescription'           = 'Registriert durch Register-PnPApplication.ps1 am {0}'

    'Register.ProfileSaved'                 = 'Das Profil ''{0}'' wurde gespeichert. Verbinde dich mit: Connect-O365 -ProfileName {0}'

    'Register.SaveAsProfile'                = 'Speichere sie als Profil mit:'

    'DateSeries.DefaultNotJson'             = '-Default konnte nicht als JSON gelesen werden: {0} Aus einer Shell gibst du es als JSON an: -Default ''{{"Status":"terminiert"}}''. In einer PowerShell-Eingabe geht auch eine Hashtable: -Default @{{ Status = ''terminiert'' }}'

    'DateSeries.DefaultNotObject'           = '-Default muss ein JSON-Objekt sein, zum Beispiel: -Default ''{"Status":"terminiert"}'''

    'DateSeries.DefaultWrongType'           = '-Default muss eine Hashtable oder ein JSON-Objekt sein, nicht {0}.'

    'DateSeries.NeedsEnd'                   = 'Gib der Serie ein Ende: entweder -Until <Datum> oder -Count <n>.'

    'DateSeries.NoDates'                    = 'Diese Wiederholung trifft auf kein Datum zu. Es gibt nichts zu planen.'

    'DateSeries.Planned'                    = '{0} Eintrag/Einträge für ''{1}'' geplant.'

    'DateSeries.PlanPath'                   = 'Plan: {0}'

    'DateSeries.ReadIt'                     = 'Lies ihn, ändere ihn und schreibe ihn dann:'

    'DateSeries.PlanNotFound'               = 'Die Plandatei ''{0}'' wurde nicht gefunden.'

    'DateSeries.PlanEmpty'                  = 'Der Plan ''{0}'' hat keine Zeilen.'

    'DateSeries.ReadingColumns'             = 'Die Spalten von ''{0}'' werden gelesen ...'

    'DateSeries.ListNotFound'               = 'Die Liste ''{0}'' wurde nicht gefunden. Diese Site hat: {1}'

    'DateSeries.AmbiguousColumn'            = '''{0}'' ist der Anzeigename von mehr als einer Spalte in ''{1}'': {2}. Nenne sie stattdessen beim internen Namen.'

    'DateSeries.DateFieldUnknown'           = '-DateField ''{0}'' passt zu keiner Spalte in ''{1}''. Vorhandene Spalten sind: {2}'

    'DateSeries.PlanColumnUnknown'          = 'Die Plan-Spalte ''{0}'' passt zu keiner Spalte in ''{1}''. Vorhandene Spalten sind: {2}. Anzeigenamen und interne Namen werden beide akzeptiert; um eine Spalte im Plan zu behalten, ohne sie zu schreiben, benenne sie mit einem Unterstrich am Anfang um.'

    'DateSeries.PlanNoDateColumn'           = 'Der Plan hat keine Spalte ''{0}''. Die Wertspalten sind: {1}. Gib bei -DateField den Namen an, den der Plan wirklich verwendet.'

    'DateSeries.KeyLeftOut'                 = '  ''{0}'' ist hier keine Spalte; sie bleibt aus der Duplikatprüfung heraus.'

    'DateSeries.KeyUnknown'                 = '-DuplicateKey nennt ''{0}'', das zu keiner Spalte in ''{1}'' passt. Vorhandene Spalten sind: {2}'

    'DateSeries.NoKeyColumns'               = 'Keine der -DuplicateKey-Spalten gibt es in ''{0}''. Gib -AllowDuplicate an, um ohne die Prüfung zu schreiben.'

    'DateSeries.DuplicateCheck'             = '  Duplikatprüfung: {0}'

    'DateSeries.KeyNotPlanned'              = 'Die Duplikatprüfung verwendet {0}, wofür der Plan keine Spalte hat. Eine Planzeile ist dort leer und kann darum nur zu einem Eintrag passen, der dort ebenfalls leer ist -- in der Praxis wird nichts als Duplikat erkannt.'

    'DateSeries.ReadingEntries'             = 'Bestehende Einträge aus ''{0}'' werden gelesen ...'

    'DateSeries.ExistingKeys'               = '  {0} vorhandene(r) Eintragsschlüssel.'

    'DateSeries.NotADate'                   = 'Zeile ''{0}'' ist kein Datum, das gelesen werden kann; sie wird übersprungen.'

    'DateSeries.Skip'                       = '  übersprungen {0} -- steht schon in der Liste'

    'DateSeries.Created'                    = '  angelegt {0}'

    'DateSeries.WouldCreate'                = '{0} Eintrag/Einträge würden angelegt; {1} übersprungen.'

    'DateSeries.Done'                       = '{0} Eintrag/Einträge angelegt; {1} übersprungen.'

    'DateSeries.Log'                        = 'Protokoll: {0}'
}
