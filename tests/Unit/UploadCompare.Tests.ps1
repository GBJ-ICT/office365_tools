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

    Context 'options a synchronisation tool offers' {

        BeforeEach {
            # notes.txt is one byte; give it a known date and a sibling one
            # level down, so both options have something to act on.
            $script:Stamp = [datetime]::new(2026, 3, 1, 12, 0, 0, [System.DateTimeKind]::Utc)
            (Get-Item -LiteralPath (Join-Path $script:TempDir 'notes.txt')).LastWriteTimeUtc = $script:Stamp

            $sub = New-Item -Path (Join-Path $script:TempDir 'Sub') -ItemType Directory -Force
            Set-Content -LiteralPath (Join-Path $sub.FullName 'deep.txt') -Value 'x' -NoNewline
        }

        It 'reports both kinds of missing file in one pass' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                Mock Get-PnPListItem { New-StubItem -Folder 'Test', 'Test/Sub' -File 'Test/notes.txt', 'Test/only-here.txt' }

                $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test')
                $byPath = @{}
                $result | ForEach-Object { $byPath[$_.RelativePath] = $_.Status }

                $byPath['notes.txt']      | Should -Be 'Match'
                $byPath['Sub/deep.txt']   | Should -Be 'MissingRemote'
                $byPath['only-here.txt']  | Should -Be 'MissingLocal'
            }
        }

        It 'leaves subfolders out on both sides with -TopLevelOnly' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                Mock Get-PnPListItem { New-StubItem -Folder 'Test', 'Test/Other' -File 'Test/notes.txt', 'Test/Other/remote-deep.txt' }

                $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly)

                $result.RelativePath | Should -Be @('notes.txt')
                $result[0].Status    | Should -Be 'Match'
            }
        }

        It 'ignores dates unless asked to compare them' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' -Modified ([datetime]'2026-09-01 08:00') }

                $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly)

                $result[0].Status | Should -Be 'Match'
            }
        }

        It 'says which side is newer with -CompareDate' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath

                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' -Modified ([datetime]'2026-09-01 08:00') }
                $later = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareDate)

                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' -Modified ([datetime]'2025-01-01 08:00') }
                $earlier = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareDate)

                $later[0].Status   | Should -Be 'RemoteNewer'
                $earlier[0].Status | Should -Be 'LocalNewer'
            }
        }

        It 'reads an unmarked SharePoint date as UTC, so equal times match in any time zone' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                # 12:00:01 UTC against a local file stamped 12:00:00 UTC: inside
                # the default two-second tolerance.
                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' -Modified ([datetime]'2026-03-01 12:00:01') }

                $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareDate)

                $result[0].Status         | Should -Be 'Match'
                $result[0].RemoteModified.Kind | Should -Be 'Utc'
            }
        }

        It 'lets a date difference win over a size difference' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' -Size 99 -Modified ([datetime]'2026-09-01 08:00') }

                $both = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareDate -CompareSize)
                $sizeOnly = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareSize)

                $both[0].Status     | Should -Be 'RemoteNewer'
                $sizeOnly[0].Status | Should -Be 'SizeDiffers'
            }
        }

        It 'treats a file with no SharePoint date as not comparable by date' {
            InModuleScope Office365Tools -Parameters @{ TempDir = $script:TempDir; StubPath = $script:StubPath } {
                param($TempDir, $StubPath)

                . $StubPath
                Mock Get-PnPListItem { New-StubItem -Folder 'Test' -File 'Test/notes.txt' }

                $result = @(Compare-SpoFolder -LocalPath $TempDir -Library 'Dokumente' -RemoteFolder 'Test' -TopLevelOnly -CompareDate)

                $result[0].Status | Should -Be 'Match'
            }
        }
    }
}
