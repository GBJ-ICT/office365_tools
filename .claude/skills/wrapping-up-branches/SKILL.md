---
name: wrapping-up-branches
description: >-
  Takes a finished branch from uncommitted work to an open pull request with green CI by running
  four skills in order: committing-changes, verifying-against-issue, opening-pull-requests and
  checking-ci. Use when asked to wrap up, finish or ship a branch.
---

# Wrapping up branches

Use this only for work the user says is ready. Each step is its own skill; load
it and follow it. Every step that commits, pushes, comments or opens something
waits for the user's approval, as that skill says.

1. **committing-changes:** plan the commits and land them one at a time.
2. **verifying-against-issue:** run the issue's tests, add missing ones (each
   added test goes back through step 1), list the manual tests, name the
   deviations and build the status table.
3. **opening-pull-requests:** offer the pull request without waiting to be
   asked, using the table and the deviations from step 2.
4. **checking-ci:** offer it once the pull request is open.

If there is no issue, say so and skip step 2; the pull request then says that
nothing was checked against an issue. If the user stops at any step, leave the
branch as it is and say what is left.
