<#
    ConvertTo-SpoPortableFieldXml decides what survives a column being copied
    from one list to another, which makes it exactly the kind of fiddly string
    work CONTRIBUTING asks to be kept private and tested without a tenant.

    The XML below is shaped like what SharePoint really returns -- attributes in
    its order, provenance mixed in among configuration -- but the GUIDs and
    names are invented.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    # Private helpers are not exported, so reach into the module scope for it.
    $script:Convert = {
        param([hashtable]$Splat)
        & (Get-Module Office365Tools) { param($s) ConvertTo-SpoPortableFieldXml @s } $Splat
    }

    $script:ChoiceXml = @'
<Field DisplayName="Status" FillInChoice="FALSE" Format="Dropdown" Name="Status"
       Required="TRUE" Title="Stale Old Title" Type="Choice"
       ID="{9e8797b1-cdd1-4f5a-a8c3-b040c5992fef}" Version="20" StaticName="Status"
       SourceID="{76e6637d-089f-43f7-afa2-fffd936ac376}" ColName="nvarchar9" RowOrdinal="0"
       CustomFormatter="{&quot;elmType&quot;:&quot;div&quot;}">
  <CHOICES><CHOICE>open</CHOICE><CHOICE>done</CHOICE></CHOICES>
  <Default>open</Default>
</Field>
'@

    $script:NoteXml = @'
<Field AppendOnly="FALSE" DisplayName="Remarks" Name="Remarks" RichText="TRUE"
       RichTextMode="FullHtml" IsolateStyles="TRUE" Title="Remarks" Type="Note"
       ID="{d3f5a940-9e43-405a-97da-60454a36f2b9}" StaticName="Remarks"
       SourceID="{76e6637d-089f-43f7-afa2-fffd936ac376}" ColName="ntext2" RowOrdinal="0"
       FromBaseType="TRUE" Sealed="TRUE" />
'@
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-SpoPortableFieldXml' {

    Context 'what it removes' {

        It 'strips every attribute that ties the field to its source list' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            foreach ($attribute in 'SourceID', 'ColName', 'RowOrdinal', 'Version') {
                $result.Field.HasAttribute($attribute) | Should -BeFalse -Because "$attribute belongs to the source list"
            }
        }

        It 'strips FromBaseType and Sealed, which would make the copy uneditable' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:NoteXml })

            $result.Field.HasAttribute('FromBaseType') | Should -BeFalse
            $result.Field.HasAttribute('Sealed') | Should -BeFalse
        }

        It 'keeps the column formatter by default' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })
            $result.Field.HasAttribute('CustomFormatter') | Should -BeTrue
        }

        It 'drops the column formatter on request' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml; DropCustomFormatter = $true })
            $result.Field.HasAttribute('CustomFormatter') | Should -BeFalse
        }
    }

    Context 'what it keeps' {

        It 'keeps the internal name, which is permanent and is what scripts address' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            $result.Field.Name | Should -Be 'Status'
            $result.Field.StaticName | Should -Be 'Status'
        }

        It 'keeps the choices and the default' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            @($result.Field.CHOICES.CHOICE) | Should -Be @('open', 'done')
            $result.Field.Default | Should -Be 'open'
        }

        It 'keeps Required' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })
            $result.Field.Required | Should -Be 'TRUE'
        }

        It 'keeps the rich-text settings of a note column' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:NoteXml })

            $result.Field.RichText | Should -Be 'TRUE'
            $result.Field.RichTextMode | Should -Be 'FullHtml'
        }
    }

    Context 'what it corrects' {

        It 'gives the copy a fresh ID' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            $result.Field.ID | Should -Not -Be '{9e8797b1-cdd1-4f5a-a8c3-b040c5992fef}'
            { [guid]::Parse($result.Field.ID) } | Should -Not -Throw
        }

        It 'gives two copies different IDs' {
            $first  = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })
            $second = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            $first.Field.ID | Should -Not -Be $second.Field.ID
        }

        It 'honours an explicit ID' {
            $id     = [guid]'11111111-2222-3333-4444-555555555555'
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml; Id = $id })

            $result.Field.ID | Should -Be '{11111111-2222-3333-4444-555555555555}'
        }

        It 'overwrites the stale Title from DisplayName' {
            # Renaming a column updates DisplayName and leaves Title behind, so
            # a straight copy carries a name the source has not used for years.
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml })

            $result.Field.Title | Should -Be 'Status'
            $result.Field.DisplayName | Should -Be 'Status'
        }

        It 'applies an explicit display name to both' {
            $result = [xml](& $script:Convert @{ SchemaXml = $script:ChoiceXml; DisplayName = 'Zustand' })

            $result.Field.Title | Should -Be 'Zustand'
            $result.Field.DisplayName | Should -Be 'Zustand'
        }
    }

    Context 'bad input' {

        It 'rejects XML that is not well-formed' {
            { & $script:Convert @{ SchemaXml = '<Field oops' } } |
                Should -Throw -ExpectedMessage '*well-formed*'
        }

        It 'rejects an element that is not a Field' {
            { & $script:Convert @{ SchemaXml = '<View Name="x" />' } } |
                Should -Throw -ExpectedMessage '*<Field>*'
        }
    }
}
