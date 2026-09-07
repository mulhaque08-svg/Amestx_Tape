# Amestx™ — TxDOT Bid Estimator & Proposal Portal

A lightweight multi-page web application for Texas Department of Transportation (TxDOT) bid estimations, monthly letting proposal analytics, direct FTP PDF document access, and Excel matrix generation.

## 🚀 Features

- **Monthly TxDOT Letting Browser**: Browse completed and scheduled highway proposals across all Texas counties and letting months (Statewide & Local Construction/Maintenance).
- **Controlling CSJ (CCSJ) Proposal Aggregation**: Group multi-county sub-CSJs under master Controlling CSJ proposal jobs matching TxDOT Notice to Contractors and BidCobra schedules.
- **Itemized Bid Tabulation & Engineer Estimates**: View official bid proposals, low bidder rankings, line-item unit prices, and engineer estimate comparisons.
- **Excel Matrix Export**: Export complete CSJ Bid Tabulations and Task Item Estimates directly to `.xlsx` spreadsheets.
- **Direct PDF Proposal & Plan Downloads**: Instant verification and downloading of TxDOT PDF proposals and construction plan sets.
- **No-Cache High Availability**: Built-in HTTP no-cache headers and dynamic client timestamp cache-busting.

## 🛠️ Architecture & Tech Stack

- **Frontend**: HTML5, Tailwind CSS, JavaScript ES6+
- **Backend**: Native PowerShell (`System.Net.HttpListener`) on Port 8080
- **Data Feeds**:
  - TxDOT Socrata Open Data API (`drau-zphx` & `de7b-7dna`)
  - TxDOT Public FTP Server (`ftp.txdot.gov`)

## ⚡ Quick Start

### Prerequisites
- Windows OS
- PowerShell 5.1 or PowerShell 7+

### Launching the Application

1. Open PowerShell and navigate to the project directory:
   ```powershell
   cd path\to\txdot_estimator_web
   ```

2. Start the local web server daemon:
   ```powershell
   powershell -ExecutionPolicy Bypass -File server.ps1
   ```

3. Open your browser and visit:
   ```
   http://localhost:8080/
   ```

## 📂 Project Structure

```
txdot_estimator_web/
├── server.ps1                    # Main PowerShell web server daemon (port 8080)
├── generate_monthly_caches.ps1   # Cache builder for monthly letting proposals
├── excel_generator.ps1           # Excel Bid Tabulation matrix generator
├── estimate_generator.ps1        # Excel Task Estimate sheet generator
├── download_monthly_pdfs.ps1     # TxDOT FTP PDF downloader
├── auto_update_schedule.ps1      # Hands-free weekly auto-update background job
├── scan_ftp_pdfs.ps1             # TxDOT FTP PDF scanner & mapper
├── enrich_ftp_maps.ps1           # FTP map enrichment script
├── GEMINI.md                     # Permanent agent prompt & development rules
├── AGENTS.md                     # Agent role configuration
├── public/
│   ├── index.html                # Web application frontend UI
│   └── downloads/                # Monthly cache JSON files & downloaded PDFs
└── README.md                     # Project documentation
```
