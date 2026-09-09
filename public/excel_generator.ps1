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
    $district = if ($firstRow.district_division) { $firstRow.district_division } else { "TxDOT District" }
    $highway = if ($firstRow.highway) { $firstRow.highway } else { "N/A" }
    $projectName = if ($firstRow.project_name) { $firstRow.project_name } else { $firstRow.project_classification }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { "N/A" }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + ".0 Working Days" } else { "N/A" }
    $seqNo = if ($firstRow.bid_item_sequence_number) { $firstRow.bid_item_sequence_number } else { "N/A" }
    $projId = if ($firstRow.project_number) { $firstRow.project_number } else { "N/A" }
    $fedProjNo = if ($firstRow.federal_project_number) { $firstRow.federal_project_number } else { "N/A" }
    $stateProjNo = if ($firstRow.state_project_number) { $firstRow.state_project_number } else { "N/A" }
    $contractNo = if ($firstRow.contract_number) { $firstRow.contract_number } else { "N/A" }
    $limitsFrom = if ($firstRow.contract_limits_from) { $firstRow.contract_limits_from } else { "N/A" }
    $limitsTo = if ($firstRow.contract_limits_to) { $firstRow.contract_limits_to } else { "N/A" }
    $length = "0"

    $letDateRaw = $firstRow.project_actual_let_date
    $letDate = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("M/d/yyyy") } else { "N/A" }
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

        $codeStr = if ($f.bid_code) { $f.bid_code.Replace("-", " ").Trim() } else { "" }
        $parts = $codeStr -split '\s+'
        $itemNo = if ($parts.Length -gt 0) { $parts[0] } else { "" }
        $specCode = if ($parts.Length -gt 1) { $parts[1] } else { "" }

        $itemsList += @{
            code = $codeStr
            itemNo = $itemNo
            specCode = $specCode
            description = $f.bid_item_description
            unit = $f.measurement_unit
            quantity = [double]$f.bid_item_quantity
            engEstUnit = [double]$f.engineer_s_estimate_unit
            bidders = $bPrices
        }
    }
}
else {
    # Fallback to Pre-Bid Datasets: qh8x-rm8r & drau-zphx
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
    $district = if ($firstRow.district_division) { $firstRow.district_division } else { if ($projInfo.district_division) { $projInfo.district_division } else { "TxDOT District" } }
    $highway = if ($firstRow.highway) { $firstRow.highway } else { $projInfo.highway }
    $projectName = if ($projInfo -and $projInfo.project_name) { $projInfo.project_name } elseif ($projInfo -and $projInfo.project_description) { $projInfo.project_description } else { $firstRow.project_classification }
    $projectType = if ($firstRow.project_classification) { $firstRow.project_classification } else { $projInfo.project_classification }
    $workingDays = if ($firstRow.maximum_number_of_working) { $firstRow.maximum_number_of_working + ".0 Working Days" } else { "N/A" }
    $seqNo = if ($projInfo -and $projInfo.sequence_number) { $projInfo.sequence_number } else { "N/A" }
    $projId = if ($firstRow.project_id) { $firstRow.project_id } else { $projInfo.project_id }
    $fedProjNo = if ($projInfo -and $projInfo.federal_project_number) { $projInfo.federal_project_number } else { "N/A" }
    $stateProjNo = if ($projInfo -and $projInfo.state_project_number) { $projInfo.state_project_number } else { "N/A" }
    $contractNo = if ($projInfo -and $projInfo.contract_number) { $projInfo.contract_number } else { "N/A" }
    $limitsFrom = if ($projInfo -and $projInfo.contract_limits_from) { $projInfo.contract_limits_from } else { "N/A" }
    $limitsTo = if ($projInfo -and $projInfo.contract_limits_to) { $projInfo.contract_limits_to } else { "N/A" }
    $length = "0"

    $letDateRaw = if ($firstRow.bids_will_be_opened_date) { $firstRow.bids_will_be_opened_date } else { $firstRow.project_approved_let_date }
    $letDate = if ($letDateRaw) { ([datetime]$letDateRaw).ToString("M/d/yyyy") } else { "N/A" }
    $engEstTotal = if ($firstRow.sealed_engineer_s_estimate) { [double]$firstRow.sealed_engineer_s_estimate } else { [double]$projInfo.sealed_engineer_s_estimate }

    $sortedItems = $rawItems | Sort-Object {[int]$_.bid_item_sequence_number}
    foreach ($item in $sortedItems) {
        $codeStr = if ($item.bid_code) { $item.bid_code.Replace("-", " ").Trim() } else { "" }
        $parts = $codeStr -split '\s+'
        $itemNo = if ($parts.Length -gt 0) { $parts[0] } else { "" }
        $specCode = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        $descStr = if ($item.bid_item_description) { $item.bid_item_description } else { $item.specification_description }

        $itemsList += @{
            code = $codeStr
            itemNo = $itemNo
            specCode = $specCode
            description = $descStr
            unit = $item.measurement_unit
            quantity = [double]$item.bid_item_quantity
            engEstUnit = 0.00
            bidders = @{}
        }
    }
}

