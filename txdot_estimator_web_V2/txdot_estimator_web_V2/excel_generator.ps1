param (
    [Parameter(Mandatory=$true)]
    [string]$CSJ,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$cleanCSJ = $CSJ.Trim()

# Fetch CSV from Texas Open Data Portal API
$apiUrl = "https://data.texas.gov/resource/de7b-7dna.csv?control_section_job_csj=$cleanCSJ"
$tempCsvPath = Join-Path $env:TEMP "txdot_csj_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').csv"

$raw = $null
try {
    Invoke-WebRequest -Uri $apiUrl -OutFile $tempCsvPath -UserAgent "Mozilla/5.0"
    if ((Test-Path $tempCsvPath) -and (Get-Item $tempCsvPath).Length -gt 50) {
        $raw = Import-Csv $tempCsvPath
    }
} catch {}

$realBidders = @()
$itemsList = @()
$isPreBid = $false

if ($raw -and $raw.Count -gt 0) {
    # 1. Parse Bidders and Ranks
    $biddersGroup = $raw | Group-Object vendor_name | ForEach-Object {
        $row = $_.Group[0]
        [PSCustomObject]@{
            Rank = $row.bid_rank_sequence_number
            VendorName = $row.vendor_name
            TotalBidAmount = [double]$row.bid_total_amount
            IsLowBidder = $row.low_bidder_flag
        }
    }

    $engEstSummary = $biddersGroup | Where-Object {$_.VendorName -like "*Engineer*" -or $_.Rank -eq "EE"} | Select-Object -First 1
    $realBidders = @($biddersGroup | Where-Object {$_.VendorName -notlike "*Engineer*" -and $_.Rank -ne "EE"} | Sort-Object {[int]$_.Rank})

    $firstRow = $raw[0]
    $county = if ($firstRow.county) { $firstRow.county } else { "N/A" }
    $highway = if ($firstRow.highway) { $firstRow.highway } else { "N/A" }
    $projectName = if ($firstRow.project_name) { $firstRow.project_name } else { $firstRow.project_classification }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { "N/A" }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + " WORKING DAYS" } else { "N/A" }
    $seqNo = if ($firstRow.bid_item_sequence_number) { $firstRow.bid_item_sequence_number } else { "3214" }
    $projId = if ($firstRow.project_number) { $firstRow.project_number } else { "N/A" }
    $limitsFrom = if ($firstRow.contract_limits_from) { $firstRow.contract_limits_from } else { "N/A" }
    $limitsTo = if ($firstRow.contract_limits_to) { $firstRow.contract_limits_to } else { "N/A" }

    $letDateRaw = $firstRow.project_actual_let_date
    $letDate = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("MM/dd/yy") } else { "N/A" }
    $engEstTotal = [double]$firstRow.sealed_engineer_s_estimate

    # 2. Parse Unique Pay Items
    $itemsGroup = $raw | Group-Object bid_code, bid_item_sequence_number | Where-Object {$_.Group[0].bid_code -ne ""} | Sort-Object {[int]$_.Group[0].bid_item_sequence_number}
    
    foreach ($ig in $itemsGroup) {
        $itemRows = $ig.Group
        $f = $itemRows[0]
        
        $bPrices = @{}
        foreach ($ir in $itemRows) {
            $bPrices[$ir.vendor_name] = [double]$ir.bid_item_unit_price_amount
        }

        $itemsList += @{
            code = if ($f.bid_code) { $f.bid_code.Replace("-", " ") } else { "" }
            description = $f.bid_item_description
            unit = $f.measurement_unit
            quantity = [double]$f.bid_item_quantity
            engEstUnit = [double]$f.engineer_s_estimate_unit
            bidders = $bPrices
        }
    }
}
else {
    # 2. Fallback to Pre-Bid Datasets: qh8x-rm8r & drau-zphx
    $apiUrl2 = "https://data.texas.gov/resource/qh8x-rm8r.json?control_section_job_csj=$cleanCSJ&`$limit=5000"
    $tempJson2 = Join-Path $env:TEMP "txdot_tab_qh8x_$($cleanCSJ -replace '[^a-zA-Z0-9]', '_').json"
    
    Invoke-WebRequest -Uri $apiUrl2 -OutFile $tempJson2 -UserAgent "Mozilla/5.0"
    if (-not (Test-Path $tempJson2)) { throw "No data found for CSJ $cleanCSJ across TxDOT datasets." }
    
    $rawItems = Get-Content $tempJson2 -Raw | ConvertFrom-Json
    Remove-Item $tempJson2 -ErrorAction SilentlyContinue
    
    if (-not $rawItems -or $rawItems.Count -eq 0) { throw "No records returned for CSJ $cleanCSJ across TxDOT datasets." }

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
    $highway = if ($firstRow.highway) { $firstRow.highway } else { $projInfo.highway }
    $projectName = if ($projInfo -and $projInfo.project_name) { $projInfo.project_name } elseif ($projInfo -and $projInfo.project_description) { $projInfo.project_description } else { $firstRow.project_classification }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { $projInfo.project_classification }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + " WORKING DAYS" } else { "N/A" }
    $seqNo = if ($projInfo -and $projInfo.sequence_number) { $projInfo.sequence_number } else { "N/A" }
    $projId = if ($firstRow.project_id) { $firstRow.project_id } else { $projInfo.project_id }
    $limitsFrom = if ($projInfo -and $projInfo.contract_limits_from) { $projInfo.contract_limits_from } else { "N/A" }
    $limitsTo = if ($projInfo -and $projInfo.contract_limits_to) { $projInfo.contract_limits_to } else { "N/A" }

    $letDateRaw = if ($firstRow.bids_will_be_opened_date) { $firstRow.bids_will_be_opened_date } else { $firstRow.project_approved_let_date }
    $letDate = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("MM/dd/yy") } else { "N/A" }
    $engEstTotal = if ($firstRow.sealed_engineer_s_estimate) { [double]$firstRow.sealed_engineer_s_estimate } else { [double]$projInfo.sealed_engineer_s_estimate }

    $sortedItems = $rawItems | Sort-Object {[int]$_.bid_item_sequence_number}
    foreach ($item in $sortedItems) {
        $codeStr = if ($item.bid_code) { $item.bid_code.Replace("-", " ") } else { "" }
        $descStr = if ($item.bid_item_description) { $item.bid_item_description } else { $item.specification_description }

        $itemsList += @{
            code = $codeStr
            description = $descStr
            unit = $item.measurement_unit
            quantity = [double]$item.bid_item_quantity
            engEstUnit = 0.00
            bidders = @{}
        }
    }
}

