Add-Type -AssemblyName System.Web

$contractorsMap = [System.Collections.Generic.Dictionary[string, hashtable]]::new()
$letters = @('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','0')

function AddOrUpdateContractor($name, $detailsHtml, $letter, $sourceType) {
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $rawName = [System.Web.HttpUtility]::HtmlDecode($name) -replace '(?s)<[^>]+>', ''
    $cleanName = $rawName.Trim()
    if ($cleanName.Length -lt 2 -or $cleanName -match 'Monthly Estimate|Prequalified|Bidder|District|TxDOT') { return }
    $key = $cleanName.ToUpper()

    $address = ""
    $cityZip = ""
    $phone = ""
    $fax = ""
    $email = ""

    if (-not [string]::IsNullOrWhiteSpace($detailsHtml)) {
        $cleanDetails = [System.Web.HttpUtility]::HtmlDecode($detailsHtml)
        $lines = ($cleanDetails -split '<br\s*/?>') | ForEach-Object { ($_.Trim() -replace '(?s)<[^>]+>', '') } | Where-Object { $_.Length -gt 0 }
        
        $addrLines = @()
        foreach ($l in $lines) {
            if ($l -match '\((\d{3})\)\s*(\d{3}-\d{4})') {
                $phone = $matches[0]
            } elseif ($l -match 'FAX\s*\:\s*\(?(\d{3})\)?[\s-]*(\d{3}-\d{4})') {
                $fax = $matches[0]
            } elseif ($l -match 'mailto:([^"''\s>]+)' -or $l -match '[\w\.-]+@[\w\.-]+\.\w+') {
                $email = $matches[0]
            } else {
                $addrLines += $l
            }
        }
        if ($addrLines.Count -gt 0) { $address = $addrLines[0] }
        if ($addrLines.Count -gt 1) { $cityZip = $addrLines[1..($addrLines.Count - 1)] -join ", " }
    }

    if (-not $contractorsMap.ContainsKey($key)) {
        $firstChar = $cleanName.Substring(0,1).ToUpper()
        $letCode = if ($firstChar -match '[A-Z]') { $firstChar } else { '0-9' }
        
        $contractorsMap[$key] = @{
            name         = $cleanName
            address      = if ($address) { $address } else { "Address on file with TxDOT" }
            cityStateZip = if ($cityZip) { $cityZip } else { "" }
            phone        = if ($phone) { $phone } else { "" }
            fax          = if ($fax) { $fax } else { "" }
            email        = if ($email) { $email } else { "" }
            letter       = $letCode
            sources      = [System.Collections.Generic.HashSet[string]]::new()
        }
    } else {
        $existing = $contractorsMap[$key]
        if (-not [string]::IsNullOrWhiteSpace($address) -and ($existing.address -eq "Address on file with TxDOT" -or [string]::IsNullOrWhiteSpace($existing.address))) {
            $existing.address = $address
        }
        if (-not [string]::IsNullOrWhiteSpace($cityZip) -and [string]::IsNullOrWhiteSpace($existing.cityStateZip)) {
            $existing.cityStateZip = $cityZip
        }
        if (-not [string]::IsNullOrWhiteSpace($phone) -and [string]::IsNullOrWhiteSpace($existing.phone)) {
            $existing.phone = $phone
        }
        if (-not [string]::IsNullOrWhiteSpace($fax) -and [string]::IsNullOrWhiteSpace($existing.fax)) {
            $existing.fax = $fax
        }
        if (-not [string]::IsNullOrWhiteSpace($email) -and [string]::IsNullOrWhiteSpace($existing.email)) {
            $existing.email = $email
        }
    }
    $contractorsMap[$key].sources.Add($sourceType) | Out-Null
}

$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "Mozilla/5.0")
$webClient.Encoding = [System.Text.Encoding]::UTF8

