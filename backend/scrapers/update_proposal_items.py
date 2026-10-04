import os
import json
import re
import urllib.request
import pypdf

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FRONTEND_DOWNLOADS = os.path.join(BASE_DIR, 'frontend', 'downloads')
PUBLIC_DOWNLOADS = os.path.join(BASE_DIR, 'frontend', 'public', 'downloads')
DATA_DOWNLOADS = os.path.join(BASE_DIR, 'data', 'downloads')

CACHE_FILE_FRONTEND = os.path.join(FRONTEND_DOWNLOADS, 'proposal_items_cache.json')
CACHE_FILE_PUBLIC = os.path.join(PUBLIC_DOWNLOADS, 'proposal_items_cache.json')
CACHE_FILE_DATA = os.path.join(DATA_DOWNLOADS, 'proposal_items_cache.json')

def load_items_cache():
    if os.path.exists(CACHE_FILE_FRONTEND):
        try:
            with open(CACHE_FILE_FRONTEND, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_items_cache(cache):
    for path in [CACHE_FILE_FRONTEND, CACHE_FILE_PUBLIC, CACHE_FILE_DATA]:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(cache, f, indent=2)

def extract_items_from_pdf(pdf_path):
    reader = pypdf.PdfReader(pdf_path)
    items = []
    
    for i, page in enumerate(reader.pages):
        t = page.extract_text()
        if 'FORM 234' in t.upper() or 'PROPOSAL SHEET' in t.upper() or 'ALT' in t.upper():
            lines = [l.strip() for l in t.split('\n') if l.strip()]
            j = 0
            while j < len(lines):
                line = lines[j]
                m = re.search(r'^(?:ALT\s+)?(\d{4})\s+(\d{4})', line)
                if m:
                    code = f"{m.group(1)} {m.group(2)}"
                    desc = ""
                    unit = ""
                    qty = 0.0
                    k = j + 1
                    while k < min(j + 10, len(lines)):
                        l_k = lines[k]
                        if l_k in ['BAG', 'TON', 'GAL', 'LS', 'CY', 'SY', 'LF', 'EA', 'MO', 'DAY', 'AC', 'MI', 'LMI', 'LB', 'SQFT']:
                            unit = l_k
                            if k + 1 < len(lines):
                                try:
                                    qty = float(lines[k+1].replace(',', ''))
                                except ValueError:
                                    pass
                            break
                        elif not desc and not l_k.startswith('DOLLARS') and not l_k.startswith('and') and not l_k.isdigit():
                            desc = l_k
                        k += 1
                    items.append({
                        'alt': '-',
                        'code': code,
                        'description': desc,
                        'unit': unit,
                        'quantity': qty,
                        'engEstUnit': 0.0,
                        'lowUnit': 0.0,
                        'bidders': {}
                    })
                else:
                    m_single = re.search(r'^\s*(\d{4})\s*$', line)
                    if m_single and j + 1 < len(lines):
                        next_m = re.search(r'^\s*(\d{4})\s*$', lines[j+1])
                        if next_m:
                            code = f"{m_single.group(1)} {next_m.group(1)}"
                            desc = ""
                            unit = ""
                            qty = 0.0
                            k = j + 2
                            while k < min(j + 10, len(lines)):
                                l_k = lines[k]
                                if l_k in ['BAG', 'TON', 'GAL', 'LS', 'CY', 'SY', 'LF', 'EA', 'MO', 'DAY', 'AC', 'MI', 'LMI', 'LB', 'SQFT']:
                                    unit = l_k
                                    if k + 1 < len(lines):
                                        try:
                                            qty = float(lines[k+1].replace(',', ''))
                                        except ValueError:
                                            pass
                                    break
                                elif not desc and not l_k.startswith('DOLLARS') and not l_k.startswith('and') and not l_k.isdigit():
                                    desc = l_k
                                k += 1
                            items.append({
                                'alt': '-',
                                'code': code,
                                'description': desc,
                                'unit': unit,
                                'quantity': qty,
                                'engEstUnit': 0.0,
                                'lowUnit': 0.0,
                                'bidders': {}
                            })
                j += 1
    return items

def update_csj_6508_16_001():
    cache = load_items_cache()
    
    # 1. Parse scratch_hidalgo.pdf if available
    hidalgo_pdf = os.path.join(BASE_DIR, 'scratch_hidalgo.pdf')
    if os.path.exists(hidalgo_pdf):
        parsed_items = extract_items_from_pdf(hidalgo_pdf)
        if parsed_items:
            cache["6508-16-001"] = parsed_items
            print(f"Extracted {len(parsed_items)} items for 6508-16-001 from PDF.")
    
    if "6508-16-001" not in cache or len(cache["6508-16-001"]) == 0:
        # Hardcode fallback for 6508-16-001 based on official proposal sheet
        cache["6508-16-001"] = [
            {"alt": "-", "code": "8009 7019", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 1)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7020", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 2)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7021", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 3)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7022", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 4)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7023", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 5)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7024", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 6)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}},
            {"alt": "-", "code": "8009 7025", "description": "HYDRAULIC CEMENT(TY I)(DEL)(ST 7)", "unit": "BAG", "quantity": 490.0, "engEstUnit": 0.0, "lowUnit": 0.0, "bidders": {}}
        ]

    save_items_cache(cache)
    print("Saved proposal_items_cache.json with 6508-16-001 items.")

    # 2. Update monthly_cache_2026-10.json across all folders
    items_6508 = cache["6508-16-001"]
    monthly_files = [
        os.path.join(FRONTEND_DOWNLOADS, "monthly_cache_2026-10.json"),
        os.path.join(PUBLIC_DOWNLOADS, "monthly_cache_2026-10.json"),
        os.path.join(DATA_DOWNLOADS, "monthly_cache_2026-10.json")
    ]
    for mf in monthly_files:
        if os.path.exists(mf):
            with open(mf, 'r', encoding='utf-8-sig') as f:
                data = json.load(f)
            updated = False
            for p in data:
                if p.get('csj') == '6508-16-001':
                    p['items'] = items_6508
                    updated = True
            if updated:
                with open(mf, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
                print(f"Updated items in {mf}")

if __name__ == '__main__':
    update_csj_6508_16_001()
