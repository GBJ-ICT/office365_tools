---
name: create-issue
description: Write a GitHub issue for this repository in the fixed ticket structure (Issue Prompt, Overall Goal, Context, Requirements and Verification Tests as a table, Out of Scope, Technical Specification, Open Questions, Tasks), label it TO BE REVIEWED, and mark it ACCEPTED once a reviewer other than the author accepts it. Use when the user asks for a ticket, issue or task description.
---

# Create an issue

Every issue in this repository has the same sections, in this order, starting
with the user's own prompt, so that a
person or an AI agent can pick it up cold and know what "done" means: all
requirements are met, each shown by its own test.

## Rules

- Write it in English. Short sentences, plain words, no marketing.
- Be concrete: name real files, commands, parameters and keys from the repo.
  Look them up first; do not guess paths.
- Requirements and their tests go in ONE two-column table: the requirement on the
  left, its verification test on the right, in the same row. There is no
  separate "success criteria" section: the ticket is done when every
  verification test passes.
- Keep each section short. Leave out a section only if it truly has nothing
  (write "None." for Out of Scope or Open Questions rather than dropping them).
- Never put secrets, tokens, tenant names or customer data in an issue.
- Creating the issue changes GitHub, so only do it when the user asked for an
  issue. Write the body to a file in the scratchpad, then
  `gh issue create --repo <owner/repo> --title ... --body-file ... --label "TO BE REVIEWED"`.
  Take owner/repo from `git remote -v`. Report the issue link afterwards.
- Every new issue gets the label `TO BE REVIEWED`. Check `gh label list` first;
  if `TO BE REVIEWED` or `ACCEPTED` does not exist, tell the user and create it
  with `gh label create` once they agree, because `gh issue create` fails on an
  unknown label.
- `TO BE REVIEWED` means a person other than the author still has to read the
  description. After creating the issue, tell the author that someone else
  must review it, and do not treat the author's own approval as a review.
- The label `ACCEPTED` means that other reviewer has accepted the task
  description. The author never sets it and you never set it for the author,
  even when the author says "accepted" or "looks good". Set it only when the
  person in this conversation is not the issue's author (compare
  `gh issue view <N> --json author --jq .author.login` with
  `gh api user --jq .login`) and says in the conversation that they accept it.
  Then swap the labels:
  `gh issue edit <N> --remove-label "TO BE REVIEWED" --add-label ACCEPTED`.
  Otherwise leave the label to the reviewer, who can set it on GitHub.
- If the reviewer asks for changes, edit the body and keep `TO BE REVIEWED`.
  An issue carries one of the two labels, never both.
- Link related issues as `#N` in Context.
- Title: an imperative phrase that starts with a verb ("Add ...", "Fix ...",
  "Test ..."), under 70 characters, no prefix. Not a noun phrase like
  "Multi-language support".
- Every task in the Tasks list also starts with a verb in the imperative
  ("Write ...", "Run ...", "Document ...").

## Structure

```markdown
## Issue Prompt
The user's request, copied word for word, as a blockquote (every line starts
with `> `), never in a code block: a code block gets a horizontal scroll bar
and a quote wraps. Do not summarise, correct or translate it. If the request
spans several messages, copy each one, in order, as separate quotes. Replace a
secret, token or tenant name with `[removed]` and say so; change nothing else.
The author may ask to take out a reference too; do the same and say so.

## Overall Goal
One or two sentences: what changes for whom, and why it matters.

## Context
What exists today, what triggered this, links to related issues, docs or
branches. Only what a newcomer needs.

## Requirements and Verification Tests
Each requirement has a test and an expected behaviour in the same row. The number is in the first column only.

| # | Requirement | Verification Test | Expected Behaviour |
|---|---|---|---|
| 1 | **MUST:** a single testable fact, with real file, parameter and key names. | **Unit:** the test or the steps. | The observable result that passes. |
| 2 | **SHOULD:** ... | **Manual:** who judges and what they look at. | ... |

Add a note below the table on what cannot be verified without a tenant or a
person.

## Out of Scope
What this ticket deliberately does not do, so nobody builds it by accident.

## Technical Specification
How to build it: files to add or change, commands and parameters, data formats,
the approach chosen and the alternative rejected, constraints from the repo
(PowerShell 7 module, 5.1-compatible launcher, string tables with BOM, no
secrets in the repo, CLAUDE.md git rules). Enough detail that an agent does not
have to invent the design.

## Open Questions
Decisions still needed from a person, with the options and a recommendation.
An agent must stop and ask about these rather than choose.

## Tasks
- [ ] Verb-first, ordered steps ("Write the script"). Each is one reviewable
      commit where possible. Mention the requirement numbers a task covers.

```

## Writing requirements

Check every requirement against this list before it goes into an issue:

- **One fact each.** No "and" that hides two checks; split it.
- **Specific and observable.** Someone can check it by running a command or
  looking at an output, with no judgement call. "`build.ps1` passes without
  network access", not "builds are robust".
- **Real names.** Use the actual file, parameter, key and command names from the
  repo; look them up.
- **Positive and complete.** Say what must happen. A "must not" (for example, no
  secret in the repo) is its own numbered requirement so it is tested too.
- **Prioritised.** Start with MUST or SHOULD.
- **Numbered, and the number is kept.** The number sits in the first column of
  the table row, so requirement 3 and its test share it. Tasks refer to it as
  "requirement 3".
- **No deadlines.** Dates belong to milestones, not to the requirement.

## Writing verification tests

- Same row as the requirement; do not repeat the number in the test cell.
- The test column says what to do; the Expected Behaviour column says what a
  pass looks like. Do not write "Expected:" inside the test cell.
- Write MUST or SHOULD in bold (`**MUST:**`). Copy the header row of the table
  exactly as in the template: its `` padding makes the three text columns
  the same width. GitHub tables have no width setting.
- Start the cell with the test type in bold: **Unit**, **Integration**, **Static**,
  **Smoke** or **Manual**. Never write just "Test". The types and how to pick one
  are defined in docs/dev/testing.md; read it before writing the tests.
- Prefer the earlier type in that list: Unit and Static before Smoke and Manual.
- In a table cell write a literal pipe as \|, also inside backticks.
- Give the exact command, input or steps, and the expected result. "Given X,
  when Y, then Z" works well.
- Prefer a check that can be automated (a Pester test, a command with an exit
  code). Use **Manual** only when a person has to judge it, and say who and by
  what.
- A test proves its requirement and nothing else; if it needs "and", the
  requirement should be split.

## Why these sections

- **Issue Prompt** keeps the original wording, so a reviewer can compare what
  was asked with what the rest of the issue says, and see where it drifted.
- **Overall Goal, Requirements, Technical Specification** are the core: the what
  and why, the testable must-haves, and the how.
- **The requirements table** is the finish line. Each row pairs a requirement
  with its test, so nothing is left unchecked and nothing is checked twice.
- **Context** stops an agent from re-deriving history or contradicting earlier
  decisions.
- **Out of Scope** is the best guard against an agent doing too much.
- **Open Questions** keeps guessed decisions out of the code.
- **Tasks** gives a commit-sized plan, which fits the one-commit-at-a-time rule
  in CLAUDE.md.
