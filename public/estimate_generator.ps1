param (
    [Parameter(Mandatory=$true)]
    [string]$CSJ,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$cleanCSJ = $CSJ.Trim()

# 1. Attempt Dataset 1: de7b-7dna (Bid Tabulations for Let Projects)
$apiUrl = "https://data.texas.gov/resource/de7b-7dna.csv?control_section_job_csj=$cleanCSJ"
$tempCsvPath = Join-Path $env:TEMP "txdot_est_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').csv"

$raw = $null
try {
    Invoke-WebRequest -Uri $apiUrl -OutFile $tempCsvPath -UserAgent "Mozilla/5.0"
    if ((Test-Path $tempCsvPath) -and (Get-Item $tempCsvPath).Length -gt 50) {
        $raw = Import-Csv $tempCsvPath
    }
} catch {}

$itemsList = @()
$isPreBid = $false

# Cache for 2026 TxDOT Low Bidder Average Unit Prices
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
    $prices = @()
    if ($lowBidUnit -gt 0) { $prices += $lowBidUnit }
    if ($highBidUnit -gt 0 -and $highBidUnit -ne $lowBidUnit) { $prices += $highBidUnit }
    if ($engEstUnit -gt 0) { $prices += $engEstUnit }

    if ($prices.Count -ge 2) {
        $sum = 0.0
        foreach ($p in $prices) { $sum += $p }
        return [math]::Round($sum / $prices.Count, 2)
    }

    $normCode = Normalize-TxDotBidCode $bidCode
    if ([string]::IsNullOrWhiteSpace($normCode)) { 
        if ($engEstUnit -gt 0) { return $engEstUnit }
        if ($lowBidUnit -gt 0) { return $lowBidUnit }
        return 0.00 
    }
    
    if ($avgPriceCache.ContainsKey($normCode)) { 
        $cached = $avgPriceCache[$normCode]
        if ($cached -gt 0) {
            $benchmarks = @($cached)
            if ($engEstUnit -gt 0) { $benchmarks += $engEstUnit }
            $bSum = 0.0
            foreach ($b in $benchmarks) { $bSum += $b }
            return [math]::Round($bSum / $benchmarks.Count, 2)
        }
    }
    
    try {
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
            $avgPriceCache[$normCode] = $compAvg
            return $compAvg
        }
    } catch {}

    if ($engEstUnit -gt 0) { return $engEstUnit }
    return 0.00
}

function Get-2026LowBidAvgPrice ([string]$bidCode) {
    return Get-AmestxCompositePrice -bidCode $bidCode
}

