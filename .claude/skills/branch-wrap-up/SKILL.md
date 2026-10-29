---
name: branch-wrap-up
description: >-
  Reviews completed branch work, proposes self-contained commit and staging plans, validates
  approved commits against the pipelines, and offers a GitHub pull request once every planned
  commit has landed. Use when asked to wrap up a branch, prepare changes for review, or commit work.
---

# Branch wrap-up

Use this skill only for changes the user has said are ready to wrap up. Follow
`CLAUDE.md` throughout; its Git rules win over anything below. In particular:
never commit, push or touch GitHub without the user's approval in this
conversation, and approval covers one commit only.

## Review and commit planning

1. Inspect the branch status, staged and unstaged diffs, recent commits
   (`git log --oneline master..HEAD`), and affected files. Identify unrelated
   changes and leave them untouched. `.claude/launch.json` and other untracked
   local files are never part of a commit.
2. Divide related changes into the smallest practical set of independently
   coherent commits. Each proposed commit must pass the pipelines on its own:
   include the implementation, tests, string-table entries (`en` and `de`),
   configuration and documentation it needs together; never split a dependency
   across commits solely to make smaller diffs.
   If a proposed commit introduces new, independently testable behaviour (a new
   command, function or fixed bug) and the branch has no test covering it yet,
   say so explicitly and suggest adding one as part of that commit. Do not
   silently leave it untested or add a test without flagging that you are doing so.
3. Propose a commit plan before staging anything. For each proposed commit, list
   the files or hunks to stage, explain why they belong together, and give its
   proposed commit message. Say what comes after it. Ask the user which proposal
   to stage first, or ask for approval to stage the complete plan.

### Commit messages

Follow the existing history (see `git log`): a short imperative subject line
(under about 70 characters), a blank line, then a short body in plain prose that
says what changed and why, in terms of behaviour and intent. Do not list the
files touched; the diff shows them. Leave the body out only for a trivial change.
End with the attribution line the harness gives for commits
(`Co-Authored-By: ...`).

## Review and validation

1. After the user approves a staging proposal, stage only that approved scope
   (`git add <files>`, or `git add -p` when one file holds two commits). Nothing
   else stays staged.
2. Review the staged diff for correctness. Then run what CI runs on the staged
   state, not just the working copy: export the index with
   `git checkout-index -a --prefix=<temp folder>/` and run there
   - `./build.ps1` (the analyzer and the unit tests), always, and with the
     language set to English as well when texts or tests changed
     (`O365_LANGUAGE=en`);
   - `mkdocs build --strict`, when documentation or `mkdocs.yml` changed.
   Report failures or uncertainty; never present an unverified change as ready.
   If a check cannot be run, say so.
3. Show the exact staged diff (`git diff --cached --stat`, and the diff itself
   when it is short), a concise summary, the result of the checks, and the
   proposed commit message in a fenced code block.
4. Ask for explicit approval of both that exact staged diff and the exact commit
   message. Approval covers neither future changes nor a future commit message.

## Commit gate

After approval, confirm the staged diff still matches the approved diff, and
create exactly the approved commit with `git commit`. Do not amend an existing
commit, and do not skip hooks. If the diff or message changes, return to review
and validation for new approval.

After each commit lands, run a short review of just that commit
(`git show --stat HEAD`) without changing anything. Report what you checked and
the result. If you find something worth changing, stop, propose the specific
change, and wait for approval before applying it; do not fold an unreviewed fix
into a commit that already landed. Then repeat the planning, review, approval and
post-commit review process for every remaining proposed commit.

## Check the issue before the pull request

Before offering a pull request, check the work against the issue it belongs to. Find the issue
from the branch name, the commit messages or `gh issue list`; if none is clear, ask the user which
one. Read it with `gh issue view <number>`. Its "Requirements and Verification Tests" table is the
checklist: one row per requirement, with a test type and the expected behaviour.

1. **Run every test in the table** that can be run here, by type
   (`docs/dev/testing.md` defines them):
   - **Unit:** run the named test or `./build.ps1`.
   - **Static:** run the exact command and compare with the expected output.
   - **Smoke:** run the command on sample data and read the result.
   - **Integration:** run only if a test tenant is configured; otherwise mark it "needs a tenant".
   - **Manual:** never run or assume; list it for the user.
