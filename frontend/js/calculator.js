/**
 * Amestx 12-Month Historical Price Calculator Engine (Frontend Single Source of Truth)
 * ==================================================================================
 * Computes authentic TxDOT 12-month historical low bidder unit price averages.
 * Locked & Isolated to prevent accidental overwrites during UI updates.
 */

(function(window) {
    'use strict';

    const HISTORICAL_AVERAGES = {
        // 100 Series - Earthwork & Right of Way
        '100': 456.18,   // PREPARING ROW (STA)
        '104': 20.60,    // REMOVING CONC (PAV) (SY)
        '110': 18.50,    // EXCAVATION (ROADWAY) (CY)
        '132': 16.50,    // EMBANKMENT (CY)
        '164': 1200.00,  // DRILL SEED / BROADCAST SEED (AC)
        '168': 25.00,    // VEGETATIVE WATERING (MG)

        // 200 Series - Subgrade & Base
        '247': 48.50,    // FLEXIBLE BASE (CY/TON)
        '260': 185.00,   // LIME (TON)
        '275': 165.00,   // CEMENT (TON)

        // 300 Series - Surface Treatments & Pavement
        '316': 135.00,   // ASPHALT / SEAL COAT (TON/GAL)
        '340': 118.00,   // DENSE-GRADED HMA (TON)
        '341': 122.00,   // DENSE-GRADED HMA TY-B/C/D (TON)
        '351': 78.50,    // FLEXIBLE PAVEMENT REPAIR (SY)
        '354': 4.50,     // PLANING & MILLING (SY)

        // 400 Series - Structures & Culverts
        '400': 35.00,    // STRUCT EXCAV (CY)
        '420': 950.00,   // CONC BENT / ABUTMENT (CY)
        '432': 480.00,   // RIPRAP (CONC/STONE) (CY)
        '462': 380.00,   // CONC BOX CULV (LF)
        '464': 145.00,   // RC PIPE CULV (LF)
        '480': 2250.00,  // CLEAN EXIST CULVERTS (EA)

        // 500 Series - Incidentals & Mobilization
        '500': 3500.00,  // MOBILIZATION (CALLOUT/LS) (EA)
        '502': 2500.00,  // BARRICADES & TRAFFIC HANDLING (MO)
        '503': 185.00,   // PORTABLE CHANGEABLE MESSAGE SIGN (DAY)
        '505': 250.00,   // TMA STATIONARY (DAY)
        '506': 4.50,     // TEMP SEDMT CONT FENCE (LF)
        '540': 28.50,    // METAL BEAM GUARD FENCE (LF)
        '544': 2850.00,  // GUARDRAIL END TREAT (EA)

        // 600 Series - Traffic Control & Markings
        '662': 1.85,     // WORK ZONE PAV MARKINGS (LF)
        '666': 1.35,     // REPM TY W/W STRIPING (LF)
        '672': 4.50,     // RAISED PAV MARKER (EA)

        // 700 Series - Maintenance & Specialty
        '700': 2500.00,  // EMERGENCY MOBILIZATION (EA)
        '730': 55.00,    // ROADSIDE MOWING (AC)
        '735': 45.00,    // DRIFTWOOD REMOVAL (CY)
        '738': 350.00,   // CLEANING / SWEEPING HIGHWAYS (MI)
        '752': 450.00,   // TREE TRIMMING & BRUSH (MI/EA)
        '760': 0.50,     // DITCH CLEANING AND RESHAPING (LF)

        // 6000+ Series - Special Specs
        '6001': 185.00,  // PORTABLE CHANGEABLE MESSAGE SIGN (DAY)
        '6185': 250.00   // TMA STATIONARY (DAY)
    };

    let txdotPeriodMapData = null;
    let txdotMasterItemMap = null;
    let txdotItemBaseAvgMap = null;

    function ensureTxDOTMasterMapLoaded() {
        if (txdotMasterItemMap !== null && txdotPeriodMapData !== null) return;
        txdotMasterItemMap = {};
        txdotItemBaseAvgMap = {};
        const baseSumMap = {};

        // 1. Try loading multi-period JSON map (24, 12, 6, 3 mo sheets)
        try {
            const xhrJson = new XMLHttpRequest();
            xhrJson.open('GET', 'downloads/txdot_averages_period_map.json', false);
            xhrJson.send(null);
            if (xhrJson.status === 200) {
                txdotPeriodMapData = JSON.parse(xhrJson.responseText);
                if (txdotPeriodMapData && txdotPeriodMapData['24']) {
                    const map24 = txdotPeriodMapData['24'].items || {};
                    for (const code in map24) {
                        if (map24[code] && map24[code].colG > 0) {
                            txdotMasterItemMap[code] = map24[code].colG;
                        }
                    }
                    txdotItemBaseAvgMap = txdotPeriodMapData['24'].baseAvgG || {};
                    return;
                }
            }
        } catch (e) {
            console.warn("JSON period map load error, falling back to CSV:", e);
        }

        // Fallback: Parse Master CSV (Column G is index 6)
        try {
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'downloads/TxDOT_Average_Bid_Prices_Item_Wise.csv', false);
            xhr.send(null);
            if (xhr.status === 200) {
                const lines = xhr.responseText.split('\n');
                for (let i = 1; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    const parts = line.split(/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/).map(s => s.replace(/^\"|\"$/g, '').trim());
                    if (parts.length >= 7) {
                        const rawCode = parts[0].replace(/[\s\-]+/g, '');
                        const unit = (parts[3] || '').trim().toUpperCase();
                        const pEng = parseFloat(parts[6]) || parseFloat(parts[4]) || 0;
                        if (pEng > 0) {
                            txdotMasterItemMap[rawCode] = pEng;
                            if (rawCode.length >= 4) {
                                const itemNoOnly = rawCode.substring(0, 4).replace(/^0+/, '');
                                const baseKey = itemNoOnly + "_" + unit;
                                if (!baseSumMap[baseKey]) {
                                    baseSumMap[baseKey] = { sum: 0, count: 0 };
                                }
                                baseSumMap[baseKey].sum += pEng;
                                baseSumMap[baseKey].count += 1;
                            }
                        }
                    }
                }
                for (const bk in baseSumMap) {
                    txdotItemBaseAvgMap[bk] = Math.round((baseSumMap[bk].sum / baseSumMap[bk].count) * 100) / 100;
                }
            }
        } catch (e) {
            console.warn("Error loading TxDOT Master CSV:", e);
        }
    }

    function getAmestxCalculatedUnitPrice(item, metaObj, allItems) {
        if (!item) return 0;

        ensureTxDOTMasterMapLoaded();

        let rawCodeStr = (item.code || item.itemNo || item.item_no || '').toString().trim();
        let specCodeStr = (item.specCode || item.spec_code || item.specCo || '').toString().trim();

        if (!specCodeStr && (rawCodeStr.includes(' ') || rawCodeStr.includes('-'))) {
            const parts = rawCodeStr.split(/[\s\-]+/);
            rawCodeStr = parts[0] || '';
            specCodeStr = parts[1] || '';
        }

        const cleanDigits = rawCodeStr.replace(/[^0-9]/g, '');
        if (!specCodeStr && cleanDigits.length >= 7 && cleanDigits.length <= 8) {
            const paddedDigits = cleanDigits.padStart(8, '0');
            rawCodeStr = paddedDigits.substring(0, 4);
            specCodeStr = paddedDigits.substring(4, 8);
        }

        const itemNoOnly = rawCodeStr.replace(/[^0-9]/g, '').replace(/^0+/, '');
        const descUpper = (item.description || item.itemDescription || '').toString().toUpperCase();
        const unitUpper = (item.unit || '').toString().toUpperCase().trim();
        const itemQty = parseFloat(item.quantity) || 0;

        let projEst = 0;
        if (metaObj) {
            projEst = parseFloat(metaObj.estimate || metaObj.engEstTotal || metaObj.engEst || metaObj.eng_est || 0);
        }

        // 1. ITEM 500 MOBILIZATION RULE: ALWAYS 5% OF THIS PROJECT'S ENGINEER ESTIMATE
        if (itemNoOnly === '500' || descUpper.includes('MOBILIZATION')) {
            if (projEst > 0) {
                return Math.round(projEst * 0.05 * 100) / 100;
            }
        }

        const itemNoPadded = itemNoOnly.padStart(4, '0');
        const specNoPadded = specCodeStr.replace(/[^0-9]/g, '').padStart(4, '0');
        const primaryKey = itemNoPadded + specNoPadded;

        let translatedSpecNo = specNoPadded;
        if (specNoPadded.startsWith('7')) {
            translatedSpecNo = '6' + specNoPadded.substring(1);
        }
        const translatedKey = itemNoPadded + translatedSpecNo;

        // =========================================================================
        // 2. HIERARCHICAL 4-TIER LOOKUP: 24-Mo -> 12-Mo -> 6-Mo -> 3-Mo (COLUMN G)
        // =========================================================================
        let val = 0;
        let periodOrder = ['24', '12', '6', '3'];
        if (typeof activeTxdotAveragePeriod !== 'undefined' && activeTxdotAveragePeriod) {
            if (activeTxdotAveragePeriod === '12') periodOrder = ['12', '24', '6', '3'];
            else if (activeTxdotAveragePeriod === '6') periodOrder = ['6', '12', '24', '3'];
            else if (activeTxdotAveragePeriod === '3') periodOrder = ['3', '6', '12', '24'];
            else if (activeTxdotAveragePeriod === '24') periodOrder = ['24', '12', '6', '3'];
        }

        if (txdotPeriodMapData) {
            for (let i = 0; i < periodOrder.length; i++) {
                const p = periodOrder[i];
                const pObj = txdotPeriodMapData[p];
                if (pObj && pObj.items) {
                    const itemsObj = pObj.items;
                    if (itemsObj[primaryKey] && itemsObj[primaryKey].colG > 0) {
                        val = itemsObj[primaryKey].colG;
                        break;
                    } else if (itemsObj[translatedKey] && itemsObj[translatedKey].colG > 0) {
                        val = itemsObj[translatedKey].colG;
                        break;
                    }
                }
            }
        }

        if (val <= 0) {
            if (txdotMasterItemMap[primaryKey]) {
                val = txdotMasterItemMap[primaryKey];
            } else if (txdotMasterItemMap[translatedKey]) {
                val = txdotMasterItemMap[translatedKey];
            }
        }

        // =========================================================================
        // 3. OUTLIER & SANITY PROTECTION FOR UNWEIGHTED SPECIAL SPEC CODES
        // =========================================================================
        // Item 502 Barricades & Traffic Handling
        if (itemNoOnly === '502' || descUpper.includes('BARRICADES')) {
            const extVal = val * itemQty;
            if (val > 25000 || (projEst > 0 && extVal > projEst)) {
                let altVal = 0;
                if (txdotPeriodMapData) {
                    for (let i = 0; i < periodOrder.length; i++) {
                        const pObj = txdotPeriodMapData[periodOrder[i]];
                        if (pObj && pObj.items) {
                            if (pObj.items['05027001'] && pObj.items['05027001'].colG > 0 && pObj.items['05027001'].colG < 25000) {
                                altVal = pObj.items['05027001'].colG;
                                break;
                            }
                        }
                    }
                }
                if (altVal > 0 && (altVal * itemQty) <= projEst) {
                    val = altVal;
                } else {
                    val = 2500.00;
                }
            }
        }

        // Item 100 Preparing Row
        if (itemNoOnly === '100' || descUpper.includes('PREPARING ROW')) {
            const extVal = val * itemQty;
            if (val > 25000 || (projEst > 0 && extVal > projEst)) {
                let altVal = 0;
                if (txdotPeriodMapData) {
                    for (let i = 0; i < periodOrder.length; i++) {
                        const pObj = txdotPeriodMapData[periodOrder[i]];
                        if (pObj && pObj.items) {
                            if (pObj.items['01007002'] && pObj.items['01007002'].colG > 0 && pObj.items['01007002'].colG < 25000) {
                                altVal = pObj.items['01007002'].colG;
                                break;
                            } else if (pObj.items['01006001'] && pObj.items['01006001'].colG > 0) {
                                altVal = pObj.items['01006001'].colG;
                                break;
                            }
                        }
                    }
                }
                if (altVal > 0 && (altVal * itemQty) <= (projEst * 0.5)) {
                    val = altVal;
                } else {
                    val = 456.18;
                }
            }
        }

        if (val > 0) {
            return Math.round(val * 100) / 100;
        }

                // =========================================================================
                // LEVEL 2B: ITEM 666 STRIPING & MARKING DESCRIPTION KEYWORD MATCHER
                // =========================================================================
                if (itemNoOnly === '666' || descUpper.includes('PAV MRK') || descUpper.includes('PM TY')) {
                    if (unitUpper === 'LF' || unitUpper === 'LM') {
                        if (descUpper.includes('6"(SLD)') || descUpper.includes('6" (SLD)') || descUpper.includes('6" SLD') || descUpper.includes('6"(SLD')) {
                            return txdotMasterItemMap['06667175'] || txdotMasterItemMap['06666174'] || 0.17;
                        }
                        if (descUpper.includes('6"(BRK)') || descUpper.includes('6" (BRK)') || descUpper.includes('6" BRK') || descUpper.includes('6"(BRK')) {
                            return txdotMasterItemMap['06667172'] || txdotMasterItemMap['06666171'] || 0.26;
                        }
                        if (descUpper.includes('6"(DOT)') || descUpper.includes('6" (DOT)') || descUpper.includes('6" DOT') || descUpper.includes('6"(DOT')) {
                            return txdotMasterItemMap['06667172'] || 0.26;
                        }
                        if (descUpper.includes('8"(SLD)') || descUpper.includes('8" (SLD)') || descUpper.includes('8" SLD') || descUpper.includes('8"(SLD')) {
                            return txdotMasterItemMap['06667451'] || txdotMasterItemMap['06667179'] || 0.43;
                        }
                        if (descUpper.includes('8"(DOT)') || descUpper.includes('8" (DOT)') || descUpper.includes('8" DOT') || descUpper.includes('8"(DOT')) {
                            return 0.75;
                        }
                        if (descUpper.includes('12"(SLD)') || descUpper.includes('12" (SLD)') || descUpper.includes('12" SLD')) {
                            return 1.85;
                        }
                        if (descUpper.includes('24"(SLD)') || descUpper.includes('24" (SLD)') || descUpper.includes('24" SLD')) {
                            return 3.92;
                        }
                    }
                }

                // =========================================================================
                // LEVEL 3: ITEM BASE NUMBER CSV AVERAGE LOOKUP
                // =========================================================================
                const baseKey = itemNoOnly + "_" + unitUpper;
                if (txdotItemBaseAvgMap && txdotItemBaseAvgMap[baseKey] && txdotItemBaseAvgMap[baseKey] > 0) {
                    return Math.round(txdotItemBaseAvgMap[baseKey] * 100) / 100;
                }

                // =========================================================================
                // LEVEL 4: STANDARD TxDOT ITEM NUMBER INDUSTRY BENCHMARKS
                // =========================================================================
                const ITEM_BENCHMARKS = {
                    '164': { SY: 0.55, AC: 650.00, LB: 6.50 },
                    '162': { SY: 4.55 },
                    '160': { SY: 1.85, CY: 28.00 },
                    '161': { SY: 1.85, CY: 28.00 },
                    '169': { SY: 1.85, CY: 28.00 },
                    '168': { TGL: 19.85, MG: 19.85 },
                    '533': { LF: 0.25, LM: 0.25 },            // Mill Rumble Strips (Shoulder / Centerline)
                    '662': { EA: 0.85, LF: 0.85, LM: 0.85 },  // Work Zone Markings & Tabs
                    '666': { LF: 1.45, EA: 1.45, LM: 1.45 },  // Reflectorized Pavement Markings & Striping
                    '668': { EA: 4.50, LF: 2.25 },
                    '672': { EA: 4.50 },                      // Raised Pavement Markers
                    '512': { LF: 18.50, LM: 18.50 },          // PTB
                    '530': { SY: 68.00 },                     // Driveways
                    '540': { LF: 28.50, EA: 1250.00 },        // Metal Beam Guard Fence
                    '542': { LF: 4.50 },                      // Remove Guard Fence
                    '544': { EA: 2850.00 }                    // Guardrail End Treatment
                };

                if (ITEM_BENCHMARKS[itemNoOnly] && ITEM_BENCHMARKS[itemNoOnly][unitUpper]) {
                    return ITEM_BENCHMARKS[itemNoOnly][unitUpper];
                }

                // =========================================================================
                // LEVEL 5: DESCRIPTION KEYWORD & SPECIFIC ITEM ANALYSIS
                // =========================================================================
                val = parseFloat(item.amestxUnit || item.avgPrice || item.unitPrice || 0);

                if (val <= 0 || val === 1.85 || val === 250.00 || val === 25.00 || val === 115.00 || val === 3500.00) {

                    // 1. Rumble Strips (Item 533 or description)
                    if (itemNoOnly === '533' || descUpper.includes('RUMBLE')) {
                        val = 0.25;
                    }
                    // 2. Work Zone Markings, Tabs, Buttons (Item 662)
                    else if (itemNoOnly === '662' || descUpper.includes('WK ZN') || descUpper.includes('SHT TERM') || descUpper.includes('TAB')) {
                        val = 0.85;
                    }
                    // 3. Striping / Reflectorized Markings (Item 666, 668, 672)
                    else if (itemNoOnly === '666' || itemNoOnly === '668' || itemNoOnly === '672' || descUpper.includes('REFL') || descUpper.includes('PAV MRK') || descUpper.includes('STRIPE') || descUpper.includes('PM TY') || descUpper.includes('RE PROFILE')) {
                        if (unitUpper === 'LF' || unitUpper === 'LM') val = 1.45;
                        else val = 4.50;
                    }
                    // 4. Seeding & Erosion Control (Item 164)
                    else if (itemNoOnly === '164' || descUpper.includes('SEED') || descUpper.includes('BOND FBR')) {
                        if (unitUpper === 'AC' || unitUpper === 'ACRE') val = 650.00;
                        else if (unitUpper === 'LB') val = 6.50;
                        else val = 0.55;
                    }
                    // 5. Sodding (Item 162)
                    else if (itemNoOnly === '162' || descUpper.includes('SOD')) {
                        val = 4.55;
                    }
                    // 6. Topsoil, Compost, Blanket (Item 160, 161, 169)
                    else if (itemNoOnly === '160' || itemNoOnly === '161' || itemNoOnly === '169' || descUpper.includes('TOPSOIL') || descUpper.includes('COMPOST') || descUpper.includes('BLANKET')) {
                        if (unitUpper === 'CY') val = 28.00;
                        else val = 1.85;
                    }
                    // 7. Vegetative Watering (Item 168)
                    else if (itemNoOnly === '168' || descUpper.includes('VEGETATIVE WATERING')) {
                        val = 19.85;
                    }
                    // 8. Cables & Fiber Optic (6004, 6005, 684)
                    else if (descUpper.includes('CBL') || descUpper.includes('CABLE') || descUpper.includes('ETHERNET') || descUpper.includes('FIBER')) {
                        if (unitUpper === 'LF' || unitUpper === 'LM') {
                            if (descUpper.includes('FIBER') || descUpper.includes('FO')) val = 6.80;
                            else if (descUpper.includes('ETHERNET') || descUpper.includes('COM')) val = 4.80;
                            else if (descUpper.includes('CONTROL') || descUpper.includes('WWD')) val = 5.20;
                            else if (descUpper.includes('TRF SIG') || descUpper.includes('SIGNAL')) val = 4.20;
                            else val = 4.50;
                        } else {
                            val = 350.00;
                        }
                    }
                    // 9. DMS / Dynamic Message Signs & Cabinets (6004, 6006)
                    else if (itemNoOnly === '6004' || descUpper.includes('DMS') || descUpper.includes('DYNAMIC MESSAGE')) {
                        if (descUpper.includes('CABINET') || descUpper.includes('FOUNDATION')) val = 24500.00;
                        else val = 48500.00;
                    }
                    // 10. System Integration (6009)
                    else if (itemNoOnly === '6009' || descUpper.includes('SYSTEM INTEGRATION') || descUpper.includes('INTEGRATION')) {
                        val = 85000.00;
                    }
                    // 11. Satellite Building / Equipment Shelter (6176)
                    else if (itemNoOnly === '6176' || descUpper.includes('SATELLITE BUILDING') || descUpper.includes('BUILDING SHELTER')) {
                        val = 65000.00;
                    }
                    // 12. C-V2X Roadside Unit (6177)
                    else if (itemNoOnly === '6177' || descUpper.includes('V2X') || descUpper.includes('ROADSIDE UNIT')) {
                        val = 11500.00;
                    }
                    // 13. ITS RVSD / Radar Vehicle Sensing (6010)
                    else if (itemNoOnly === '6010' || descUpper.includes('RVSD') || descUpper.includes('RADAR')) {
                        if (descUpper.includes('RELOCATE')) val = 2400.00;
                        else val = 7800.00;
                    }
                    // 14. ITS Poles & Towers (6011, 6250)
                    else if (itemNoOnly === '6011' || descUpper.includes('ITS POLE') || descUpper.includes('CAMERA POLE')) {
                        if (descUpper.includes('RELOCATE')) val = 3500.00;
                        else val = 14500.00;
                    }
                    // 15. Item 462 / Concrete Box Culverts
                    else if (itemNoOnly === '462' || descUpper.includes('BOX CULV') || descUpper.includes('CONC BOX')) {
                        if (descUpper.includes('10 FT') || descUpper.includes('10FT') || descUpper.includes('9 FT') || descUpper.includes('9FT')) val = 750.00;
                        else if (descUpper.includes('8 FT') || descUpper.includes('8FT')) val = 650.00;
                        else if (descUpper.includes('7 FT') || descUpper.includes('7FT')) val = 580.00;
                        else if (descUpper.includes('6 FT') || descUpper.includes('6FT')) val = 480.00;
                        else if (descUpper.includes('5 FT') || descUpper.includes('5FT')) val = 380.00;
                        else if (descUpper.includes('4 FT') || descUpper.includes('4FT')) val = 290.00;
                        else if (descUpper.includes('3 FT') || descUpper.includes('3FT')) val = 220.00;
                        else val = 450.00;
                    }
                    // 16. Item 464 / RC Pipe
                    else if (itemNoOnly === '464' || descUpper.includes('RC PIPE') || descUpper.includes('RCP')) {
                        if (descUpper.includes('48 IN') || descUpper.includes('48"')) val = 180.00;
                        else if (descUpper.includes('36 IN') || descUpper.includes('36"')) val = 145.00;
                        else if (descUpper.includes('24 IN') || descUpper.includes('24"')) val = 112.42;
                        else if (descUpper.includes('18 IN') || descUpper.includes('18"')) val = 103.78;
                        else val = 115.00;
                    }
                    // 17. 7000-series Utilities & Maintenance
                    else if (itemNoOnly.startsWith('7') || descUpper.includes('WATER MAIN') || descUpper.includes('SEWER')) {
                        if (descUpper.includes('WATER') || descUpper.includes('SEWER') || descUpper.includes('SAN')) {
                            if (unitUpper === 'LF' || unitUpper === 'LM') {
                                if (descUpper.includes('12 IN') || descUpper.includes('16 IN') || descUpper.includes('18 IN')) val = 165.00;
                                else if (descUpper.includes('8 IN') || descUpper.includes('10 IN')) val = 125.00;
                                else val = 85.00;
                            } else if (unitUpper === 'EA' || unitUpper === 'EACH') {
                                val = 4800.00;
                            } else if (unitUpper === 'LS' || unitUpper === 'LUMP') {
                                val = 65000.00;
                            } else {
                                val = 125.00;
                            }
                        } else if (descUpper.includes('MOW') || descUpper.includes('LITTER') || descUpper.includes('TREE') || descUpper.includes('VEG')) {
                            if (unitUpper === 'AC' || unitUpper === 'ACRE') val = 65.00;
                            else if (unitUpper === 'MI' || unitUpper === 'MILE') val = 350.00;
                            else if (unitUpper === 'MO' || unitUpper === 'MONTH') val = 1800.00;
                            else if (unitUpper === 'HR' || unitUpper === 'HOUR') val = 85.00;
                            else if (unitUpper === 'CY') val = 35.00;
                            else val = 450.00;
                        } else {
                            if (unitUpper === 'LF' || unitUpper === 'LM') val = 85.00;
                            else if (unitUpper === 'EA' || unitUpper === 'EACH') val = 2800.00;
                            else if (unitUpper === 'SY' || unitUpper === 'SQFT') val = 45.00;
                            else if (unitUpper === 'LS' || unitUpper === 'LUMP') val = 25000.00;
                            else val = 350.00;
                        }
                    }
                    // 18. 8000-series Special Materials
                    else if (itemNoOnly.startsWith('8') || descUpper.includes('SPECIAL MATERIAL')) {
                        if (unitUpper === 'LF' || unitUpper === 'LM') val = 45.00;
                        else if (unitUpper === 'EA' || unitUpper === 'EACH') val = 3200.00;
                        else if (unitUpper === 'TON' || unitUpper === 'TN') val = 140.00;
                        else if (unitUpper === 'CY') val = 180.00;
                        else if (unitUpper === 'SY' || unitUpper === 'SQFT') val = 35.00;
                        else if (unitUpper === 'LS' || unitUpper === 'LUMP') val = 30000.00;
                        else val = 450.00;
                    }
                    // 19. Concrete Repair & Asphalt Paving
                    else if (descUpper.includes('CONC') || descUpper.includes('PAV') || descUpper.includes('REPAIR')) {
                        if (unitUpper === 'SY' || unitUpper === 'SQFT') val = 75.00;
                        else if (unitUpper === 'CY') val = 450.00;
                        else if (unitUpper === 'LF' || unitUpper === 'LM') val = 65.00;
                        else if (unitUpper === 'EA' || unitUpper === 'EACH') val = 3500.00;
                        else val = 150.00;
                    }
                    else if (descUpper.includes('ASPH') || descUpper.includes('HMA') || descUpper.includes('HOT MIX')) {
                        if (unitUpper === 'TON' || unitUpper === 'TN') val = 115.00;
                        else if (unitUpper === 'GAL' || unitUpper === 'GALLON') val = 4.20;
                        else if (unitUpper === 'SY' || unitUpper === 'SQFT') val = 18.00;
                        else if (unitUpper === 'LF' || unitUpper === 'LM') val = 0.25;
                        else val = 115.00;
                    }
                    // 20. Guardrail & Barriers
                    else if (descUpper.includes('GUARDRAIL') || descUpper.includes('ATTEN') || descUpper.includes('BARRIER')) {
                        if (unitUpper === 'LF' || unitUpper === 'LM') val = 38.00;
                        else if (unitUpper === 'EA' || unitUpper === 'EACH') val = 3200.00;
                        else val = 850.00;
                    }
                    // 21. Generic Unit Fallbacks
                    else if (unitUpper === 'BAG' || unitUpper === 'BAGS') {
                        val = 11.90;
                    }
                    else if (unitUpper === 'LF' || unitUpper === 'LM' || unitUpper === 'LFR') {
                        if (descUpper.includes('STRIPE') || descUpper.includes('LINE') || descUpper.includes('MARK') || descUpper.includes('TAPE') || descUpper.includes('REPM')) {
                            val = 1.85;
                        } else {
                            val = 18.50;
                        }
                    }
                    else if (unitUpper === 'SY' || unitUpper === 'SQFT' || unitUpper === 'SF') {
                        val = unitUpper === 'SF' ? 4.50 : 8.50;
                    }
                    else if (unitUpper === 'CY' || unitUpper === 'CUYD') {
                        val = 180.00;
                    }
                    else if (unitUpper === 'TON' || unitUpper === 'TN') {
                        val = 110.00;
                    }
                    else if (unitUpper === 'GAL' || unitUpper === 'GALLON') {
                        val = 4.50;
                    }
                    else if (unitUpper === 'EA' || unitUpper === 'EACH') {
                        val = 850.00;
                    }
                    else if (unitUpper === 'LS' || unitUpper === 'LUMP') {
                        val = 15000.00;
                    }
                    else if (unitUpper === 'MO' || unitUpper === 'MONTH') {
                        val = 2500.00;
                    }
                    else if (unitUpper === 'DAY') {
                        val = 150.00;
                    }
                    else if (unitUpper === 'HR' || unitUpper === 'HOUR') {
                        val = 95.00;
                    }
                    else if (unitUpper === 'STA') {
                        val = 450.00;
                    }
                    else if (unitUpper === 'AC' || unitUpper === 'ACRE') {
                        val = 1800.00;
                    }
                    else {
                        val = 350.00;
                    }
                }

                return Math.round(val * 100) / 100;
            }

    window.ensureTxDOTMasterMapLoaded = ensureTxDOTMasterMapLoaded;
    window.getAmestxCalculatedUnitPrice = getAmestxCalculatedUnitPrice;

})(window);
