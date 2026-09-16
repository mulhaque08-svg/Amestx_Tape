param (
    [string]$Month = "2026-09"
)

$pair = 'planuser:txdotplans'
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$headers = @{ Authorization = 'Basic ' + $base64 }

$year = $Month.Substring(0,4)
$mNum = $Month.Substring(5,2)
$monthNames = @("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
$mIdx = [int]$mNum - 1
$monthName = $monthNames[$mIdx]
$monthFolder = "$mNum $monthName"
$encodedMonth = [Uri]::EscapeDataString($monthFolder)

$categories = @('State-Let-Construction', 'State-Let-Maintenance', 'Local-Let-Maintenance')

Write-Host "Scanning TxDOT FTP for $monthFolder ($year)..."

$pdfMap = @{}

foreach ($cat in $categories) {
    foreach ($sub in @("$mNum Plans", "$mNum Proposals")) {
        $encodedSub = [Uri]::EscapeDataString($sub)
        $url = "https://ftp.txdot.gov/plans/$cat/$year/$encodedMonth/$encodedSub/"
        try {
            $r = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 5
            $lines = $r.Content -split "`n"
            foreach ($line in $lines) {
                if ($line -match 'href="([^"]+\.pdf)"') {
                    $pdfName = [Uri]::UnescapeDataString($matches[1])
                    if ($pdfName -match '(\d{4}-\d{2}-\d{3})') {
                        $csjFound = $matches[1]
                        $fullFileUrl = "$url$([Uri]::EscapeDataString($pdfName))"
                        $isProp = $sub -like "*Proposals*"
                        
                        if (-not $pdfMap.ContainsKey($csjFound)) {
                            $pdfMap[$csjFound] = @{}
                        }
                        if ($isProp) {
                            $pdfMap[$csjFound]["proposalUrl"] = $fullFileUrl
                            $pdfMap[$csjFound]["proposalName"] = $pdfName
                        } else {
                            $pdfMap[$csjFound]["planUrl"] = $fullFileUrl
                            $pdfMap[$csjFound]["planName"] = $pdfName
                        }
                    }
                }
            }
        } catch {}
    }
}

Write-Host "Found $($pdfMap.Count) CSJs with direct PDF links on TxDOT FTP!"

$downloadsDir = Join-Path $PSScriptRoot "public\downloads"
if (-not (Test-Path $downloadsDir)) { New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null }

$jsonFile = Join-Path $downloadsDir "ftp_map_$Month.json"
$pdfMap | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile
Write-Host "Saved FTP map to $jsonFile"
