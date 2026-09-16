# Scans all 6 TxDOT FTP directories for 2026-09 proposals & plans
# Captures single-file PDFs as well as multi-volume plan sets (Vol.1, Vol.2, Part 1, Part 2, etc.)

$propDirs = @(
    'https://ftp.txdot.gov/plans/State-Let-Construction/2026/09%20September/09%20Proposals/',
    'https://ftp.txdot.gov/plans/State-Let-Maintenance/2026/09%20September/09%20Proposals/',
    'https://ftp.txdot.gov/plans/Local-Let-Maintenance/2026/09%20September/09%20Proposal/'
)

$planDirs = @(
    'https://ftp.txdot.gov/plans/State-Let-Construction/2026/09%20September/09%20Plans/',
    'https://ftp.txdot.gov/plans/State-Let-Maintenance/2026/09%20September/09%20Plans/',
    'https://ftp.txdot.gov/plans/Local-Let-Maintenance/2026/09%20September/09%20Plans/'
)

$map = @{}

foreach ($d in $propDirs) {
    Write-Host ("Scanning Proposal Directory: " + $d)
    $html = curl.exe -s $d
    $lines = $html -split "`n"
    foreach ($line in $lines) {
        if ($line -like "*href=*" -and $line -notlike "*Parent Directory*") {
            $idx1 = $line.IndexOf('href="')
            if ($idx1 -ge 0) {
                $sub = $line.Substring($idx1 + 6)
                $idx2 = $sub.IndexOf('"')
                if ($idx2 -gt 0) {
                    $rawHref = $sub.Substring(0, $idx2)
                    $decoded = [System.Uri]::UnescapeDataString($rawHref)
                    if ($decoded -match '\d{4}-\d{2}-\d{3}') {
                        $csj = $Matches[0]
                        if (-not $map[$csj]) { $map[$csj] = @{} }
                        $map[$csj].proposalUrl = $d + $rawHref
                        $map[$csj].proposalName = $decoded
                    }
                }
            }
        }
    }
}

foreach ($d in $planDirs) {
    Write-Host ("Scanning Plans Directory: " + $d)
    $html = curl.exe -s $d
    $lines = $html -split "`n"
    foreach ($line in $lines) {
        if ($line -like "*href=*" -and $line -notlike "*Parent Directory*") {
            $idx1 = $line.IndexOf('href="')
            if ($idx1 -ge 0) {
                $sub = $line.Substring($idx1 + 6)
                $idx2 = $sub.IndexOf('"')
                if ($idx2 -gt 0) {
                    $rawHref = $sub.Substring(0, $idx2)
                    $decoded = [System.Uri]::UnescapeDataString($rawHref)
                    if ($decoded -match '\d{4}-\d{2}-\d{3}') {
                        $csj = $Matches[0]
                        if (-not $map[$csj]) { $map[$csj] = @{} }
                        
                        if (-not $map[$csj].planVolumes) {
                            $map[$csj].planVolumes = @()
                        }
                        $map[$csj].planVolumes += @{
                            name = $decoded
                            url = $d + $rawHref
                        }

                        if (-not $map[$csj].planUrl) {
                            $map[$csj].planUrl = $d + $rawHref
                            $map[$csj].planName = $decoded
                        }
                    }
                }
            }
        }
    }
}

Write-Host ("Total unique CSJs mapped: " + $map.Count)

$destFolders = @(
    "C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web\downloads",
    "C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web\public\downloads",
    "C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web_V2\downloads",
    "C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web_V2\public\downloads",
    "C:\Users\fibrg\OneDrive\1 Desktop 2026\txdot_estimator_web_V3\downloads",
    "C:\Users\fibrg\OneDrive\1 Desktop 2026\txdot_estimator_web_V3\public\downloads"
)

$json = $map | ConvertTo-Json -Depth 5

foreach ($folder in $destFolders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    Set-Content -Path (Join-Path $folder "ftp_map_2026-09.json") -Value $json -Encoding UTF8
    Set-Content -Path (Join-Path $folder "ftp_proposals_map_2026-09.json") -Value $json -Encoding UTF8
}

Write-Host "Synchronized ftp_map_2026-09.json and ftp_proposals_map_2026-09.json to all 6 target directories!"
