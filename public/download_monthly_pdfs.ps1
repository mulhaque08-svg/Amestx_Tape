param (
    [string]$Month = "2026-09",
    [switch]$Force
)

$pair = 'planuser:txdotplans'
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$authHeader = 'Basic ' + $base64

$publicDir = Join-Path $PSScriptRoot "public"
$downloadsBaseDir = Join-Path $publicDir "downloads"
$monthDir = Join-Path $downloadsBaseDir $Month

if (-not (Test-Path $monthDir)) {
    New-Item -ItemType Directory -Path $monthDir -Force | Out-Null
}

$ftpMapFile = Join-Path $downloadsBaseDir "ftp_map_$Month.json"
if (-not (Test-Path $ftpMapFile)) {
    Write-Host "FTP Map file not found for $Month. Running scan_ftp_pdfs.ps1 first..."
    $scanScript = Join-Path $PSScriptRoot "scan_ftp_pdfs.ps1"
    if (Test-Path $scanScript) {
        & $scanScript -Month $Month
    }
}

if (-not (Test-Path $ftpMapFile)) {
    Write-Host "ERROR: Could not locate or generate ftp_map_$Month.json"
    exit 1
}

$ftpMap = Get-Content $ftpMapFile -Raw | ConvertFrom-Json
$props = @($ftpMap.PSObject.Properties)
$totalCSJs = $props.Count

Write-Host "Starting Local PDF Downloader for Month $Month ($totalCSJs CSJs in map)..."

$localIndexFile = Join-Path $monthDir "local_pdf_index.json"
$localIndex = [ordered]@{}
if (Test-Path $localIndexFile) {
    try {
        $rawLocal = Get-Content $localIndexFile -Raw | ConvertFrom-Json
        foreach ($p in $rawLocal.PSObject.Properties) {
            $localIndex[$p.Name] = [ordered]@{
                proposalLocal = $p.Value.proposalLocal
                planLocal = $p.Value.planLocal
            }
        }
    } catch {}
}

# Build download item queue
$downloadQueue = [System.Collections.Generic.List[object]]::new()
$skippedCount = 0

foreach ($p in $props) {
    $csj = $p.Name
    $entry = $p.Value
    $cleanCSJName = $csj -replace '[^a-zA-Z0-9\-]', '_'

    if (-not $localIndex.Contains($csj)) {
        $localIndex[$csj] = [ordered]@{
            proposalLocal = ""
            planLocal = ""
        }
    }

    # Proposal
    if ($entry.proposalUrl -and $entry.proposalUrl -like "*.pdf") {
        $propFileName = "CSJ_${cleanCSJName}_Proposal.pdf"
        $propFilePath = Join-Path $monthDir $propFileName
        $relPropPath = "/downloads/$Month/$propFileName"

        if (-not $Force -and (Test-Path $propFilePath) -and (Get-Item $propFilePath).Length -gt 1000) {
            $localIndex[$csj]["proposalLocal"] = $relPropPath
            $skippedCount++
        } else {
            $downloadQueue.Add(@{
                csj = $csj
                type = "proposal"
                url = $entry.proposalUrl
                filePath = $propFilePath
                relPath = $relPropPath
            })
        }
    }

    # Plan
    if ($entry.planUrl -and $entry.planUrl -like "*.pdf") {
        $planFileName = "CSJ_${cleanCSJName}_Plan.pdf"
        $planFilePath = Join-Path $monthDir $planFileName
        $relPlanPath = "/downloads/$Month/$planFileName"

        if (-not $Force -and (Test-Path $planFilePath) -and (Get-Item $planFilePath).Length -gt 1000) {
            $localIndex[$csj]["planLocal"] = $relPlanPath
            $skippedCount++
        } else {
            $downloadQueue.Add(@{
                csj = $csj
                type = "plan"
                url = $entry.planUrl
                filePath = $planFilePath
                relPath = $relPlanPath
            })
        }
    }
}

Write-Host "Queue built: $($downloadQueue.Count) PDF files to download ($skippedCount already local)..."

for ($i = 0; $i -lt $downloadQueue.Count; $i++) {
    $item = $downloadQueue[$i]
    $pct = [math]::Round((($i + 1) / $downloadQueue.Count) * 100)
    Write-Host "[$($i+1)/$($downloadQueue.Count) - ${pct}%] Downloading $($item.csj) $($item.type)..."
    
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Authorization", $authHeader)
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($item.url, $item.filePath)
        $wc.Dispose()
        if (Test-Path $item.filePath -and (Get-Item $item.filePath).Length -gt 1000) {
            $propName = $item.type + "Local"
            $localIndex[$item.csj][$propName] = $item.relPath
            $downloadedCount++
        } else {
            $failedCount++
        }
    } catch {
        $failedCount++
    }
}

# Save local index
$localIndex | ConvertTo-Json -Depth 4 | Set-Content -Path $localIndexFile

Write-Host "=========================================================="
Write-Host "Local PDF Downloader Complete for Month $Month"
Write-Host "Total CSJs Indexed: $($localIndex.Count)"
Write-Host "Newly Downloaded: $downloadedCount files"
Write-Host "Already Saved Local: $skippedCount files"
Write-Host "Failed / Unavailable: $failedCount files"
Write-Host "Index Saved To: $localIndexFile"
Write-Host "=========================================================="
