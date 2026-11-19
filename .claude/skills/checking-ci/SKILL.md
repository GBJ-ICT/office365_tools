---
name: checking-ci
description: >-
  Waits once for the CI checks of a pull request (or GitLab merge request), reads the result and,
  for a failed job, finds the cause in its log, reproduces it locally and proposes a fix. Never
  polls. Use after a pull request is opened or a branch is pushed, or when asked about the CI,
  pipeline or check status. Works with GitHub Actions and GitLab CI.
---

# Checking CI

"Pull request" here also means a GitLab merge request. The commands for each
platform are in [reference/github.md](reference/github.md) and
[reference/gitlab.md](reference/gitlab.md); read the one for this repository
(`git remote -v`).

Look up the project's facts first (usually a "Project facts" section in
`CLAUDE.md`): which local command reproduces which CI job, and known
differences between this machine and the CI runners.

Requires the platform's CLI, installed and signed in. If it is not, stop and
tell the user how to sign in.

## 1. Wait for the result, once

Never poll: no sleep loops, no repeated status commands, no scheduled wake-ups.

- **If the session has a tool that watches pull requests and notifies you**
  (for example the Claude desktop app's pull-request status and bind tools,
  when they are listed), use
  it. Report the current state and stop; continue when the notification
  arrives. Never turn on auto-merge unless the user asked.
- **Otherwise** run the platform's blocking wait command once, with a timeout of
  about 10 minutes. If it times out while jobs still run, say so and stop; do
  not start a second wait.

## 2. On success

Report that every check passed, with the link to the pull request, and stop.

## 3. On failure

1. List every failed job, not just the first.
2. Read each failed job's log once. Find the actual error (a lint finding, a
   failing test, a build error); do not guess from the job's name.
3. Find the cause in the log and in the source and test files it names.
4. Reproduce it locally with the command the project facts give for that job,
   and with the runner's settings where they differ from this machine (for
   example its language or time zone).
5. Propose the fix: the root cause in one or two sentences, and the diff or the
   commands. Do not apply it without the user's approval. A commit that follows
   goes through the project's commit rules.
6. If the cause is infrastructure, not code (a runner timeout, a failed
   download, an outage), say so and offer to re-run only the failed jobs.
   Re-running changes the platform, so ask first.
7. Handle unrelated failures separately; one proposal per cause.

After an approved fix is pushed, start again at step 1 for the new run.
