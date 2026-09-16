# Map all TxDOT Proposal PDFs across all 3 directories (State Construction, State Maintenance, Local Maintenance)
$dirs = @(
    'https://ftp.txdot.gov/plans/State-Let-Construction/2026/09%20September/09%20Proposals/',
    'https://ftp.txdot.gov/plans/State-Let-Maintenance/2026/09%20September/09%20Proposals/',
    'https://ftp.txdot.gov/plans/Local-Let-Maintenance/2026/09%20September/09%20Proposal/'
)

$proposalMap = @{}

foreach ($d in $dirs) {
    Write-Host ("Fetching: " + $d)
    $html = curl.exe -s $d
    $lines = $html -split "`n"
    foreach ($line in $lines) {
        if ($line -like "*Proposal.pdf*") {
            $idx1 = $line.IndexOf('href="')
            if ($idx1 -ge 0) {
                $sub = $line.Substring($idx1 + 6)
                $idx2 = $sub.IndexOf('"')
                if ($idx2 -gt 0) {
                    $rawHref = $sub.Substring(0, $idx2)
                    $decoded = [System.Uri]::UnescapeDataString($rawHref)
                    if ($decoded -match '\d{4}-\d{2}-\d{3}') {
                        $csj = $Matches[0]
                        $fullUrl = $d + $rawHref
                        $proposalMap[$csj] = @{
                            proposalUrl = $fullUrl
                            proposalName = $decoded
                        }
                    }
                }
            }
        }
    }
}

Write-Host ("Total Unique CSJ Proposals Mapped: " + $proposalMap.Count)

$outPath = 'C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web\downloads\ftp_proposals_map_2026-09.json'
$json = $proposalMap | ConvertTo-Json -Depth 3
Set-Content -Path $outPath -Value $json -Encoding UTF8
Write-Host "Saved ftp_proposals_map_2026-09.json successfully!"
