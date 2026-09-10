param(
    [int]$port = 8081
)
$listener = New-Object System.Net.HttpListener

$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")
try { $listener.Prefixes.Add("http://[::1]:$port/") } catch {}

try {
    $listener.Start()
} catch {
    Write-Host "CRITICAL ERROR: Failed to start server on port $port"
    exit 1
}

Write-Host "=========================================================="
Write-Host " TxDOT Estimator Web App Server Running strictly at:"
Write-Host " http://localhost:$port/"
Write-Host "=========================================================="

$baseDir = $PSScriptRoot
$publicDir = Join-Path $baseDir "public"
$excelGenScript = Join-Path $baseDir "excel_generator.ps1"
$estimateGenScript = Join-Path $baseDir "estimate_generator.ps1"

$script:memoryCache = @{}
$script:avgPriceCache = @{}

function Normalize-TxDotBidCode([string]$bidCode) {
    if ([string]::IsNullOrWhiteSpace($bidCode)) { return "" }
    $clean = $bidCode.Replace(" ", "-").Trim()
    $parts = $clean -split '-'
    if ($parts.Count -eq 2) {
        $p1 = $parts[0].TrimStart('0')
        if ([string]::IsNullOrWhiteSpace($p1)) { $p1 = "0" }
        $p2 = $parts[1].TrimStart('0')
        if ([string]::IsNullOrWhiteSpace($p2)) { $p2 = "0" }
        return "$p1-$p2"
    }
    return $clean
}

function Is-Item800([string]$code) {
    if ([string]::IsNullOrWhiteSpace($code)) { return $false }
    $clean = $code.Trim()
    if ($clean -eq "800" -or $clean -eq "0800") { return $true }
    if ($clean -like "800-*" -or $clean -like "0800-*" -or $clean -like "800 *" -or $clean -like "0800 *") { return $true }
    $parts = $clean -split '[\s\-]+'
    if ($parts.Count -gt 0) {
        $p0 = $parts[0].TrimStart('0')
        if ($p0 -eq "800") { return $true }
    }
    return $false
}

function Get-AmestxCompositePrice ([string]$bidCode, [double]$engEstUnit = 0.00, [double]$lowBidUnit = 0.00, [double]$highBidUnit = 0.00) {
    if (Is-Item800 $bidCode) { return 0.00 }
    # 1. If project bids exist (Low Bidder, High Bidder, Eng Est)
    $prices = @()
    if ($lowBidUnit -gt 0) { $prices += $lowBidUnit }
    if ($highBidUnit -gt 0 -and $highBidUnit -ne $lowBidUnit) { $prices += $highBidUnit }
    if ($engEstUnit -gt 0) { $prices += $engEstUnit }

    if ($prices.Count -ge 2) {
        $sum = 0.0
        foreach ($p in $prices) { $sum += $p }
        return [math]::Round($sum / $prices.Count, 2)
    }

    # 2. Otherwise query TxDOT statewide dataset for historical benchmarks
    $normCode = Normalize-TxDotBidCode $bidCode
    if ([string]::IsNullOrWhiteSpace($normCode)) { 
        if ($engEstUnit -gt 0) { return $engEstUnit }
        if ($lowBidUnit -gt 0) { return $lowBidUnit }
        return 0.00 
    }
    
    if ($script:avgPriceCache.ContainsKey($normCode)) { 
        $cached = $script:avgPriceCache[$normCode]
        if ($cached -gt 0) {
            $benchmarks = @($cached)
            if ($engEstUnit -gt 0) { $benchmarks += $engEstUnit }
            $bSum = 0.0
            foreach ($b in $benchmarks) { $bSum += $b }
            return [math]::Round($bSum / $benchmarks.Count, 2)
        }
    }
    
    try {
        # Query TxDOT Socrata Dataset de7b-7dna for both low-bidder avg and overall market avg
        $urlLow = "https://data.texas.gov/resource/de7b-7dna.json?`$select=bid_code,AVG(bid_item_unit_price_amount)+as+low_avg&`$where=(low_bidder_flag='true'+OR+low_bidder_flag='True'+OR+bid_rank_sequence_number='1')+AND+bid_code='$normCode'&`$group=bid_code"
        $resLow = Invoke-RestMethod -Uri $urlLow -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 5

        $urlAll = "https://data.texas.gov/resource/de7b-7dna.json?`$select=bid_code,AVG(bid_item_unit_price_amount)+as+all_avg&`$where=bid_code='$normCode'&`$group=bid_code"
        $resAll = Invoke-RestMethod -Uri $urlAll -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 5

        $bList = @()
        if ($resLow -and $resLow.Count -gt 0 -and $resLow[0].low_avg) {
            $bList += [double]$resLow[0].low_avg
        }
        if ($resAll -and $resAll.Count -gt 0 -and $resAll[0].all_avg) {
            $bList += [double]$resAll[0].all_avg
        }
        if ($engEstUnit -gt 0) {
            $bList += $engEstUnit
        }

        if ($bList.Count -gt 0) {
            $sum = 0.0
            foreach ($b in $bList) { $sum += $b }
            $compAvg = [math]::Round($sum / $bList.Count, 2)
            $script:avgPriceCache[$normCode] = $compAvg
            return $compAvg
        }
    } catch {}

    if ($engEstUnit -gt 0) { return $engEstUnit }
    return 0.00
}

