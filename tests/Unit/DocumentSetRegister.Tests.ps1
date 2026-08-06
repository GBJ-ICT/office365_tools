<#
    Tests for the pure half of the Document Set register logic: the shape of
    the reference URL, and the key that decides whether the register already
    has a row for a Document Set.

    Both are plain string handling, deliberately, so the part of the feature
    most likely to be wrong is the part testable without a tenant.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'New-SpoDocumentSetReference' {

    It 'builds the library view URL with the folder as the id parameter' {
        InModuleScope Office365Tools {
            New-SpoDocumentSetReference `
                -SiteUrl 'https://contoso.sharepoint.com/sites/cds' `
                -ViewUrl '/sites/cds/Management/Forms/AllItems.aspx' `
                -ServerRelativeUrl '/sites/cds/Management/Budget' |
                Should -Be 'https://contoso.sharepoint.com/sites/cds/Management/Forms/AllItems.aspx?id=%2Fsites%2Fcds%2FManagement%2FBudget'
        }
    }

    It 'encodes spaces, parentheses and non-ASCII the way SharePoint does' {
        # SharePoint round-trips these three encoded. A folder named
        # "AVOR (Teil 6)" or "ÄB" is ordinary here, not an edge case.
        InModuleScope Office365Tools {
            New-SpoDocumentSetReference `
                -SiteUrl 'https://contoso.sharepoint.com/sites/cds' `
                -ViewUrl '/sites/CDS/Management/Forms/Alle.aspx' `
                -ServerRelativeUrl '/sites/CDS/Management/ÄB (HG 4425)' |
                Should -Be 'https://contoso.sharepoint.com/sites/CDS/Management/Forms/Alle.aspx?id=%2Fsites%2FCDS%2FManagement%2F%C3%84B%20%28HG%204425%29'
        }
    }

    It 'takes only scheme and host from the site URL, not its path' {
        # The view URL is already server-relative from the site collection
        # root; appending it to the full site URL would double the path.
        InModuleScope Office365Tools {
            New-SpoDocumentSetReference `
                -SiteUrl 'https://contoso.sharepoint.com/sites/cds/subweb/' `
                -ViewUrl '/sites/cds/Lib/Forms/AllItems.aspx' `
                -ServerRelativeUrl '/sites/cds/Lib/A' |
                Should -BeLike 'https://contoso.sharepoint.com/sites/cds/Lib/Forms/AllItems.aspx?id=*'
        }
    }

    It 'accepts an absolute view URL unchanged' {
        InModuleScope Office365Tools {
            New-SpoDocumentSetReference `
                -SiteUrl 'https://contoso.sharepoint.com/sites/cds' `
                -ViewUrl 'https://other.sharepoint.com/sites/x/Lib/Forms/AllItems.aspx' `
                -ServerRelativeUrl '/sites/x/Lib/A' |
                Should -Be 'https://other.sharepoint.com/sites/x/Lib/Forms/AllItems.aspx?id=%2Fsites%2Fx%2FLib%2FA'
        }
    }

    It 'does not care whether the view URL has a leading slash' {
        InModuleScope Office365Tools {
            $withSlash = New-SpoDocumentSetReference -SiteUrl 'https://c.sharepoint.com/sites/s' `
                -ViewUrl '/sites/s/Lib/Forms/AllItems.aspx' -ServerRelativeUrl '/sites/s/Lib/A'
            $without = New-SpoDocumentSetReference -SiteUrl 'https://c.sharepoint.com/sites/s' `
                -ViewUrl 'sites/s/Lib/Forms/AllItems.aspx' -ServerRelativeUrl '/sites/s/Lib/A'

            $without | Should -Be $withSlash
        }
    }
}