Remove-Item $tempCsvPath -ErrorAction SilentlyContinue

# Initialize Excel COM
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$wb = $excel.Workbooks.Add()
$ws = $wb.Worksheets.Item(1)
$ws.Name = "Bid Tabulation"
try { $ws.Views.Item(1).DisplayGridlines = $true } catch {}

$ws.Cells.Font.Name = "Calibri"
$ws.Cells.Font.Size = 9

# --- TOP HEADER METADATA BLOCK ---
$ws.Cells.Item(1, 1).Value = "County:"
$ws.Cells.Item(1, 1).Font.Bold = $true
$ws.Cells.Item(1, 2).Value = $county

$ws.Cells.Item(2, 1).Value = "Type:"
$ws.Cells.Item(2, 1).Font.Bold = $true
$ws.Cells.Item(2, 2).Value = $projectType

$ws.Cells.Item(3, 1).Value = "Time:"
$ws.Cells.Item(3, 1).Font.Bold = $true
$ws.Cells.Item(3, 2).Value = $workingDays

$ws.Cells.Item(4, 1).Value = "Highway:"
$ws.Cells.Item(4, 1).Font.Bold = $true
$ws.Cells.Item(4, 2).Value = $highway

$ws.Cells.Item(5, 1).Value = "Length:"
$ws.Cells.Item(5, 1).Font.Bold = $true

$ws.Cells.Item(6, 1).Value = "Engineer's Estimate:"
$ws.Cells.Item(6, 1).Font.Bold = $true
$ws.Cells.Item(6, 2).Value = "$engEstTotal"
$ws.Cells.Item(6, 2).NumberFormat = "$#,##0.00"
$ws.Cells.Item(6, 2).Font.Bold = $true

$ws.Cells.Item(1, 3).Value = "Let Date:"
$ws.Cells.Item(1, 3).Font.Bold = $true
$ws.Cells.Item(1, 4).Value = $letDate

