# Integration tests

Tests that need a real SharePoint tenant. **Not run by CI** and not run by
`./build.ps1` — they would need credentials in the pipeline and would mutate a
live site.

## Running them

Point them at a **sandbox site you are willing to have modified**. Several of
these create and delete lists.

```powershell
$env:O365TOOLS_TEST_PROFILE = 'sandbox'
Invoke-Pester ./tests/Integration
```

## Writing them

- Never target a production site. Guard on the profile name if you can.
- Create what you need in `BeforeAll` and remove it in `AfterAll`, so a failed
  run does not leave debris behind.
- Prefix anything you create with `pester-` and a GUID, so leftovers are
  identifiable and safe to clean up by hand.
- If a behaviour can be tested without a tenant, it belongs in `tests/Unit`
  instead. Factor the logic into a private helper and test that — see
  `Test-SpoNameRule` and `ConvertTo-SpoPermissionSignature` for the pattern.

## What is worth testing here

Only things that genuinely cannot be verified offline:

- `Connect-O365` against a real tenant, including the failure messages
- Permission signature comparison against real CSOM role assignments
- Content type inheritance behaviour, which has quirks no mock reproduces
- `Import-SpoListItem` field validation against a real list schema
- Throttling behaviour on a large library
