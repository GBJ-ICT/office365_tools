# Language

> **Status: planned.** This describes how it will work once it is built.
> For developers: [multilanguage.md](../dev/multilanguage.md).

The tools speak **English** or **German**. By default they use the language your
Windows is set to, so most people never need to change anything.

## Change the language

When a tool shows a menu, you will see this line at the top:

```
Language: English        (L = change / ändern)
```

Press **L**, then pick **English**, **Deutsch** or **Follow Windows**.

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

To use the other language just once, add `-Language en` or `-Language de` to a
command.

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
