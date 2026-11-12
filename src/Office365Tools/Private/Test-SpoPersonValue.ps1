<#
.SYNOPSIS
    Internal: tells whether a field value is a person or a group.
.DESCRIPTION
    A Person or Group column arrives as a FieldUserValue: a lookup value that
    also carries an address. That pair of properties is what sets it apart from
    an ordinary lookup, which has no address, so the test is about the shape of
    the value rather than its type -- which keeps it working on what a test
    builds as well as on what SharePoint returns.
.PARAMETER Value
    The field value.
.OUTPUTS
    System.Boolean
.EXAMPLE
    Test-SpoPersonValue -Value ([pscustomobject]@{ LookupValue = 'Pat'; Email = 'pat@example.org' })
#>
function Test-SpoPersonValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value -or $Value -is [string] -or $Value -is [System.Collections.IEnumerable]) { return $false }

    return ($null -ne $Value.PSObject.Properties['LookupValue'] -and $null -ne $Value.PSObject.Properties['Email'])
}
