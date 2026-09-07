$url = "https://ftp.txdot.gov/plans/State-Let-Construction/2026/09%20September/09%20Proposals/Bee%200101-01-070%20Proposal.pdf"
$pair = 'planuser:txdotplans'
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$authHeader = 'Basic ' + $base64

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("Authorization", $authHeader)
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

try {
    Write-Host "Downloading $url ..."
    $wc.DownloadFile($url, "test_bee.pdf")
    Write-Host "SUCCESS: File size is $((Get-Item 'test_bee.pdf').Length) bytes"
    Remove-Item "test_bee.pdf" -Force
} catch {
    Write-Host "FAIL: $($_.Exception.Message)"
}
