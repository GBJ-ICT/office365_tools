---
name: committing-changes
description: >-
  Splits a branch's changes into small self-contained commits and makes them one at a time:
  stages each, runs the project's verify commands on the staged state, shows the diff and the
  message, commits only after explicit approval, then reviews the commit. Use when asked to
  commit, to split work into commits, or to prepare changes for review.
---

# Committing changes

The project's own rules (usually `CLAUDE.md`) win over anything here. Look up
its facts first: the base branch, the verify commands, and the files that are
never committed.

Every commit needs the user's explicit approval in this conversation, and an
approval covers one commit only. Never amend, rebase, push or skip hooks unless
the user asks.

## 1. Plan

1. Read the state: `git status`, the staged and unstaged diffs, and
   `git log --oneline <base>..HEAD`. Leave unrelated changes and never-commit
   files alone.
2. Split the changes into the smallest set of commits that each pass the verify
   commands on their own. A commit carries everything it needs together: code,
   tests, texts, configuration, docs. Never split a dependency only to make a
   diff smaller.
3. If a commit adds behaviour that can be tested (a command, a function, a bug
   fix) and nothing tests it yet, say so and propose a test inside that commit.
4. Tell the user the plan in a few lines: each commit's subject and what it
   holds, in order.

## 2. Prepare one commit

Take the first commit of the plan; the rest waits for its turn.

1. Stage exactly its files or hunks (`git add <files>`, `git add -p` when one
   file holds two commits). Nothing else stays staged.
2. Review the staged diff for mistakes.
3. Run the verify commands on the staged state, not the working copy: export
   the index (`git checkout-index -a --prefix=<temp folder>/`) and run them
   there. Run long ones in the background.
4. Write the commit message (below).
5. Show the user: `git diff --cached --stat` (and the diff when it is short),
   the result of each verify command, the message in a code block, and what
   comes next in the plan. If a check failed or could not run, say so; never
   present an unverified commit as ready.
6. Ask for approval of this staged diff and this message.

## 3. Commit

1. After a clear "yes", check that the staged diff is still the one shown, then
   `git commit` with the approved message. If the diff or message changed, go
   back to step 2.5.
2. Review the commit (`git show --stat HEAD`) without changing anything, and
   report what you checked. If something should change, propose it and wait; do
   not fold a fix into a commit that already landed.
3. Continue with the next commit of the plan at step 2.

## Commit messages

Follow the style of `git log` in the repository. Without one:

- Subject: imperative, under about 70 characters, no trailing period.
- A blank line, then a short body in plain prose: what changed and why, in
  terms of behaviour. Do not list the files; the diff shows them.
- Leave the body out only for a trivial change.
- End with the attribution line the session gives for commits, if any.
