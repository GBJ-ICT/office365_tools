<#
.SYNOPSIS
    Finds items whose full path is at or over SharePoint's length limits.
.DESCRIPTION
    SharePoint Online allows a decoded server-relative URL of up to 400
    characters. Items over that cannot be created; items close to it break as
    soon as someone renames a parent folder or moves the branch one level
    deeper, which is the failure people actually hit.

    Reports at two thresholds so you can fix things before they break:
      PathLength.Exceeded - over the limit now
      PathLength.NearLimit - within -WarnAt characters of it
.PARAMETER Library
    Library or list to scan.
.PARAMETER Limit
    Hard limit in characters. Defaults to 400, SharePoint Online's documented
    maximum for the decoded server-relative URL.
.PARAMETER WarnAt
    Emit a warning finding when the remaining headroom drops below this many
    characters. Default 50.
.PARAMETER PageSize
    Items fetched per request.
.OUTPUTS
    PSCustomObject with PSTypeName 'Office365Tools.Finding'.
.EXAMPLE
    Test-SpoPathLength -Library Documents
.EXAMPLE
    Test-SpoPathLength -Library Documents -WarnAt 100 |
        Sort-Object { $_.Detail.Length } -Descending
.LINK
    Test-SpoFileName
.LINK
    Test-SpoLibraryHealth
#>
function Test-SpoPathLength {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('List', 'LibraryName')]
        [string]$Library,

        [Parameter()]
        [ValidateRange(100, 400)]
        [int]$Limit = 400,

        [Parameter()]
        [ValidateRange(0, 200)]
        [int]$WarnAt = 50,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        Assert-SpoConnection | Out-Null
    }

    process {
        $list = Resolve-SpoList -Identity $Library

        Write-O365Log (Get-O365String 'Library.Paths.Checking' $list.Title $Limit) 'Info'

        $items = Get-PnPListItem -List $list -PageSize $PageSize

        foreach ($item in $items) {
            $url = $item.FieldValues['FileRef']
            if (-not $url) { continue }

            # The stored value is already decoded; that is what the limit
            # applies to.
            $length    = $url.Length
            $remaining = $Limit - $length

            if ($remaining -lt 0) {
                New-SpoFinding -RuleId 'PathLength.Exceeded' -Severity Error -Scope Item `
                    -Target $url -List $list.Title `
                    -Message (Get-O365String 'Rule.PathLength.Exceeded' $length ([Math]::Abs($remaining)) $Limit) `
                    -Detail @{ Length = $length; Limit = $Limit; Remaining = $remaining; ItemId = $item.Id }
            }
            elseif ($remaining -le $WarnAt) {
                New-SpoFinding -RuleId 'PathLength.NearLimit' -Severity Warning -Scope Item `
                    -Target $url -List $list.Title `
                    -Message (Get-O365String 'Rule.PathLength.NearLimit' $length $remaining $Limit) `
                    -Detail @{ Length = $length; Limit = $Limit; Remaining = $remaining; ItemId = $item.Id }
            }
        }

        Write-O365Log (Get-O365String 'Library.Paths.Done' $list.Title) 'Success'
    }
}
