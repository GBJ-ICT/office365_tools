# Die O365 Tools im Überblick

Welche Tools es gibt und wie du sie startest. Einzelheiten stehen in den
[ausführlichen Anleitungen](../sandbox/README.md) (nur auf Englisch).

## Drei Arten, die O365 Tools zu benutzen

**Doppelklick auf ein einzelnes Tool.** Für alle, die PowerShell nicht benutzen. Du
bekommst eine Startdatei für ein Tool, zum Beispiel `Check-Upload.cmd`, klickst
doppelt darauf und beantwortest ein paar Fragen. Das Tool startet sofort.

**Doppelklick auf `Office365-Tools.cmd`.** Auch für alle, die PowerShell nicht
benutzen. Diese Datei bekommst du, wenn du mehrere Tools erhältst. Es öffnet sich ein
Fenster mit allen verfügbaren Tools, jedes mit einer kurzen Beschreibung. Klicke das
Tool an, das du starten möchtest. Im Moment sind das **SharePoint-Liste als PDF** und die **Upload-Prüfung**; neue
Tools erscheinen in diesem Fenster von selbst. Unten links kannst du im Feld
**Language / Sprache** die Sprache ändern.

**PowerShell.** Für alles andere. Öffne PowerShell 7 im Ordner des Repositorys und
starte ein Skript, oder benutze die Befehle direkt.

## SharePoint-Liste als PDF (Doppelklick)

Druckt eine SharePoint-Liste oder eine ihrer Ansichten als PDF, das du aufbewahren,
verschicken oder ausdrucken kannst. Es liest nur und verändert nie etwas in
SharePoint.

1. Doppelklicke `List-To-Pdf.cmd`. Mit `Office365-Tools.cmd` klickst du im Fenster
   stattdessen auf **SharePoint-Liste als PDF**.
2. Beim ersten Mal fragt es nach einer Adresse. Kopiere sie aus deinem Browser und
   füge sie ein. Es kann die Adresse der Website sein oder einer Seite darin: Kopierst
   du die Adresse der gewünschten Liste, wird daraus die Website genommen und auch die
   Liste, du wirst also nicht nach ihr gefragt. Trage die Adresse in `list-to-pdf.xml`
   neben dem Starter ein, dann fragt es nicht mehr.
3. Melde dich mit deinem Geschäftskonto an und wähle dann die **Liste** und die
   **Ansicht** aus nummerierten Listen. Die Ansichten sind die gespeicherten Auswahlen
   dieser Liste, so benannt, wie sie die Ansichtsauswahl in SharePoint zeigt; Enter
   nimmt die Standardansicht. In `list-to-pdf.xml` kannst du stattdessen eine Ansicht
   benennen, dann wird nicht gefragt.
4. Tippe, warum du exportierst, oder drücke Enter, um das wegzulassen. Der Grund steht
   auf der ersten Seite.
5. Das PDF liegt im Ordner `Reports` neben dem Starter, und der Ordner öffnet sich mit
   dem PDF markiert.

Die erste Seite sagt, was exportiert wurde, wann, von wem (dein Name, aus der
Anmeldung) und warum. Das Papier ist A4 quer; `list-to-pdf.xml` bietet auch A3, A5,
Letter, Legal und Hochformat an. Eine Liste mit vielen Textspalten liest sich auf A3
besser.

So wird jede Art von Spalte gedruckt:

| Spalte in SharePoint | Auf der Seite |
|---|---|
| Einzelne Textzeile, Auswahl, Zahl, Währung, Berechnet | Der Text, wie ihn die Liste zeigt. Mehrere Auswahlwerte sind mit `;` getrennt. |
| Mehrere Textzeilen, einfach | Der ganze Text mit seinen Zeilenumbrüchen. |
| Mehrere Textzeilen, erweiterter Rich-Text | Der Text mit Absätzen, Aufzählungen und Nummern. Links darin sind anklickbar. Emoji werden gedruckt. |
| Datum und Uhrzeit | Das Datum, und die Uhrzeit, wenn es eine gibt. |
| Ja/Nein | Yes oder No. |
| Person oder Gruppe | Der Anzeigename. Mehrere Personen stehen untereinander, ein Name pro Zeile. Der Name öffnet eine E-Mail an die Person; eine Gruppe hat keine Adresse. |
| Nachschlagen, Verwaltete Metadaten | Der Wert, oder die Werte, mit `;` getrennt. |
| Link, Bild | Die Beschreibung, oder die Adresse, wenn es keine gibt. Es ist ein anklickbarer Link. |
| Anlagen, Inhaltstyp | Werden nicht gedruckt. |

Farben aus SharePoint (bedingte Formatierung, farbige Auswahlwerte) werden nicht
übernommen: Die Tabelle hat eine graue Kopfzeile, und jede zweite Zeile ist schattiert.

