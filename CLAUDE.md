# Instructions for Claude

Rules for working in this repository. They apply to every session. More will be
added over time; keep this file short and add each rule under the right heading.

## Git

- **Never commit on your own.** Do not run `git commit` (or amend, merge, rebase,
  tag or push) until the user has approved it in this conversation.
- **Propose the commit first.** Show the user the proposed commit message and the
  list of files it will include. Wait for an explicit "yes" before committing.
  Approval covers that one commit only, not later ones.
- **Stage what the proposal covers, before you propose it.** Run `git add` for
  exactly the files (or changes) that belong to the proposed commit, so the user
  can review them as the staged diff and nothing unrelated is in it. Nothing else
  stays staged. Use `git add -p` when one file holds changes for two commits.
  Staging is not committing: it still waits for the "yes".
- **Go step by step.** Propose one commit at a time: stage it, show the message
  and the files, wait for approval, commit, and only then stage and propose the
  next one. Do not queue several proposals at once.
- **Group changes sensibly.** Prefer several small, separate commits over one
  large one. Say how you would split them when you propose, and what comes after
  the one in front of the user.
- **Commit messages** follow the existing history: a short imperative subject
  line, a blank line, then a body in plain prose explaining what changed and why.
- **Stay local.** Do not push, open pull requests or change anything on GitHub
  unless the user asks for it.
