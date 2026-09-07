$baseDir = "C:\Users\fibrg\.gemini\antigravity\brain\ffe802c5-ca44-440d-82e0-9f02bbcc4bbb\scratch\txdot_estimator_web"
$publicDir = Join-Path $baseDir "public"
$downloadsDir = Join-Path $publicDir "downloads"
if (-not (Test-Path $downloadsDir)) { New-Item -ItemType Directory -Path $downloadsDir | Out-Null }

$months = @("2026-06", "2026-07", "2026-08", "2026-09", "2026-10", "2026-11", "2026-12")

foreach ($month in $months) {
    Write-Host "Building refined cache for month $month..."
    $year = [int]$month.Substring(0,4)
    $mNum = [int]$month.Substring(5,2)
    if ($mNum -eq 12) {
        $nextYear = $year + 1
        $nextM = "01"
    } else {
        $nextYear = $year
        $nextM = ($mNum + 1).ToString("00")
    }

    $startDate = "$month-01T00:00:00"
    $endDate = "$nextYear-$nextM-01T00:00:00"

    $projectsMap = @{}

    # Query 1: Completed Lettings (de7b-7dna)
    $q1 = "project_actual_let_date >= '$startDate' and project_actual_let_date < '$endDate'"
    $url1 = "https://data.texas.gov/resource/de7b-7dna.json?`$where=" + [Uri]::EscapeDataString($q1) + "&`$limit=50000"
    try {
        $raw1 = Invoke-RestMethod -Uri $url1 -TimeoutSec 15
        if ($raw1) {
            $grouped1 = $raw1 | Group-Object {
                $ccsj = if ($_.controlling_project_id_ccsj) { $_.controlling_project_id_ccsj.ToString().Trim() } else { "" }
                if (-not [string]::IsNullOrWhiteSpace($ccsj)) { $ccsj } else { $_.control_section_job_csj.ToString().Trim() }
            }

            foreach ($g in $grouped1) {
                $ccsjKey = $g.Name
                $rows = $g.Group

                # Collect all unique sub-CSJs in this Controlling CSJ group
                $subCsjList = @($rows | ForEach-Object { if ($_.control_section_job_csj) { $_.control_section_job_csj.ToString().Trim() } } | Select-Object -Unique)

                # Primary Controlling CSJ row search
                $controlRow = $null
                foreach ($r in $rows) {
                    if ($r.control_section_job_csj -and $r.control_section_job_csj.ToString().Trim() -eq $ccsjKey) {
                        $controlRow = $r
                        break
                    }
                }
                if (-not $controlRow) { $controlRow = $rows[0] }

                $letD = if ($controlRow.project_actual_let_date) { ([datetime]$controlRow.project_actual_let_date).ToString("MM/dd/yyyy") } else { "N/A" }
                $pType = if ($controlRow.project_classification) { $controlRow.project_classification } elseif ($controlRow.short_description) { $controlRow.short_description } else { "Highway Construction" }
                
                $estVal = 0.0
                if ($controlRow.sealed_engineer_s_estimate) { $estVal = [double]$controlRow.sealed_engineer_s_estimate }
                if ($estVal -eq 0 -and $controlRow.sealed_engineer_s_estimate_1) { $estVal = [double]$controlRow.sealed_engineer_s_estimate_1 }

                $cName = if ($controlRow.county -and $controlRow.county -ne "TxDOT District") { (Get-Culture).TextInfo.ToTitleCase($controlRow.county.ToLower()) } else { "TxDOT District" }
                $hway = if ($controlRow.highway -and $controlRow.highway -ne "TxDOT Hwy") { $controlRow.highway } else { "TxDOT Hwy" }

                $projectsMap[$ccsjKey] = @{
                    csj = $ccsjKey
                    letDate = $letD
                    county = $cName
                    highway = $hway
                    estimate = $estVal
                    projectName = if ($controlRow.project_name) { $controlRow.project_name } else { $pType }
                    projectType = $pType
                    typeOfWork = $pType
                    projectDescription = $pType
                    subCSJs = $subCsjList
                    subCSJCount = $subCsjList.Count
                }
            }
        }
    } catch { Write-Host "Query 1 error ($month): $($_.Exception.Message)" }

    # Query 2: Scheduled / Future Lettings (drau-zphx)
    $q2 = "project_estimated_let_date >= '$startDate' and project_estimated_let_date < '$endDate'"
    $url2 = "https://data.texas.gov/resource/drau-zphx.json?`$where=" + [Uri]::EscapeDataString($q2) + "&`$limit=50000"
    try {
        $raw2 = Invoke-RestMethod -Uri $url2 -TimeoutSec 15
        if ($raw2) {
            $grouped2 = $raw2 | Group-Object {
                $ccsj = if ($_.controlling_project_id_ccsj) { $_.controlling_project_id_ccsj.ToString().Trim() } else { "" }
                if (-not [string]::IsNullOrWhiteSpace($ccsj)) { $ccsj } else { $_.control_section_job_csj.ToString().Trim() }
            }

            foreach ($g in $grouped2) {
                $ccsjKey = $g.Name
                if ($projectsMap.ContainsKey($ccsjKey)) { continue }

                $rows = $g.Group

                # Primary Controlling CSJ row search
                $controlRow = $null
                foreach ($r in $rows) {
                    if ($r.control_section_job_csj -and $r.control_section_job_csj.ToString().Trim() -eq $ccsjKey) {
                        $controlRow = $r
                        break
                    }
                }
                if (-not $controlRow) { $controlRow = $rows[0] }

                $pTypeGroup = if ($controlRow.project_type) { $controlRow.project_type.ToString().Trim() } else { "" }
                $letGroup = if ($controlRow.let_type_description) { $controlRow.let_type_description.ToString().Trim() } else { "" }

                # Filter out Non-Letting and Local Agency projects
                if ($pTypeGroup -eq "Non-Let" -or $pTypeGroup -eq "Feasibility Study" -or $pTypeGroup -eq "Alternative Delivery" -or 
                    $letGroup -like "*Non-Let*" -or $letGroup -eq "Local Agency Let" -or $letGroup -eq "Local Agency - Local Funded" -or $letGroup -eq "Design Build") {
                    continue
                }

                # Collect all unique sub-CSJs in this Controlling CSJ group
                $subCsjList = @($rows | ForEach-Object { if ($_.control_section_job_csj) { $_.control_section_job_csj.ToString().Trim() } } | Select-Object -Unique)

                $letD = if ($controlRow.project_estimated_let_date) { ([datetime]$controlRow.project_estimated_let_date).ToString("MM/dd/yyyy") } else { "N/A" }
                $pType = if ($controlRow.type_of_work) { $controlRow.type_of_work } elseif ($controlRow.project_classification) { $controlRow.project_classification } elseif ($controlRow.project_description) { $controlRow.project_description } else { "Highway Construction" }
                
                $estVal = 0.0
                if ($controlRow.sealed_engineer_s_estimate) { $estVal = [double]$controlRow.sealed_engineer_s_estimate }
                if ($estVal -eq 0 -and $controlRow.sealed_engineer_s_estimate_1) { $estVal = [double]$controlRow.sealed_engineer_s_estimate_1 }
                if ($estVal -eq 0 -and $controlRow.project_estimate_low_bid) { $estVal = [double]$controlRow.project_estimate_low_bid }

                $cName = if ($controlRow.county -and $controlRow.county -ne "TxDOT District") { (Get-Culture).TextInfo.ToTitleCase($controlRow.county.ToLower()) } else { "TxDOT District" }
                $hway = if ($controlRow.highway -and $controlRow.highway -ne "TxDOT Hwy") { $controlRow.highway } else { "TxDOT Hwy" }

                $projectsMap[$ccsjKey] = @{
                    csj = $ccsjKey
                    letDate = $letD
                    county = $cName
                    highway = $hway
                    estimate = $estVal
                    projectName = if ($controlRow.project_name) { $controlRow.project_name } else { $pType }
                    projectType = $pType
                    typeOfWork = $pType
                    projectDescription = if ($controlRow.project_description) { $controlRow.project_description } else { $pType }
                    subCSJs = $subCsjList
                    subCSJCount = $subCsjList.Count
                }
            }
        }
    } catch { Write-Host "Query 2 error ($month): $($_.Exception.Message)" }

    # Default sort by County, then CSJ
    $projectList = @($projectsMap.Values | Sort-Object county, csj)
    $outCacheFile = Join-Path $publicDir "downloads\monthly_cache_$month.json"
    $jsonStr = $projectList | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($outCacheFile, $jsonStr, [System.Text.Encoding]::UTF8)
    Write-Host "Month $month cache saved to $outCacheFile with $($projectList.Count) projects."
}
