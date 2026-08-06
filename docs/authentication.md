# Authentication

Every command needs a connection made by `Connect-O365`. That needs two things:
a **site URL** and a **client ID** for an Entra ID application registered in your
tenant.

## Why an app registration at all

PnP.PowerShell used to ship a first-party application ID that everyone shared.
Microsoft retired that, so each tenant now registers its own. It is a one-time
job for an administrator; everyone else just uses the resulting client ID.

## Registering the application

Needs an account with Application Administrator or Global Administrator rights.

```powershell
./scripts/Register-PnPApplication.ps1 -Tenant contoso.onmicrosoft.com
```

A browser opens for sign-in and consent. The script prints a client ID.

To register and save a ready-to-use profile in one go:

```powershell
./scripts/Register-PnPApplication.ps1 `
    -Tenant contoso.onmicrosoft.com `
    -ProfileName prod `
    -SiteUrl https://contoso.sharepoint.com/sites/team
```

### Permission scopes

The default is `AllSites.FullControl`, which the administrative commands need
(resetting inheritance, editing content types, granting permissions).

If your use is read-only — audits and reports — register a second application
with less:

```powershell
./scripts/Register-PnPApplication.ps1 `
    -Tenant contoso.onmicrosoft.com `
    -ApplicationName 'office365_tools Read Only' `
    -Permission 'AllSites.Read'
```

| Scope | Commands it covers |
|---|---|
| `AllSites.Read` | Every `Get-`, `Find-`, `Test-`, `Compare-`, `Export-` command |
| `AllSites.Write` | Adds `Add-SpoListItem`, `Update-SpoListItem`, `Import-SpoListItem` |
| `AllSites.FullControl` | Adds everything touching permissions and content types |

Delegated permissions never exceed what the signed-in user already has. An
application with `AllSites.FullControl` used by someone with read-only access to
a site still cannot write there.

## Profiles

Profiles live in `config/profiles.json` — gitignored, so tenant details stay out
of the repository. `config/profiles.example.json` is the tracked template.

```powershell
Set-O365Profile -Name prod `
    -SiteUrl https://contoso.sharepoint.com/sites/team `
    -ClientId 1234abcd-12ab-34cd-56ef-1234567890ab `
    -Tenant contoso.onmicrosoft.com `
    -Description 'Production' `
    -SetDefault

Get-O365Profile
Connect-O365                      # uses the default
Connect-O365 -ProfileName test    # uses a specific one
```

The first profile you create becomes the default automatically.

### Connecting without a profile

```powershell
Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/other -ClientId <guid>
```

Useful for one-off sites and CI.

## One site at a time

A connection points at one site collection. `Connect-O365` again to move:

```powershell
Connect-O365 -ProfileName prod
Test-SpoLibraryHealth -Library Documents

Connect-O365 -SiteUrl https://contoso.sharepoint.com/sites/hr -ClientId <guid>
Test-SpoLibraryHealth -Library Documents
```

The module keeps connection state in module scope rather than in environment
variables. The old scripts used `$env:client_id` and `$env:gbj_client_id`, which
outlive the shell that set them and leak into unrelated sessions — an excellent
way to run a repair against the wrong tenant.

Check where you are before doing anything destructive:

```powershell
Get-O365Connection
```

## Troubleshooting

### "Not connected to SharePoint"

`Connect-O365` has not run, or the token expired. Run it again.

### "AADSTS65001: The user or administrator has not consented"

Consent was not granted, or has not propagated yet. Wait a few minutes and
retry. If it persists, an administrator needs to grant admin consent for the
application in the Entra portal.

### "AADSTS700016: Application not found in the directory"

The client ID is from a different tenant, or the registration was deleted.
Verify with `Get-O365Profile` that the client ID matches the tenant in the site
URL.

### Connection succeeds but every list is "not found"

You are connected to the wrong site. `Get-O365Connection` shows which. Note that
a site collection and a subsite have different URLs, and a library only exists on
one of them.

### Interactive login does not open a browser

```powershell
Connect-O365 -ProfileName prod -Interactive
```

forces the interactive flow rather than reusing a cached token.

### Everything is slow

Permission checks cost one request per item, which dominates on a large library.

```powershell
Test-SpoLibraryHealth -Library Documents -Rule Naming, PathLength, Duplicate
./scripts/Invoke-LibraryAudit.ps1 -SkipPermissions
```

## Related

- [Getting started](getting-started.md)
- [Health rules](health-rules.md)
