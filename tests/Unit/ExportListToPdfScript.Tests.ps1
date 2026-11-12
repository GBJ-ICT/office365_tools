<#
    scripts/Export-ListToPdf.ps1 is what people already run from the command
    line. The "SharePoint list to PDF" tool was built beside it, not into it, so
    the script has to keep every parameter it had: something written against
    it must still run.

    The script is read, not run: its parameters come from its syntax tree.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Consumed by the It blocks below, which the analyzer does not trace.')]
param()

BeforeAll {
    $script:Parameters = @{}

    $path = Join-Path $PSScriptRoot '../../scripts/Export-ListToPdf.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)

    foreach ($parameter in $ast.ParamBlock.Parameters) {
        $named = @{}
        foreach ($attribute in $parameter.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }) {
            foreach ($argument in $attribute.NamedArguments) {
                $named[$argument.ArgumentName] = $argument.Argument.Extent.Text
            }
        }

        $script:Parameters[$parameter.Name.VariablePath.UserPath] = [pscustomobject]@{
            Type      = $parameter.StaticType.Name
            Mandatory = $named.ContainsKey('Mandatory')
            Set       = $named['ParameterSetName']
        }
    }
}

Describe 'scripts/Export-ListToPdf.ps1' {

    It 'keeps every parameter it had, under the same name' {
        $had = @(
            'ProfileName', 'SiteUrl', 'ClientId', 'List', 'View', 'Field', 'SortBy', 'Descending', 'GroupBy',
            'Title', 'Subtitle', 'Orientation', 'PaperSize', 'FontSize', 'Margin', 'ColumnWidth', 'Css',
            'ItemLink', 'LinkColumn', 'NoAutoLink', 'RowNumber', 'PageFooter', 'SkipVerification', 'Sample',
            'KeepHtml', 'BrowserPath', 'Interactive', 'OutputPath', 'Language')

        @($had | Where-Object { -not $script:Parameters.ContainsKey($_) }) | Should -BeNullOrEmpty
    }

    It 'still needs a list, and either a profile or a site with its application ID' {
        $script:Parameters['List'].Mandatory | Should -BeTrue
        $script:Parameters['ProfileName'].Set | Should -Match 'Profile'
        $script:Parameters['SiteUrl'].Mandatory | Should -BeTrue
        $script:Parameters['SiteUrl'].Set | Should -Match 'Url'
        $script:Parameters['ClientId'].Mandatory | Should -BeTrue
        $script:Parameters['ClientId'].Set | Should -Match 'Url'
    }

    It 'still takes the same kinds of value' {
        $script:Parameters['View'].Type | Should -Be 'String'
        $script:Parameters['Field'].Type | Should -Be 'String[]'
        $script:Parameters['FontSize'].Type | Should -Be 'Double'
        $script:Parameters['Sample'].Type | Should -Be 'Int32'
        $script:Parameters['Descending'].Type | Should -Be 'SwitchParameter'
        $script:Parameters['SkipVerification'].Type | Should -Be 'SwitchParameter'
    }
}