Describe 'ConvertTo-SpoRegisterKey' {

    It 'keys a Document ID hyperlink on the ID in its URL' {
        InModuleScope Office365Tools {
            $link = [pscustomobject]@{
                Url         = 'https://c.sharepoint.com/sites/s/_layouts/15/DocIdRedir.aspx?ID=GBJCDS-204499463-31'
                Description = 'GBJCDS-204499463-31'
            }

            ConvertTo-SpoRegisterKey -Value $link | Should -Be 'gbjcds-204499463-31'
        }
    }

    It 'keys a Document ID hyperlink the same way after its text has been relabelled' {
        # The one that matters. A register that shows a friendly label instead
        # of the raw ID must still match its Document Sets -- otherwise every
        # row looks unregistered and the next sync duplicates the lot.
        InModuleScope Office365Tools {
            $raw = [pscustomobject]@{
                Url         = 'https://c.sharepoint.com/sites/s/_layouts/15/DocIdRedir.aspx?ID=GBJCDS-204499463-31'
                Description = 'GBJCDS-204499463-31'
            }
            $labelled = [pscustomobject]@{
                Url         = 'https://c.sharepoint.com/sites/s/_layouts/15/DocIdRedir.aspx?ID=GBJCDS-204499463-31'
                Description = 'HG4425-AEB (HG 4425)'
            }

            ConvertTo-SpoRegisterKey -Value $labelled |
                Should -Be (ConvertTo-SpoRegisterKey -Value $raw)
        }
    }

    It 'matches a Document ID hyperlink against the plain string a Document Set carries' {
        # This is the whole point: the register holds a URL value, the source
        # holds _dlc_DocId as a string, and the two have to meet.
        InModuleScope Office365Tools {
            $link = [pscustomobject]@{ Url = 'https://x/DocIdRedir.aspx?ID=A-1'; Description = 'anything at all' }

            ConvertTo-SpoRegisterKey -Value $link |
                Should -Be (ConvertTo-SpoRegisterKey -Value 'A-1')
        }
    }

    It 'reads the ID even when it is not the first query parameter' {
        InModuleScope Office365Tools {
            $link = [pscustomobject]@{ Url = 'https://x/_layouts/15/DocIdRedir.aspx?source=x&ID=A-1'; Description = '' }

            ConvertTo-SpoRegisterKey -Value $link | Should -Be 'a-1'
        }
    }

    It 'does not mistake a reference link''s folder path for a Document ID' {
        # A back-link carries an 'id=' too -- the folder it points at. Keying on
        # that would quietly replace the URL key with half of itself.
        InModuleScope Office365Tools {
            $link = [pscustomobject]@{
                Url         = 'https://c.sharepoint.com/sites/s/Lib/Forms/AllItems.aspx?id=%2Fsites%2Fs%2FLib%2FA'
                Description = 'A'
            }

            ConvertTo-SpoRegisterKey -Value $link | Should -Be 'a'
        }
    }

    It 'falls back to the URL when the hyperlink has no description' {
        InModuleScope Office365Tools {
            $link = [pscustomobject]@{ Url = 'https://c.sharepoint.com/sites/s/Lib/Forms/AllItems.aspx?id=%2Fa'; Description = '' }

            ConvertTo-SpoRegisterKey -Value $link |
                Should -Be 'https://c.sharepoint.com/sites/s/lib/forms/allitems.aspx?id=%2fa'
        }
    }

    It 'is case-insensitive, because SharePoint rewrites URL casing' {
        InModuleScope Office365Tools {
            ConvertTo-SpoRegisterKey -Value '/Sites/CDS/Management' |
                Should -Be (ConvertTo-SpoRegisterKey -Value '/sites/cds/management')
        }
    }

    It 'returns empty for values that cannot identify anything' {
        InModuleScope Office365Tools {
            ConvertTo-SpoRegisterKey -Value $null | Should -Be ''
            ConvertTo-SpoRegisterKey -Value '' | Should -Be ''
            ConvertTo-SpoRegisterKey -Value ([pscustomobject]@{ Url = ''; Description = '' }) | Should -Be ''
        }
    }

    It 'keys a plain text column on its trimmed value' {
        InModuleScope Office365Tools {
            ConvertTo-SpoRegisterKey -Value '  Budget 2026  ' | Should -Be 'budget 2026'
        }
    }
}

