# Pull requests with `gh`

| Action | Command |
|---|---|
| Check sign-in | `gh auth status` |
| Push | `git push -u origin <branch>` |
| Create | `gh pr create --base <base> --head <branch> --title "<t>" --body-file <f>` |
| Read back | `gh pr view <pr> --json title,baseRefName,headRefName,closingIssuesReferences,url` |
| Update the body | `gh pr edit <pr> --body-file <f>` |

`Closes #N` in the body links and closes the issue on merge; `Part of #N` only
links it.
