# Merge requests with `glab`

| Action | Command |
|---|---|
| Check sign-in | `glab auth status` |
| Push | `git push -u origin <branch>` |
| Create | `glab mr create --target-branch <base> --source-branch <branch> --title "<t>" --description "$(cat <f>)"` |
| Read back | `glab mr view <mr> --output json` |
| Update the body | `glab mr update <mr> --description "$(cat <f>)"` |

`Closes #N` in the description closes the issue on merge into the default
branch; `Part of #N` (or `Related to #N`) only links it.

If a flag is rejected, check `glab mr <command> --help`; the CLI changes between
versions.
