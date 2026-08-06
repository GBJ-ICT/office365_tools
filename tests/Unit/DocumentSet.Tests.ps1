<#
    Tests for the pure half of the Document Set logic.

    The CSOM types (TaxonomyFieldValue, FieldLookupValue, ...) cannot be
    constructed in a test, which is precisely why the comparison and conversion
    helpers probe properties through PSObject rather than by type: a
    pscustomobject with the same shape exercises the same code path a real
    SharePoint value does.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Test-SpoIsDocumentSetContentType' {

    It 'recognises the built-in Document Set content type' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId '0x0120D520' | Should -BeTrue
        }
    }

    It 'recognises a custom Document Set derived from it' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId '0x0120D520005DB65D094035A241BAC9AF083F825F3B' | Should -BeTrue
        }
    }

    It 'is case-insensitive, because content type IDs are written both ways' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId '0x0120d520005db65d' | Should -BeTrue
        }
    }

    It 'rejects a plain folder' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId '0x0120' | Should -BeFalse
        }
    }

    It 'rejects a document' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId '0x0101008A2B...' | Should -BeFalse
        }
    }

    It 'rejects null and empty' {
        InModuleScope Office365Tools {
            Test-SpoIsDocumentSetContentType -ContentTypeId $null | Should -BeFalse
            Test-SpoIsDocumentSetContentType -ContentTypeId '' | Should -BeFalse
        }
    }
}

Describe 'Get-SpoParentContentTypeId' {

    It 'strips the list copy suffix' {
        InModuleScope Office365Tools {
            $siteId = '0x0120D520005DB65D094035A241BAC9AF083F825F3B'
            $listId = $siteId + '00' + '0123456789ABCDEF0123456789ABCDEF'

            Get-SpoParentContentTypeId -ContentTypeId $listId | Should -Be $siteId
        }
    }

    It 'strips one level only, whatever kind of derivation it is' {
        InModuleScope Office365Tools {
            # A custom site Document Set is derived from the built-in one in
            # exactly the shape a list copy is derived from it, so the ID alone
            # cannot say which this was -- hence one level, and the caller
            # decides what to do with the answer.
            $siteId = '0x0120D520005DB65D094035A241BAC9AF083F825F3B'
            Get-SpoParentContentTypeId -ContentTypeId $siteId | Should -Be '0x0120D520'
        }
    }

    It 'leaves an ID with no derivation suffix alone' {
        InModuleScope Office365Tools {
            Get-SpoParentContentTypeId -ContentTypeId '0x0120D520' | Should -Be '0x0120D520'
            Get-SpoParentContentTypeId -ContentTypeId '0x0101' | Should -Be '0x0101'
        }
    }
}

