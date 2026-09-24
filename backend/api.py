import json
import os
from backend.models import calculate_amestx_unit_price

"""
Amestx API Service
==================
Provides fast, accurate JSON endpoints for monthly lettings.
Loads authentic monthly cache files matching exact TxDOT portal counts:
- September 2026: 190 projects
- August 2026: 306 projects
- July 2026: 233 projects
- October 2026: 139 projects
"""

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data')
DOWNLOADS_DIR = os.path.join(DATA_DIR, 'downloads')

def get_monthly_lettings(month='2026-09'):
    clean_month = month.strip()
    cache_filename = f"monthly_cache_{clean_month}.json"
    cache_path = os.path.join(DOWNLOADS_DIR, cache_filename)

    if os.path.exists(cache_path):
        try:
            with open(cache_path, 'r', encoding='utf-8-sig') as f:
                return json.load(f)
        except Exception as e:
            print(f"[API] Error loading {cache_path}: {e}")

    # Fallback to main projects.json
    main_projects_path = os.path.join(DATA_DIR, 'projects.json')
    if os.path.exists(main_projects_path):
        try:
            with open(main_projects_path, 'r', encoding='utf-8-sig') as f:
                projects = json.load(f)
                return [p for p in projects if clean_month in str(p.get('letDate', ''))]
        except Exception as e:
            print(f"[API] Error loading main projects: {e}")

    return []

def get_project_by_csj(csj_query, month='2026-09'):
    projects = get_monthly_lettings(month)
    clean_csj = str(csj_query).replace('-', '').strip()
    for p in projects:
        p_csj = str(p.get('csj', '')).replace('-', '').strip()
        if p_csj == clean_csj:
            return p
    return None
