# Test types

The default five types. A project may define its own, or say where each type
lives in its repository; then the project's definition wins.

| Type | What it is | Runs in CI |
|---|---|---|
| **Unit** | An automated test with every outside call (network, cloud service, database) replaced by a mock. | Yes |
| **Integration** | An automated test against a real outside system, such as a test tenant, account or database. It creates its own data and removes it. | Usually not |
| **Static** | A check of the repository's content without running the product: a search, a file listing, a linter, a docs build. | Yes, when written as a test or part of the build |
| **Smoke** | Run the real product on sample data and look at what it prints or writes. | No |
| **Manual** | Something a person has to judge or click through. | No |

## Choosing a type

Take the first that fits:

1. Provable by code with outside calls mocked? **Unit.**
2. Only meaningful against the real outside system (sign-in, throttling, how the
   service behaves)? **Integration.**
3. A fact about the files in the repository ("no key file is tracked")?
   **Static.**
4. "Does it run and look right on sample data"? **Smoke.**
5. Only a person's judgement settles it (wording, layout)? **Manual.**

A requirement that can be Unit or Static is never left as Manual. A Manual check
repeated every release should become a Smoke or Unit test.

## What each test states

- **Unit, Integration:** the test file or name, and the result that passes.
- **Static:** the exact command and the output that passes ("prints nothing").
- **Smoke:** the exact command, the sample data, and what to look for.
- **Manual:** who judges, what they look at, and what counts as a pass.
