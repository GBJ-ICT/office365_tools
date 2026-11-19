# Contribution workflow

How a change goes from an idea to a merged pull request, and the Claude skills
that help at each step. The same steps apply when you work without
Claude; the skills only make them quicker and keep them uniform.

The Git rules that always apply are in [CLAUDE.md](https://github.com/GBJ-ICT/office365_tools/blob/master/CLAUDE.md).
How to write a command is in [CONTRIBUTING.md](https://github.com/GBJ-ICT/office365_tools/blob/master/CONTRIBUTING.md).

## The path of a change

```mermaid
flowchart LR
    A[Idea] --> B[Issue<br/>TO BE REVIEWED]
    B -->|another person reviews| C[Issue<br/>ACCEPTED]
    C --> D[Branch and work]
    D --> E[Small commits<br/>one at a time]
    E --> F[Issue check]
    F --> G[Pull request]
    G --> H[CI checks]
    H --> I[Review and merge]
```

### 1. Write an issue

Every change starts with an issue in the fixed structure: **Issue Prompt**,
Overall Goal, Context, **Requirements and Verification Tests** (one table),
Out of Scope, Technical Specification, Open Questions and Tasks.

- The **Issue Prompt** is the request copied word for word, so a reviewer can
  see where the rest of the issue drifted from what was asked.
- Each requirement has its own test and expected behaviour in the same row. The
  issue is done when every test passes. The five test types (Unit, Integration,
  Static, Smoke, Manual) are defined in [Testing](testing.md).
- A new issue gets the label **TO BE REVIEWED**.

### 2. Have someone else review it

A person other than the author reads the description and either asks for
changes or sets the label **ACCEPTED** (and removes TO BE REVIEWED). An issue
carries one of the two labels, never both. Start work on an accepted issue.

The author's own approval does not count. This rule is kept by convention for
now; nothing on GitHub enforces it.

### 3. Work on a branch

Create a branch from the right base and make the change. Add the tests the
issue asks for, the German and English texts for every user-visible message, and
the documentation, in the same change.

### 4. Commit in small steps

Every commit has to pass the pipelines on its own, so it contains the
implementation, tests, texts and documentation it needs together. Locally, the
pipelines are:

```powershell
./build.ps1              # the analyzer and the unit tests
mkdocs build --strict    # when the documentation changed
```

Commits are proposed one at a time, with the message and the file list, and made
only after approval. Commit messages have a short imperative subject line, a
blank line and a body in plain prose.

### 5. Check the work against the issue

Before the pull request, go through the requirements table: run each test that
can be run, write a missing Unit or Static test, and list the Manual tests for
a person. The result goes into the pull request as a status table.

Compare what was built with the whole issue too. Every deviation (what the issue
says, what was done instead, and why) is written as a comment on the issue and
again in the pull request. The issue's own text is not edited to hide one.

### 6. Open the pull request

The description summarises the change, shows the status table, lists the
deviations from the issue and says what was not verified. It says `Closes #N`
only if every requirement passed, otherwise `Part of #N` and the open rows.

### 7. Read the pipeline

GitHub Actions runs `.github/workflows/ci.yml` (analyzer, unit tests, manifest
check) and `.github/workflows/docs.yml` (documentation build) on the pull
request. A red check is diagnosed from its log, reproduced locally and fixed
with a new commit.

## The skills

The skills live in `.claude/skills/`. Claude Code loads them by itself when your
request matches, or you can name one ("wrap up this branch"). Each one stops and
asks before anything outward-facing: a commit, a push, a pull request, a label,
a comment.

The skills hold only the procedure and name no project, so they work in any
repository on GitHub or GitLab. What is particular to this repository (the base
branch, the build and docs commands, the CI jobs, the files that are never
committed, the labels) is in the "Project facts" section of
[CLAUDE.md](https://github.com/GBJ-ICT/office365_tools/blob/master/CLAUDE.md),
where the skills look it up.

| Skill | Use it to | What it does |
|---|---|---|
| `writing-issues` | Turn a request into an issue | Writes the issue in the fixed structure, copies your prompt into **Issue Prompt**, labels it **TO BE REVIEWED**, and sets **ACCEPTED** only when a person other than the author accepts it. |
| `committing-changes` | Commit your work | Plans small commits, stages each one for your review, runs the verify commands on the staged state, and commits after your approval. |
| `verifying-against-issue` | Check the work against its issue | Runs each requirement's test, adds a missing Unit or Static test, lists the Manual tests, names every deviation from the issue and builds the status table. |
| `opening-pull-requests` | Open the pull request | Drafts the title and description with the status table and deviations, and after your approval pushes and opens it. |
| `checking-ci` | Read CI after a pull request | Waits once for the checks, and for a failed job finds the cause in the log, reproduces it locally and proposes a fix. It does not poll. |
| `wrapping-up-branches` | Finish a branch in one go | Runs `committing-changes`, `verifying-against-issue`, `opening-pull-requests` and `checking-ci` in that order. |
| `reviewing-across-models` | Get several independent reviews | Has Haiku, Sonnet and Opus review the code in parallel, then compares the reviews: where they agree, contradict or stand alone. Shows each finding with its suggested diff; you decide what is fixed. |

The usual order is `writing-issues`, then your work, then
`wrapping-up-branches`. Run `reviewing-across-models` before the pull request
when a change is large or risky.

### Review agent

`reviewing-across-models` hands the reviews to the agent `code-reviewer` in
`.claude/agents/`, started once each with Haiku, Sonnet and Opus. An agent works
in its own context and returns only its result, so the three reviews run at the
same time and none sees the others.

The agent reviews the diff for bugs, security, tests and maintainability. It
can only read: it changes no file. Every finding comes back with a suggested
diff, and nothing is applied until you pick it.

## Notes

- The labels **TO BE REVIEWED** and **ACCEPTED** must exist in the repository
  before the first issue uses them; `writing-issues` asks before creating them.
- The skills use the GitHub CLI (`gh`), which has to be installed and logged in
  (`gh auth status`).
- Nothing is pushed or changed on GitHub without your approval in the
  conversation.
