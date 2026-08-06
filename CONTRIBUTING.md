# Contributing

The goal is that anyone can add a command without reading a style guide first.
CI enforces most of what is below, so if `./build.ps1` is green you have
probably followed it.

## Adding a command

**1. Create one file, named after the command.**

```
src/Office365Tools/Public/<Area>/<Verb>-<Noun>.ps1
```

The file name must equal the function name — the loader derives the export list
from file names. Areas are `Connection`, `Permission`, `ContentType`, `Library`,
`ListItem`, `Report`. Add a new folder if none fits.

**2. Add the name to `FunctionsToExport`** in
`src/Office365Tools/Office365Tools.psd1`. Wildcards are not used here on purpose:
an explicit list keeps command discovery fast and makes accidental exports
visible in review. A test fails if the manifest and the actual exports disagree.

**3. Write it to the template below.**

```powershell
<#
.SYNOPSIS
    One line, imperative, no trailing period-free telegraphese.
.DESCRIPTION
    What it does and — more usefully — when you would reach for it, what it
    deliberately does not do, and anything surprising about SharePoint that
    motivated the design.
.PARAMETER Library
    Every parameter needs one of these.
.OUTPUTS
    What comes out.
.EXAMPLE
    Verb-SpoNoun -Library Documents
    At least one example. Two or three is better; make the second one show the
    command composed with something else.
.LINK
    The-Related-Command
#>
function Verb-SpoNoun {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]   # if it mutates
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        if ($PSCmdlet.ShouldProcess($target, 'What will happen')) {
            # ...
        }
    }
}
```

**4. Add tests** in `tests/Unit/`. If the logic is pure — string handling,
comparison, formatting — put it in a private helper so it can be tested without
a tenant. `Test-SpoNameRule` and `ConvertTo-SpoPermissionSignature` exist
precisely for this reason.

**5. Run the build.**

```bash
pwsh ./build.ps1
```

## The rules

### Emit objects, never write to the host

`Write-Host` from a module command is unusable output: it cannot be piped,
filtered, exported, or tested. Emit objects and let the caller decide.

For narration, use `Write-O365Log`, which routes to the verbose or warning
stream and also writes to the file log when one is active:

```powershell
Write-O365Log "Scanned $count items." 'Success'
Write-O365Log "Could not read '$url': $($_.Exception.Message)" 'Warning'
```

`Write-Host` is fine in `scripts/`, where colourised console output is the point.

### Separate reading from writing

A command whose verb is `Get`, `Find`, `Test`, or `Compare` must not change
anything, ever. A test enforces this by asserting those commands have no
`-WhatIf` parameter.

Mutating commands accept the reading command's output on the pipeline:

```powershell
Get-SpoPermissionMismatch -Library Docs | Repair-SpoPermissionInheritance
```

This is the whole dry-run story. It is also why
`check_for_permission_mismatches.ps1` — which was named "check" and reset
inheritance as a side effect — was split into two commands.

### Support `-WhatIf` on everything that mutates

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
...
if ($PSCmdlet.ShouldProcess($target, 'Remove field Priority')) { ... }
```

**In `scripts/`, `-WhatIf` does not propagate on its own.** `$WhatIfPreference`,
set by a script's own `-WhatIf`, does not reach a function defined inside a
module: the function resolves preference variables in the *module's* scope,
where it is still false. A script that relies on it writes for real while every
`if ($WhatIfPreference)` in it agrees that nothing happened. Either forward it
or gate the call yourself:

```powershell
Add-SpoListItem -Library $list -Values $values -WhatIf:$WhatIfPreference
# or
if ($PSCmdlet.ShouldProcess($list, 'Add item')) { Add-SpoListItem ... }
```

`ScriptSafety.Tests.ps1` checks every script that declares
`SupportsShouldProcess` does one of the two.

Never hand-roll confirmation with `Read-Host`. `ConfirmImpact` guidance:

| Impact | Use for |
|---|---|
| `High` | Irreversible or wide-reaching: discarding permissions, removing fields |
| `Medium` | Reversible but significant: updating items, removing a profile |
| `Low` | Additive and easily undone: adding an item, writing a report |

### Use approved verbs and a noun prefix

`Get-Verb` lists the approved verbs. Nouns are prefixed `Spo` (SharePoint
operations) or `O365` (module concerns: connection, profiles, logging). Both are
enforced by tests.

### Fail with a message that says what to do next

Not this:

```powershell
throw "List not found"
```

This:

```powershell
throw [System.InvalidOperationException]::new(
    "List or library '$Identity' was not found. Available lists on $($script:O365State.SiteUrl): $($available -join ', ')"
)
```

The person hitting the error is usually not the person who wrote the command.

### Never commit tenant data

Site URLs, client IDs, user names, file paths from a real site. `config/*.json`
and `out/` are gitignored; keep it that way. Reports and logs go in `out/`.

## Findings

Diagnostic commands emit findings via `New-SpoFinding`, in one shape:

```powershell
New-SpoFinding -RuleId 'FileName.IllegalCharacter' -Severity Error -Scope Item `
    -Target $url -List $list.Title `
    -Message 'Name contains characters SharePoint does not permit: ?' `
    -Detail @{ Name = $leaf; Characters = @('?') }
```

- **`RuleId`** is `Category.SpecificProblem`, and is a stable contract. People
  filter and suppress on it. Renaming one is a breaking change.
- **`Severity`** — `Error` means broken now or will break for a user;
  `Warning` means latent problem; `Info` means observation, no action implied.
- **`Message`** is one sentence, written for someone who did not run the scan.
- **`Detail`** holds rule-specific extras so the core columns stay uniform.

Because the shape is shared, `Export-SpoReport` formats output from any
diagnostic command, and new rules get HTML and CSV reporting for free.

## Style

Four-space indent, `PascalCase` parameters, aligned assignments. Comments explain
*why*, not what — the code already says what. If a comment restates the line
below it, delete the comment.

`PSScriptAnalyzer` settings are in `PSScriptAnalyzerSettings.psd1`. If a rule is
wrong for a specific case, suppress it at the function with a justification
rather than switching it off globally:

```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'ExpandGroups',
    Justification = 'Used inside the $emit script block, which the analyzer does not trace into.')]
```

## Tests

`tests/Unit/` must run with no tenant and no network. Mock or, better, factor the
logic so there is nothing to mock.

- `Conventions.Tests.ps1` enforces this document mechanically. If you add a
  convention, add it here too.
- Note the `BeforeDiscovery` block in that file: Pester evaluates `-ForEach`
  during discovery, before `BeforeAll` runs, so the module must be imported at
  discovery time for a command list to exist.
- Per-test setup (`BeforeEach`/`AfterEach`) must live inside a `Describe`, not at
  file root.

Integration tests that need a real tenant go in `tests/Integration/` and are not
run by CI.
