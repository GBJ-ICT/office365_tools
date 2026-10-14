# Die Werkzeuge im Überblick

Was alles dabei ist und wie du jedes startest. Einzelheiten zu jedem stehen in den
[ausführlichen Anleitungen](../sandbox/README.md) (nur auf Englisch).

## Zwei Arten, die Werkzeuge zu benutzen

**Doppelklick.** Für Leute, die kein PowerShell benutzen. Du bekommst eine
Starter-Datei, doppelklickst sie und beantwortest ein paar Fragen. Heute ist das
die **Upload-Prüfung**.

**PowerShell.** Für alles andere. Öffne PowerShell 7 im Ordner des Repositorys und
starte ein Skript, oder benutze die Befehle direkt.

## Die Upload-Prüfung (Doppelklick)

Prüft einen Ordner **vor** dem Hochladen nach SharePoint und **danach**, ob alles
angekommen ist. Die Prüfung schaut nur nach; sie verändert nie etwas.

1. Doppelklicke `Check-Upload.cmd`, oder ziehe den Ordner, den du prüfen willst,
   darauf.
2. Wähle den Ordner, dann was geschehen soll: vor dem Hochladen prüfen, prüfen ob
   es angekommen ist, oder beides.
3. Lies den Bericht im Ordner `Reports` neben dem Starter. Rot heisst: vor dem
   Hochladen beheben.

Die Prüfung vor dem Hochladen braucht keine Anmeldung. Die Prüfung danach bittet
dich, dich mit deinem Geschäftskonto anzumelden.

## Die PowerShell-Werkzeuge

Starte jedes Skript so, im Ordner des Repositorys:

```powershell
pwsh ./scripts/<Name>.ps1
```

Skripte, die mit SharePoint sprechen, brauchen eine Verbindung zu deinem Tenant
(siehe "Vor dem ersten Start" unten). Manche brauchen ein paar Angaben, etwa
welche Bibliothek oder Liste; `Get-Help ./scripts/<Name>.ps1 -Full` zeigt sie.
Skripte, die Daten ändern, sagen das in ihrer Hilfe, und die, die eine Änderung
vorab zeigen können, kennen `-WhatIf`.

| Ich möchte ... | Start | Ändert Daten? |
|---|---|---|
| Eine oder alle Bibliotheken auf Probleme prüfen und Berichte bekommen | `Invoke-LibraryAudit.ps1` | Nein, nur lesend |
| Einen Ordner vor dem Hochladen prüfen, oder ob ein Upload angekommen ist | `Test-Upload.ps1` | Nein |
| Dokumentsätze finden, deren Dateien die Metadaten nicht mehr tragen | `Test-DocumentSetSync.ps1` | Nein, nur lesend |
| Die Metadaten jedes Dokumentsatzes auf seine Dateien und Ordner übertragen | `Repair-DocumentSetSync.ps1` | Ja, zuerst `-WhatIf` probieren |
| Jeden fehlenden Dokumentsatz in eine Übersichtsliste aufnehmen | `Sync-DocumentSetRegister.ps1` | Erst, nachdem du eine Plan-Datei freigibst |
| Eine Liste als PDF drucken und prüfen, ob jeder Wert in der Datei steht | `Export-ListToPdf.ps1` | Nein, schreibt ein PDF und einen Bericht |
| Listeneinträge an einem wiederkehrenden Datum anlegen, etwa jeden zweiten Sonntag | `New-ListItemDateSeries.ps1` | Erst, nachdem du eine Plan-Datei freigibst |
| Einen Auswahlwert in jedem Eintrag umbenennen, der noch den alten hat | `Update-SpoFieldValue.ps1` | Ja, zuerst `-WhatIf` probieren |
| Die Spalten einer Liste in eine andere kopieren (nicht Nachschlage-, verwaltete Metadaten- oder berechnete Spalten) | `Copy-ListSchema.ps1` | Nur mit `-Apply` |
| Inhaltstypen und Spalten über ein Menü ansehen und bearbeiten | `Manage-ContentType.ps1` | Ja, nachdem du jede Änderung bestätigst |
| Die Anmeldung für deine Organisation einrichten (Administration, einmalig) | `Register-PnPApplication.ps1` | Registriert eine Anwendung in deinem Tenant |

Jedes Skript erklärt sich selbst: `Get-Help ./scripts/Test-Upload.ps1 -Full`.

## Vor dem ersten Start

Du brauchst PowerShell 7 und, für alles, was mit SharePoint spricht, eine
Anwendungs-ID für deine Organisation. Wer deinen Tenant verwaltet, registriert sie
einmal und gibt sie dir. Wie, steht in [Anmeldung](../sandbox/authentication.md)
(nur auf Englisch).

## Sprache

Die Werkzeuge sprechen Englisch oder Deutsch. Siehe [Sprache](language.md).