Describe 'ConvertTo-SpoFieldValueKey' {

    It 'treats null, empty string and empty collection as no value' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueKey -Value $null | Should -Be ''
            ConvertTo-SpoFieldValueKey -Value '' | Should -Be ''
            ConvertTo-SpoFieldValueKey -Value @() | Should -Be ''
        }
    }

    It 'ignores surrounding whitespace' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueKey -Value '  Projekt A ' |
                Should -Be (ConvertTo-SpoFieldValueKey -Value 'Projekt A')
        }
    }

    It 'compares managed metadata by term GUID, not by label' {
        InModuleScope Office365Tools {
            # The same term after somebody renamed it in the term store.
            $before = [pscustomobject]@{ Label = 'Bau'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333'; WssId = 12 }
            $after  = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333'; WssId = 47 }

            ConvertTo-SpoFieldValueKey -Value $before |
                Should -Be (ConvertTo-SpoFieldValueKey -Value $after)
        }
    }

    It 'distinguishes different terms that share a label' {
        InModuleScope Office365Tools {
            $a = [pscustomobject]@{ Label = 'Planung'; TermGuid = '11111111-0000-4000-8000-000000000001' }
            $b = [pscustomobject]@{ Label = 'Planung'; TermGuid = '22222222-0000-4000-8000-000000000002' }

            ConvertTo-SpoFieldValueKey -Value $a |
                Should -Not -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'normalises GUID casing and braces' {
        InModuleScope Office365Tools {
            $a = [pscustomobject]@{ Label = 'x'; TermGuid = '{8F3D1C2A-0000-4000-8000-111122223333}' }
            $b = [pscustomobject]@{ Label = 'x'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' }

            ConvertTo-SpoFieldValueKey -Value $a |
                Should -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'compares lookup and person values by ID, not display name' {
        InModuleScope Office365Tools {
            $a = [pscustomobject]@{ LookupId = 17; LookupValue = 'Anna Schmidt' }
            $b = [pscustomobject]@{ LookupId = 17; LookupValue = 'Schmidt, Anna' }

            ConvertTo-SpoFieldValueKey -Value $a |
                Should -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'treats an unresolved lookup as no value' {
        InModuleScope Office365Tools {
            $unresolved = [pscustomobject]@{ LookupId = -1; LookupValue = '' }
            ConvertTo-SpoFieldValueKey -Value $unresolved | Should -Be ''
        }
    }

    It 'ignores the order of a multi-value column' {
        InModuleScope Office365Tools {
            $a = @('Bau', 'Planung', 'Abnahme')
            $b = @('Abnahme', 'Bau', 'Planung')

            ConvertTo-SpoFieldValueKey -Value $a |
                Should -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'still distinguishes multi-value columns with different contents' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueKey -Value @('Bau', 'Planung') |
                Should -Not -Be (ConvertTo-SpoFieldValueKey -Value @('Bau', 'Abnahme'))
        }
    }

    It 'handles a multi-value taxonomy collection' {
        InModuleScope Office365Tools {
            $a = @(
                [pscustomobject]@{ Label = 'Bau'; TermGuid = '11111111-0000-4000-8000-000000000001' }
                [pscustomobject]@{ Label = 'Planung'; TermGuid = '22222222-0000-4000-8000-000000000002' }
            )
            $b = @(
                [pscustomobject]@{ Label = 'Planung'; TermGuid = '22222222-0000-4000-8000-000000000002' }
                [pscustomobject]@{ Label = 'Bau'; TermGuid = '11111111-0000-4000-8000-000000000001' }
            )

            ConvertTo-SpoFieldValueKey -Value $a | Should -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'compares dates by instant, across time zones and sub-second noise' {
        InModuleScope Office365Tools {
            $utc   = [datetime]::new(2026, 3, 1, 12, 0, 0, [System.DateTimeKind]::Utc)
            $local = $utc.ToLocalTime()

            ConvertTo-SpoFieldValueKey -Value $utc | Should -Be (ConvertTo-SpoFieldValueKey -Value $local)
        }
    }

    It 'reports genuinely different dates as different' {
        InModuleScope Office365Tools {
            $a = [datetime]::new(2026, 3, 1, 12, 0, 0, [System.DateTimeKind]::Utc)
            $b = [datetime]::new(2026, 3, 2, 12, 0, 0, [System.DateTimeKind]::Utc)

            ConvertTo-SpoFieldValueKey -Value $a | Should -Not -Be (ConvertTo-SpoFieldValueKey -Value $b)
        }
    }

    It 'treats an integer and the same value as a double as equal' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueKey -Value 1 | Should -Be (ConvertTo-SpoFieldValueKey -Value 1.0)
        }
    }

    It 'formats numbers in the invariant culture' {
        InModuleScope Office365Tools {
            # A German locale would render this as '1,5' and make two identical
            # values compare as different.
            ConvertTo-SpoFieldValueKey -Value 1.5 | Should -Be '1.5'
        }
    }

    It 'compares booleans' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueKey -Value $true | Should -Be 'True'
            ConvertTo-SpoFieldValueKey -Value $true | Should -Not -Be (ConvertTo-SpoFieldValueKey -Value $false)
        }
    }

    It 'compares hyperlink values by URL and description' {
        InModuleScope Office365Tools {
            $a = [pscustomobject]@{ Url = 'https://example.org/a'; Description = 'A' }
            $b = [pscustomobject]@{ Url = 'https://example.org/a'; Description = 'A' }
            $c = [pscustomobject]@{ Url = 'https://example.org/b'; Description = 'A' }

            ConvertTo-SpoFieldValueKey -Value $a | Should -Be (ConvertTo-SpoFieldValueKey -Value $b)
            ConvertTo-SpoFieldValueKey -Value $a | Should -Not -Be (ConvertTo-SpoFieldValueKey -Value $c)
        }
    }
}

Describe 'ConvertTo-SpoFieldValueText' {

    It 'renders a term as its label' {
        InModuleScope Office365Tools {
            $value = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' }
            ConvertTo-SpoFieldValueText -Value $value | Should -Be 'Bauwesen'
        }
    }

    It 'renders a person as their display name' {
        InModuleScope Office365Tools {
            $value = [pscustomobject]@{ LookupId = 17; LookupValue = 'Anna Schmidt' }
            ConvertTo-SpoFieldValueText -Value $value | Should -Be 'Anna Schmidt'
        }
    }

    It 'joins a multi-value column' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueText -Value @('Bau', 'Planung') | Should -Be 'Bau; Planung'
        }
    }

    It 'returns an empty string for no value' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldValueText -Value $null | Should -Be ''
        }
    }
}

Describe 'ConvertTo-SpoFieldUpdateValue' {

    It 'converts a term to the Label|Guid form Set-PnPListItem expects' {
        InModuleScope Office365Tools {
            $value = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' }
            ConvertTo-SpoFieldUpdateValue -Value $value | Should -Be 'Bauwesen|8f3d1c2a-0000-4000-8000-111122223333'
        }
    }

    It 'converts a multi-value taxonomy column to an array of them' {
        InModuleScope Office365Tools {
            $value = @(
                [pscustomobject]@{ Label = 'Bau'; TermGuid = '11111111-0000-4000-8000-000000000001' }
                [pscustomobject]@{ Label = 'Planung'; TermGuid = '22222222-0000-4000-8000-000000000002' }
            )

            $result = ConvertTo-SpoFieldUpdateValue -Value $value

            @($result).Count | Should -Be 2
            $result[0] | Should -Be 'Bau|11111111-0000-4000-8000-000000000001'
        }
    }

    It 'converts a person to their e-mail, not their ID' {
        InModuleScope Office365Tools {
            # Set-PnPListItem resolves user fields with EnsureUser, so a
            # numeric ID comes back as "the specified user was not found".
            $value = [pscustomobject]@{ LookupId = 17; LookupValue = 'Anna Schmidt'; Email = 'anna@example.org' }
            ConvertTo-SpoFieldUpdateValue -Value $value | Should -Be 'anna@example.org'
        }
    }

    It 'falls back to the display name for a group with no mailbox' {
        InModuleScope Office365Tools {
            $value = [pscustomobject]@{ LookupId = 28; LookupValue = 'Mitglieder von Vorstand'; Email = '' }
            ConvertTo-SpoFieldUpdateValue -Value $value | Should -Be 'Mitglieder von Vorstand'
        }
    }

    It 'converts a multi-value person column to an array of logins' {
        InModuleScope Office365Tools {
            $value = @(
                [pscustomobject]@{ LookupId = 17; LookupValue = 'Anna'; Email = 'anna@example.org' }
                [pscustomobject]@{ LookupId = 18; LookupValue = 'Bob'; Email = 'bob@example.org' }
            )

            $result = ConvertTo-SpoFieldUpdateValue -Value $value
            @($result).Count | Should -Be 2
            $result[0] | Should -Be 'anna@example.org'
        }
    }

    It 'still converts a plain lookup to its numeric ID' {
        InModuleScope Office365Tools {
            # No Email property: a lookup to another list, where the ID is
            # exactly what Set-PnPListItem wants.
            $value = [pscustomobject]@{ LookupId = 42; LookupValue = 'Projekt Alpha' }
            ConvertTo-SpoFieldUpdateValue -Value $value | Should -Be 42
        }
    }

    It 'converts a hyperlink to the url, description form' {
        InModuleScope Office365Tools {
            $value = [pscustomobject]@{ Url = 'https://example.org/a'; Description = 'Plan' }
            ConvertTo-SpoFieldUpdateValue -Value $value | Should -Be 'https://example.org/a, Plan'
        }
    }

    It 'passes plain values through unchanged' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldUpdateValue -Value 'Freigegeben' | Should -Be 'Freigegeben'
            ConvertTo-SpoFieldUpdateValue -Value 42 | Should -Be 42
            ConvertTo-SpoFieldUpdateValue -Value $true | Should -Be $true
        }
    }

    It 'returns null for an empty value, which clears the column' {
        InModuleScope Office365Tools {
            ConvertTo-SpoFieldUpdateValue -Value $null | Should -BeNullOrEmpty
            ConvertTo-SpoFieldUpdateValue -Value '   ' | Should -BeNullOrEmpty
            ConvertTo-SpoFieldUpdateValue -Value @() | Should -BeNullOrEmpty
        }
    }

    It 'round-trips: a converted value keys the same as the original' {
        InModuleScope Office365Tools {
            # What the repair writes must compare equal on the next scan,
            # otherwise the same item is reported as drifted for ever.
            $source = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' }

            $written = ConvertTo-SpoFieldUpdateValue -Value $source
            $reread  = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = ($written -split '\|')[1] }

            ConvertTo-SpoFieldValueKey -Value $reread |
                Should -Be (ConvertTo-SpoFieldValueKey -Value $source)
        }
    }
}

