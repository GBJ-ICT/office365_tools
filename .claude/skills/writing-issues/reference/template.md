# Issue template

Copy this structure. The text under each heading says what goes there; replace
it. Keep every section short.

```markdown
## Issue Prompt
> The user's request, copied word for word as a quote: every line starts with
> `> `. Never use a code block, which scrolls sideways; a quote wraps.
> Do not summarise, correct or translate. If the request spans several
> messages, quote each one, in order. Replace a secret with `[removed]` and say
> so below the quote; change nothing else.

## Overall Goal
One or two sentences: what changes for whom, and why it matters.

## Context
What exists today, what triggered this, links to related issues, docs or
branches. Only what a newcomer needs, so nobody re-derives history or
contradicts an earlier decision.

## Requirements and Verification Tests
Each requirement has its test and the expected behaviour in the same row.

| # | Requirement | Verification Test | Expected Behaviour |
|---|---|---|---|
| 1 | **MUST:** one testable fact, with real names. | **Unit:** the test or the steps. | The observable result that passes. |
| 2 | **SHOULD:** … | **Manual:** who judges and what they look at. | … |

Below the table: what cannot be verified without a real external system or a
person.

## Out of Scope
What this issue deliberately does not do, so nobody builds it by accident.

## Technical Specification
How to build it: files to add or change, commands and parameters, data formats,
the approach chosen and the alternative rejected, and the project's design
constraints. Enough that an agent does not have to invent the design.

## Open Questions
Decisions still needed from a person, each with the options and a
recommendation. An agent stops and asks about these rather than choosing.

## Tasks
- [ ] Verb-first, ordered steps, each one reviewable commit where possible,
      naming the requirements it covers ("requirement 3").
```

The issue is done when every verification test passes. There is no separate
"success criteria" section.