Describe 'Get-SpoRegisterEntryAction' {

    It 'says Create when the register has no row' {
        InModuleScope Office365Tools {
            $verdict = Get-SpoRegisterEntryAction -Current $null -ContentType 'Project Entry' `
                -ReferenceField 'Link' -Reference 'https://x/Lib/Forms/AllItems.aspx?id=%2FLib%2FA'

            $verdict.Action | Should -Be 'Create'
            $verdict.Difference | Should -BeNullOrEmpty
        }
    }

    It 'says Current when the row is filed and linked correctly' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = 'Project Entry'; Reference = 'https://x/A' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'Project Entry' -ReferenceField 'Link' -Reference 'https://x/A'
            $verdict.Action | Should -Be 'Current'
        }
    }

    It 'says Update on both counts when the Document Set has moved library' {
        # The whole reason Update exists: the Document ID matched, so the row is
        # the right row -- but it is filed under the library it used to be in,
        # and its link still points there.
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{
                ContentType = 'Project Entry'
                Reference   = 'https://x/Projekte/Forms/AllItems.aspx?id=%2FProjekte%2FA'
            }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'Management Entry' `
                -ReferenceField 'Link' -Reference 'https://x/Management/Forms/AllItems.aspx?id=%2FManagement%2FA'

            $verdict.Action | Should -Be 'Update'
            $verdict.Difference | Should -Contain 'ContentType'
            $verdict.Difference | Should -Contain 'Link'
        }
    }

    It 'reports the reference alone when only the folder moved within a library' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = 'Project Entry'; Reference = 'https://x/old' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'Project Entry' `
                -ReferenceField 'Link' -Reference 'https://x/new'

            $verdict.Action | Should -Be 'Update'
            @($verdict.Difference) | Should -Be @('Link')
        }
    }

    It 'does not reclassify a row when the library was never mapped' {
        # No -ContentTypeMap entry means no opinion about where the row belongs,
        # which is different from an opinion that it belongs nowhere.
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = 'Project Entry'; Reference = 'https://x/A' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType '' -ReferenceField 'Link' -Reference 'https://x/A'
            $verdict.Action | Should -Be 'Current'
        }
    }

    It 'does not reclassify a row whose current content type could not be read' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = ''; Reference = 'https://x/A' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'Project Entry' -ReferenceField 'Link' -Reference 'https://x/A'
            $verdict.Action | Should -Be 'Current'
        }
    }

    It 'ignores the reference when the register has no reference column' {
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = 'Project Entry'; Reference = '' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'Project Entry' -ReferenceField '' -Reference 'https://x/A'
            $verdict.Action | Should -Be 'Current'
        }
    }

    It 'treats a reference that differs only in casing as unchanged' {
        # SharePoint rewrites URL casing on its own; reporting that as drift
        # would rewrite every row on every run.
        InModuleScope Office365Tools {
            $row = [pscustomobject]@{ ContentType = 'X'; Reference = 'https://x/Lib/Forms/AllItems.aspx?id=%2FLib%2FA' }

            $verdict = Get-SpoRegisterEntryAction -Current $row -ContentType 'X' -ReferenceField 'Link' -Reference 'https://x/lib/forms/allitems.aspx?id=%2flib%2fa'
            $verdict.Action | Should -Be 'Current'
        }
    }
}

Describe 'Get-SpoDocumentSetRegisterEntry' {

    It 'takes a content type per library, because the two names cannot be derived from each other' {
        (Get-Command Get-SpoDocumentSetRegisterEntry).Parameters.Keys | Should -Contain 'ContentTypeMap'
    }

    It 'has no List or Library property on its output, so it cannot bind Add-SpoListItem' {
        # Add-SpoListItem aliases -Library to 'List'. Either name on the output
        # object would bind on the pipeline and write the entries back into the
        # library they were read from.
        $help = Get-Help Get-SpoDocumentSetRegisterEntry -Full
        $help.returnValues | Out-String | Should -Match 'SourceList'
    }

    It 'is read-only and therefore takes no WhatIf' {
        (Get-Command Get-SpoDocumentSetRegisterEntry).Parameters.Keys | Should -Not -Contain 'WhatIf'
    }
}

Describe 'Update-SpoListItem' {

    It 'can reclassify an item, so a row can follow its Document Set to another library' {
        (Get-Command Update-SpoListItem).Parameters.Keys | Should -Contain 'ContentType'
    }

    It 'no longer demands -Values, because a reclassification changes no field' {
        (Get-Command Update-SpoListItem).Parameters['Values'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.Mandatory } |
            Should -Not -Contain $true
    }

    It 'binds ContentType from the pipeline, so register entries carry their own' {
        (Get-Command Update-SpoListItem).Parameters['ContentType'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.ValueFromPipelineByPropertyName } |
            Should -Contain $true
    }
}

Describe 'Update-SpoListItemLinkText' {

    It 'supports ShouldProcess because it writes' {
        $command = (Get-Command Update-SpoListItemLinkText).Parameters.Keys
        $command | Should -Contain 'WhatIf'
        $command | Should -Contain 'Confirm'
    }

    It 'does not bind Library from the pipeline' {
        # Items come down the pipeline; a Library property arriving mid-stream
        # would silently change which list is written to.
        (Get-Command Update-SpoListItemLinkText).Parameters['Library'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.ValueFromPipelineByPropertyName } |
            Should -Not -Contain $true
    }
}