function Get-2026LowBidAvgPrice ([string]$bidCode) {
    return Get-AmestxCompositePrice -bidCode $bidCode
}

function Get-DefaultItems {
    return @(
        @{ code = "0500 6001"; description = "MOBILIZATION"; unit = "LS"; quantity = 1.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "0502 6001"; description = "BARRICADES, SIGNS AND TRAFFIC HANDLING"; unit = "MO"; quantity = 6.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "0506 6038"; description = "TEMP SEDMT CONT FENCE (INSTALL)"; unit = "LF"; quantity = 500.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "0506 6039"; description = "TEMP SEDMT CONT FENCE (REMOVE)"; unit = "LF"; quantity = 500.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "0666 6303"; description = "REPM TY W/W 4 (SLD)(100MIL)"; unit = "LF"; quantity = 1200.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "0666 6315"; description = "REPM TY W/W 4 (YLD)(100MIL)"; unit = "LF"; quantity = 1200.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "6001 6002"; description = "PORTABLE CHANGEABLE MESSAGE SIGN"; unit = "EA"; quantity = 2.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} },
        @{ code = "6185 6002"; description = "TMA (STATIONARY)"; unit = "DAY"; quantity = 45.00; engEstUnit = 0.00; lowUnit = 0.00; bidders = @{} }
    )
}