Describe 'Compare-SpoDocumentSetValue' {

    It 'reports nothing when the item already carries the same values' {
        InModuleScope Office365Tools {
            $source = @{ Status = 'Freigegeben'; Jahr = 2026 }
            $target = @{ Status = 'Freigegeben'; Jahr = 2026 }

            @(Compare-SpoDocumentSetValue -Column @('Status', 'Jahr') `
                    -DocumentSetValue $source -ItemValue $target).Count | Should -Be 0
        }
    }

    It 'calls an unset item column EmptyOnItem -- the ordinary never-pushed case' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = 'Freigegeben' } -ItemValue @{ Status = $null })

            $result.Count            | Should -Be 1
            $result[0].Reason        | Should -Be 'EmptyOnItem'
            $result[0].DocumentSetValue | Should -Be 'Freigegeben'
            $result[0].ItemValue     | Should -Be ''
        }
    }

    It 'treats a column absent from the item entirely as EmptyOnItem' {
        InModuleScope Office365Tools {
            # A folder inside a Document Set has no value for a column that
            # only the document content type carries.
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = 'Freigegeben' } -ItemValue @{})

            $result[0].Reason | Should -Be 'EmptyOnItem'
        }
    }

    It 'calls two disagreeing values ValueDiffers' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = 'Freigegeben' } -ItemValue @{ Status = 'Entwurf' })

            $result[0].Reason    | Should -Be 'ValueDiffers'
            $result[0].ItemValue | Should -Be 'Entwurf'
        }
    }

    It 'calls a value the Document Set lacks EmptyOnDocumentSet' {
        InModuleScope Office365Tools {
            # The repair must not push this: it would delete the only copy.
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = '' } -ItemValue @{ Status = 'Entwurf' })

            $result[0].Reason | Should -Be 'EmptyOnDocumentSet'
        }
    }

    It 'calls a column that is not on the library ColumnMissingFromLibrary' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = 'Freigegeben' } -ItemValue @{} `
                    -AvailableColumn @('Jahr'))

            $result[0].Reason | Should -Be 'ColumnMissingFromLibrary'
        }
    }

    It 'treats every column as available when no list is given' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status') `
                    -DocumentSetValue @{ Status = 'Freigegeben' } -ItemValue @{} `
                    -AvailableColumn $null)

            $result[0].Reason | Should -Be 'EmptyOnItem'
        }
    }

    It 'does not report a renamed term as a difference' {
        InModuleScope Office365Tools {
            $source = @{ Bereich = [pscustomobject]@{ Label = 'Bauwesen'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' } }
            $target = @{ Bereich = [pscustomobject]@{ Label = 'Bau'; TermGuid = '8f3d1c2a-0000-4000-8000-111122223333' } }

            @(Compare-SpoDocumentSetValue -Column @('Bereich') `
                    -DocumentSetValue $source -ItemValue $target).Count | Should -Be 0
        }
    }

    It 'does not report a reordered multi-value column as a difference' {
        InModuleScope Office365Tools {
            $source = @{ Phasen = @('Bau', 'Planung') }
            $target = @{ Phasen = @('Planung', 'Bau') }

            @(Compare-SpoDocumentSetValue -Column @('Phasen') `
                    -DocumentSetValue $source -ItemValue $target).Count | Should -Be 0
        }
    }

    It 'reports each differing column separately' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status', 'Jahr', 'Bereich') `
                    -DocumentSetValue @{ Status = 'Freigegeben'; Jahr = 2026; Bereich = 'Bau' } `
                    -ItemValue @{ Status = 'Freigegeben'; Jahr = 2025; Bereich = $null })

            $result.Count                   | Should -Be 2
            @($result | ForEach-Object { $_.Field }) | Should -Be @('Jahr', 'Bereich')
        }
    }

    It 'marks whether SharePoint was ever supposed to sync the column' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('Status', 'Notiz') `
                    -DocumentSetValue @{ Status = 'A'; Notiz = 'B' } -ItemValue @{} `
                    -SharedColumn @('Status'))

            ($result | Where-Object Field -eq 'Status').IsShared | Should -BeTrue
            ($result | Where-Object Field -eq 'Notiz').IsShared | Should -BeFalse
        }
    }

    It 'uses the display name when one is supplied' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('ProjectStatus') `
                    -DocumentSetValue @{ ProjectStatus = 'A' } -ItemValue @{} `
                    -DisplayName @{ ProjectStatus = 'Projektstatus' })

            $result[0].DisplayName | Should -Be 'Projektstatus'
        }
    }

    It 'falls back to the internal name when no display name is known' {
        InModuleScope Office365Tools {
            $result = @(Compare-SpoDocumentSetValue -Column @('ProjectStatus') `
                    -DocumentSetValue @{ ProjectStatus = 'A' } -ItemValue @{})

            $result[0].DisplayName | Should -Be 'ProjectStatus'
        }
    }
}

