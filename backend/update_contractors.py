"""
TxDOT Qualified Contractors Monthly Auto-Updater
=================================================
Fetches the official live TxDOT Qualified Vendors list from Tableau:
https://tableau.txdot.gov/views/VendorInformation/VendorList.csv

Parses contact info, qualification status, phone, fax, email, address, and letter,
and updates all local backend/frontend JSON caches.
"""

import urllib.request
import csv
import io
import json
import re
import os
import sys

def fetch_and_update_contractors():
    sys.stdout.reconfigure(encoding='utf-8')
    url = 'https://tableau.txdot.gov/views/VendorInformation/VendorList.csv'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})

    print(f"[INFO] Fetching latest live vendor data from Tableau: {url}...")
    with urllib.request.urlopen(req, timeout=30) as resp:
        csv_text = resp.read().decode('utf-8', errors='ignore')

    reader = csv.reader(io.StringIO(csv_text))
    header = next(reader, None)
    
    contractors = []
    
    for row in reader:
        if len(row) < 3:
            continue
        raw_contact, status, name = row[0], row[1], row[2].strip()
        if not name:
            continue
        
        address_lines = []
        phone = ''
        fax = ''
        email = ''
        
        for line in raw_contact.split('\n'):
            l = line.strip()
            if not l:
                continue
            if l.lower().startswith(('ph:', 'phone:', 'tel:')):
                phone = re.sub(r'^(ph:|phone:|tel:)\s*', '', l, flags=re.IGNORECASE).strip()
            elif l.lower().startswith('fax:'):
                fax = re.sub(r'^fax:\s*', '', l, flags=re.IGNORECASE).strip()
            elif l.lower().startswith(('email:', 'e-mail:')):
                email = re.sub(r'^(email:|e-mail:)\s*', '', l, flags=re.IGNORECASE).strip()
            else:
                address_lines.append(l)
        
        address = ', '.join(address_lines)
        first_char = name[0].upper() if name else '#'
        letter = first_char if first_char.isalpha() else '#'
        
        contractors.append({
            'name': name,
            'qualificationStatus': status,
            'address': address,
            'phone': phone,
            'fax': fax,
            'email': email,
            'letter': letter,
            'listType': 'TxDOT Qualified Vendors Registry'
        })

    # Sort contractors alphabetically
    contractors.sort(key=lambda x: x['name'].upper())

    print(f"[SUCCESS] Parsed {len(contractors)} official TxDOT qualified vendors.")

    # Target JSON files to overwrite
    target_paths = [
        r'C:\Users\fibrg\Desktop\Amestx Estimator App\frontend\public\downloads\prequalified_contractors.json',
        r'C:\Users\fibrg\Desktop\Amestx Estimator App\frontend\downloads\prequalified_contractors.json',
        r'C:\Users\fibrg\Desktop\Amestx Estimator App\data\downloads\prequalified_contractors.json'
    ]

    for p in target_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='utf-8') as f:
            json.dump(contractors, f, indent=2, ensure_ascii=False)
        print(f"  -> Updated: {p} ({os.path.getsize(p):,} bytes)")

if __name__ == '__main__':
    fetch_and_update_contractors()
