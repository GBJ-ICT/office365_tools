---
name: opening-pull-requests
description: >-
  Drafts a pull request (or GitLab merge request) with a summary, the issue's status table, the
  deviations and what was not verified, and after approval pushes the branch, opens it and checks
  the result. Use when asked to open a pull or merge request, or once a branch's commits and its
  check against the issue are done.
---

# Opening pull requests

"Pull request" here also means a GitLab merge request. The commands are in
[reference/github.md](reference/github.md) and
[reference/gitlab.md](reference/gitlab.md); read the one for this repository
(`git remote -v`).

Look up the project's facts first (usually a "Project facts" section in
`CLAUDE.md`): the base branch and the platform.

Pushing and opening a pull request are outward-facing: nothing happens until the
user approves the exact title and body.

## 1. Draft

- **Title:** a short imperative phrase, under about 70 characters.
- **Body:** the template below. Fill the status table and the deviations from
  the check against the issue; if that check has not run, run it first or say
  under "Not verified" that it did not.
- **Base:** the project's base branch, unless the branch was cut from another
  one; then name both and ask.

Write the body to a temporary file and show it to the user with the title and
the base.

## 2. Open

After a clear "yes" to that title, body and base:

1. Push the branch with upstream tracking.
2. Create the pull request from the body file.
3. Read it back and check that the title, base, branch and linked issue are as
   approved. Show the link.
4. Offer to check its CI next.

If the user declines, stop and leave the branch as it is.

## Body template

```markdown
## Summary
What changed and why, in a few sentences or bullets. Behaviour, not a file list.

## Issue
Closes #N
(Or, when a row is still open: Part of #N. Open rows: 4, 7.)

The full tests and expected behaviour are in the issue.

| # | Requirement | Status | How it was tested |
|---|---|---|---|
| … | … | … | … |

## Deviations from the issue
Each with "Issue says", "Done instead" and "Why". Or "None."

## Screenshots
Only when something a person sees changed. List the exact screens (window or
menu, language, before and after); the user adds the images.

## Not verified
Manual tests still open, checks that could not run, missing screenshots.
```

Leave out the Issue table, but keep the heading with one line, when there is no
issue. End the body with the attribution line the session gives for pull
requests, if any.

When the user later reports a manual test, update its row in the body.
