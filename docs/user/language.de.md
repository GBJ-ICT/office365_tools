# Sprache

Die Werkzeuge sprechen **Englisch** oder **Deutsch**. Standardmässig nehmen sie
die Sprache, auf die dein Windows eingestellt ist, die meisten müssen also
nichts ändern.

!!! note "Was in beiden Sprachen vorliegt"
    Alles: die **Upload-Prüfung** (der Starter, das Werkzeug-Menü, die Prüfung
    selbst und ihre Berichte), die **Prüfungen der Dateinamen**, alle **Skripte**
    und die **PowerShell-Befehle**. Namen von Befehlen und Parametern und die
    Spaltennamen in CSV-Dateien bleiben bewusst englisch.

## Die Sprache ändern

**Im Werkzeug-Fenster:** Nimm das Feld **Language / Sprache** unten links und
wähle English, Deutsch oder Windows folgen. Das Fenster öffnet sich danach in
dieser Sprache neu.

**In einem Text-Menü** (der Frage der Upload-Prüfung "Was möchtest du tun?" und
der nummerierten Liste) steht oben diese Zeile:

```
Sprache: Deutsch        (L = ändern / change)
```

Tippe **L** und wähle **English**, **Deutsch** oder **Windows folgen**. Mit Enter
lässt du alles, wie es ist.

Deine Wahl wird gemerkt. Alle Werkzeuge starten danach in dieser Sprache, bis du
sie wieder änderst.

## PowerShell-Befehle

Nur, wenn du selbst mit PowerShell arbeitest:

```powershell
Set-O365Language de      # ab jetzt Deutsch
Set-O365Language en      # ab jetzt Englisch
Set-O365Language auto    # wieder Windows folgen
Get-O365Language         # zeigen, welche Sprache gerade gilt
```

Um die andere Sprache nur einmal zu verwenden, hänge `-Language en` oder
`-Language de` an das Skript der Upload-Prüfung:

```powershell
./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Language en
```

## Was sich ändert und was nicht

- **Übersetzt:** Menüs, Meldungen und der Text in Berichten.
- **Nicht übersetzt:** Dateinamen und Inhalte aus SharePoint sowie die
  technischen Namen in Berichten, zum Beispiel `FileName.IllegalCharacter`. Die Namen
  bleiben gleich, damit deine Filter und Tabellen weiter funktionieren.

Ein Bericht ist in der Sprache geschrieben, die du beim Start hattest. Für die
andere Sprache führst du die Prüfung nochmals aus.

## Wenn etwas nicht stimmt

| Problem | Was du tun kannst |
|---|---|
| Alles ist englisch, aber Windows ist deutsch | Vielleicht hast du früher Englisch gewählt. Tippe **L** und wähle **Windows folgen** |
| Umlaute (ä, ö, ü) sehen kaputt aus | Schliesse das Fenster und starte das Werkzeug nochmals über den Starter |
| Eine Meldung lautet "Meldung nicht verfügbar" | In der Übersetzung fehlt etwas. Sag es bitte der Person, die die Werkzeuge pflegt |
| Einzelne Meldungen sind in einer anderen Sprache | Meldungen von Windows oder PowerShell selbst lassen sich nicht übersetzen |
