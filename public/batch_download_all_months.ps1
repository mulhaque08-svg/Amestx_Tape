param (
    [string[]]$Months = @("2026-06", "2026-07", "2026-08", "2026-09", "2026-10", "2026-11", "2026-12")
)

$scriptDir = $PSScriptRoot

foreach ($m in $Months) {
    Write-Host "=========================================================="
    Write-Host "Processing Month: $m"
    Write-Host "=========================================================="
    
    $scanScript = Join-Path $scriptDir "scan_ftp_pdfs.ps1"
    if (Test-Path $scanScript) {
        & $scanScript -Month $m
    }
}

Write-Host "Enriching all FTP maps with CCSJ lookup data..."
$enrichScript = Join-Path $scriptDir "enrich_ftp_maps.ps1"
if (Test-Path $enrichScript) {
    & $enrichScript
}

foreach ($m in $Months) {
    Write-Host "=========================================================="
    Write-Host "Downloading Local PDFs for Month: $m"
    Write-Host "=========================================================="
    
    $dlScript = Join-Path $scriptDir "download_monthly_pdfs.ps1"
    if (Test-Path $dlScript) {
        & $dlScript -Month $m
    }
}

Write-Host "=========================================================="
Write-Host "ALL MONTHS SCANNED, ENRICHED, AND DOWNLOADED SUCCESSFULLY!"
Write-Host "=========================================================="
