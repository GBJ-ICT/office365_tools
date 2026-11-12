---
name: pipeline-monitoring
description: >-
  Reads the GitHub Actions result for a pull request after it is created and, if a job fails,
  diagnoses it and proposes a fix. Use after branch-wrap-up opens a pull request, or whenever
  asked to check a pipeline's status.
---

# Pipeline monitoring

This repository's CI is GitHub Actions: `.github/workflows/ci.yml` (jobs `analyze`, `test`,
`manifest`, run on push, pull request and by hand) and `.github/workflows/docs.yml` (the
`mkdocs build --strict` build, and the Pages deploy). The same commands run locally as
`./build.ps1` and `mkdocs build --strict`.

## Prerequisites

Requires the GitHub CLI (`gh`), installed and logged in (`gh auth status`). If `gh` is missing or
not logged in, stop and tell the user to install it or run `gh auth login`. Stay within
`CLAUDE.md`: nothing is pushed or changed on GitHub without the user's approval.

## When to run this

Run after `branch-wrap-up` opens a pull request (offer it as the next step; do not wait to be
asked), or any time the user asks to check a pipeline. It needs the branch pushed and a pull
request open.

## Watching the pipeline

Do not poll CI yourself: no sleep loops, no `/loop`, no scheduled wake-ups, no repeated
`gh run list` or `gh pr checks`.

1. Call the app's `get_status` pull-request tool. If it does not report the pull request, bind it
   with `bind_pr`.
2. Read the CI state it reports. The desktop app watches the pull request and sends a message
   when a check finishes; act on that message rather than checking again.
3. While the checks are still running, tell the user so, offer Auto-fix, and stop. Do not wait
   for the result in this turn.
4. Never enable auto-merge unless the user asked for it.

### Without the desktop app

The `get_status` and `bind_pr` tools exist only in the Claude desktop app. If they are not
available (Claude Code in a terminal or an IDE), wait for the checks with one blocking command
instead of a loop:

```bash
gh pr checks <number> --watch --fail-fast
```

`gh` does the waiting and returns when every check has finished, or at the first failure. Run it
once, with a timeout of about 10 minutes. If the timeout ends while checks are still running,
say so and stop; do not start a second wait. Then continue with "On success" or "On failure". The
ban on hand-made loops still applies.

## On success

Report that the checks passed, with the pull request link, and stop.

## On failure

1. Find every failed job, not just the first: `gh pr checks <number>` lists the checks, and
   `gh run view <run-id>` shows the jobs of one run.
2. For each failed job, read its log once: `gh run view <run-id> --log-failed`. Read enough to
   find the actual error (analyzer finding, failing test, docs build error) and do not guess from
   the job name.
3. Diagnose the root cause from the log and the source and test files involved.
4. Try to reproduce it locally before proposing a fix:
   - `analyze` and `test`: `./build.ps1` (and again with `O365_LANGUAGE=en` when the failure
     looks like a wording or language test: this machine is set to German, the runner is not);
   - `manifest`: look at the step's command in `ci.yml` and run it locally;
   - `Docs`: `mkdocs build --strict`.
5. Propose a concrete fix (the diff or the commands) and explain the root cause in one or two
   sentences. Do not apply it without approval: this is a proposal, not an autonomous commit.
   Any commit that follows goes through `branch-wrap-up` and `CLAUDE.md`'s Git rules.
6. If the failure is infrastructure or flakiness rather than the code (a runner timeout, a
   download from the PowerShell Gallery or PyPI that failed, a GitHub outage), say so explicitly
   and offer to re-run only the failed jobs (`gh run rerun <run-id> --failed`) instead of
   proposing a code fix. Re-running is a change on GitHub, so ask first.
7. If several jobs fail for unrelated reasons, handle them separately and do not bundle
   unrelated fixes into one proposal.

## After a fix is approved and pushed

Go back to "Watching the pipeline" for the new run that the push starts.
