# GitHub Actions with `gh`

| Action | Command |
|---|---|
| Check sign-in | `gh auth status` |
| Wait for all checks (blocking, once) | `gh pr checks <pr> --watch --fail-fast` |
| List checks and their state | `gh pr checks <pr>` |
| Jobs of one run | `gh run view <run-id>` |
| Log of the failed steps | `gh run view <run-id> --log-failed` |
| Re-run only the failed jobs | `gh run rerun <run-id> --failed` |

The run id is the number in the check's link (`…/actions/runs/<run-id>/job/…`),
or comes from `gh run list --branch <branch> --limit 5`.

`--fail-fast` returns at the first failure, so the other jobs may still run.
Look at `gh pr checks <pr>` once more before you report, to catch every failed
job.
