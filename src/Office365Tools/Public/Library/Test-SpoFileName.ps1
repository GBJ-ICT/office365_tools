<#
.SYNOPSIS
    Validates file and folder names against SharePoint Online's rules.
.DESCRIPTION
    Names that SharePoint accepts through one path but rejects through another
    are a recurring source of "the sync client reports an error but the file
    looks fine in the browser". This checks the documented restrictions in one
    place.

    Two modes:

      Offline - pass -Name (or pipe strings) to validate names you are about to
                create. No connection required, so it works in scripts and in
                tests before anything touches the tenant.

      Online  - pass -Library to scan what is already there.

    Rules:
      FileName.IllegalCharacter  " * : < > ? / \ | are not permitted
      FileName.LeadingSpace      leading whitespace, silently stripped by some clients
      FileName.TrailingSpace     trailing whitespace, same problem
      FileName.TrailingPeriod    a trailing '.' breaks the sync client
      FileName.ReservedName      CON, PRN, AUX, NUL, COM0-9, LPT0-9, .lock, desktop.ini
      FileName.ReservedPrefix    names starting with ~$ or _vti_
      FileName.TooLong           over 255 characters
      FileName.RiskyCharacter    # and % work but break some downstream tools
.PARAMETER Name
    One or more names to validate offline.
.PARAMETER Library
    Scan this library's items instead of validating supplied names.
.PARAMETER IncludeRisky
    Report the FileName.RiskyCharacter rule. Off by default: # and % are legal
    in modern SharePoint, so reporting them would be noise on most sites.
.PARAMETER PageSize
    Items fetched per request in online mode.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'. Emits nothing for
    an acceptable name.
.EXAMPLE
    Test-SpoFileName -Name 'Q1 report: draft.docx'
    Reports the illegal ':' before you try to upload it.
.EXAMPLE
    'good.docx', 'bad?.docx' | Test-SpoFileName
.EXAMPLE
    Test-SpoFileName -Library Documents | Export-SpoReport -Path out/names.html
.LINK
    Test-SpoPathLength
.LINK
    Test-SpoLibraryHealth
#>
function Test-SpoFileName {
    [CmdletBinding(DefaultParameterSetName = 'Offline')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Offline', Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'Online', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [switch]$IncludeRisky,

        [Parameter(ParameterSetName = 'Online')]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Offline') {
            foreach ($candidate in $Name) {
                Test-SpoNameRule -Name $candidate -Target $candidate -IncludeRisky:$IncludeRisky
            }
            return
        }

        Assert-SpoConnection | Out-Null
        $list = Resolve-SpoList -Identity $Library

        Write-O365Log "Checking names in '$($list.Title)'." 'Info'

        foreach ($item in (Get-PnPListItem -List $list -PageSize $PageSize)) {
            $leaf = $item.FieldValues['FileLeafRef']
            $url  = $item.FieldValues['FileRef']
            if (-not $leaf) { continue }

            Test-SpoNameRule -Name $leaf -Target $url -List $list.Title -IncludeRisky:$IncludeRisky
        }

        Write-O365Log "Name check for '$($list.Title)' complete." 'Success'
    }
}
