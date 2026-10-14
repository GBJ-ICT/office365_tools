# Language

The tools speak **English** or **German**. By default they use the language your
Windows is set to, so most people never need to change anything.

!!! note "What is in both languages"
    Everything: the **upload checker** (the launcher, the tool menu, the checker
    itself and its reports), the **file name checks**, all the **scripts** and the
    **PowerShell commands**. Command names, parameter names and the column names
    in CSV files stay English on purpose.

## Change the language

**In the tool window:** use the **Language / Sprache** box at the bottom left and
pick English, Deutsch or Follow Windows. The window opens again in that language.

**In a text menu** (the upload checker's "What would you like to do?" and the
numbered list), the top shows this line:

```
Language: English        (L = change / ändern)
```

Press **L**, then pick **English**, **Deutsch** or **Follow Windows**. Press Enter
to leave things as they are.

Your choice is remembered. Every tool starts in that language from now on, until
you change it again.

## Using PowerShell commands

Only if you work in PowerShell yourself:

```powershell
Set-O365Language de      # use German from now on
Set-O365Language en      # use English from now on
Set-O365Language auto    # follow Windows again
Get-O365Language         # show which language is active
```

To use the other language just once, add `-Language en` or `-Language de` to the
upload checker's script:

```powershell
./scripts/Test-Upload.ps1 -LocalPath C:\ToUpload -Language de
```

## What changes, and what does not

- **Translated:** menus, messages, and the text in reports.
- **Not translated:** file names and SharePoint content, and the technical names
  in reports, such as `FileName.IllegalCharacter`. These stay the same so your
  filters and spreadsheets keep working.

A report is written in the language you used when you ran it. To get the other
language, run the check again.

## If something looks wrong

| Problem | What to do |
|---|---|
| Everything is in English, but Windows is German | You may have chosen English earlier. Press **L** and pick **Follow Windows** |
| Umlauts (ä, ö, ü) look broken | Close the window and start the tool again from the launcher |
| A message says "Message unavailable" | Something is missing in the translation. Please tell the person who maintains the tools |
| A few messages are in a different language | Messages from Windows or PowerShell themselves cannot be translated |
