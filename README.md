# Amestx TxDOT Estimator & Proposal Platform (Modular Architecture)

A modern, decoupled civil construction letting estimator and bid tabulation matrix generator for Texas Department of Transportation (TxDOT) pre-bid and post-bid lettings.

## Directory Structure

```text
Amestx Estimator App/
├── backend/
│   ├── scrapers/
│   │   ├── txdot.py          # Automated TxDOT FTP/Portal letting scraper (Pulls 100% of all 159 projects)
│   │   └── txdot_icx.py      # TxDOT Bid Tabulation ICX parser
│   ├── models.py             # Amestx 12-Month Historical Price Calculator (Python)
│   ├── api.py                # Fast REST API endpoints
│   └── main.py               # Backend runner
│
├── frontend/
│   ├── index.html            # Landing / Marketing Page
│   ├── app.html              # App Dashboard
│   ├── home.html             # Homepage
│   └── js/
│       ├── calculator.js     # Single Source of Truth 12-Month Unit Price Engine
│       ├── excelExport.js    # Tab-specific Excel Exporters (Tab 1, Tab 5, Tab 6)
│       └── app.js            # UI Tab Rendering & Event Logic
│
├── data/
│   └── projects.json         # Unified complete TxDOT dataset
│
├── requirements.txt          # Python dependencies
└── README.md
```

## Features
- **100% TxDOT Project Data Ingestion**: Parses all 159 monthly letting projects directly via server-side Python scrapers.
- **Isolated Unit Price Calculator (`calculator.js`)**: Guaranteed mathematical consistency using authentic TxDOT 12-month low bidder historical averages.
- **Strict Tab Export Isolation (`excelExport.js`)**:
  - **Tab 1 (Project Tasks)**: Exports $0.00 zero-price proposal sheet for bidders (NO disclaimer).
  - **Tab 6 (Amestx Estimate)**: Exports $146,250.00 Amestx Estimate sheet with 12-month rates + Legal Disclaimer.
  - **Tab 5 (Bid Tabulations)**: Exports itemized bidder comparison matrix.
