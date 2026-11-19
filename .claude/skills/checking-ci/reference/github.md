# GitHub Actions with `gh`

| Action | Command |
|---|---|
| Check sign-in | `gh auth status` |
| Wait for all checks (blocking, once) | `gh pr checks <pr> --watch` |
| List checks and their state | `gh pr checks <pr>` |
| Jobs of one run | `gh run view <run-id>` |
| Log of the failed steps | `gh run view <run-id> --log-failed` |
| Re-run only the failed jobs | `gh run rerun <run-id> --failed` |

The run id is the number in the check's link (`…/actions/runs/<run-id>/job/…`),
or comes from `gh run list --branch <branch> --limit 5`.

`--watch` returns when every check has finished, so its output already lists
every failed job.