Jede Spalte ist so breit, wie ihr Inhalt es braucht, eine kurze höchstens 70 mm; die
langen Textspalten teilen sich den Rest der Seite. Aller Text steht auf der Seite:
lange Texte brechen um und können auf der nächsten Seite weitergehen, nichts wird
abgeschnitten. Nach dem Drucken liest das Tool das PDF zurück und prüft, dass jeder
Wert darin steht. Fehlt einer, sagt es das und rät, dich nicht auf die Datei zu
verlassen. Eine Ansicht ohne Zeilen schreibt kein PDF.

Braucht PowerShell 7 (der Starter sagt, wie du es bekommst) und für die Anmeldung die
Anwendungs-ID deiner Organisation. Eine Liste, die jemand in SharePoint nicht lesen
darf, kann nicht gedruckt werden.

## Die Upload-Prüfung (Doppelklick)

Prüft einen Ordner **vor** dem Hochladen nach SharePoint und **danach**, ob alles
angekommen ist. Die Prüfung liest nur und verändert nie etwas.

1. Doppelklicke `Check-Upload.cmd`, oder ziehe den Ordner, den du prüfen willst,
   darauf. Mit `Office365-Tools.cmd` klickst du im Fenster stattdessen auf
   **Upload-Prüfung**.
2. Wähle den Ordner und dann, was passieren soll: vor dem Hochladen prüfen, nach dem
   Hochladen prüfen, ob alles angekommen ist, oder beides.
3. Lies den Bericht im Ordner `Reports` neben dem Starter. Rot heisst: Das musst du
   vor dem Hochladen beheben.

Die Prüfung vor dem Hochladen braucht keine Anmeldung. Für die Prüfung danach
meldest du dich mit deinem Geschäftskonto an.

## Die PowerShell-Tools

Starte jedes Skript so, im Ordner des Repositorys:

```powershell
pwsh ./scripts/<Name>.ps1
```

Skripte, die auf SharePoint zugreifen, brauchen eine Verbindung zu deinem Tenant
(siehe "Vor dem ersten Start" unten). Manche brauchen weitere Angaben, etwa welche
Bibliothek oder Liste; `Get-Help ./scripts/<Name>.ps1 -Full` zeigt sie. Skripte,
die Daten ändern, sagen das in ihrer Hilfe. Wenn sie die Änderung vorab anzeigen
können, kennen sie `-WhatIf`.

| Ich möchte ... | Start | Ändert Daten? |
|---|---|---|
| Eine oder alle Bibliotheken auf Probleme prüfen und Berichte bekommen | `Invoke-LibraryAudit.ps1` | Nein, nur lesend |
| Einen Ordner vor dem Hochladen prüfen, oder ob ein Upload angekommen ist | `Test-Upload.ps1` | Nein |
| Dokumentsätze finden, deren Dateien nicht mehr dieselben Metadaten haben | `Test-DocumentSetSync.ps1` | Nein, nur lesend |
| Die Metadaten jedes Dokumentsatzes auf seine Dateien und Ordner übertragen | `Repair-DocumentSetSync.ps1` | Ja, zuerst `-WhatIf` probieren |
| Jeden fehlenden Dokumentsatz in eine Übersichtsliste aufnehmen | `Sync-DocumentSetRegister.ps1` | Erst, nachdem du eine Plan-Datei freigibst |
| Eine Liste als PDF drucken und prüfen, ob jeder Wert in der Datei steht | `Export-ListToPdf.ps1` | Nein, schreibt ein PDF und einen Bericht |
| Listeneinträge an einem wiederkehrenden Datum anlegen, etwa jeden zweiten Sonntag | `New-ListItemDateSeries.ps1` | Erst, nachdem du eine Plan-Datei freigibst |
| Einen Auswahlwert in jedem Eintrag umbenennen, der noch den alten hat | `Update-SpoFieldValue.ps1` | Ja, zuerst `-WhatIf` probieren |
| Die Spalten einer Liste in eine andere kopieren (nicht Nachschlage-, verwaltete Metadaten- oder berechnete Spalten) | `Copy-ListSchema.ps1` | Nur mit `-Apply` |
| Inhaltstypen und Spalten über ein Menü ansehen und bearbeiten | `Manage-ContentType.ps1` | Ja, nachdem du jede Änderung bestätigst |
| Die Anmeldung für deine Organisation einrichten (Administration, einmalig) | `Register-PnPApplication.ps1` | Registriert eine Anwendung in deinem Tenant |

Jedes Skript beschreibt sich selbst: `Get-Help ./scripts/Test-Upload.ps1 -Full`.

## Vor dem ersten Start

Du brauchst PowerShell 7 und, für alles, was auf SharePoint zugreift, eine
Anwendungs-ID für deine Organisation. Wer deinen Tenant verwaltet, registriert sie
einmal und gibt sie dir. Wie, steht in [Anmeldung](../sandbox/authentication.md)
(nur auf Englisch).

## Sprache

Die O365 Tools sind auf Englisch und Deutsch verfügbar. Siehe [Sprache](language.md).
