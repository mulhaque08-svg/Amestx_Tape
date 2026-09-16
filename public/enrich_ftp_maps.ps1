Write-Host "Building master CSJ -> CCSJ lookup table from Socrata..."

$csjMap = @{}

# 1. Fetch from drau-zphx (Scheduled Lettings)
try {
    $r1 = Invoke-RestMethod -Uri 'https://data.texas.gov/resource/drau-zphx.json?$select=control_section_job_csj,controlling_project_id_ccsj&$limit=50000' -UserAgent 'Mozilla/5.0'
    foreach ($item in $r1) {
        $csj = $item.control_section_job_csj
        $ccsj = $item.controlling_project_id_ccsj
        if ($csj -and $ccsj) {
            $csjMap[$csj.Trim()] = $ccsj.Trim()
        }
    }
} catch { Write-Host "Error fetching drau-zphx: $_" }

# 2. Fetch from qh8x-rm8r (Pre-Bid Items)
try {
    $r2 = Invoke-RestMethod -Uri 'https://data.texas.gov/resource/qh8x-rm8r.json?$select=control_section_job_csj,controlling_project_id_ccsj&$limit=50000' -UserAgent 'Mozilla/5.0'
    foreach ($item in $r2) {
        $csj = $item.control_section_job_csj
        $ccsj = $item.controlling_project_id_ccsj
        if ($csj -and $ccsj) {
            $csjMap[$csj.Trim()] = $ccsj.Trim()
        }
    }
} catch { Write-Host "Error fetching qh8x-rm8r: $_" }

# 3. Fetch from de7b-7dna (Completed Lettings)
try {
    $r3 = Invoke-RestMethod -Uri 'https://data.texas.gov/resource/de7b-7dna.json?$select=control_section_job_csj,controlling_project_id_ccsj&$limit=50000' -UserAgent 'Mozilla/5.0'
    foreach ($item in $r3) {
        $csj = $item.control_section_job_csj
        $ccsj = $item.controlling_project_id_ccsj
        if ($csj -and $ccsj) {
            $csjMap[$csj.Trim()] = $ccsj.Trim()
        }
    }
} catch { Write-Host "Error fetching de7b-7dna: $_" }

Write-Host "Mapped $($csjMap.Count) CSJs to their Controlling CCSJs!"

# Save master CSJ -> CCSJ lookup file
$downloadsDir = Join-Path $PSScriptRoot "public\downloads"
if (-not (Test-Path $downloadsDir)) { New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null }
$ccsjFile = Join-Path $downloadsDir "csj_to_ccsj.json"
$csjMap | ConvertTo-Json -Depth 2 | Set-Content -Path $ccsjFile
Write-Host "Saved $ccsjFile"

# Enrich all ftp_map_*.json files
$mapFiles = Get-ChildItem -Path $downloadsDir -Filter "ftp_map_*.json"
foreach ($mf in $mapFiles) {
    Write-Host "Enriching $($mf.Name)..."
    $rawMap = Get-Content $mf.FullName -Raw | ConvertFrom-Json
    $ht = [ordered]@{}
    
    # Copy existing properties
    foreach ($prop in $rawMap.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }

    # Add child CSJs pointing to controlling CSJ entries
    $addedCount = 0
    foreach ($csj in $csjMap.Keys) {
        $ccsj = $csjMap[$csj]
        if ($ccsj -and $ht.Contains($ccsj) -and -not $ht.Contains($csj)) {
            $entry = $ht[$ccsj]
            $newEntry = @{
                proposalUrl = $entry.proposalUrl
                proposalName = $entry.proposalName
                planUrl = $entry.planUrl
                planName = $entry.planName
                ccsj = $ccsj
            }
            $ht[$csj] = $newEntry
            $addedCount++
        }
    }
    
    $ht | ConvertTo-Json -Depth 5 | Set-Content -Path $mf.FullName
    Write-Host "Enriched $($mf.Name) with $addedCount child CSJs! Total CSJs in map: $($ht.Count)"
}

Write-Host "All FTP maps enriched successfully!"
