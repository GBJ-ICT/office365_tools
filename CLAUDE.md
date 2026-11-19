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
- **Every commit passes the pipelines on its own.** Before proposing a commit,
  check that the staged state, not just the working copy, passes the verify
  commands under "Project facts". Export the index to a temporary folder
  (`git checkout-index -a --prefix=<folder>/`) and run them there. A change that
  only works together with a later one belongs in the same commit, or the
  later part is held back until its turn. Say in the proposal that the check
  passed; if it cannot be run, say so rather than implying it.
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

## Issues and pull requests

- **Name every deviation from the issue, in both places.** When what was built
  differs from the issue (a different approach or value, a requirement met
  another way or not met, a test in another place, something added that the
  issue does not ask for), write it as a comment on the issue and under
  "Deviations from the issue" in the pull request. Give each one three parts:
  what the issue says, what was done instead, and why. Do not edit the issue's
  own text to hide a deviation.

## Project facts

The facts that the skills in `.claude/skills/` look up. The skills hold the
procedures and name no project; this section is the only place for the
repository's own commands, names and quirks.

- **Platform:** GitHub, repository `GBJ-ICT/office365_tools`, CLI `gh`.
- **Base branch:** `master`.
- **Verify commands** (what CI runs, for every commit):
  - `./build.ps1`: the script analyzer and the unit tests. It takes about
    13 minutes; run it in the background.
  - When texts or tests changed, also run it in English
    (`$env:O365_LANGUAGE = 'en'; ./build.ps1`). This machine is set to German,
    the CI runners are not.
  - `mkdocs build --strict` when anything under `docs/` or `mkdocs.yml`
    changed. It needs the packages from `requirements-docs.txt`.
- **CI jobs and how to reproduce them locally:**
  - `CI` / `PSScriptAnalyzer` and `CI` / `Pester (unit)`: `./build.ps1`.
  - `CI` / `Module manifest`: the commands of that step in
    `.github/workflows/ci.yml`.
  - `Docs` / `Build site`: `mkdocs build --strict`.
  - Failed downloads from the PowerShell Gallery or PyPI are infrastructure,
    not code.
- **Never commit:** `.claude/launch.json`, `config/*.json` (only the
  `*.example.json` templates are tracked), certificates and keys.
- **Every user-visible text** goes into both string tables, `en` and `de`
  (UTF-8 with BOM).
- **Test types:** Unit, Integration, Static, Smoke and Manual, as defined in
  `docs/dev/testing.md`. Integration tests need a test tenant and are not part
  of `./build.ps1`.
- **Constraints for a design:** a PowerShell 7 module with a launcher that
  still starts on Windows PowerShell 5.1; no secrets, tenant names or customer
  data in the repository or in issues.
- **Issue review labels:** `TO BE REVIEWED` on a new issue; `ACCEPTED` once a
  person other than the author accepts it.
