/**
 * Amestx Excel Export Engine (Frontend Isolated Module)
 * ======================================================
 * Manages tab-specific Excel matrix downloads with 100% strict isolation:
 * - Tab 1 (Project Tasks): Zero-price ($0.00) proposal sheet for bidders (NO disclaimer).
 * - Tab 6 (Amestx Estimate): 12-month historical estimate sheet (WITH legal disclaimer).
 * - Tab 5 (Bid Tabulation): Multi-bidder itemized comparison matrix.
 */

(function(window) {
    'use strict';

    function createStyledProjectWorksheet(meta, items, isZeroPrice = false) {
        const ws = {};

        const csj = meta.csj || 'N/A';
        const county = meta.county || 'N/A';
        const hwy = meta.highway || 'N/A';
        const letDate = meta.letDate || 'N/A';
        const projectType = meta.projectType || meta.projectName || 'Highway Construction';
        const engEstTotal = meta.engEstTotal || meta.estimate || 0;
        const guarantyCheck = (engEstTotal * 0.02);

        const thinBorder = {
            top: { style: "thin", color: { rgb: "FFD3D3D3" } },
            bottom: { style: "thin", color: { rgb: "FFD3D3D3" } },
            left: { style: "thin", color: { rgb: "FFD3D3D3" } },
            right: { style: "thin", color: { rgb: "FFD3D3D3" } }
        };

        function setCell(r, c, val, type, style) {
            const cellRef = XLSX.utils.encode_cell({ r: r, c: c });
            const cellObj = { t: type || 's', s: style || {} };
            if (type === 'f') {
                if (typeof val === 'object' && val !== null) {
                    cellObj.f = val.formula;
                    cellObj.v = typeof val.value === 'number' && !isNaN(val.value) ? val.value : 0;
                } else {
                    cellObj.f = val;
                    cellObj.v = 0;
                }
                cellObj.t = 'n';
            } else {
                cellObj.v = (val === '' || val === null || val === undefined) ? '\u00A0' : val;
            }
            if (style && style.numFmt) cellObj.z = style.numFmt;
            ws[cellRef] = cellObj;
        }

        // Title Banner
        const titleText = `${letDate} | ${county} | ${hwy} | $${engEstTotal.toLocaleString(undefined, {minimumFractionDigits:2})} | ${projectType}`;
        for (let c = 0; c < 8; c++) {
            setCell(0, c, c === 0 ? titleText : '\u00A0', 's', {
                font: { name: 'Arial', sz: 14, bold: true, color: { rgb: '0066CC' } },
                alignment: { vertical: 'center', horizontal: 'left' }
            });
        }

        // Metadata Header
        const metaFields = [
            ["COUNTY:", county],
            ["DISTRICT:", meta.district || "TxDOT District"],
            ["CSJ:", csj],
            ["PROJECT ID:", meta.projectId || 'N/A'],
            ["PROJECT NO (Federal):", "N/A"],
            ["PROJECT NO (State):", "N/A"],
            ["CONTRACT NUMBER:", meta.contractNumber || "N/A"],
            ["HWY:", hwy],
            ["TIME:", `${meta.workingDays || 'N/A'} Working Days`],
            ["TYPE:", projectType],
            ["LENGTH:", "0"],
            ["ESTIMATE:", `$${engEstTotal.toLocaleString(undefined, {minimumFractionDigits:2})}`],
            ["GUARANTY CHECK:", `$${guarantyCheck.toLocaleString(undefined, {minimumFractionDigits:2})}`],
            ["DBE GOAL:", "0.00%"],
            ["BIDS RECEIVED UNTIL:", letDate],
            ["BIDS WILL BE OPENED:", letDate],
            ["APPROVED LET DATE:", letDate],
            ["ESTIMATED LET DATE:", letDate]
        ];

        metaFields.forEach((field, idx) => {
            const r = idx + 1;
            setCell(r, 0, field[0], 's', { font: { name: 'Arial', sz: 9, bold: true } });
            setCell(r, 1, field[1], 's', { font: { name: 'Arial', sz: 9 } });
        });

        // Column Headers (Row 20)
        const headers = ["ALT", "ITEM NO.", "SPEC CO.", "ITEM DESCRIPTION", "UNIT", "APPROXIMATE QUANTITIES", "UNIT PRICE", "EXTENDED PRICE"];
        headers.forEach((h, c) => {
            setCell(20, c, h, 's', {
                font: { name: 'Arial', sz: 9, bold: true, color: { rgb: 'FFFFFF' } },
                fill: { fgColor: { rgb: '000000' } },
                alignment: { horizontal: 'center' }
            });
        });

        // Item Data Rows
        items.forEach((it, idx) => {
            const r = 21 + idx;
            const excelRowNum = r + 1;
            const parts = (it.code || "").split(" ");
            const itemNo = parts[0] || "";
            const specCode = parts[1] || "";
            const desc = it.description || "";
            const qty = parseFloat(it.quantity) || 0;

            setCell(r, 0, "\u00A0", 's', { border: thinBorder });
            setCell(r, 1, itemNo, 's', { border: thinBorder, alignment: { horizontal: 'center' }, numFmt: '@' });
            setCell(r, 2, specCode, 's', { border: thinBorder, alignment: { horizontal: 'center' }, numFmt: '@' });
            setCell(r, 3, desc, 's', { border: thinBorder, alignment: { horizontal: 'left' } });
            setCell(r, 4, it.unit || '\u00A0', 's', { border: thinBorder, alignment: { horizontal: 'center' } });
            setCell(r, 5, qty, 'n', { border: thinBorder, alignment: { horizontal: 'right' }, numFmt: '#,##0.00' });

            const uPrice = isZeroPrice ? 0 : window.getAmestxCalculatedUnitPrice(it, meta, items);
            setCell(r, 6, uPrice, 'n', { border: thinBorder, alignment: { horizontal: 'right' }, numFmt: '$#,##0.00' });
            setCell(r, 7, { formula: `F${excelRowNum}*G${excelRowNum}`, value: qty * uPrice }, 'f', { border: thinBorder, alignment: { horizontal: 'right' }, numFmt: '$#,##0.00' });
        });

        // Total Row
        const lastItemExcelRow = 21 + items.length;
        const totalR = 21 + items.length + 1;
        setCell(totalR, 6, "TOTAL", 's', { font: { name: 'Arial', sz: 9, bold: true }, alignment: { horizontal: 'right' } });

        let totalExtVal = isZeroPrice ? 0 : items.reduce((sum, it) => {
            const qty = parseFloat(it.quantity) || 0;
            const up = window.getAmestxCalculatedUnitPrice(it, meta, items);
            return sum + (qty * up);
        }, 0);

        setCell(totalR, 7, { formula: `SUM(H22:H${lastItemExcelRow})`, value: totalExtVal }, 'f', {
            font: { name: 'Arial', sz: 9, bold: true },
            fill: { fgColor: { rgb: 'FFFF00' } },
            alignment: { horizontal: 'right' },
            border: thinBorder,
            numFmt: '$#,##0.00'
        });

        let totalRows = totalR + 2;

        // Legal Disclaimer (ONLY for Tab 6 Amestx Estimate, NOT for Tab 1 Project Tasks)
        if (!isZeroPrice) {
            const discTitleR = totalR + 1;
            const merges = ws['!merges'] || [{ s: { r: 0, c: 0 }, e: { r: 0, c: 7 } }];

            for (let c = 0; c < 8; c++) {
                setCell(discTitleR, c, c === 0 ? 'DISCLAIMER' : '\u00A0', 's', {
                    font: { name: 'Arial', sz: 9.5, bold: true, underline: true, color: { rgb: 'FF0000' } },
                    alignment: { horizontal: 'center' }
                });
            }
            merges.push({ s: { r: discTitleR, c: 0 }, e: { r: discTitleR, c: 7 } });

            const discLines = [
                "This estimate has been generated by Amestx using historical average bid prices and publicly available data.",
                "It is provided solely as a preliminary reference to assist bidders in understanding potential cost ranges.",
                "Actual bid pricing may vary based on market conditions, project location, labor availability, material costs, and each bidder's internal calculations.",
                "Amestx does not guarantee the accuracy of this estimate and is not responsible for any miscalculations or pricing decisions made by bidders.",
                "All bidders must independently determine and submit their own unit prices based on their professional judgment and project-specific factors."
            ];

            discLines.forEach((line, idx) => {
                const lineR = discTitleR + 1 + idx;
                for (let c = 0; c < 8; c++) {
                    setCell(lineR, c, c === 0 ? line : '\u00A0', 's', {
                        font: { name: 'Arial', sz: 8.5, italic: true, bold: true, color: { rgb: '707070' } },
                        alignment: { horizontal: 'center' }
                    });
                }
                merges.push({ s: { r: lineR, c: 0 }, e: { r: lineR, c: 7 } });
            });

            totalRows = discTitleR + 1 + discLines.length;
            ws['!merges'] = merges;
        }

        ws['!ref'] = XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: totalRows - 1, c: 7 } });
        return ws;
    }

    // Tab 1: Export Zero Price Proposal Matrix for Bidders (NO Disclaimer)
    function downloadProjectTasksExcelCurrent() {
        if (!window.currentCSJ) {
            alert("Please select a project CSJ first.");
            return;
        }
        const meta = (window.currentProjectData && window.currentProjectData.metadata) ? window.currentProjectData.metadata : {};
        const items = (window.currentProjectData && window.currentProjectData.items) ? window.currentProjectData.items : [];
        const csj = meta.csj || window.currentCSJ;

        if (typeof XLSX !== 'undefined') {
            const wb = XLSX.utils.book_new();
            const ws = createStyledProjectWorksheet(meta, items, true); // true = $0.00 prices, NO disclaimer
            const sheetName = `CSJ ${csj}`.replace(/[:\\\/\?\*\[\]]/g, '-').slice(0, 31);
            XLSX.utils.book_append(wb, ws, sheetName);
            XLSX.writeFile(wb, `CSJ_${csj}_Task_Items.xlsx`);
        }
    }

    // Tab 6: Export Amestx Calculated Estimate Matrix (WITH Disclaimer)
    function downloadEstimateExcelCurrent() {
        if (!window.currentCSJ) {
            alert("Please select a project CSJ first.");
            return;
        }
        const meta = (window.currentProjectData && window.currentProjectData.metadata) ? window.currentProjectData.metadata : {};
        const items = (window.currentProjectData && window.currentProjectData.items) ? window.currentProjectData.items : [];
        const csj = meta.csj || window.currentCSJ;

        if (typeof XLSX !== 'undefined') {
            const wb = XLSX.utils.book_new();
            const ws = createStyledProjectWorksheet(meta, items, false); // false = 12-month prices + Disclaimer
            const sheetName = `CSJ ${csj}`.replace(/[:\\\/\?\*\[\]]/g, '-').slice(0, 31);
            XLSX.utils.book_append(wb, ws, sheetName);
            XLSX.writeFile(wb, `CSJ_${csj}_Task_Items_Estimate.xlsx`);
        }
    }

    window.downloadProjectTasksExcelCurrent = downloadProjectTasksExcelCurrent;
    window.downloadEstimateExcelCurrent = downloadEstimateExcelCurrent;

})(window);