2. **Find the missing tests.** For each row, look for the test that proves it. If a row has no
   automated test although its type is Unit or Static, write one: propose it as part of the commit
   plan (a test commit, or inside the commit it covers), say clearly that you are adding it, and
   run it. Do not mark a row as covered by a test that does not exist. If a requirement cannot be
   met or tested as written, say so and propose a change to the issue instead of bending the test.
3. **Summarize the status** to the user in a table of four columns. The issue stays the single
   source for the requirements, their tests and the expected behaviour, so copy the `#` and
   `Requirement` text from the issue's table as it is (fetch the body with
   `gh issue view <number> --json body`; never retype it) and add the result of this run. Do not
   copy the `Verification Test` and `Expected Behaviour` columns into the pull request: six
   columns of text do not fit the width of a pull-request description and force sideways
   scrolling. Say in the line above the table that the full test and expected behaviour are in
   the issue, and link it. The type from the issue's test goes at the start of the last column.

   | # | Requirement | Status | How it was tested |
   |---|---|---|---|
   | 1 | ... | Passed | **Smoke:** the command or test that ran, and what it showed |
   | 7 | ... | 🔴 **Manual test needed** | **Manual:** what the user has to do |

   Statuses: Passed, Failed, Added test and passed, `🔴 **Manual test needed**`, Needs a tenant,
   Not covered. "How it was tested" names the actual command, test name or file, with the result and
   the commit it was run on (`git rev-parse --short HEAD`), so a reader can repeat it. Report
   failures and gaps first, and never write "done" for a row you did not run. Do not change the
   issue's table to record results: the status belongs to this run, and an issue can have several
   pull requests. If the issue's table itself is wrong, propose the fix to the issue separately.
4. **List the manual tests for the user, and carry on.** Do not wait for their answer: the pull
   request does not depend on it. List each manual test with the exact steps and the expected
   behaviour from the table, and say how to test without a release (for example by starting the
   checkout's own script). In the pull-request table, mark each such row so it cannot be missed:
   put `🔴 **Manual test needed**` in the Status column (GitHub cannot colour a table cell, so the red
   circle and the bold text are the marker). When the user reports back, update the row (Passed or
   Failed, with how it was tested). If they report a problem, fix it through the normal plan and
   approval flow.
5. **Put the status in the pull request.** The body carries this extended table (a copy, dated by
   the commit it names), and what was not verified. Update the same table in the pull-request
   body when a manual row is reported back.
   Write `Closes #N` only when every row passed. If any manual, tenant or other row is still open,
   write `Part of #N` and name the open rows.

If the issue has no requirements table, say so, summarize what you can verify from the code, and
suggest rewriting the issue with the `create-issue` skill before you rely on it.

## Pull-request proposal

Once every planned commit has landed and passed its post-commit review, and the issue check above
is done, proactively offer to open a GitHub pull request; do not wait for the user to ask.
Opening one is outward-facing, so nothing is pushed until the user says yes.

If the user accepts:

1. Show the title, the body and the target branch (normally `master`) first. The
   title is a short imperative phrase. The body has a summary of what changed and
   why, the status table from the issue check, what was not verified, and
   `Closes #N` (only when every row passed) or `Part of #N` for the issue it
   belongs to (look it up with `gh issue list`). End the body with the
   attribution line the harness gives for pull requests.
   If the change alters something a person sees (a window, a menu, console output, a report), the
   body also has a "Screenshots" section. You cannot capture a window and `gh` cannot upload
   images, so list the exact screens needed (which window or menu, in which language, before and
   after if it existed) as a manual step for the user, who drags them into the pull-request
   description. Name them under "Not verified" until they are there.
   Manual rows do not hold the pull request back; they are marked in the table and listed under
   "Not verified" until the user has answered.
2. After explicit approval of that exact title and body, push the branch
   (`git push -u origin <branch>`) and create the pull request with
   `gh pr create --base master --title ... --body-file ...`.
3. Verify it: show the link, and check with `gh pr view` that the title, base,
   branch and linked issue are as approved. Then offer the `pipeline-monitoring`
   skill to bind it and read its CI.

If the user declines or wants to wait, stop and leave the branch as committed.
