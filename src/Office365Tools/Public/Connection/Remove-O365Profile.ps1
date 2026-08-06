<#
.SYNOPSIS
    Deletes a connection profile from config/profiles.json.
.DESCRIPTION
    Removes the named profile. If it was the default, the default is cleared
    (or moved to the only remaining profile, if exactly one is left).
.PARAMETER Name
    Profile to remove.
.EXAMPLE
    Remove-O365Profile -Name sandbox
.EXAMPLE
    Remove-O365Profile -Name sandbox -WhatIf
.LINK
    Set-O365Profile
#>
function Remove-O365Profile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    process {
        $store = Get-O365ProfileStore

        if (-not $store.Profiles.ContainsKey($Name)) {
            Write-O365Log "Profile '$Name' does not exist; nothing to remove." 'Warning'
            return
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Remove profile')) {
            $store.Profiles.Remove($Name)

            if ($store.DefaultProfile -eq $Name) {
                $store.DefaultProfile = if ($store.Profiles.Count -eq 1) {
                    @($store.Profiles.Keys)[0]
                }
                else {
                    $null
                }
            }

            Save-O365ProfileStore -Store $store
            Write-O365Log "Removed profile '$Name'." 'Success'
        }
    }
}
