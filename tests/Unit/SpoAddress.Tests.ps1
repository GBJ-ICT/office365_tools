<#
    The address parser is what stands between someone pasting a browser URL and
    a check that runs against the wrong folder. It never contacts a tenant, so
    every case it will meet in the field can be pinned down here -- including
    the Teams channel folder, which is the one that has actually gone wrong.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-SpoAddress' {

    Context 'a modern library view' {

        It 'takes the folder out of id= rather than the visible path' {
            # Verbatim from a Teams-connected site: the breadcrumb says "Test",
            # the address says General/Test, and General is the whole problem.
            $address = 'https://contoso.sharepoint.com/sites/test_team/Freigegebene%20Dokumente/Forms/' +
            'AllItems.aspx?id=%2Fsites%2Ftest%5Fteam%2FFreigegebene%20Dokumente%2FGeneral%2FTest' +
            '&viewid=979041fd%2D5323%2D46d9%2Db490%2D022913808137'

            $result = ConvertFrom-SpoAddress $address

            $result.SiteUrl | Should -BeExactly 'https://contoso.sharepoint.com/sites/test_team'
            $result.Library | Should -BeExactly 'Freigegebene Dokumente'
            $result.RemoteFolder | Should -BeExactly 'General/Test'
            $result.FolderIsCertain | Should -BeTrue
        }

        It 'reads the library root as an empty folder, not as Forms/AllItems.aspx' {
            $result = ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx'

            $result.Library | Should -BeExactly 'Shared Documents'
            $result.RemoteFolder | Should -BeExactly ''
            # Nothing in that address states the folder, and a caller that
            # cares -- the checker offers the picker instead -- can tell.
            $result.FolderIsCertain | Should -BeFalse
        }

        It 'handles a nested folder with spaces and dots' {
            $address = 'https://contoso.sharepoint.com/sites/cds/Dokumente/Forms/AllItems.aspx' +
            '?id=%2Fsites%2Fcds%2FDokumente%2FProjekte%202026%2FQ1.final'

            $result = ConvertFrom-SpoAddress $address

            $result.RemoteFolder | Should -BeExactly 'Projekte 2026/Q1.final'
        }

        It 'accepts the classic view, which names the folder RootFolder' {
            $address = 'https://contoso.sharepoint.com/sites/team/Documents/Forms/AllItems.aspx' +
            '?RootFolder=%2Fsites%2Fteam%2FDocuments%2F2026&FolderCTID=0x0120'

            $result = ConvertFrom-SpoAddress $address

            $result.Library | Should -BeExactly 'Documents'
            $result.RemoteFolder | Should -BeExactly '2026'
        }
    }

    Context 'other shapes of address' {

        It 'accepts a plain folder path with no view page' {
            $result = ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team/Documents/2026/Q1'

            $result.SiteUrl | Should -BeExactly 'https://contoso.sharepoint.com/sites/team'
            $result.Library | Should -BeExactly 'Documents'
            $result.RemoteFolder | Should -BeExactly '2026/Q1'
        }

        It 'accepts a bare site address and reports no library' {
            $result = ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team/'

            $result.SiteUrl | Should -BeExactly 'https://contoso.sharepoint.com/sites/team'
            $result.Library | Should -BeNullOrEmpty
            $result.RemoteFolder | Should -BeExactly ''
        }

        It 'recognises a /teams/ site collection' {
            $result = ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/teams/finance/Documents/2026'

            $result.SiteUrl | Should -BeExactly 'https://contoso.sharepoint.com/teams/finance'
            $result.Library | Should -BeExactly 'Documents'
        }

        It 'recognises OneDrive, where the site is the personal path' {
            $address = 'https://contoso-my.sharepoint.com/personal/ada_contoso_com/_layouts/15/onedrive.aspx' +
            '?id=%2Fpersonal%2Fada%5Fcontoso%5Fcom%2FDocuments%2FUpload'

            $result = ConvertFrom-SpoAddress $address

            $result.SiteUrl | Should -BeExactly 'https://contoso-my.sharepoint.com/personal/ada_contoso_com'
            $result.Library | Should -BeExactly 'Documents'
            $result.RemoteFolder | Should -BeExactly 'Upload'
        }

        It 'treats a library on the root site as sitting directly under the host' {
            $result = ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/Shared%20Documents/2026'

            $result.SiteUrl | Should -BeExactly 'https://contoso.sharepoint.com'
            $result.Library | Should -BeExactly 'Shared Documents'
            $result.RemoteFolder | Should -BeExactly '2026'
        }

        It 'keeps the port and host of an on-premises address' {
            $result = ConvertFrom-SpoAddress 'http://sp2019:8080/sites/team/Documents/2026'

            $result.SiteUrl | Should -BeExactly 'http://sp2019:8080/sites/team'
            $result.Library | Should -BeExactly 'Documents'
        }
    }

    Context 'punctuation that comes along with a paste' {

        It 'survives <Description>' -ForEach @(
            @{ Description = 'surrounding quotes'; Text = '"https://contoso.sharepoint.com/sites/team/Documents/2026"' }
            @{ Description = 'mail-client angle brackets'; Text = '<https://contoso.sharepoint.com/sites/team/Documents/2026>' }
            @{ Description = 'surrounding whitespace'; Text = '   https://contoso.sharepoint.com/sites/team/Documents/2026   ' }
        ) {
            $result = ConvertFrom-SpoAddress $Text

            $result.Library | Should -BeExactly 'Documents'
            $result.RemoteFolder | Should -BeExactly '2026'
        }
    }

    Context 'addresses it must refuse' {

        It 'refuses a sharing link, which names no folder' {
            { ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/:f:/s/team/Ex4kQm9bTn1Aq' } |
                Should -Throw '*sharing link*'
        }

        It 'refuses a Teams deep link and says where to click instead' {
            { ConvertFrom-SpoAddress 'https://teams.microsoft.com/l/channel/19%3aabc%40thread.tacv2/General' } |
                Should -Throw '*Open in SharePoint*'
        }

        It 'refuses a SharePoint page that is not a library view' {
            { ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team/_layouts/15/settings.aspx' } |
                Should -Throw '*page rather than a folder*'
        }

        It 'refuses something that is not a web address at all' {
            { ConvertFrom-SpoAddress 'C:\Users\ada\Documents' } | Should -Throw '*not a web address*'
        }

        It 'refuses an empty address' {
            { ConvertFrom-SpoAddress '' } | Should -Throw
        }
    }

    Context 'shape of the result' {

        It 'reports the full server-relative path, for looking the library up after sign-in' {
            $address = 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx' +
            '?id=%2Fsites%2Fteam%2FShared%20Documents%2FGeneral%2FTest'

            (ConvertFrom-SpoAddress $address).ServerRelativePath |
                Should -BeExactly '/sites/team/Shared Documents/General/Test'
        }

        It 'reports the library root separately, which is what a path length check measures from' {
            $address = 'https://contoso.sharepoint.com/sites/team/Shared%20Documents/Forms/AllItems.aspx' +
            '?id=%2Fsites%2Fteam%2FShared%20Documents%2FGeneral%2FTest'

            (ConvertFrom-SpoAddress $address).LibraryPath |
                Should -BeExactly '/sites/team/Shared Documents'
        }

        It 'has no library path when the address names only a site' {
            (ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team').LibraryPath |
                Should -BeNullOrEmpty
        }

        It 'is typed, so a caller can tell an address from a string' {
            (ConvertFrom-SpoAddress 'https://contoso.sharepoint.com/sites/team').PSTypeNames |
                Should -Contain 'Office365Tools.Address'
        }

        It 'accepts the address from the pipeline' {
            $result = 'https://contoso.sharepoint.com/sites/team/Documents' | ConvertFrom-SpoAddress
            $result.Library | Should -BeExactly 'Documents'
        }
    }
}