function Get-CSJData {
    param ([string]$CSJ)
    
    $cleanCSJ = $CSJ.Trim()
    
    if ($script:memoryCache.ContainsKey("csj_$cleanCSJ")) {
        return $script:memoryCache["csj_$cleanCSJ"]
    }

    # 1. Try Dataset 2: qh8x-rm8r (Pre-Bid Scheduled Items)
    $qWhere2 = "control_section_job_csj='$cleanCSJ' or controlling_project_id_ccsj='$cleanCSJ'"
    $apiUrl2 = "https://data.texas.gov/resource/qh8x-rm8r.json?`$where=" + [Uri]::EscapeDataString($qWhere2) + "&`$limit=5000"
    $tempJson2 = Join-Path $env:TEMP "csj_qh8x_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
    
    $preBidData = $null
    try {
        Invoke-WebRequest -Uri $apiUrl2 -OutFile $tempJson2 -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 10
        if (Test-Path $tempJson2) {
            $rawItems = Get-Content $tempJson2 -Raw | ConvertFrom-Json
            Remove-Item $tempJson2 -ErrorAction SilentlyContinue
            
            if ($rawItems -and $rawItems.Count -gt 0) {
                $first = $rawItems[0]
                $letD = if ($first.bids_will_be_opened_date) { 
                    ([datetime]$first.bids_will_be_opened_date).ToString("MM/dd/yy") 
                } elseif ($first.project_approved_let_date) { 
                    ([datetime]$first.project_approved_let_date).ToString("MM/dd/yy") 
                } else { "Scheduled" }

                $pName = if ($first.specification_description) { $first.specification_description } else { $first.project_classification }

                $estVal = [double]$first.sealed_engineer_s_estimate
                if ($estVal -eq 0 -and $first.sealed_engineer_s_estimate_1) { $estVal = [double]$first.sealed_engineer_s_estimate_1 }
                if ($estVal -eq 0 -and $first.project_estimate_low_bid) { $estVal = [double]$first.project_estimate_low_bid }
                if ($estVal -eq 0 -and $rawItems) {
                    $calcEst = 0.0
                    foreach ($f in $rawItems) {
                        $uEst = [double]$f.engineer_s_estimate_unit
                        $qty = [double]$f.bid_item_quantity
                        if ($uEst -gt 0 -and $qty -gt 0) { $calcEst += ($uEst * $qty) }
                    }
                    if ($calcEst -gt 0) { $estVal = $calcEst }
                }

                $meta = @{
                    csj = $cleanCSJ
                    ccsj = $first.controlling_project_id_ccsj
                    county = $first.county
                    highway = $first.highway
                    projectName = $pName
                    projectType = if ($first.project_classification) { $first.project_classification } else { $first.specification_description }
                    workingDays = $first.maximum_number_of_working
                    letDate = $letD
                    projectId = $first.project_id
                    engEstTotal = $estVal
                    isPreBid = $true
                    statusNote = "CSJ $cleanCSJ Scheduled Letting"
                }

                $sortedItems = $rawItems | Sort-Object {[int]$_.bid_item_sequence_number}
                $items = @()
                foreach ($f in $sortedItems) {
                    $qty = [double]$f.bid_item_quantity
                    $codeStr = if ($f.bid_code) { $f.bid_code.Replace("-", " ") } else { "" }
                    $descStr = if ($f.bid_item_description) { $f.bid_item_description } else { $f.specification_description }
                    $engUnit = [double]$f.engineer_s_estimate_unit

                    # Amestx Composite Unit Price (Low Avg + Market Avg + Eng Est) / N
                    $amestxPrice = Get-AmestxCompositePrice -bidCode $f.bid_code -engEstUnit $engUnit

                    $items += @{
                        code = $codeStr
                        description = $descStr
                        unit = $f.measurement_unit
                        quantity = $qty
                        engEstUnit = $engUnit
                        amestxUnit = $amestxPrice
                        lowUnit = if ($amestxPrice -gt 0) { $amestxPrice } else { $engUnit }
                        bidders = @{}
                    }
                }

                $preBidData = @{
                    metadata = $meta
                    bidders = @()
                    items = $items
                }
            }
        }
    } catch {}

    # 2. Try Dataset 1: de7b-7dna (Bid Tabulations for Let Projects)
    $qWhere1 = "control_section_job_csj='$cleanCSJ' or controlling_project_id_ccsj='$cleanCSJ'"
    $apiUrl1 = "https://data.texas.gov/resource/de7b-7dna.json?`$where=" + [Uri]::EscapeDataString($qWhere1) + "&`$limit=5000"
    $tempJson1 = Join-Path $env:TEMP "csj_de7b_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
    
    $completedData = $null
    try {
        Invoke-WebRequest -Uri $apiUrl1 -OutFile $tempJson1 -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 10
        if (Test-Path $tempJson1) {
            $raw = Get-Content $tempJson1 -Raw | ConvertFrom-Json
            Remove-Item $tempJson1 -ErrorAction SilentlyContinue
            
            if ($raw -and $raw.Count -gt 0) {
                $first = $raw[0]
                $biddersGroup = $raw | Group-Object vendor_name | ForEach-Object {
                    $r = $_.Group[0]
                    [PSCustomObject]@{
                        rank = $r.bid_rank_sequence_number
                        vendorName = $r.vendor_name
                        totalBidAmount = [double]$r.bid_total_amount
                    }
                }
                $realBidders = $biddersGroup | Where-Object {$_.vendorName -notlike "*Engineer*" -and $_.rank -ne "EE"} | Sort-Object {[int]$_.rank}

                $estTotal1 = [double]$first.sealed_engineer_s_estimate
                if ($estTotal1 -eq 0 -and $first.sealed_engineer_s_estimate_1) { $estTotal1 = [double]$first.sealed_engineer_s_estimate_1 }
                if ($estTotal1 -eq 0 -and $realBidders -and $realBidders.Count -gt 0) { $estTotal1 = [double]$realBidders[0].totalBidAmount }

                $meta = @{
                    csj = $cleanCSJ
                    ccsj = $first.controlling_project_id_ccsj
                    county = $first.county
                    highway = $first.highway
                    projectName = if ($first.project_name) { $first.project_name } else { $first.project_classification }
                    projectType = $first.project_classification
                    workingDays = $first.maximum_number_of_working
                    letDate = if ($first.project_actual_let_date) { ([datetime]$first.project_actual_let_date).ToString("MM/dd/yy") } else { "N/A" }
                    projectId = $first.project_number
                    engEstTotal = $estTotal1
                    isPreBid = $false
                    statusNote = "Completed Let Project"
                }

                $itemsGroup = $raw | Group-Object bid_code, bid_item_sequence_number | Where-Object {$_.Group[0].bid_code -ne ""} | Sort-Object {[int]$_.Group[0].bid_item_sequence_number}
                
                $items = @()
                foreach ($ig in $itemsGroup) {
                    $itemRows = $ig.Group
                    $f = $itemRows[0]
                    
                    $bPrices = @{}
                    foreach ($ir in $itemRows) {
                        $bPrices[$ir.vendor_name] = [double]$ir.bid_item_unit_price_amount
                    }

                    $engUnit = [double]$f.engineer_s_estimate_unit
                    $lowUnitVal = if ($realBidders.Count -gt 0 -and $bPrices.ContainsKey($realBidders[0].vendorName)) { $bPrices[$realBidders[0].vendorName] } else { 0.00 }
                    $highUnitVal = if ($realBidders.Count -gt 1 -and $bPrices.ContainsKey($realBidders[-1].vendorName)) { $bPrices[$realBidders[-1].vendorName] } else { $lowUnitVal }

                    # Amestx Composite Unit Price (Low Bidder + High Bidder + Eng Est) / N
                    $amestxPrice = Get-AmestxCompositePrice -bidCode $f.bid_code -engEstUnit $engUnit -lowBidUnit $lowUnitVal -highBidUnit $highUnitVal

                    $items += @{
                        code = if ($f.bid_code) { $f.bid_code.Replace("-", " ") } else { "" }
                        description = $f.bid_item_description
                        unit = $f.measurement_unit
                        quantity = [double]$f.bid_item_quantity
                        engEstUnit = $engUnit
                        amestxUnit = $amestxPrice
                        lowUnit = if ($lowUnitVal -gt 0) { $lowUnitVal } else { $amestxPrice }
                        bidders = $bPrices
                    }
                }

                $completedData = @{
                    metadata = $meta
                    bidders = $realBidders
                    items = $items
                }
            }
        }
    } catch {}

    # 3. Decision: If preBidData exists and its letDate is later/equal or completedData is missing, return preBidData
    if ($preBidData) {
        $pDate = $preBidData.metadata.letDate
        $cDate = if ($completedData) { $completedData.metadata.letDate } else { "01/01/1900" }
        
        $pDt = [datetime]::MinValue
        $cDt = [datetime]::MinValue
        [datetime]::TryParse($pDate, [ref]$pDt) | Out-Null
        [datetime]::TryParse($cDate, [ref]$cDt) | Out-Null

        if (-not $completedData -or $pDt -ge $cDt -or $pDt.Year -ge 2026) {
            $script:memoryCache["csj_$cleanCSJ"] = $preBidData
            return $preBidData
        }
    }

    if ($completedData) {
        $script:memoryCache["csj_$cleanCSJ"] = $completedData
        return $completedData
    }

    # 3. Try Dataset 3: drau-zphx (Scheduled Lettings Metadata)
    $apiUrl3 = "https://data.texas.gov/resource/drau-zphx.json?control_section_job_csj=$cleanCSJ&`$limit=1"
    $tempJson3 = Join-Path $env:TEMP "csj_drau_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
    try {
        Invoke-WebRequest -Uri $apiUrl3 -OutFile $tempJson3 -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 10
        if (Test-Path $tempJson3) {
            $raw3 = Get-Content $tempJson3 -Raw | ConvertFrom-Json
            Remove-Item $tempJson3 -ErrorAction SilentlyContinue
            if ($raw3 -and $raw3.Count -gt 0) {
                $f3 = $raw3[0]
                $letD3 = if ($f3.project_estimated_let_date) { 
                    ([datetime]$f3.project_estimated_let_date).ToString("MM/dd/yy") 
                } else { "Scheduled" }

                $estVal3 = [double]$f3.sealed_engineer_s_estimate
                if ($estVal3 -eq 0 -and $f3.sealed_engineer_s_estimate_1) { $estVal3 = [double]$f3.sealed_engineer_s_estimate_1 }
                if ($estVal3 -eq 0 -and $f3.project_estimate_low_bid) { $estVal3 = [double]$f3.project_estimate_low_bid }
                if ($estVal3 -eq 0) {
                    $estVal3 = 0.00
                }

                $pType3 = if ($f3.type_of_work) { $f3.type_of_work } elseif ($f3.project_classification) { $f3.project_classification } elseif ($f3.project_description) { $f3.project_description } else { "Highway Construction" }

                $isNonLet3 = ($f3.project_type -eq "Non-Let") -or ($f3.let_type_description -like "*Non-Let*") -or ($f3.project_type -eq "Feasibility Study")
                $statusNoteStr = if ($isNonLet3) { "Non-State Let / Local Project (No TxDOT State Bids Published)" } else { "CSJ $cleanCSJ Scheduled Letting" }

                $meta3 = @{
                    csj = $cleanCSJ
                    ccsj = $f3.controlling_project_id_ccsj
                    county = $f3.county
                    highway = $f3.highway
                    projectName = if ($f3.project_name) { $f3.project_name } else { $pType3 }
                    projectType = $pType3
                    workingDays = $f3.maximum_number_of_working
                    letDate = $letD3
                    projectId = $f3.project_id
                    engEstTotal = $estVal3
                    isPreBid = $true
                    statusNote = $statusNoteStr
                }

                $resObj3 = @{
                    metadata = $meta3
                    bidders = @()
                    items = (Get-DefaultItems)
                }
                $script:memoryCache["csj_$cleanCSJ"] = $resObj3
                return $resObj3
            }
        }
    } catch {}

    # 4. Fallback: Return Clean Default Pre-Bid Object
    $resObj = @{
        metadata = @{
            csj = $cleanCSJ
            county = "TxDOT District"
            highway = "TxDOT Hwy"
            projectName = "Scheduled Letting Project"
            projectType = "Highway Construction"
            workingDays = "N/A"
            letDate = "Scheduled"
            projectId = "N/A"
            engEstTotal = 485000.00
            isPreBid = $true
            statusNote = "CSJ $cleanCSJ results will be announced after bid date"
        }
        bidders = @()
        items = (Get-DefaultItems)
    }
    $script:memoryCache["csj_$cleanCSJ"] = $resObj
    return $resObj
}

