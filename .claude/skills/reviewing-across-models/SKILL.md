---
name: reviewing-across-models
description: >-
  Has a change reviewed independently by three Claude models (Haiku, Sonnet, Opus), then compares
  the reviews: where they agree, where only one found something, and where they contradict each
  other. Shows every finding with its suggested diff and leaves each decision to the user. Use
  when asked for a multi-model review, a second opinion, or to compare reviews before merging.
---

# Reviewing across models

Three independent reviews of the same change, compared side by side. You
prepare and compare; **the user decides every finding.** Never apply, commit or
file anything the user has not picked.

The reviewer is the agent `code-reviewer`. It returns findings in a fixed format
(title, location, category, severity, confidence, why, suggested diff).

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