Remove-Item $tempCsvPath -ErrorAction SilentlyContinue

$guarantyCheck = [math]::Round($engEstTotal * 0.02, 2)
$dbeGoal = "0.00%"

# Initialize Excel COM
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$wb = $excel.Workbooks.Add()
$ws = $wb.Worksheets.Item(1)
$ws.Name = "Bid Tabulation"
try { $ws.Views.Item(1).DisplayGridlines = $true } catch {}

$ws.Cells.Font.Name = "Arial"
$ws.Cells.Font.Size = 9

# --- ROW 1: TOP BANNER TITLE (Blue Bold Font) ---
$estFormatted = $engEstTotal.ToString("C2")
$ws.Cells.Item(1, 1).Value = "$letDate | $county | $highway | $estFormatted | $projectType"
$ws.Cells.Item(1, 1).Font.Color = 12615680 # Dark Blue font (#0066CC)
$ws.Cells.Item(1, 1).Font.Bold = $true
$ws.Cells.Item(1, 1).Font.Size = 12

# --- ROWS 2 to 19: KEY-VALUE METADATA BLOCK (Matching Projects Tasks Sheet format) ---
$headers = @(
    @("COUNTY:", $county),
    @("DISTRICT:", $district),
    @("CSJ:", $cleanCSJ),
    @("PROJECT ID:", $projId),
    @("PROJECT NO (Federal):", $fedProjNo),
    @("PROJECT NO (State):", $stateProjNo),
    @("CONTRACT NUMBER:", $contractNo),
    @("HWY:", $highway),
    @("TIME:", $workingDays),
    @("TYPE:", $projectType),
    @("LENGTH:", $length),
    @("ESTIMATE:", "$engEstTotal"),
    @("GUARANTY CHECK:", "$guarantyCheck"),
    @("DBE GOAL:", $dbeGoal),
    @("BIDS RECEIVED UNTIL:", $letDate),
    @("BIDS WILL BE OPENED:", $letDate),
    @("APPROVED LET DATE:", $letDate),
    @("ESTIMATED LET DATE:", $letDate)
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

# --- SUMMARY OF BIDDERS TABLE (Positioned at Column D, Rows 3+) ---
if ($realBidders.Count -gt 0) {
    $ws.Cells.Item(3, 4).Value = "Bidder"
    $ws.Cells.Item(3, 5).Value = "Bid Amount"
    $ws.Cells.Item(3, 6).Value = "% Over/Under"
    $ws.Cells.Item(3, 7).Value = "Company"
    $ws.Cells.Item(3, 8).Value = "Contact Info"

    $summaryHeaderRange = $ws.Range("D3:H3")
    $summaryHeaderRange.Font.Bold = $true
    $summaryHeaderRange.Borders.Item(4).LineStyle = 1 # Bottom border

    # Eng. Est. Row (Row 4)
    $ws.Cells.Item(4, 4).Value = "Eng. Est."
    $ws.Cells.Item(4, 5).Value = "$engEstTotal"
    $ws.Cells.Item(4, 5).NumberFormat = "$#,##0.00"

    # Real Bidders Rows (Rows 5+)
    $br = 5
    foreach ($b in $realBidders) {
        $ws.Cells.Item($br, 4).Value = "Bidder " + $b.Rank
        $ws.Cells.Item($br, 5).Value = "$($b.TotalBidAmount)"
        $ws.Cells.Item($br, 5).NumberFormat = "$#,##0.00"
        
        # % Over/Under Formula
        $ws.Cells.Item($br, 6).Formula = "=(E" + $br + "-E4)/E4"
        $ws.Cells.Item($br, 6).NumberFormat = "0.00%"
        
        $ws.Cells.Item($br, 7).Value = $b.VendorName
        
        if ([int]$b.Rank -eq 1 -or $b.IsLowBidder -eq "1" -or $b.IsLowBidder -eq "Y") {
            $ws.Cells.Item($br, 4).Font.Color = 32768 # Green font
            $ws.Cells.Item($br, 5).Font.Color = 32768
            $ws.Cells.Item($br, 6).Font.Color = 32768
            $ws.Cells.Item($br, 7).Font.Color = 32768
        }
        $br++
    }
}

# --- MAIN BID MATRIX TABLE (Starting at Row 22) ---
$startMatrixRow = 22

# Black Background Header Row with White Text
$cols = @("Difference", "ITEM NO.", "SPEC CO.", "ITEM DESCRIPTION", "UNIT", "APPROXIMATE QUANTITIES", "Eng. Est.")

if ($realBidders.Count -gt 0) {
    $lowBidderName = $realBidders[0].VendorName
    $cols += "1) $lowBidderName" # Unit Price
    $cols += "1) $lowBidderName" # Extended Price
    for ($i = 1; $i -lt $realBidders.Count; $i++) {
        $cols += ($i + 1).ToString() + ") " + $realBidders[$i].VendorName
    }
} else {
    $cols += "Unit Price"
    $cols += "Extended Price"
}

for ($c = 1; $c -le $cols.Count; $c++) {
    $cell = $ws.Cells.Item($startMatrixRow, $c)
    $cell.Value = $cols[$c - 1]
    $cell.Interior.Color = 0 # Black background
    $cell.Font.Color = 16777215 # White text
    $cell.Font.Bold = $true
    $cell.WrapText = $true
    $cell.HorizontalAlignment = -4108 # Center
}

# Adjust specific alignments for header row
$ws.Cells.Item($startMatrixRow, 4).HorizontalAlignment = -4131 # Left align Description
$ws.Cells.Item($startMatrixRow, 6).HorizontalAlignment = -4152 # Right align Quantities

# --- POPULATE PAY ITEMS DATA ROWS ---
$rowIdx = $startMatrixRow + 1

foreach ($item in $itemsList) {
    # Col B: ITEM NO.
    $ws.Cells.Item($rowIdx, 2).Value = "'" + $item.itemNo
    $ws.Cells.Item($rowIdx, 2).HorizontalAlignment = -4108 # Center
    
    # Col C: SPEC CO.
    $ws.Cells.Item($rowIdx, 3).Value = "'" + $item.specCode
    $ws.Cells.Item($rowIdx, 3).HorizontalAlignment = -4108 # Center
    
    # Col D: ITEM DESCRIPTION
    $ws.Cells.Item($rowIdx, 4).Value = $item.description
    
    # Col E: UNIT (BLUE font color #006699)
    $ws.Cells.Item($rowIdx, 5).Value = $item.unit
    $ws.Cells.Item($rowIdx, 5).HorizontalAlignment = -4108
    $ws.Cells.Item($rowIdx, 5).Font.Color = 10053120 # Blue (#006699)
    
    # Col F: APPROXIMATE QUANTITIES (BLUE font color #006699)
    $ws.Cells.Item($rowIdx, 6).Value = "$($item.quantity)"
    $ws.Cells.Item($rowIdx, 6).NumberFormat = "#,##0.000"
    $ws.Cells.Item($rowIdx, 6).Font.Color = 10053120 # Blue (#006699)
    
    # Col G: Eng Est Unit Price (PURPLE font color #7030A0)
    $ws.Cells.Item($rowIdx, 7).Value = "$($item.engEstUnit)"
    $ws.Cells.Item($rowIdx, 7).NumberFormat = "$#,##0.000"
    $ws.Cells.Item($rowIdx, 7).Font.Color = 10498160 # Purple (#7030A0)
    
    if ($realBidders.Count -gt 0) {
        $lowBidderName = $realBidders[0].VendorName
        $lowUnit = if ($item.bidders.ContainsKey($lowBidderName)) { $item.bidders[$lowBidderName] } else { 0.00 }
        
        # Col H: Low Bidder Unit Price (GREEN font color #00B050)
        $ws.Cells.Item($rowIdx, 8).Value = "$lowUnit"
        $ws.Cells.Item($rowIdx, 8).NumberFormat = "$#,##0.000"
        $ws.Cells.Item($rowIdx, 8).Font.Color = 52736 # Bright Green (#00B050)
        
        # Col I: Low Bidder Extension (Formula = F * H, GREEN font color #00B050)
        $ws.Cells.Item($rowIdx, 9).Formula = "=F" + $rowIdx + "*H" + $rowIdx
        $ws.Cells.Item($rowIdx, 9).NumberFormat = "$#,##0.000"
        $ws.Cells.Item($rowIdx, 9).Font.Color = 52736 # Bright Green (#00B050)
        
        # Col A: Difference (Low Unit Price - Eng Est Unit Price, RED font color #FF0000)
        $ws.Cells.Item($rowIdx, 1).Formula = "=(H" + $rowIdx + "-G" + $rowIdx + ")"
        $ws.Cells.Item($rowIdx, 1).NumberFormat = "#,##0.00;(#,##0.00);""0.00"""
        $ws.Cells.Item($rowIdx, 1).Font.Color = 255 # Red
        
        # Cols J onwards: Other Bidders Unit Prices (BLACK font color)
        $c = 10
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
    } else {
        # Col H: Unit Price ($0.00)
        $ws.Cells.Item($rowIdx, 8).Value = 0.00
        $ws.Cells.Item($rowIdx, 8).NumberFormat = "$#,##0.000"
        
        # Col I: Extended Price (=F*H)
        $ws.Cells.Item($rowIdx, 9).Formula = "=F" + $rowIdx + "*H" + $rowIdx
        $ws.Cells.Item($rowIdx, 9).NumberFormat = "$#,##0.000"
        
        # Col A: Difference
        $ws.Cells.Item($rowIdx, 1).Value = 0.00
        $ws.Cells.Item($rowIdx, 1).Font.Color = 255
    }
    
    $rowIdx++
}

# --- TOTALS ROW AT BOTTOM ---
$totalRow = $rowIdx

$ws.Cells.Item($totalRow, 6).Value = "TOTAL"
$ws.Cells.Item($totalRow, 6).Font.Bold = $true
$ws.Cells.Item($totalRow, 6).HorizontalAlignment = -4152 # Right align

# Eng Est Total (SUMPRODUCT Qty * Eng Est Unit Price, PURPLE font color)
$ws.Cells.Item($totalRow, 7).Formula = "=SUMPRODUCT(F23:F" + ($totalRow - 1) + ", G23:G" + ($totalRow - 1) + ")"
$ws.Cells.Item($totalRow, 7).NumberFormat = "$#,##0.00"
$ws.Cells.Item($totalRow, 7).Font.Bold = $true
$ws.Cells.Item($totalRow, 7).Font.Color = 10498160 # Purple

if ($realBidders.Count -gt 0) {
    # Low Bidder Unit Price Sum (GREEN font color)
    $ws.Cells.Item($totalRow, 8).Formula = "=SUMPRODUCT(F23:F" + ($totalRow - 1) + ", H23:H" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 8).NumberFormat = "$#,##0.00"
    $ws.Cells.Item($totalRow, 8).Font.Bold = $true
    $ws.Cells.Item($totalRow, 8).Font.Color = 52736 # Bright Green

    # Low Bidder Extension Sum (GREEN font color, Yellow fill)
    $ws.Cells.Item($totalRow, 9).Formula = "=SUM(I23:I" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 9).NumberFormat = "$#,##0.00"
    $ws.Cells.Item($totalRow, 9).Font.Bold = $true
    $ws.Cells.Item($totalRow, 9).Font.Color = 52736 # Bright Green
    $ws.Cells.Item($totalRow, 9).Interior.Color = 65535 # Bright Yellow

    # Other Bidders Totals (SUMPRODUCT Qty * Unit Price, BLACK font color, Yellow fill)
    $c = 10
    for ($i = 1; $i -lt $realBidders.Count; $i++) {
        $colLetter = [char](64 + $c)
        if ($c -gt 26) {
            $colLetter = "A" + [char](64 + ($c - 26))
        }
        $ws.Cells.Item($totalRow, $c).Formula = "=SUMPRODUCT(F23:F" + ($totalRow - 1) + ", " + $colLetter + "23:" + $colLetter + ($totalRow - 1) + ")"
        $ws.Cells.Item($totalRow, $c).NumberFormat = "$#,##0.00"
        $ws.Cells.Item($totalRow, $c).Font.Bold = $true
        $ws.Cells.Item($totalRow, $c).Font.Color = 0 # Black
        $ws.Cells.Item($totalRow, $c).Interior.Color = 65535 # Bright Yellow
        $c++
    }
} else {
    $ws.Cells.Item($totalRow, 8).Value = 0.00
    $ws.Cells.Item($totalRow, 8).NumberFormat = "$#,##0.00"
    $ws.Cells.Item($totalRow, 8).Font.Bold = $true
    
    $ws.Cells.Item($totalRow, 9).Formula = "=SUM(I23:I" + ($totalRow - 1) + ")"
    $ws.Cells.Item($totalRow, 9).NumberFormat = "$#,##0.00"
    $ws.Cells.Item($totalRow, 9).Font.Bold = $true
    $ws.Cells.Item($totalRow, 9).Interior.Color = 65535 # Bright Yellow
}