Describe 'Test-SpoSyncableColumn' {

    It 'accepts an ordinary custom column' {
        InModuleScope Office365Tools {
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = 'ProjectStatus' }) | Should -BeTrue
        }
    }

    It 'rejects read-only and hidden columns' {
        InModuleScope Office365Tools {
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = 'X'; ReadOnly = $true }) | Should -BeFalse
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = 'X'; Hidden = $true }) | Should -BeFalse
        }
    }

    It 'rejects identity columns that must not be copied downwards' {
        InModuleScope Office365Tools {
            foreach ($name in 'Title', 'Name', 'FileLeafRef', 'Created', 'Author', 'ContentType') {
                Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = $name }) |
                    Should -BeFalse -Because "$name identifies the item, not its metadata"
            }
        }
    }

    It 'rejects SharePoint plumbing columns' {
        InModuleScope Office365Tools {
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = '_ComplianceTag' }) | Should -BeFalse
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ InternalName = 'TaxCatchAll' }) | Should -BeFalse
        }
    }

    It 'rejects null and shapeless input' {
        InModuleScope Office365Tools {
            Test-SpoSyncableColumn -Field $null | Should -BeFalse
            Test-SpoSyncableColumn -Field ([pscustomobject]@{ Something = 'else' }) | Should -BeFalse
        }
    }
}