$ws.Cells.Item(2, 3).Value = "Seq No:"
$ws.Cells.Item(2, 3).Font.Bold = $true
$ws.Cells.Item(2, 4).Value = $seqNo

$ws.Cells.Item(3, 3).Value = "Project ID:"
$ws.Cells.Item(3, 3).Font.Bold = $true
$ws.Cells.Item(3, 4).Value = $projId

$ws.Cells.Item(4, 3).Value = "CCSJ:"
$ws.Cells.Item(4, 3).Font.Bold = $true
$ws.Cells.Item(4, 4).Value = $cleanCSJ

$ws.Cells.Item(5, 3).Value = "Limits From:"
$ws.Cells.Item(5, 3).Font.Bold = $true
$ws.Cells.Item(5, 4).Value = $limitsFrom

$ws.Cells.Item(5, 5).Value = "Limits To:"
$ws.Cells.Item(5, 5).Font.Bold = $true
$ws.Cells.Item(5, 6).Value = $limitsTo

# Light Grey Shading Box (Row 1, Cols E to I)
$bannerRange = $ws.Range("E1:I1")
$bannerRange.Merge()
$bannerRange.Interior.Color = 15000804 # Light Grey (#E0E0E0)

# --- BIDDER SUMMARY TABLE (Rows 8 to 19) ---
if ($realBidders.Count -gt 0) {
    $ws.Cells.Item(8, 1).Value = "Bidder"
    $ws.Cells.Item(8, 2).Value = "Bid Amount"
    $ws.Cells.Item(8, 3).Value = "% Over/Under"
    $ws.Cells.Item(8, 4).Value = "Company"
    $ws.Cells.Item(8, 5).Value = "Contact Info"

    $headerSummaryRange = $ws.Range("A8:E8")
    $headerSummaryRange.Font.Bold = $true
    $headerSummaryRange.Borders.Item(4).LineStyle = 1 # Bottom border

    # Eng. Est. Row
    $ws.Cells.Item(9, 1).Value = "Eng. Est."
    $ws.Cells.Item(9, 2).Value = "$engEstTotal"
    $ws.Cells.Item(9, 2).NumberFormat = "$#,##0.00"

    # Real Bidders Rows (Rows 10 to 19)
    $r = 10
    foreach ($b in $realBidders) {
        $ws.Cells.Item($r, 1).Value = "Bidder " + $b.Rank
        $ws.Cells.Item($r, 2).Value = "$($b.TotalBidAmount)"
        $ws.Cells.Item($r, 2).NumberFormat = "$#,##0.00"
        
        # % Over/Under Formula
        $ws.Cells.Item($r, 3).Formula = "=(B" + $r + "-B9)/B9"
        $ws.Cells.Item($r, 3).NumberFormat = "0.00%"
        
        $ws.Cells.Item($r, 4).Value = $b.VendorName
        
        if ([int]$b.Rank -eq 1 -or $b.IsLowBidder -eq "1" -or $b.IsLowBidder -eq "Y") {
            $ws.Cells.Item($r, 1).Font.Color = 32768 # Dark Green
            $ws.Cells.Item($r, 2).Font.Color = 32768
            $ws.Cells.Item($r, 3).Font.Color = 32768
            $ws.Cells.Item($r, 4).Font.Color = 32768
        }
        $r++
    }
}

# --- MAIN BID MATRIX TABLE (Header at Row 24) ---
$startMatrixRow = 24

$ws.Cells.Item($startMatrixRow, 1).Value = "Difference"
$ws.Cells.Item($startMatrixRow, 1).Font.Color = 255 # Red text

$ws.Cells.Item($startMatrixRow, 2).Value = "Item Code"
$ws.Cells.Item($startMatrixRow, 3).Value = "Description"
$ws.Cells.Item($startMatrixRow, 4).Value = "Unit"

$ws.Cells.Item($startMatrixRow, 5).Value = "Quantity"
$ws.Cells.Item($startMatrixRow, 5).Font.Color = 10053120 # Blue text (#006699)

$ws.Cells.Item($startMatrixRow, 6).Value = "Eng. Est."
$ws.Cells.Item($startMatrixRow, 6).Font.Color = 10498160 # Purple text (#7030A0)

