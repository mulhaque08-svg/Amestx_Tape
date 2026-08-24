/**
 * SiteTap PRO - PDF Executive Contractor Report & CSV Exporter
 */

export class ReportGenerator {
  /**
   * Export Professional PDF Contractor Bid / Estimate
   */
  static generatePDF(projectData) {
    const reportHtml = `
      <div style="font-family: 'Helvetica Neue', Arial, sans-serif; padding: 24px; color: #111; max-width: 800px; margin: 0 auto;">
        <!-- Header -->
        <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #00e5ff; padding-bottom: 12px; margin-bottom: 20px;">
          <div>
            <h1 style="margin: 0; color: #0f172a; font-size: 24px;">SiteTap<span style="color: #0284c7;">PRO</span> Executive Bid Report</h1>
            <p style="margin: 4px 0 0 0; color: #64748b; font-size: 13px;">High-Precision Site & RTK Measurement Estimate</p>
          </div>
          <div style="text-align: right; font-size: 12px; color: #475569;">
            <p style="margin: 0;"><strong>Date:</strong> ${new Date().toLocaleDateString()}</p>
            <p style="margin: 2px 0 0 0;"><strong>Ref #:</strong> STP-${Math.floor(100000 + Math.random() * 900000)}</p>
          </div>
        </div>

        <!-- Metadata Section -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; background: #f8fafc; border: 1px solid #e2e8f0; padding: 12px 16px; border-radius: 8px; margin-bottom: 20px; font-size: 13px;">
          <div>
            <p style="margin: 0 0 4px 0;"><strong>Project Name:</strong> ${projectData.projectName || 'Site Lot Measurement'}</p>
            <p style="margin: 0;"><strong>Contractor/Client:</strong> ${projectData.clientName || 'Apex Construction'}</p>
          </div>
          <div>
            <p style="margin: 0 0 4px 0;"><strong>Measurement Mode:</strong> ${projectData.mode || 'Screen Click / RTK'}</p>
            <p style="margin: 0;"><strong>RTK Fix Status:</strong> ${projectData.rtkStatus || 'RTK FIX (1.2 cm)'}</p>
          </div>
        </div>

        <!-- Summary Highlights -->
        <div style="display: flex; gap: 12px; margin-bottom: 24px;">
          <div style="flex: 1; background: #eff6ff; border: 1px solid #bfdbfe; padding: 12px; border-radius: 8px; text-align: center;">
            <span style="font-size: 11px; color: #1e40af; text-transform: uppercase; font-weight: 700;">Total Path / Perimeter</span>
            <h2 style="margin: 4px 0 0 0; color: #1e3a8a; font-size: 20px;">${projectData.totalLength}</h2>
          </div>
          <div style="flex: 1; background: #f0fdf4; border: 1px solid #bbf7d0; padding: 12px; border-radius: 8px; text-align: center;">
            <span style="font-size: 11px; color: #166534; text-transform: uppercase; font-weight: 700;">Total Measured Area</span>
            <h2 style="margin: 4px 0 0 0; color: #14532d; font-size: 20px;">${projectData.totalArea}</h2>
          </div>
          <div style="flex: 1; background: #fefce8; border: 1px solid #fef08a; padding: 12px; border-radius: 8px; text-align: center;">
            <span style="font-size: 11px; color: #854d0e; text-transform: uppercase; font-weight: 700;">Total Estimated Cost</span>
            <h2 style="margin: 4px 0 0 0; color: #713f12; font-size: 20px;">${projectData.totalCost}</h2>
          </div>
        </div>

        <!-- Itemized Measurements Table -->
        <h3 style="font-size: 15px; color: #0f172a; margin: 0 0 8px 0; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px;">Itemized Ground Measurements</h3>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 12px;">
          <thead>
            <tr style="background: #f1f5f9; text-align: left; color: #334155;">
              <th style="padding: 8px; border: 1px solid #cbd5e1;">#</th>
              <th style="padding: 8px; border: 1px solid #cbd5e1;">Item Name</th>
              <th style="padding: 8px; border: 1px solid #cbd5e1;">Type</th>
              <th style="padding: 8px; border: 1px solid #cbd5e1;">Dimension</th>
              <th style="padding: 8px; border: 1px solid #cbd5e1;">Slope Grade</th>
            </tr>
          </thead>
          <tbody>
            ${projectData.items.map((item, idx) => `
              <tr>
                <td style="padding: 8px; border: 1px solid #e2e8f0;">${idx + 1}</td>
                <td style="padding: 8px; border: 1px solid #e2e8f0; font-weight: 600;">${item.name}</td>
                <td style="padding: 8px; border: 1px solid #e2e8f0;">${item.type}</td>
                <td style="padding: 8px; border: 1px solid #e2e8f0; font-family: monospace; font-weight: bold;">${item.value}</td>
                <td style="padding: 8px; border: 1px solid #e2e8f0;">${item.slope || '0.0 % (Flat)'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>

        <!-- Sign-Off Block -->
        <div style="margin-top: 40px; border-top: 1px solid #cbd5e1; padding-top: 16px; display: flex; justify-content: space-between; font-size: 12px; color: #475569;">
          <div>
            <p style="margin: 0 0 32px 0;"><strong>Prepared By:</strong> SiteTap PRO Surveyor</p>
            <p style="margin: 0; border-top: 1px solid #94a3b8; width: 200px; padding-top: 4px;">Signature / Date</p>
          </div>
          <div>
            <p style="margin: 0 0 32px 0;"><strong>Client Approval:</strong> ${projectData.clientName || 'Client'}</p>
            <p style="margin: 0; border-top: 1px solid #94a3b8; width: 200px; padding-top: 4px;">Signature / Date</p>
          </div>
        </div>
      </div>
    `;

    const opt = {
      margin: 10,
      filename: `${projectData.projectName || 'Site_Measurement'}_Report.pdf`,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2 },
      jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' }
    };

    if (window.html2pdf) {
      window.html2pdf().set(opt).from(reportHtml).save();
    } else {
      // Fallback print window
      const printWin = window.open('', '_blank');
      printWin.document.write(reportHtml);
      printWin.document.close();
      printWin.print();
    }
  }

  /**
   * Export CSV Point File for Surveyor CAD Software
   */
  static generateCSV(items, projectName = 'Site_Points') {
    let csvStr = 'Point_ID,Name,Type,X_Meters,Y_Meters,Z_Elevation,Value,Slope_Grade\n';
    let pId = 1;

    items.forEach(item => {
      if (item.points && item.points.length > 0) {
        item.points.forEach((pt, pIdx) => {
          csvStr += `${pId++},"${item.name}_P${pIdx + 1}","${item.type}",${pt.x.toFixed(4)},${pt.y.toFixed(4)},${(pt.z || 0).toFixed(4)},"${item.value}","${item.slope || '0%'}"\n`;
        });
      }
    });

    const blob = new Blob([csvStr], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `${projectName}_Points.csv`;
    link.click();
  }
}