Write-Host "1. Fetching Prequalified Contractors (PqList A-Z & 0)..."
foreach ($let in $letters) {
    $url = "https://www.dot.state.tx.us/insdtdot/orgchart/cmd/cserve/pqlist/PqList${let}.Htm"
    try {
        $html = $webClient.DownloadString($url)
        if ($html) {
            $matches = [regex]::Matches($html, '(?s)<td[^>]*valign=[''"]?top[''"]?[^>]*>\s*<b>(.*?)</b>\s*<br\s*/?>(.*?)</td>', 'IgnoreCase')
            foreach ($m in $matches) {
                $name = $m.Groups[1].Value
                $details = $m.Groups[2].Value
                $letCode = if ($let -eq '0') { '0-9' } else { $let }
                AddOrUpdateContractor $name $details $letCode "Prequalified"
            }
        }
    } catch {}
}

Write-Host "2. Fetching Bidder's Questionnaire Contractors (BqList A-Z & 0)..."
foreach ($let in $letters) {
    $url = "https://www.dot.state.tx.us/insdtdot/orgchart/cmd/cserve/bqlist/BqList${let}.Htm"
    try {
        $html = $webClient.DownloadString($url)
        if ($html) {
            $matches = [regex]::Matches($html, '(?s)<td[^>]*valign=[''"]?top[''"]?[^>]*>\s*<b>(.*?)</b>\s*<br\s*/?>(.*?)</td>', 'IgnoreCase')
            foreach ($m in $matches) {
                $name = $m.Groups[1].Value
                $details = $m.Groups[2].Value
                $letCode = if ($let -eq '0') { '0-9' } else { $let }
                AddOrUpdateContractor $name $details $letCode "Bidder's Questionnaire"
            }
        }
    } catch {}
}

Write-Host "3. Fetching Monthly Estimate Reports Contractors (CIS Reports A-Z & 0)..."
foreach ($let in $letters) {
    $url = "https://www.dot.state.tx.us/insdtdot/orgchart/cmd/cserve/cisrpts/cis_${let}.htm"
    try {
        $html = $webClient.DownloadString($url)
        if ($html) {
            $matches = [regex]::Matches($html, '(?s)<td[^>]*background-color:#C0C0C0[^>]*>\s*<b><a[^>]*>(.*?)</a></b>\s*</td>', 'IgnoreCase')
            foreach ($m in $matches) {
                $name = $m.Groups[1].Value
                $letCode = if ($let -eq '0') { '0-9' } else { $let }
                AddOrUpdateContractor $name "" $letCode "Monthly Estimate Reports"
            }
        }
    } catch {}
}

$outputList = [System.Collections.Generic.List[PSObject]]::new()

foreach ($kv in ($contractorsMap.Values | Sort-Object { $_.name })) {
    $sourceStr = ($kv.sources | Sort-Object) -join ", "
    $firstChar = $kv.name.Substring(0,1).ToUpper()
    $letterCode = if ($firstChar -match '[A-Z]') { $firstChar } else { '0-9' }

    $fullAddr = if (-not [string]::IsNullOrWhiteSpace($kv.address) -and -not [string]::IsNullOrWhiteSpace($kv.cityStateZip)) {
        "$($kv.address), $($kv.cityStateZip)"
    } elseif (-not [string]::IsNullOrWhiteSpace($kv.address)) {
        $kv.address
    } elseif (-not [string]::IsNullOrWhiteSpace($kv.cityStateZip)) {
        $kv.cityStateZip
    } else {
        "Address on file with TxDOT"
    }

    $outputList.Add([PSCustomObject]@{
        name         = $kv.name
        address      = $fullAddr
        phone        = $kv.phone
        fax          = $kv.fax
        email        = $kv.email
        letter       = $letterCode
        listType     = $sourceStr
    })
}

Write-Host "Total Unique Contractors Merged Across All 3 Lists: $($outputList.Count)"

$jsonPath = "downloads/prequalified_contractors.json"
$outputList | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
Write-Host "Successfully saved master contractor dataset to $jsonPath"
