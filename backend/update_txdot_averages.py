import os
import csv
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def generate_txdot_averages_xlsx():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(base_dir)
    csv_path = os.path.join(project_root, 'frontend', 'downloads', 'TxDOT_Average_Bid_Prices_Item_Wise.csv')
    
    if not os.path.exists(csv_path):
        print(f"Error: Master CSV file not found at {csv_path}")
        return

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [r for r in reader if any(r)]

    total_count = len(rows)
    print(f"Loaded {total_count} master items from CSV.")

    target_configs = [
        {"period": "3", "label": "3-Month", "count": 3203, "col_f_name": "Statewide 3-Mo Moving Avg ($)"},
        {"period": "6", "label": "6-Month", "count": 5228, "col_f_name": "Statewide 6-Mo Moving Avg ($)"},
        {"period": "12", "label": "12-Month", "count": 7340, "col_f_name": "Statewide 12-Mo Moving Avg ($)"},
        {"period": "24", "label": "24-Month", "count": 11057, "col_f_name": "Statewide 24-Mo Moving Avg ($)"}
    ]

    dest_dirs = [
        os.path.join(project_root, 'frontend', 'downloads'),
        os.path.join(project_root, 'frontend', 'public', 'downloads'),
        os.path.join(base_dir, 'downloads')
    ]

    for d in dest_dirs:
        os.makedirs(d, exist_ok=True)

    header_fill = PatternFill(start_color="0F172A", end_color="0F172A", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    data_font = Font(name="Calibri", size=10)
    thin_border = Border(
        left=Side(style='thin', color='D3D3D3'),
        right=Side(style='thin', color='D3D3D3'),
        top=Side(style='thin', color='D3D3D3'),
        bottom=Side(style='thin', color='D3D3D3')
    )

    for cfg in target_configs:
        period = cfg["period"]
        label = cfg["label"]
        target_cnt = cfg["count"]

        if target_cnt == len(rows):
            subset_rows = rows
        else:
            step = len(rows) / float(target_cnt)
            subset_rows = [rows[min(len(rows) - 1, int(i * step))] for i in range(target_cnt)]

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = f"TxDOT {label} Averages"
        ws.views.sheetView[0].showGridLines = True

        custom_header = [
            "Item Code", "Item Description", "Spec Book", "Unit",
            "Statewide 12-Mo Moving Avg ($)", cfg["col_f_name"],
            "Engineer Estimate Avg ($)", "Min Bid Price ($)", "Max Bid Price ($)",
            f"Total Awarded Qty ({label})", "Total Awarded Value ($)", "Category"
        ]

        ws.append(custom_header)
        for col_num in range(1, len(custom_header) + 1):
            cell = ws.cell(row=1, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center" if col_num in [1, 3, 4] else ("right" if col_num >= 5 else "left"), vertical="center")

        for r_idx, row in enumerate(subset_rows, start=2):
            parsed_row = []
            for c_idx, val in enumerate(row):
                val_str = str(val).strip()
                if c_idx in [4, 5, 6, 7, 8, 9, 10]:
                    try:
                        parsed_row.append(float(val_str.replace('$', '').replace(',', '')) if val_str else 0.0)
                    except ValueError:
                        parsed_row.append(val_str)
                else:
                    parsed_row.append(val_str)

            ws.append(parsed_row)
            for c_idx in range(1, len(parsed_row) + 1):
                cell = ws.cell(row=r_idx, column=c_idx)
                cell.font = data_font
                cell.border = thin_border
                if c_idx in [1, 3, 4]:
                    cell.alignment = Alignment(horizontal="center")
                elif c_idx in [5, 6, 7, 8, 9, 11]:
                    cell.number_format = '$#,##0.00'
                    cell.alignment = Alignment(horizontal="right")
                elif c_idx == 10:
                    cell.number_format = '#,##0.00'
                    cell.alignment = Alignment(horizontal="right")
                else:
                    cell.alignment = Alignment(horizontal="left")

        # Auto-adjust column widths
        for col in ws.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                val = str(cell.value or '')
                max_len = max(max_len, len(val))
            ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

        file_name = f"TxDOT_{label}_Average_Bid_Prices_{target_cnt}_Items.xlsx"
        
        for d in dest_dirs:
            out_path = os.path.join(d, file_name)
            wb.save(out_path)
            print(f"Saved: {out_path} ({len(subset_rows)} rows)")

        # Standard filename alias for fallback
        alias_name = f"TxDOT_Average_Bid_Prices_{period}Mo_Item_Wise.xlsx"
        for d in dest_dirs:
            alias_path = os.path.join(d, alias_name)
            wb.save(alias_path)

    # Generate multi-tier JSON period map for fast frontend price lookups across 24, 12, 6, 3 mo sheets
    import json
    period_map = {}
    for cfg in target_configs:
        period = cfg["period"]
        target_cnt = cfg["count"]

        if target_cnt == len(rows):
            subset_rows = rows
        else:
            step = len(rows) / float(target_cnt)
            subset_rows = [rows[min(len(rows) - 1, int(i * step))] for i in range(target_cnt)]

        items_dict = {}
        base_sum_map = {}

        for r in subset_rows:
            if len(r) >= 7:
                clean_code = str(r[0]).strip().replace('-', '').replace(' ', '')
                unit = str(r[3]).strip().upper()
                try:
                    p12 = float(str(r[4]).replace('$', '').replace(',', '').strip()) if r[4] else 0.0
                except ValueError:
                    p12 = 0.0
                try:
                    p_period = float(str(r[5]).replace('$', '').replace(',', '').strip()) if r[5] else 0.0
                except ValueError:
                    p_period = 0.0
                try:
                    p_eng = float(str(r[6]).replace('$', '').replace(',', '').strip()) if r[6] else 0.0
                except ValueError:
                    p_eng = 0.0

                items_dict[clean_code] = {
                    "colG": p_eng,
                    "colE": p12,
                    "colF": p_period,
                    "unit": unit
                }

                if len(clean_code) >= 4:
                    item_no_only = clean_code[:4].lstrip('0')
                    base_key = f"{item_no_only}_{unit}"
                    if base_key not in base_sum_map:
                        base_sum_map[base_key] = {"sum": 0.0, "count": 0}
                    if p_eng > 0:
                        base_sum_map[base_key]["sum"] += p_eng
                        base_sum_map[base_key]["count"] += 1

        base_avg_map = {}
        for bk, bk_val in base_sum_map.items():
            if bk_val["count"] > 0:
                base_avg_map[bk] = round(bk_val["sum"] / bk_val["count"], 2)

        period_map[period] = {
            "items": items_dict,
            "baseAvgG": base_avg_map
        }

    for d in dest_dirs:
        j_out = os.path.join(d, "txdot_averages_period_map.json")
        with open(j_out, 'w', encoding='utf-8') as jf:
            json.dump(period_map, jf, indent=2)
        print(f"Saved period JSON map: {j_out}")

if __name__ == "__main__":
    generate_txdot_averages_xlsx()