if ($raw -and $raw.Count -gt 0) {
    $firstRow = $raw[0]

    # Parse Metadata
    $county = if ($firstRow.county) { $firstRow.county } else { "N/A" }
    $district = if ($firstRow.district_division) { $firstRow.district_division } else { "TxDOT District" }
    $projectId = if ($firstRow.project_id) { $firstRow.project_id } else { "N/A" }
    $fedProjNo = if ($firstRow.federal_project_number) { $firstRow.federal_project_number } else { "N/A" }
    $stateProjNo = if ($firstRow.state_project_number) { $firstRow.state_project_number } else { "N/A" }
    $contractNo = if ($firstRow.contract_number) { $firstRow.contract_number } else { "N/A" }
    $hwy = if ($firstRow.highway) { $firstRow.highway } else { "N/A" }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + " Working Days" } else { "N/A" }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { "N/A" }
    $length = "0.000"
    $estimateTotal = [double]$firstRow.sealed_engineer_s_estimate

    $letDateRaw = $firstRow.project_actual_let_date
    $bidsOpened = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("M/dd/yyyy") } else { "N/A" }

    # Parse Unique Items
    $itemsGroup = $raw | Group-Object bid_code, bid_item_sequence_number | Where-Object {$_.Group[0].bid_code -ne ""} | Sort-Object {[int]$_.Group[0].bid_item_sequence_number}
    
    foreach ($ig in $itemsGroup) {
        $itemRows = $ig.Group
        $item = $itemRows[0]
        $codeStr = if ($item.bid_code) { $item.bid_code.Replace("-", " ").Trim() } else { "" }
        $parts = $codeStr -split '\s+'
        $itemNo = if ($parts.Length -gt 0) { $parts[0] } else { "" }
        $specCode = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        
        # Get low bidder unit price or engineer estimate or 2026 low bidder average
        $unitPrice = 0.00
        $lowRow = $itemRows | Where-Object { $_.low_bidder_flag -eq "True" -or $_.bid_rank_sequence_number -eq "1" } | Select-Object -First 1
        if ($lowRow -and $lowRow.bid_item_unit_price_amount) {
            $unitPrice = [double]$lowRow.bid_item_unit_price_amount
        } elseif ($item.engineer_s_estimate_unit) {
            $unitPrice = [double]$item.engineer_s_estimate_unit
        } else {
            $unitPrice = Get-2026LowBidAvgPrice $item.bid_code
        }

        $itemsList += @{
            code = $codeStr
            itemNo = $itemNo
            specCode = $specCode
            description = $item.bid_item_description
            unit = $item.measurement_unit
            quantity = [double]$item.bid_item_quantity
            engEstPrice = $unitPrice
        }
    }
}
else {
    # 2. Fallback to Pre-Bid Datasets: qh8x-rm8r & drau-zphx
    $apiUrl2 = "https://data.texas.gov/resource/qh8x-rm8r.json?control_section_job_csj=$cleanCSJ&`$limit=5000"
    $tempJson2 = Join-Path $env:TEMP "txdot_qh8x_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
    
    Invoke-WebRequest -Uri $apiUrl2 -OutFile $tempJson2 -UserAgent "Mozilla/5.0"
    if (-not (Test-Path $tempJson2)) { throw "No data found for CSJ $cleanCSJ across TxDOT datasets." }
    
    $rawItems = Get-Content $tempJson2 -Raw | ConvertFrom-Json
    Remove-Item $tempJson2 -ErrorAction SilentlyContinue
    
    if (-not $rawItems -or $rawItems.Count -eq 0) { throw "No records found for CSJ $cleanCSJ across TxDOT datasets." }

    $projInfo = $null
    try {
        $apiUrlInfo = "https://data.texas.gov/resource/drau-zphx.json?control_section_job_csj=$cleanCSJ"
        $tempJsonInfo = Join-Path $env:TEMP "csj_info_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
        Invoke-WebRequest -Uri $apiUrlInfo -OutFile $tempJsonInfo -UserAgent "Mozilla/5.0"
        if (Test-Path $tempJsonInfo) {
            $infoArr = Get-Content $tempJsonInfo -Raw | ConvertFrom-Json
            if ($infoArr -and $infoArr.Count -gt 0) { $projInfo = $infoArr[0] }
            Remove-Item $tempJsonInfo -ErrorAction SilentlyContinue
        }
    } catch {}

    $firstRow = $rawItems[0]
    $isPreBid = $true

    $county = if ($firstRow.county) { $firstRow.county } else { $projInfo.county }
    $district = if ($firstRow.district_division) { $firstRow.district_division } else { if ($projInfo.district_division) { $projInfo.district_division } else { "TxDOT District" } }
    $projectId = if ($firstRow.project_id) { $firstRow.project_id } else { $projInfo.project_id }
    $fedProjNo = if ($projInfo -and $projInfo.federal_project_number) { $projInfo.federal_project_number } else { "N/A" }
    $stateProjNo = if ($projInfo -and $projInfo.state_project_number) { $projInfo.state_project_number } else { "N/A" }
    $contractNo = if ($projInfo -and $projInfo.contract_number) { $projInfo.contract_number } else { "N/A" }
    $hwy = if ($firstRow.highway) { $firstRow.highway } else { $projInfo.highway }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + " Working Days" } else { "N/A" }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { $projInfo.project_classification }
    $length = "0.000"
    $estimateTotal = if ($firstRow.sealed_engineer_s_estimate) { [double]$firstRow.sealed_engineer_s_estimate } else { [double]$projInfo.sealed_engineer_s_estimate }
    
    $letDateRaw = if ($firstRow.bids_will_be_opened_date) { $firstRow.bids_will_be_opened_date } else { $firstRow.project_approved_let_date }
    $bidsOpened = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("M/dd/yyyy") } else { "N/A" }

    $sortedItems = $rawItems | Sort-Object {[int]$_.bid_item_sequence_number}
    foreach ($item in $sortedItems) {
        $codeStr = if ($item.bid_code) { $item.bid_code.Replace("-", " ").Trim() } else { "" }
        $parts = $codeStr -split '\s+'
        $itemNo = if ($parts.Length -gt 0) { $parts[0] } else { "" }
        $specCode = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        $descStr = if ($item.bid_item_description) { $item.bid_item_description } else { $item.specification_description }

        # Fetch 2026 TxDOT Low Bidder Average Unit Price
        $avgUnitPrice = Get-2026LowBidAvgPrice $item.bid_code

        $itemsList += @{
            code = $codeStr
            itemNo = $itemNo
            specCode = $specCode
            description = $descStr
            unit = $item.measurement_unit
            quantity = [double]$item.bid_item_quantity
            engEstPrice = $avgUnitPrice
        }
    }
}

