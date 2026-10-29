# Sprache

Die O365 Tools sind auf **Englisch** und **Deutsch** verfügbar. Standardmässig
verwenden sie die Sprache, auf die dein Windows eingestellt ist, die meisten
müssen also nichts ändern.

!!! note "Was es in beiden Sprachen gibt"
    Alles gibt es auf Deutsch und auf Englisch: die **Upload-Prüfung** (Starter,
    Tool-Menü, die Prüfung selbst und ihre Berichte), die **Dateinamen-Prüfungen**,
    alle **Skripte** und alle **PowerShell-Befehle**. Namen von Befehlen und
    Parametern und die Spaltennamen in CSV-Dateien bleiben bewusst auf Englisch.

## Die Sprache ändern

Du kannst die Sprache an zwei Stellen ändern.

**1. Im Fenster zur Auswahl der Tools.** Es erscheint, wenn du `Office365-Tools.cmd`
doppelklickst. Unten links steht das Feld **Language / Sprache**. Klicke darauf und
wähle **English**, **Deutsch** oder **Windows folgen**. Danach öffnet sich das
Fenster neu, in der gewählten Sprache.

**2. In der Upload-Prüfung.** Die Prüfung läuft in einem Textfenster (schwarz oder blau),
in dem du Zahlen und Buchstaben eintippst:

1. Starte die Upload-Prüfung, zum Beispiel mit `Check-Upload.cmd`.
2. Warte auf die Frage **"Was möchtest du tun?"** mit den Zahlen 1, 2 und 3. Direkt
   darüber steht diese Zeile:

   ```
   Sprache: Deutsch        (L = ändern / change)
   ```

3. Tippe hinter **Nummer [1]** den Buchstaben **L** und drücke die Eingabetaste.
4. Tippe die Zahl der gewünschten Sprache (English, Deutsch oder Windows folgen) und
   drücke die Eingabetaste. Drückst du nur die Eingabetaste, bleibt alles, wie es ist.
5. Die Frage erscheint nochmals, jetzt in der gewählten Sprache. Wähle nun wie
   gewohnt 1, 2 oder 3.

Die Frage "Was möchtest du tun?" erscheint nur, wenn in `upload-check.xml` bei
`<Mode>` der Wert `ask` steht (das ist die Standardeinstellung). Steht dort ein
fester Wert, startet die Prüfung gleich. Ändere die Sprache dann im Fenster zur
Auswahl der Tools, oder mit `-Language` (siehe unten).

Deine Wahl wird gespeichert. Alle O365 Tools starten danach in dieser Sprache, bis
du sie wieder änderst.

## PowerShell-Befehle

Nur für den Fall, dass du selbst mit PowerShell arbeitest:

```powershell
Set-O365Language de      # ab jetzt Deutsch
Set-O365Language en      # ab jetzt Englisch
Set-O365Language auto    # wieder der Windows-Sprache folgen
Get-O365Language         # anzeigen, welche Sprache gerade gilt
```

Wenn du die andere Sprache nur einmal brauchst, gib beim Skript der Upload-Prüfung
`-Language en` oder `-Language de` an:

```powershell
./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Language en
```

## Was sich ändert und was nicht

- **Übersetzt:** Menüs, Meldungen und der Text in Berichten.
- **Nicht übersetzt:** Dateinamen und Inhalte aus SharePoint sowie die
  technischen Namen in Berichten, zum Beispiel `FileName.IllegalCharacter`. Diese
  Namen bleiben gleich, damit deine Filter und Tabellen weiter funktionieren.

Ein Bericht ist in der Sprache verfasst, die beim Start eingestellt war. Für die
andere Sprache startest du die Prüfung nochmals.

## Wenn etwas nicht stimmt

| Problem | Was du tun kannst |
|---|---|
| Alles ist auf Englisch, aber Windows ist auf Deutsch | Vielleicht hast du früher Englisch gewählt. Tippe **L** und wähle **Windows folgen** |
| Umlaute (ä, ö, ü) werden falsch angezeigt | Schliesse das Fenster und starte das Tool nochmals über den Starter |
| Eine Meldung lautet "Meldung nicht verfügbar" | In der Übersetzung fehlt ein Text. Sag es bitte der Person, die die O365 Tools betreut |
| Einzelne Meldungen sind in einer anderen Sprache | Meldungen von Windows oder PowerShell selbst werden nicht übersetzt |
