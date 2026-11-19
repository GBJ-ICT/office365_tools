---
name: verifying-against-issue
description: >-
  Checks finished work against the issue it belongs to: runs each requirement's verification
  test, adds missing automated tests, lists manual tests for a person, names every deviation from
  the issue, and produces the status table for the pull request. Use before opening a pull or
  merge request, or when asked whether a branch meets its issue.
---

# Verifying against the issue

The issue is the single source of the requirements. This check records how far
the branch meets them; it never changes the issue to fit the work.

Look up the project's facts first (usually a "Project facts" section in
`CLAUDE.md`): platform, verify commands and test types.

## 1. Find and read the issue

Find it from the branch name, the commit messages or the open issues. If none
is clear, ask the user. Fetch the body (commands below) and find its
requirements table: one row per requirement with a test type and an expected
behaviour.

If the issue has no such table, say so, verify what you can from the code, and
suggest rewriting the issue in that structure before relying on it.

## 2. Run every test that can run here

By the type at the start of the test cell:

- **Unit:** run the named test, or the verify commands.
- **Static:** run the exact command and compare with the expected behaviour.
- **Smoke:** run the command on the sample data and read the result.
- **Integration:** run only if the project has a test system configured;
  otherwise the status is "Needs a test system".
- **Manual:** never run or assume it; it goes to the user (step 4).

Note the commit each test ran on (`git rev-parse --short HEAD`).

## 3. Find the missing tests

For each row, find the test that proves it. If a Unit or Static row has none,
write it: say clearly that you are adding it, run it, and commit it through the
normal commit procedure. Never mark a row as covered by a test that does not
exist. If a requirement cannot be met or tested as written, that is a deviation
(step 5); do not bend the test.

## 4. List the manual tests and carry on

List each Manual row for the user with the exact steps and the expected
behaviour, and how to try it without a release. Do not wait for the answer; the
pull request does not depend on it. When the user reports back, update the row.

## 5. Name every deviation

Compare what was built with the whole issue, not only its table: requirements,
Context, Technical Specification and Out of Scope. A deviation is anything that
differs: another approach or value, a requirement met another way or not met, a
test in another place than named, something added that the issue does not ask
for, or a limit found on the way. Write each one in three parts:

- **Issue says:** …
- **Done instead:** …
- **Why:** …

Post the list as one comment on the issue (ask first; it changes the platform)
and put the same list in the pull request. Write "None." when there are none.
Never edit the issue's own text to make a deviation disappear; edit the body
only when the user asks. A deviation found later gets a new comment.

## 6. Build the status table

Copy `#` and `Requirement` from the issue exactly (from the fetched body; never
retype). Leave out the test and expected-behaviour columns, which make the table
too wide; link the issue for them instead.

| # | Requirement | Status | How it was tested |
|---|---|---|---|
| 1 | … | Passed | **Unit:** `the test name`, on `abc1234` |
| 4 | … | 🔴 **Manual test needed** | **Manual:** what the user has to do |

- **Status** is one of: Passed, Failed, Added test and passed,
  `🔴 **Manual test needed**`, Needs a test system, Not covered.
- **How it was tested** starts with the test type and names the command, test
  or file, the result and the commit, so a reader can repeat it.
- Put failures and gaps first in your report. Never write "done" for a row you
  did not run.
- The status belongs to this branch; do not write it into the issue.

The pull request closes the issue only when every row passed. Otherwise it is
"part of" the issue and names the open rows.

## Platform commands

| Action | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Find issues | `gh issue list` | `glab issue list` |
| Read the body | `gh issue view <n> --json body --jq .body` | `glab issue view <n> --output json \| jq -r .description` |
| Comment | `gh issue comment <n> --body-file <f>` | `glab issue note <n> --message "$(cat <f>)"` |
