<#
    Tests for the CAML field XML builder.

    This is the highest-value pure function in the module to pin down: the XML
    is sent verbatim to SharePoint, which responds to malformed input with an
    error that names neither the attribute nor the reason.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'New-SpoFieldXml' {

    Context 'basic structure' {

        It 'produces well-formed XML' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'Contract Value' -InternalName 'ContractValue' -Type Currency
                { [xml]$xml } | Should -Not -Throw
            }
        }

        It 'sets the core attributes' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'Contract Value' -InternalName 'ContractValue' -Type Currency -Group 'Contract Columns')

                $xml.Field.Type        | Should -Be 'Currency'
                $xml.Field.DisplayName | Should -Be 'Contract Value'
                $xml.Field.Name        | Should -Be 'ContractValue'
                $xml.Field.StaticName  | Should -Be 'ContractValue'
                $xml.Field.Group       | Should -Be 'Contract Columns'
            }
        }

        It 'defaults Required to FALSE' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text)
                $xml.Field.Required | Should -Be 'FALSE'
            }
        }

        It 'sets Required to TRUE when asked' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text -Required)
                $xml.Field.Required | Should -Be 'TRUE'
            }
        }

        It 'emits a braced upper-case GUID' {
            InModuleScope Office365Tools {
                $id = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                $xml = [xml](New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text -Id $id)
                $xml.Field.ID | Should -Be '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}'
            }
        }

        It 'generates a distinct GUID per call when none is given' {
            InModuleScope Office365Tools {
                $a = ([xml](New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text)).Field.ID
                $b = ([xml](New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text)).Field.ID
                $a | Should -Not -Be $b
            }
        }

        It 'emits a self-closing element when there are no children' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text
                $xml | Should -Match '/>$'
            }
        }

        It 'omits Group and Description when not supplied' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text
                $xml | Should -Not -Match 'Group='
                $xml | Should -Not -Match 'Description='
            }
        }
    }

    Context 'choice columns' {

        It 'renders each option as a CHOICE element' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'Status' -InternalName 'Status' -Type Choice -Choice 'Draft', 'Signed', 'Expired')

                $choices = @($xml.Field.CHOICES.CHOICE)
                $choices | Should -HaveCount 3
                $choices | Should -Contain 'Draft'
                $choices | Should -Contain 'Signed'
                $choices | Should -Contain 'Expired'
            }
        }

        It 'sets Format to Dropdown for Choice' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'Status' -InternalName 'Status' -Type Choice -Choice 'A', 'B')
                $xml.Field.Format | Should -Be 'Dropdown'
            }
        }

        It 'does not set Format for MultiChoice, which ignores it' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'Tags' -InternalName 'Tags' -Type MultiChoice -Choice 'A', 'B'
                $xml | Should -Not -Match 'Format='
            }
        }

        It 'ignores choices on a non-choice type' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text -Choice 'X', 'Y'
                $xml | Should -Not -Match 'CHOICES'
            }
        }

        It 'includes a default value' {
            InModuleScope Office365Tools {
                $xml = [xml](New-SpoFieldXml -DisplayName 'Status' -InternalName 'Status' -Type Choice -Choice 'Draft', 'Signed' -DefaultValue 'Draft')
                $xml.Field.Default | Should -Be 'Draft'
            }
        }
    }

    Context 'escaping' {

        # A column called 'R&D spend' or 'Q1 <draft>' is entirely legal in
        # SharePoint and would produce broken XML without escaping.

        It 'escapes an ampersand in the display name' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'R&D Spend' -InternalName 'RDSpend' -Type Currency
                { [xml]$xml } | Should -Not -Throw
                ([xml]$xml).Field.DisplayName | Should -Be 'R&D Spend'
            }
        }

        It 'escapes angle brackets in the display name' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'Q1 <draft>' -InternalName 'Q1Draft' -Type Text
                { [xml]$xml } | Should -Not -Throw
                ([xml]$xml).Field.DisplayName | Should -Be 'Q1 <draft>'
            }
        }

        It 'escapes quotes in the description' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text -Description 'The "official" value'
                { [xml]$xml } | Should -Not -Throw
                ([xml]$xml).Field.Description | Should -Be 'The "official" value'
            }
        }

        It 'escapes special characters inside choice options' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'Dept' -InternalName 'Dept' -Type Choice -Choice 'R&D', 'Sales & Marketing'
                { [xml]$xml } | Should -Not -Throw

                $choices = @(([xml]$xml).Field.CHOICES.CHOICE)
                $choices | Should -Contain 'R&D'
                $choices | Should -Contain 'Sales & Marketing'
            }
        }

        It 'escapes a group name containing an ampersand' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'A' -InternalName 'A' -Type Text -Group 'Legal & Compliance'
                { [xml]$xml } | Should -Not -Throw
                ([xml]$xml).Field.Group | Should -Be 'Legal & Compliance'
            }
        }

        It 'survives a name with German umlauts' {
            InModuleScope Office365Tools {
                $xml = New-SpoFieldXml -DisplayName 'Priorität' -InternalName 'Prioritaet' -Type Text
                { [xml]$xml } | Should -Not -Throw
                ([xml]$xml).Field.DisplayName | Should -Be 'Priorität'
            }
        }
    }
}
