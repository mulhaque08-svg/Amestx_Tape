# ==============================================================================
# TxDOT Estimator Web - Hands-Free Weekly Auto-Updater (Option A)
# Automatically scans, enriches, and downloads TxDOT proposals & plans
# for active past months, current month, and upcoming months.
# ==============================================================================

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$downloadsDir = Join-Path $PSScriptRoot "public\downloads"
if (-not (Test-Path $downloadsDir)) { New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null }

$logFile = Join-Path $downloadsDir "auto_update.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log([string]$msg) {
    $line = "[$timestamp] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "=========================================================="
Write-Log "Starting Weekly TxDOT PDF Auto-Update Routine"
Write-Log "=========================================================="

# Calculate Target Months: Current Month, Past 2 Months, Next 2 Months
$now = Get-Date
$targetMonths = @(
    $now.AddMonths(-2).ToString("yyyy-MM"),
    $now.AddMonths(-1).ToString("yyyy-MM"),
    $now.ToString("yyyy-MM"),
    $now.AddMonths(1).ToString("yyyy-MM"),
    $now.AddMonths(2).ToString("yyyy-MM")
)

Write-Log "Target Months for Sync: $($targetMonths -join ', ')"

# 1. Scan TxDOT FTP for direct PDF links across target months
$scanScript = Join-Path $PSScriptRoot "scan_ftp_pdfs.ps1"
if (Test-Path $scanScript) {
    foreach ($m in $targetMonths) {
        Write-Log "Scanning TxDOT FTP for month: $m ..."
        try {
            & $scanScript -Month $m
        } catch {
            Write-Log "Error scanning month $m: $_"
        }
    }
} else {
    Write-Log "WARNING: scan_ftp_pdfs.ps1 not found!"
}

# 2. Enrich maps with Socrata CCSJ lookups
$enrichScript = Join-Path $PSScriptRoot "enrich_ftp_maps.ps1"
if (Test-Path $enrichScript) {
    Write-Log "Enriching FTP maps with Socrata CCSJ mappings..."
    try {
        & $enrichScript
    } catch {
        Write-Log "Error enriching maps: $_"
    }
} else {
    Write-Log "WARNING: enrich_ftp_maps.ps1 not found!"
}

# 3. Download any missing proposals & plans locally
$dlScript = Join-Path $PSScriptRoot "download_monthly_pdfs.ps1"
if (Test-Path $dlScript) {
    foreach ($m in $targetMonths) {
        Write-Log "Downloading missing local PDFs for month: $m ..."
        try {
            & $dlScript -Month $m
        } catch {
            Write-Log "Error downloading PDFs for $m: $_"
        }
    }
} else {
    Write-Log "WARNING: download_monthly_pdfs.ps1 not found!"
}

Write-Log "=========================================================="
Write-Log "Weekly Auto-Update Completed Successfully!"
Write-Log "=========================================================="
