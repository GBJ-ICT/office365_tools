<#
    Tests for Compare-SpoFolder.

    The case worth pinning down is the one that misleads: pointing the
    comparison at a folder that is not there produces exactly the same empty
    remote list as an upload where nothing arrived, and reporting that as
    "none of your files arrived" sends someone hunting for a problem that does
    not exist.

    PnP is not installed for these tests -- the stubs below stand in for it, so
    the comparison logic can be exercised without a tenant.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/Office365Tools/Office365Tools.psd1') -Force

    # Passed into InModuleScope explicitly: inside it, $PSScriptRoot is the
    # module's folder rather than this one.
    $script:StubPath = Join-Path $PSScriptRoot 'UploadCompare.Stubs.ps1'
}

AfterAll {
    Remove-Module Office365Tools -Force -ErrorAction SilentlyContinue
}

Describe 'Compare-SpoFolder' {

    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "o365tools-compare-$([guid]::NewGuid())"
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:TempDir 'notes.txt') -Value 'x' -NoNewline
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force
        }
    }

    It 'says the folder does not exist rather than reporting every file as missing' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath

            # A Teams site: the files are under General, which is the segment
            # people leave out when they read the path off the address bar.
            Mock Get-PnPListItem { New-StubItem -Folder 'General', 'General/Test' -File 'General/Test/notes.txt' }

            $message = ''
            try {
                Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test'
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match "no folder 'Test'"
            $message | Should -Match 'nothing to compare'
        }
    }

    It 'suggests the folder it found one level down' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -Folder 'General', 'General/Test' }

            $message = ''
            try {
                Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test'
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'General/Test'
        }
    }

    It 'lists the top-level folders when nothing resembles what was asked for' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -Folder 'Archiv', 'Vorlagen' }

            $message = ''
            try {
                Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test'
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Archiv'
            $message | Should -Match 'Vorlagen'
        }
    }

    It 'reports a real failed upload when the folder is there but empty' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -Folder 'Test' }

            $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test')

            $result.Count    | Should -Be 1
            $result[0].Status | Should -Be 'MissingRemote'
        }
    }

    It 'matches a file that did arrive' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' }

            $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test')

            $result.Count     | Should -Be 1
            $result[0].Status | Should -Be 'Match'
        }
    }

    It 'trusts files over the folder listing' {
        # Defensive: if a folder item ever fails to come back while its files
        # do, the files settle the question. Guessing "missing folder" there
        # would block a comparison that is perfectly valid.
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -File 'Test/notes.txt' }

            $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test')

            $result[0].Status | Should -Be 'Match'
        }
    }

    It 'compares against the library root without asking whether a folder exists' {
        InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
            param($TempDir, $StubPath)

            . $StubPath
            Mock Get-PnPListItem { New-StubItem -File 'notes.txt' }

            $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente')

            $result.Count     | Should -Be 1
            $result[0].Status | Should -Be 'Match'
        }
    }
}
