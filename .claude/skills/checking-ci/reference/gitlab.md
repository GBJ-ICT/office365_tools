# GitLab CI with `glab`

| Action | Command |
|---|---|
| Check sign-in | `glab auth status` |
| Wait for the pipeline (blocking, once) | `glab ci status --live --branch <branch>` |
| Jobs of the pipeline and their state | `glab ci view <branch>` (interactive), or `glab ci get --branch <branch>` |
| Log of one job | `glab ci trace <job-id>` |
| Re-run one failed job | `glab ci retry <job-id>` |

The job ids come from `glab ci get --branch <branch>`. Read the log of every
failed job, one at a time.

If a flag is rejected, check `glab ci <command> --help`; the CLI changes
between versions.
