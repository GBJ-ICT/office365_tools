---
name: reviewing-across-models
description: >-
  Has a change reviewed independently by three Claude models (Haiku, Sonnet, Opus), then compares
  the reviews: where they agree, where only one found something, and where they contradict each
  other. Shows every finding with its suggested diff, posts the review as numbered rounds of
  suggestions on the pull request when asked, and leaves each decision to the user. Use when
  asked for a multi-model review, a second opinion, or to compare reviews before merging.
---

# Reviewing across models

Three independent reviews of the same change, compared side by side. You
prepare and compare; **the user decides every finding.** Never apply, commit or
file anything the user has not picked.

The reviewer is the agent `code-reviewer`. It returns findings in a fixed format
(title, location, category, severity, confidence, why, suggested diff). Its
effort is set in its own file (`effort: xhigh`), so every run uses it whatever
the session's effort is; do not override it when you start the agent.

## 1. Fix the scope

Take the scope from the user. Without one, use the branch against the project's
base branch (from the project facts, usually in `CLAUDE.md`):
`git diff <base>...HEAD`. Note the base and head commits
(`git rev-parse --short`).

Show the scope in one line: commits, files, lines changed.

## 2. Start the reviews in parallel

Start all three in one message, so they run at the same time and none sees
another's result:

| Reviewer | Agent | Model |
|---|---|---|
| A | `code-reviewer` | `haiku` |
| B | `code-reviewer` | `sonnet` |
| C | `code-reviewer` | `opus` |

Give each the same brief: the scope (base, head, or the file list), the
project's verify commands if a reviewer may run tests, and "change nothing". Do
not tell a reviewer about the others, or what you expect it to find.

## 3. Match the findings

Two findings are the same when they point at the same place (same file, a few
lines apart, or the same component) **and** describe the same problem. Same
place with a different problem is two findings. Name each merged finding M1, M2, …
and keep the reviewers' own numbers (A-F2, C-F1) beside it.

## 4. Check each finding against the code

Read the code at each location yourself and add one of:

- **Confirmed:** the problem is in the code as described.
- **Not confirmed:** the code does not do what the finding says; give the line
  that shows it.
- **Unclear:** it depends on something you cannot see (a caller elsewhere, the
  runtime, an intent); say what.

This is a fact check, not a decision.

## 5. Present the comparison

Show three groups, in this order, each sorted by severity:

1. **Convergence:** found by two or more reviewers.
2. **Contradictions:** reviewers disagree (one calls it a bug, another calls it
   correct, or they propose opposite changes). Show both sides.
3. **Single findings:** found by one reviewer only.

Start with one overview table:

| # | Finding | Location | A Haiku | B Sonnet | C Opus | Check |
|---|---|---|---|---|---|---|
| M1 | … | `file:line` | high | high | — | Confirmed |

Then, for each finding: the "Why" of each reviewer who raised it (short), your
check with its reason, and **the suggested diff** in a `diff` code block. When
reviewers suggest different diffs, show each one, labelled by reviewer.

End with a short note on the reviewers themselves: how many findings each had,
and how many of those were not confirmed.

Give no recommendation on what to fix unless the user asks for one.

## 6. Let the user decide

Ask the user to choose, per finding: **fix**, **skip**, or **open an issue**. A
list like "fix M1, M3; issue M4; skip the rest" is enough.

Then do only what was chosen:

- **Fix:** apply the chosen diff, show the resulting `git diff` for that file,
  and commit through the project's commit procedure.
- **Open an issue:** draft it with the project's issue procedure and show it
  before filing.
- **Skip:** nothing.

## 7. Post the review on the pull request

Only when the user asks for it: posting changes the platform. The user then
decides on the platform instead of in step 6.

1. **Number the round.** Count the earlier reviews on this pull request whose
   title starts with "Review round"; this one is the next. Prefix every
   finding with the round: `R2-M3`.
2. **Read the exact lines.** For each confirmed finding, take the lines its fix
   replaces from the head commit (`git show <head>:<path>`), with their line
   numbers, and write the full replacement text, indentation included.
3. **Post one review** at the head commit, without approving or requesting
   changes:
   - **Say who wrote it.** The review is posted with the user's own account,
     so the body and every inline comment start with the line
     `> 🤖 Written by Claude (reviewing-across-models skill), posted from the user's account.`
     If the session has a bot identity of its own (a token for a bot account
     or app), post with that instead, and still keep the line.
   - **Title and body:** `## Review round N`, then the overview table, the three
     groups, the notes from the check and the count per reviewer.
   - **One inline comment per confirmed finding,** titled
     `Review round N · M3: <title>`, with who raised it, the check, one or two
     sentences why, and the fix as a suggestion block over exactly the lines it
     replaces (first to last line, new side). Open the block with four
     backticks, so backticks inside the fix do not end it.
   - **Alternatives:** one comment each, labelled by reviewer, saying "take one".
   - **No overlaps:** the line ranges of two suggestions never overlap, so they
     can be committed together.
   - **Outside of the PR diff:** a suggestion can only replace lines that are
     part of the pull request's diff. Put every fix for any other line or file
     into the body under its own heading, `### Outside of the PR diff`, each
     with its finding ID and title, the file, and the fix as a `diff` block.
     Say under the heading that these have no suggestion button and need a
     normal commit.
   - **Not confirmed:** in the body only, without a suggestion.
4. **Report the link.** Tell the user: **Commit suggestion** applies one,
   **Add suggestion to batch** collects several into one commit, and
   **Resolve conversation** drops one. Never commit, resolve or dismiss a
   suggestion yourself. After suggestions are committed on the platform, pull
   before working on the branch again.

On GitHub, post with
`gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input <file.json>`:
`commit_id` is the full head SHA, `event` is `COMMENT`, and each entry in
`comments` has `path`, `line`, `side: "RIGHT"`, and for several lines
`start_line` and `start_side: "RIGHT"`. Find earlier rounds with
`gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[].body'`. On GitLab, post
each finding as a merge-request discussion on its line; the suggestion block is
`suggestion:-<lines above>+<lines below>`.