Remove-Item $tempCsvPath -ErrorAction SilentlyContinue

$guarantyCheck = [math]::Round($estimateTotal * 0.02, 2)
$dbeGoal = "0.00%"

# Initialize Excel COM
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$wb = $excel.Workbooks.Add()
$ws = $wb.Worksheets.Item(1)
$ws.Name = "CSJ Estimate Sheet"
try { $ws.Views.Item(1).DisplayGridlines = $true } catch {}

$ws.Cells.Font.Name = "Arial"
$ws.Cells.Font.Size = 8.5

# Top Banner Title (Row 1)
$estFormatted = $estimateTotal.ToString("C2")
$ws.Cells.Item(1, 1).Value = "$bidsOpened | $county | $hwy | $estFormatted | $projectType"
$ws.Cells.Item(1, 1).Font.Color = 12615680 # Dark Blue font (#0066CC)
$ws.Cells.Item(1, 1).Font.Bold = $true
$ws.Cells.Item(1, 1).Font.Size = 12

# Header Key-Value Block
$headers = @(
    @("COUNTY:", $county),
    @("DISTRICT:", $district),
    @("CSJ:", $cleanCSJ),
    @("PROJECT ID:", $projectId),
    @("PROJECT NO (Federal):", $fedProjNo),
    @("PROJECT NO (State):", $stateProjNo),
    @("CONTRACT NUMBER:", $contractNo),
    @("HWY:", $hwy),
    @("TIME:", $workingDays),
    @("TYPE:", $projectType),
    @("LENGTH:", $length),
    @("ESTIMATE:", "$estimateTotal"),
    @("GUARANTY CHECK:", "$guarantyCheck"),
    @("DBE GOAL:", $dbeGoal),
    @("BIDS RECEIVED UNTIL:", $bidsOpened),
    @("BIDS WILL BE OPENED:", $bidsOpened),
    @("APPROVED LET DATE:", $bidsOpened),
    @("ESTIMATED LET DATE:", $bidsOpened)
)

$r = 2
foreach ($h in $headers) {
    $ws.Cells.Item($r, 1).Value = $h[0]
    $ws.Cells.Item($r, 1).Font.Bold = $true
    
    $ws.Cells.Item($r, 2).Value = $h[1]
    
    # Format currency fields
    if ($h[0] -eq "ESTIMATE:" -or $h[0] -eq "GUARANTY CHECK:") {
        $ws.Cells.Item($r, 2).NumberFormat = "$#,##0.00"
    }

    # Yellow Highlight Fills for Key Fields (CSJ, TYPE, ESTIMATE, BIDS OPENED)
    if ($h[0] -eq "CSJ:" -or $h[0] -eq "TYPE:" -or $h[0] -eq "ESTIMATE:" -or $h[0] -eq "BIDS RECEIVED UNTIL:" -or $h[0] -eq "BIDS WILL BE OPENED:") {
        $ws.Cells.Item($r, 2).Interior.Color = 65535 # Bright Yellow (#FFFF00)
        $ws.Cells.Item($r, 2).Font.Bold = $true
    }
    
    $r++
}

# --- TABLE HEADER (Black background, White text) ---
$startTable = 21

$cols = @("ALT", "ITEM NO.", "SPEC CO.", "ITEM DESCRIPTION", "UNIT", "APPROXIMATE QUANTITIES", "UNIT PRICE", "EXTENDED PRICE")
for ($c = 1; $c -le $cols.Count; $c++) {
    $cell = $ws.Cells.Item($startTable, $c)
    $cell.Value = $cols[$c - 1]
    $cell.Interior.Color = 0 # Black background
    $cell.Font.Color = 16777215 # White text
    $cell.Font.Bold = $true
    $cell.HorizontalAlignment = -4108 # Center
}

# Alignments for table headers
$ws.Cells.Item($startTable, 4).HorizontalAlignment = -4131 # Left align Description
$ws.Cells.Item($startTable, 6).HorizontalAlignment = -4152 # Right align Quantities
$ws.Cells.Item($startTable, 7).HorizontalAlignment = -4152 # Right align Unit Price
$ws.Cells.Item($startTable, 8).HorizontalAlignment = -4152 # Right align Extended Price

# --- POPULATE PAY ITEMS DATA ROWS ---
$rowIdx = $startTable + 1

