---
name: writing-issues
description: >-
  Writes an issue (ticket, user story, task description) in a fixed structure that starts with
  the user's request word for word and pairs every requirement with its verification test, files
  it with a review label, and marks it accepted only after someone other than the author reviews
  it. Use when asked to create, write or rewrite an issue or ticket, or to accept one. Works with
  GitHub and GitLab.
---

# Writing issues

An issue is written so that a person or an agent can pick it up cold and know
what "done" means: every requirement is met, each shown by its own test.

Look up the project's facts first (usually a "Project facts" section in
`CLAUDE.md`): platform, review labels, test types, design constraints. Where
the project has none, use the defaults below and say so.

## Steps

1. **Collect the material.** Keep the user's request as given. Read the code,
   docs and related issues it touches; use real file, command, parameter and
   key names, never guessed ones.
2. **Write the body** in the structure of [reference/template.md](reference/template.md),
   every section in that order. Write "None." in a section that has nothing.
3. **Check every requirement and test** against
   [reference/requirements.md](reference/requirements.md). Pick each test type
   with [reference/test-types.md](reference/test-types.md), unless the project
   defines its own types.
4. **Show the title and body to the user and wait for a clear "yes".**
   Creating the issue changes the platform: file it only when the user asked
   for an issue and approved this exact title and body.
5. **File it** with the new-issue label (default `TO BE REVIEWED`). Write the
   body to a temporary file and use the command for the platform below. Take
   the repository from `git remote -v`. Report the link.
6. **Ask for a review.** Tell the author that a person other than them must
   review the issue before work starts.

## Writing rules

- English, short sentences, plain words, no marketing.
- **Title:** an imperative phrase that starts with a verb ("Add …", "Fix …"),
  under 70 characters, no prefix. Not a noun phrase.
- **Tasks** also start with a verb and name the requirement numbers they cover.
- Link related issues in Context.
- Never put secrets, tokens, internal host or tenant names, or customer data in
  an issue. In the Issue Prompt, replace them with `[removed]` and say so.

## Review labels

An issue carries exactly one of two labels:

- **New-issue label** (default `TO BE REVIEWED`): a person other than the author
  still has to read it. Keep it while changes are requested.
- **Accepted label** (default `ACCEPTED`): that other person has accepted it.

Set the accepted label only when both hold:

1. The person in this conversation is not the issue's author: compare the
   issue's author with the signed-in user (commands below).
2. That person says in this conversation that they accept it.

Then swap the labels. The author's own "looks good" never counts, and you never
set the label for the author. Otherwise leave it to the reviewer.

If a label does not exist yet, creating the issue fails. Check the label list
first; if one is missing, ask the user, then create it.

## Platform commands

| Action | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| List labels | `gh label list` | `glab label list` |
| Create label | `gh label create "<name>"` | `glab label create --name "<name>"` |
| Create issue | `gh issue create --title "<t>" --body-file <f> --label "<l>"` | `glab issue create --title "<t>" --description "$(cat <f>)" --label "<l>"` |
| Issue author | `gh issue view <n> --json author --jq .author.login` | `glab issue view <n> --output json \| jq -r .author.username` |
| Signed-in user | `gh api user --jq .login` | `glab api user \| jq -r .username` |
| Swap labels | `gh issue edit <n> --remove-label "<old>" --add-label "<new>"` | `glab issue update <n> --unlabel "<old>" --label "<new>"` |
| Edit body | `gh issue edit <n> --body-file <f>` | `glab issue update <n> --description "$(cat <f>)"` |

If a flag is rejected, check `<cli> <command> --help`; the CLIs change between
versions.
