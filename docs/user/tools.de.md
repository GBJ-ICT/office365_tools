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
Tool an, das du starten möchtest. Im Moment ist das die **Upload-Prüfung**; neue
Tools erscheinen in diesem Fenster von selbst. Unten links kannst du im Feld
**Language / Sprache** die Sprache ändern.

**PowerShell.** Für alles andere. Öffne PowerShell 7 im Ordner des Repositorys und
starte ein Skript, oder benutze die Befehle direkt.

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
