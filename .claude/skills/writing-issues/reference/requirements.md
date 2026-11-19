# Requirements and verification tests

Check every row of the requirements table against both lists.

## A requirement

- **One fact.** An "and" that hides two checks becomes two rows.
- **Observable.** Someone can check it by running a command or looking at an
  output, without a judgement call: "the build passes without network access",
  not "builds are robust".
- **Real names.** The actual file, parameter, key and command names.
- **Prioritised.** Starts with `**MUST:**` or `**SHOULD:**`.
- **Positive.** Says what must happen. A "must not" (no secret in the
  repository) is its own row, so it is tested too.
- **Numbered for good.** The number sits in the first column only. Tasks and
  pull requests refer to it ("requirement 3"); never renumber.
- **No dates.** Deadlines belong to milestones.

## A verification test

- Same row as its requirement. Do not repeat the number.
- Starts with its type in bold, for example `**Unit:**`. Never just "Test".
- Prefer the earliest type that fits (see test-types.md). Use **Manual** only
  when a person has to judge, and say who and by what.
- Gives the exact command, input or steps. "Given X, when Y, then Z" works well.
- The Verification Test column says what to do; the Expected Behaviour column
  says what a pass looks like. No "Expected:" inside the test cell.
- Proves its requirement and nothing else. If it needs "and", split the
  requirement.
- Write a literal pipe in a table cell as `\|`, also inside backticks.
