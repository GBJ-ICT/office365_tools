# Testing

How we test this repository, and the five **test types** that issues, pull
requests and commits use to say how something is verified. Using the same words
everywhere means "Unit" always means the same thing.

## The five test types

| Type | What it is | Needs a tenant | Runs in `./build.ps1` and CI | Where it lives |
|---|---|---|---|---|
| **Unit** | An automated Pester test. PnP and other outside calls are mocked. | No | Yes | `tests/Unit` |
| **Integration** | An automated Pester test against a real tenant. It creates its own objects and removes them. | Yes | No | `tests/Integration` |
| **Static** | A check of the repository's content without running the tool: `git grep`, `git ls-files`, the script analyzer, `mkdocs build --strict`, a file or folder check. | No | Yes, when written as a Pester test or as part of the build | `tests/Unit` (as a test), or a command in the issue |
| **Smoke** | Run the real tool on sample data on your machine and look at what it prints or writes. | No | No | A command in the issue or the docs |
| **Manual** | Something a person has to judge or click through. | Sometimes | No | A named person and a clear check in the issue |

### Choosing the type

Take the first that fits, from top to bottom:

1. Can it be proven by code with outside calls mocked? **Unit.**
2. Does it only make sense against a real tenant, such as sign-in, throttling or
   how SharePoint treats a content type? **Integration.**
3. Is it a fact about the files in the repository, such as "no secret is tracked"
   or "every command has a help synopsis"? **Static.**
4. Is it "does the tool run and look right on sample data"? **Smoke.**
5. Does only a person's eye or judgement settle it, such as the wording of a
   message or how a window looks? **Manual.**

Prefer the earlier types. A requirement that can be a Unit or a Static test
should not be left as a Manual check. If a Manual check is repeated every
release, turn it into a Smoke or Unit test.

### What each type must state

- **Unit, Integration:** the test file or the test name, and the result that
  passes.
- **Static:** the exact command and the output that passes (for example, "prints
  nothing").
- **Smoke:** the exact command, the sample data, and what to look for.
- **Manual:** who judges, what they look at and what counts as a pass.

## Running them

```powershell
./build.ps1                      # analyzer and all Unit and Static tests
./build.ps1 -Task Test           # Unit and Static tests only
Invoke-Pester ./tests/Integration  # Integration; needs a tenant, see below
mkdocs build --strict            # docs build (Static)
```

## Integration tests

They run against a tenant you are willing to have modified. They are never part
of `./build.ps1` or the normal CI. How to run them and how to write them is in
[tests/Integration/README.md](https://github.com/GBJ-ICT/office365_tools/blob/master/tests/Integration/README.md).
The short version: point `O365TOOLS_TEST_PROFILE` at a test profile, name
everything you create with the prefix `pester-` and a GUID, and remove it in
`AfterAll`.

No secret belongs in the repository. `config/*.json` is ignored by git; only the
`*.example.json` templates are tracked.

## Using the types in an issue

The `create-issue` skill puts each requirement, its test and its expected
behaviour in one table row. The test cell starts with its type:

| # | Requirement | Verification Test | Expected Behaviour |
|---|---|---|---|
| 2 | **MUST:** no `.pfx`, `.pem` or `.key` file is tracked. | **Static:** `git ls-files '*.pfx' '*.pem' '*.key'` | Prints nothing. |
| 5 | **MUST:** `Get-Thing -Name x` returns the item named `x`. | **Unit:** mock the PnP call, run the command. | One item whose `Name` is `x`. |

In a table cell write a literal pipe as `\|`, also inside backticks.
