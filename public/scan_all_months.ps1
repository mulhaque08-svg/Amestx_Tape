param (
    [string]$Year = "2026"
)

$scriptDir = $PSScriptRoot
$scanScript = Join-Path $scriptDir "scan_ftp_pdfs.ps1"

1..12 | ForEach-Object {
    $mStr = "{0:D2}" -f $_
    $monthKey = "$Year-$mStr"
    Write-Host ">>> Scanning TxDOT FTP for $monthKey..."
    & $scanScript -Month $monthKey
}
Write-Host "All 12 months for $Year scanned and indexed successfully!"