if ($realBidders.Count -gt 0) {
    # Low Bidder / Bid Winner Headers (Cols G & H) - Green font ONLY
    $lowBidderName = $realBidders[0].VendorName
    $ws.Cells.Item($startMatrixRow, 7).Value = "1) " + $lowBidderName
    $ws.Cells.Item($startMatrixRow, 7).Font.Color = 52736 # Bright Green text (#00B050)
    $ws.Cells.Item($startMatrixRow, 7).WrapText = $true

    $ws.Cells.Item($startMatrixRow, 8).Value = "1) " + $lowBidderName
    $ws.Cells.Item($startMatrixRow, 8).Font.Color = 52736 # Bright Green text (#00B050)
    $ws.Cells.Item($startMatrixRow, 8).WrapText = $true

    # Other Bidders Headers (Cols I onwards) - Black font
    $colIndex = 9
    for ($i = 1; $i -lt $realBidders.Count; $i++) {
        $b = $realBidders[$i]
        $ws.Cells.Item($startMatrixRow, $colIndex).Value = ($i + 1).ToString() + ") " + $b.VendorName
        $ws.Cells.Item($startMatrixRow, $colIndex).Font.Color = 0 # Black text
        $ws.Cells.Item($startMatrixRow, $colIndex).WrapText = $true
        $colIndex++
    }
}

$matrixHeaderRange = $ws.Range("A" + $startMatrixRow + ":Q" + $startMatrixRow)
$matrixHeaderRange.Font.Bold = $true
$matrixHeaderRange.Borders.Item(4).LineStyle = 1

# --- POPULATE PAY ITEMS DATA ROWS ---
$rowIdx = $startMatrixRow + 1

foreach ($item in $itemsList) {
    # Col B: Item Code
    $ws.Cells.Item($rowIdx, 2).Value = "'" + $item.code
    $ws.Cells.Item($rowIdx, 2).HorizontalAlignment = -4108 # Center
    
    # Col C: Description
    $ws.Cells.Item($rowIdx, 3).Value = $item.description
    
    # Col D: Unit
    $ws.Cells.Item($rowIdx, 4).Value = $item.unit
    $ws.Cells.Item($rowIdx, 4).HorizontalAlignment = -4108
    
    # Col E: Quantity (BLUE font color)
    $ws.Cells.Item($rowIdx, 5).Value = "$($item.quantity)"
    $ws.Cells.Item($rowIdx, 5).NumberFormat = "#,##0.000"
    $ws.Cells.Item($rowIdx, 5).Font.Color = 10053120 # Blue (#006699)
    
    # Col F: Eng Est Unit Price (PURPLE font color)
    $ws.Cells.Item($rowIdx, 6).Value = "$($item.engEstUnit)"
    $ws.Cells.Item($rowIdx, 6).NumberFormat = "$#,##0.000"
    $ws.Cells.Item($rowIdx, 6).Font.Color = 10498160 # Purple (#7030A0)
    
    if ($realBidders.Count -gt 0) {
        $lowBidderName = $realBidders[0].VendorName
        $lowUnit = if ($item.bidders.ContainsKey($lowBidderName)) { $item.bidders[$lowBidderName] } else { 0.00 }
        
        # Col G: Low Bidder / Bid Winner Unit Price (GREEN font color)
        $ws.Cells.Item($rowIdx, 7).Value = "$lowUnit"
        $ws.Cells.Item($rowIdx, 7).NumberFormat = "$#,##0.000"
        $ws.Cells.Item($rowIdx, 7).Font.Color = 52736 # Bright Green (#00B050)
        
        # Col H: Low Bidder / Bid Winner Extension (Formula = E * G, GREEN font color)
        $ws.Cells.Item($rowIdx, 8).Formula = "=E" + $rowIdx + "*G" + $rowIdx
        $ws.Cells.Item($rowIdx, 8).NumberFormat = "$#,##0.000"
        $ws.Cells.Item($rowIdx, 8).Font.Color = 52736 # Bright Green (#00B050)
        
        # Col A: Difference (Low Unit Price - Eng Est Unit Price, RED font color)
        $ws.Cells.Item($rowIdx, 1).Formula = "=(G" + $rowIdx + "-F" + $rowIdx + ")"
        $ws.Cells.Item($rowIdx, 1).NumberFormat = "#,##0.00;(#,##0.00);""0.00"""
        $ws.Cells.Item($rowIdx, 1).Font.Color = 255 # Red
        
        # Cols I onwards: Other Bidders Unit Prices (BLACK font color)
        $c = 9
        for ($i = 1; $i -lt $realBidders.Count; $i++) {
            $bName = $realBidders[$i].VendorName
            if ($item.bidders.ContainsKey($bName)) {
                $uP = $item.bidders[$bName]
                $ws.Cells.Item($rowIdx, $c).Value = "$uP"
                $ws.Cells.Item($rowIdx, $c).NumberFormat = "$#,##0.000"
                $ws.Cells.Item($rowIdx, $c).Font.Color = 0 # Black
            }
            $c++
        }
    }
    
    $rowIdx++
}