foreach ($item in $itemsList) {
    # Col A: ALT
    $ws.Cells.Item($rowIdx, 1).Value = ""
    
    # Col B: ITEM NO.
    $ws.Cells.Item($rowIdx, 2).Value = "'" + $item.itemNo
    $ws.Cells.Item($rowIdx, 2).HorizontalAlignment = -4108
    
    # Col C: SPEC CO.
    $ws.Cells.Item($rowIdx, 3).Value = "'" + $item.specCode
    $ws.Cells.Item($rowIdx, 3).HorizontalAlignment = -4108
    
    # Col D: ITEM DESCRIPTION
    $ws.Cells.Item($rowIdx, 4).Value = $item.description
    
    # Col E: UNIT
    $ws.Cells.Item($rowIdx, 5).Value = $item.unit
    $ws.Cells.Item($rowIdx, 5).HorizontalAlignment = -4108
    
    # Col F: APPROXIMATE QUANTITIES
    $ws.Cells.Item($rowIdx, 6).Value = "$($item.quantity)"
    $ws.Cells.Item($rowIdx, 6).NumberFormat = "#,##0.000"
    
    # Col G: UNIT PRICE (2026 TxDOT Low Bidder Average Unit Price)
    $ws.Cells.Item($rowIdx, 7).Value = [double]$item.engEstPrice
    $ws.Cells.Item($rowIdx, 7).NumberFormat = "$#,##0.00"
    
    # Col H: EXTENDED PRICE (Formula = Qty * Unit Price)
    $ws.Cells.Item($rowIdx, 8).Formula = "=F$rowIdx*G$rowIdx"
    $ws.Cells.Item($rowIdx, 8).NumberFormat = "$#,##0.00"
    
    $rowIdx++
}

# Add Total Row at bottom
$totalRowIdx = $rowIdx + 1

$ws.Cells.Item($totalRowIdx, 7).Value = "TOTAL"
$ws.Cells.Item($totalRowIdx, 7).Font.Bold = $true
$ws.Cells.Item($totalRowIdx, 7).HorizontalAlignment = -4152 # Right align

$firstItemRow = 22
$lastItemRow = $rowIdx - 1
$ws.Cells.Item($totalRowIdx, 8).Formula = "=SUM(H$firstItemRow:H$lastItemRow)"
$ws.Cells.Item($totalRowIdx, 8).NumberFormat = "$#,##0.00"
$ws.Cells.Item($totalRowIdx, 8).Interior.Color = 65535 # Bright Yellow (#FFFF00)
$ws.Cells.Item($totalRowIdx, 8).Font.Bold = $true

# Apply continuous thin grey borders to the full table range A2:H
$lastDataRow = $totalRowIdx
$fullRange = $ws.Range("A2:H$lastDataRow")
$fullRange.Borders.LineStyle = 1
$fullRange.Borders.Weight = 2
$fullRange.Borders.Color = 13882323

# --- MANDATORY LEGAL DISCLAIMER AT BOTTOM ---
$discTitleRow = $totalRowIdx + 1
$rTitle = $ws.Range("A${discTitleRow}:H${discTitleRow}")
$rTitle.Merge()
$rTitle.Value = "DISCLAIMER"
$rTitle.Font.Bold = $true
$rTitle.Font.Underline = 2 # Single Underline
$rTitle.Font.Color = 255 # Bright Red (#FF0000)
$rTitle.Font.Size = 9.5
$rTitle.HorizontalAlignment = -4108 # Center

$discLines = @(
    "This estimate has been generated by Amestx using historical average bid prices and publicly available data.",
    "It is provided solely as a preliminary reference to assist bidders in understanding potential cost ranges.",
    "Actual bid pricing may vary based on market conditions, project location, labor availability, material costs, and each bidder's internal calculations.",
    "Amestx does not guarantee the accuracy of this estimate and is not responsible for any miscalculations or pricing decisions made by bidders.",
    "All bidders must independently determine and submit their own unit prices based on their professional judgment and project-specific factors."
)

$currRow = $discTitleRow + 1
foreach ($line in $discLines) {
    $rLine = $ws.Range("A${currRow}:H${currRow}")
    $rLine.Merge()
    $rLine.Value = $line
    $rLine.Font.Italic = $true
    $rLine.Font.Bold = $true
    $rLine.Font.Size = 8.5
    $rLine.Font.Color = 7368816 # Medium Gray (#707070)
    $rLine.HorizontalAlignment = -4108 # Center
    $currRow++
}

# AutoFit Columns
$ws.Columns.AutoFit()
$ws.Columns.Item(4).ColumnWidth = 45 # Description column width

# Save Workbook
$wb.SaveAs($OutputPath, 51)
$wb.Close()
$excel.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "SUCCESS: Estimate Excel Sheet with 2026 Low Bidder Averages & Disclaimer generated at $OutputPath"