# Border for TOTALS row
$lastColIdx = [math]::Max(9, (8 + $realBidders.Count))
$lastColLetter = [char](64 + $lastColIdx)
if ($lastColIdx -gt 26) { $lastColLetter = "A" + [char](64 + ($lastColIdx - 26)) }

$totalsRange = $ws.Range("A" + $totalRow + ":" + $lastColLetter + $totalRow)
$totalsRange.Borders.Item(3).LineStyle = 1 # Top border
$totalsRange.Borders.Item(4).LineStyle = 9 # Double bottom border

# Explicit Column Widths matching Projects Tasks Sheet
$ws.Columns.Item(1).ColumnWidth = 12 # Difference
$ws.Columns.Item(2).ColumnWidth = 10 # ITEM NO.
$ws.Columns.Item(3).ColumnWidth = 10 # SPEC CO.
$ws.Columns.Item(4).ColumnWidth = 45 # ITEM DESCRIPTION
$ws.Columns.Item(5).ColumnWidth = 10 # UNIT
$ws.Columns.Item(6).ColumnWidth = 22 # APPROXIMATE QUANTITIES
$ws.Columns.Item(7).ColumnWidth = 15 # Eng. Est.
$ws.Columns.Item(8).ColumnWidth = 18 # Low Bidder Unit
$ws.Columns.Item(9).ColumnWidth = 18 # Low Bidder Ext

for ($col = 10; $col -le 25; $col++) {
    $ws.Columns.Item($col).ColumnWidth = 18
}

# Apply thin continuous borders to the metadata & table range
$allRange = $ws.Range("A2:" + $lastColLetter + $totalRow)
$allRange.Borders.LineStyle = 1
$allRange.Borders.Weight = 2
$allRange.Borders.Color = 13882323

# Save Workbook
$wb.SaveAs($OutputPath, 51)
$wb.Close()
$excel.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "SUCCESS: Bid Tabulation Excel generated at $OutputPath matching Projects Tasks Sheet format!"