# --- TOTALS ROW ---
if ($realBidders.Count -gt 0) {
    $totalRow = $rowIdx

    $ws.Cells.Item($totalRow, 5).Value = "TOTALS:"
    $ws.Cells.Item($totalRow, 5).Font.Bold = $true
    $ws.Cells.Item($totalRow, 5).HorizontalAlignment = -4152 # Right align

    # Eng Est Total (SUMPRODUCT Qty * Eng Est Unit Price, PURPLE font color)
    $ws.Cells.Item($totalRow, 6).Formula = "=SUMPRODUCT(E25:E" + ($totalRow - 1) + ", F25:F" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 6).NumberFormat = "$#,##0.000"
    $ws.Cells.Item($totalRow, 6).Font.Bold = $true
    $ws.Cells.Item($totalRow, 6).Font.Color = 10498160 # Purple

    # Low Bidder / Bid Winner Unit Price Sum (GREEN font color)
    $ws.Cells.Item($totalRow, 7).Formula = "=SUMPRODUCT(E25:E" + ($totalRow - 1) + ", G25:G" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 7).NumberFormat = "$#,##0.000"
    $ws.Cells.Item($totalRow, 7).Font.Bold = $true
    $ws.Cells.Item($totalRow, 7).Font.Color = 52736 # Bright Green

    # Low Bidder / Bid Winner Extension Sum (GREEN font color)
    $ws.Cells.Item($totalRow, 8).Formula = "=SUM(H25:H" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 8).NumberFormat = "$#,##0.000"
    $ws.Cells.Item($totalRow, 8).Font.Bold = $true
    $ws.Cells.Item($totalRow, 8).Font.Color = 52736 # Bright Green

    # Other Bidders Totals (SUMPRODUCT Qty * Unit Price, BLACK font color)
    $c = 9
    for ($i = 1; $i -lt $realBidders.Count; $i++) {
        $colLetter = [char](64 + $c)
        if ($c -gt 26) {
            $colLetter = "A" + [char](64 + ($c - 26))
        }
        $ws.Cells.Item($totalRow, $c).Formula = "=SUMPRODUCT(E25:E" + ($totalRow - 1) + ", " + $colLetter + "25:" + $colLetter + ($totalRow - 1) + ")"
        $ws.Cells.Item($totalRow, $c).NumberFormat = "$#,##0.000"
        $ws.Cells.Item($totalRow, $c).Font.Bold = $true
        $ws.Cells.Item($totalRow, $c).Font.Color = 0 # Black
        $c++
    }

    # Border for TOTALS row
    $totalsRange = $ws.Range("A" + $totalRow + ":Q" + $totalRow)
    $totalsRange.Borders.Item(3).LineStyle = 1 # Top border
    $totalsRange.Borders.Item(4).LineStyle = 9 # Double bottom border
}

# Explicit Column Widths matching screenshot media_1788574726542.png
$ws.Columns.Item(1).ColumnWidth = 14 # Difference
$ws.Columns.Item(2).ColumnWidth = 12 # Item Code
$ws.Columns.Item(3).ColumnWidth = 42 # Description
$ws.Columns.Item(4).ColumnWidth = 10 # Unit
$ws.Columns.Item(5).ColumnWidth = 14 # Quantity
$ws.Columns.Item(6).ColumnWidth = 15 # Eng. Est.
$ws.Columns.Item(7).ColumnWidth = 16 # 1) Low Bidder Unit
$ws.Columns.Item(8).ColumnWidth = 18 # 1) Low Bidder Ext

for ($col = 9; $col -le 25; $col++) {
    $ws.Columns.Item($col).ColumnWidth = 16
}

# Save Workbook
$wb.SaveAs($OutputPath, 51)
$wb.Close()
$excel.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "SUCCESS: Bid Tabulation Excel generated at $OutputPath"