# Weekly Hands-Free TxDOT PDF Auto-Update Check (Option A)
$autoUpdateScript = Join-Path $baseDir "auto_update_schedule.ps1"
$autoLogFile = Join-Path $publicDir "downloads\auto_update.log"
$shouldRunAutoUpdate = $true
if (Test-Path $autoLogFile) {
    $lastRun = (Get-Item $autoLogFile).LastWriteTime
    if ((Get-Date) - $lastRun -lt (New-TimeSpan -Days 7)) {
        $shouldRunAutoUpdate = $false
    }
}
if ($shouldRunAutoUpdate -and (Test-Path $autoUpdateScript)) {
    Write-Host "Triggering weekly hands-free TxDOT PDF auto-update background job..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$autoUpdateScript`"" -WindowStyle Hidden
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
        $response.AddHeader("Pragma", "no-cache")
        $response.AddHeader("Expires", "0")

        $url = $request.Url.AbsolutePath
        $query = $request.QueryString

        if ($url -eq "/" -or $url -eq "/home" -or $url -eq "/home.html") {
            $homePath = Join-Path $publicDir "home.html"
            if (-not (Test-Path $homePath)) { $homePath = Join-Path $baseDir "home.html" }
            if (-not (Test-Path $homePath)) { $homePath = Join-Path $publicDir "index.html" }
            if (-not (Test-Path $homePath)) { $homePath = Join-Path $baseDir "index.html" }

            if (Test-Path $homePath) {
                $content = [System.IO.File]::ReadAllBytes($homePath)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                $response.StatusCode = 404
            }
        }
        elseif ($url -eq "/app" -or $url -eq "/index.html") {
            $indexPath = Join-Path $publicDir "index.html"
            if (-not (Test-Path $indexPath)) { $indexPath = Join-Path $baseDir "index.html" }
            if (Test-Path $indexPath) {
                $content = [System.IO.File]::ReadAllBytes($indexPath)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                $response.StatusCode = 404
            }
        }
        elseif ((Test-Path (Join-Path $publicDir ($url.TrimStart('/')))) -or (Test-Path (Join-Path $baseDir ($url.TrimStart('/'))))) {
            $filePath = Join-Path $publicDir ($url.TrimStart('/'))
            if (-not (Test-Path $filePath -PathType Leaf)) {
                $filePath = Join-Path $baseDir ($url.TrimStart('/'))
            }
            if (Test-Path $filePath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                switch ($ext) {
                    ".html" { $response.ContentType = "text/html; charset=utf-8" }
                    ".htm"  { $response.ContentType = "text/html; charset=utf-8" }
                    ".js"   { $response.ContentType = "application/javascript" }
                    ".css"  { $response.ContentType = "text/css" }
                    ".png"  { $response.ContentType = "image/png" }
                    ".jpg"  { $response.ContentType = "image/jpeg" }
                    ".json" { $response.ContentType = "application/json" }
                    default { $response.ContentType = "application/octet-stream" }
                }
                $content = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                $response.StatusCode = 404
            }
        }
        elseif ($url.StartsWith("/downloads/")) {
            $relPath = $url.Substring(1) -replace '/', '\'
            $localFilePath = Join-Path $publicDir $relPath
            if (Test-Path $localFilePath -PathType Leaf) {
                $fileInfo = Get-Item $localFilePath
                $fileLen = $fileInfo.Length

                if ($localFilePath.EndsWith(".pdf")) {
                    $response.ContentType = "application/pdf"
                    $fileName = [System.IO.Path]::GetFileName($localFilePath)
                    $response.AddHeader("Content-Disposition", "inline; filename=`"$fileName`"")
                } elseif ($localFilePath.EndsWith(".json")) {
                    $response.ContentType = "application/json"
                } else {
                    $response.ContentType = "application/octet-stream"
                }
                $response.ContentLength64 = $fileLen

                $fs = [System.IO.File]::OpenRead($localFilePath)
                try {
                    if ($request.HttpMethod -ne "HEAD") {
                        $buffer = New-Object byte[] 65536 # 64KB chunk buffer
                        $bytesRead = 0
                        while (($bytesRead = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $response.OutputStream.Write($buffer, 0, $bytesRead)
                        }
                        $response.OutputStream.Flush()
                    }
                } finally {
                    $fs.Close()
                    $fs.Dispose()
                }
            } else {
                $response.StatusCode = 404
            }
        }
        elseif ($url -eq "/api/monthly-lettings") {
            $month = $query["month"]
            if ([string]::IsNullOrWhiteSpace($month)) {
                $month = "2026-09"
            }

            if ($script:memoryCache.ContainsKey("month_$month")) {
                $jsonStr = $script:memoryCache["month_$month"]
            } else {
                $diskCacheFile = Join-Path $publicDir "downloads\monthly_cache_$month.json"
                if (Test-Path $diskCacheFile) {
                    $jsonStr = Get-Content $diskCacheFile -Raw
                    $script:memoryCache["month_$month"] = $jsonStr
                } else {
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
                    } catch {}

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
                    } catch {}

                    $projectList = @($projectsMap.Values | Sort-Object county, csj)
                    $jsonStr = $projectList | ConvertTo-Json -Depth 4
                    [System.IO.File]::WriteAllText($diskCacheFile, $jsonStr, [System.Text.Encoding]::UTF8)
                    $script:memoryCache["month_$month"] = $jsonStr
                }
            }

            $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $jsonBytes.Length
            try {
                $response.OutputStream.Write($jsonBytes, 0, $jsonBytes.Length)
            } catch {}
        }
        elseif ($url -eq "/api/bidtab") {
            $csj = $query["csj"]
            if ([string]::IsNullOrWhiteSpace($csj)) {
                $response.StatusCode = 400
                $errMsg = [System.Text.Encoding]::UTF8.GetBytes('{"error":"CSJ parameter is required"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($errMsg, 0, $errMsg.Length)
            }
            else {
                $data = Get-CSJData -CSJ $csj
                $jsonStr = $data | ConvertTo-Json -Depth 6
                $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
                
                $response.ContentType = "application/json"
                $response.ContentLength64 = $jsonBytes.Length
                $response.OutputStream.Write($jsonBytes, 0, $jsonBytes.Length)
            }
        }
        elseif ($url -eq "/api/export-excel") {
            $csj = $query["csj"]
            if ([string]::IsNullOrWhiteSpace($csj)) {
                $response.StatusCode = 400
            }
            else {
                $cleanCSJ = $csj.Trim()
                $outXlsx = Join-Path $env:TEMP "CSJ_${cleanCSJ}_Bid_Tabulation.xlsx"
                powershell -ExecutionPolicy Bypass -File $excelGenScript -CSJ $cleanCSJ -OutputPath $outXlsx
                if (Test-Path $outXlsx) {
                    $bytes = [System.IO.File]::ReadAllBytes($outXlsx)
                    $response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    $response.AddHeader("Content-Disposition", "attachment; filename=`"CSJ_${cleanCSJ}_Bid_Tabulation.xlsx`"")
                    $response.ContentLength64 = $bytes.Length
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    Remove-Item $outXlsx -ErrorAction SilentlyContinue
                } else {
                    $response.StatusCode = 500
                }
            }
        }
        elseif ($url -eq "/api/export-estimate-excel") {
            $csj = $query["csj"]
            if ([string]::IsNullOrWhiteSpace($csj)) {
                $response.StatusCode = 400
            }
            else {
                $cleanCSJ = $csj.Trim()
                $outXlsx = Join-Path $env:TEMP "CSJ_${cleanCSJ}_Estimate_Sheet.xlsx"
                powershell -ExecutionPolicy Bypass -File $estimateGenScript -CSJ $cleanCSJ -OutputPath $outXlsx
                if (Test-Path $outXlsx) {
                    $bytes = [System.IO.File]::ReadAllBytes($outXlsx)
                    $response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    $response.AddHeader("Content-Disposition", "attachment; filename=`"CSJ_${cleanCSJ}_Task_Items_Estimate.xlsx`"")
                    $response.ContentLength64 = $bytes.Length
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    Remove-Item $outXlsx -ErrorAction SilentlyContinue
                } else {
                    $response.StatusCode = 500
                }
            }
        }
        elseif ($url -eq "/api/csj-pdf-links") {
            $csj = $query["csj"]
            $month = $query["month"]
            if ([string]::IsNullOrWhiteSpace($month)) { $month = "2026-09" }

            if ([string]::IsNullOrWhiteSpace($csj)) {
                $response.StatusCode = 400
                $errMsg = [System.Text.Encoding]::UTF8.GetBytes('{"error":"CSJ parameter is required"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($errMsg, 0, $errMsg.Length)
            } else {
                $cleanCSJ = $csj.Trim()
                $downloadsDir = Join-Path $publicDir "downloads"

                # 1. Fetch metadata first to get CCSJ if any
                $csjDetails = Get-CSJData -CSJ $cleanCSJ
                $ccsj = $null
                if ($csjDetails -and $csjDetails.metadata -and $csjDetails.metadata.ccsj) {
                    $ccsj = $csjDetails.metadata.ccsj
                }

                $foundEntry = $null
                $foundCCSJ = ""

                # Helper to check a map file
                $checkMap = {
                    param ([string]$mFile)
                    if (Test-Path $mFile) {
                        try {
                            $mapData = Get-Content $mFile -Raw | ConvertFrom-Json
                            if ($mapData.PSObject.Properties[$cleanCSJ]) {
                                return $mapData.PSObject.Properties[$cleanCSJ].Value
                            }
                            if ($ccsj -and $mapData.PSObject.Properties[$ccsj]) {
                                $script:foundCCSJ = $ccsj
                                return $mapData.PSObject.Properties[$ccsj].Value
                            }
                        } catch {}
                    }
                    return $null
                }

                # 2. Search specified month map first
                $jsonMapFile = Join-Path $downloadsDir "ftp_map_$month.json"
                $foundEntry = &$checkMap -mFile $jsonMapFile

                # 3. If not found in specified month, search all other 2026 month maps
                if (-not $foundEntry) {
                    $allMaps = Get-ChildItem -Path $downloadsDir -Filter "ftp_map_2026-*.json" | Sort-Object Name -Descending
                    foreach ($mapItem in $allMaps) {
                        $foundEntry = &$checkMap -mFile $mapItem.FullName
                        if ($foundEntry) { break }
                    }
                }

                $year = $month.Substring(0,4)
                $mNum = $month.Substring(5,2)
                $monthNames = @("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
                $mIdx = [int]$mNum - 1
                if ($mIdx -lt 0 -or $mIdx -gt 11) { $mIdx = 8 }
                $monthName = $monthNames[$mIdx]

                $monthFolder = [Uri]::EscapeDataString("$mNum $monthName")
                $mSub = [Uri]::EscapeDataString("$mNum Proposals")
                $pSub = [Uri]::EscapeDataString("$mNum Plans")

                $fallbackPropFolder = "https://ftp.txdot.gov/plans/State-Let-Construction/$year/$monthFolder/$mSub/"
                $fallbackPlanFolder = "https://ftp.txdot.gov/plans/State-Let-Construction/$year/$monthFolder/$pSub/"

                # 4. Check if files exist locally in public/downloads/{month}/
                $cleanCSJName = $cleanCSJ -replace '[^a-zA-Z0-9\-]', '_'
                $localPropFile = Join-Path $downloadsDir "$month\CSJ_${cleanCSJName}_Proposal.pdf"
                $localPlanFile = Join-Path $downloadsDir "$month\CSJ_${cleanCSJName}_Plan.pdf"

                $hasLocalProp = (Test-Path $localPropFile) -and ((Get-Item $localPropFile).Length -gt 1000)
                $hasLocalPlan = (Test-Path $localPlanFile) -and ((Get-Item $localPlanFile).Length -gt 1000)

                $finalPropUrl = if ($hasLocalProp) { "/downloads/$month/CSJ_${cleanCSJName}_Proposal.pdf" } elseif ($foundEntry -and $foundEntry.proposalUrl) { $foundEntry.proposalUrl } else { $fallbackPropFolder }
                $finalPropName = if ($hasLocalProp) { "CSJ_${cleanCSJName}_Proposal.pdf" } elseif ($foundEntry -and $foundEntry.proposalName) { $foundEntry.proposalName } else { "$monthName $year Proposals Folder" }

                $finalPlanUrl = if ($hasLocalPlan) { "/downloads/$month/CSJ_${cleanCSJName}_Plan.pdf" } elseif ($foundEntry -and $foundEntry.planUrl) { $foundEntry.planUrl } else { $fallbackPlanFolder }
                $finalPlanName = if ($hasLocalPlan) { "CSJ_${cleanCSJName}_Plan.pdf" } elseif ($foundEntry -and $foundEntry.planName) { $foundEntry.planName } else { "$monthName $year Plans Folder" }

                $result = [ordered]@{
                    csj = $cleanCSJ
                    ccsj = if ($script:foundCCSJ) { $script:foundCCSJ } else { $ccsj }
                    found = [bool]($foundEntry -ne $null -or $hasLocalProp -or $hasLocalPlan)
                    isLocalProp = $hasLocalProp
                    isLocalPlan = $hasLocalPlan
                    planUrl = $finalPlanUrl
                    planName = $finalPlanName
                    proposalUrl = $finalPropUrl
                    proposalName = $finalPropName
                }

                $jsonStr = $result | ConvertTo-Json -Depth 4
                $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $jsonBytes.Length
                $response.OutputStream.Write($jsonBytes, 0, $jsonBytes.Length)
            }
        }
        elseif ($url -eq "/api/trigger-month-download") {
            $month = $query["month"]
            if ([string]::IsNullOrWhiteSpace($month)) { $month = "2026-09" }
            $dlScript = Join-Path $baseDir "download_monthly_pdfs.ps1"
            if (Test-Path $dlScript) {
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$dlScript`" -Month `"$month`"" -WindowStyle Hidden
                $jsonStr = '{"success":true,"message":"Local PDF download job launched in background for ' + $month + '"}'
            } else {
                $jsonStr = '{"success":false,"error":"Downloader script not found"}'
            }
            $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $jsonBytes.Length
            $response.OutputStream.Write($jsonBytes, 0, $jsonBytes.Length)
        }
        else {
            $response.StatusCode = 404
        }
    }
    catch {
        Write-Host "Error handling request: $_"
    }
    finally {
        try { $response.Close() } catch {}
    }
}
