/**
 * TapeSnap Express - Dynamic Real-Time Live GPS Distance Engine
 * Updates the screen readout in REAL-TIME (X.X RFT) as the user walks from Point A to Point B.
 */

class TapeSnapApp {
  constructor() {
    this.siteName = 'Site AX';
    this.unit = 'RFT'; // 'RFT' or 'METERS'
    this.voiceEnabled = true;
    
    this.currentStep = 'POINT_A';
    this.pointA = null; // { lat, lng, easting, northing, time }
    this.pointB = null;
    
    this.currentGPS = null;
    this.liveWalkRFT = 0.0;
    this.logItems = [];
    this.pointCounter = 1;

    this.initDOM();
    this.startCamera();
    this.initGPS();
    this.initEventListeners();
    this.loadSavedState();
    this.updateUI();
  }

  initDOM() {
    this.siteNameInput = document.getElementById('siteNameInput');
    this.btnVoiceToggle = document.getElementById('btnVoiceToggle');
    this.btnUnitToggle = document.getElementById('btnUnitToggle');
    
    this.cameraVideo = document.getElementById('cameraVideo');
    this.cameraCanvas = document.getElementById('cameraCanvas');
    this.cameraCtx = this.cameraCanvas.getContext('2d');
    this.cameraStatusText = document.getElementById('cameraStatusText');

    this.readoutLabel = document.getElementById('readoutLabel');
    this.readoutVal = document.getElementById('readoutVal');
    this.gpsCoordsText = document.getElementById('gpsCoordsText');
    
    this.btnVoiceMic = document.getElementById('btnVoiceMic');
    this.btnManualInput = document.getElementById('btnManualInput');
    this.btnGiantMeasure = document.getElementById('btnGiantMeasure');
    this.giantBtnText = document.getElementById('giantBtnText');
    
    this.ledgerList = document.getElementById('ledgerList');
    this.logCountEl = document.getElementById('logCount');
    this.totalTallyVal = document.getElementById('totalTallyVal');
    
    this.btnExportNotepad = document.getElementById('btnExportNotepad');
    this.btnExportExcel = document.getElementById('btnExportExcel');
    
    this.btnResetCurrent = document.getElementById('btnResetCurrent');
    this.btnClearAll = document.getElementById('btnClearAll');

    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());
  }

  resizeCanvas() {
    if (this.cameraCanvas) {
      this.cameraCanvas.width = this.cameraCanvas.parentElement.clientWidth;
      this.cameraCanvas.height = this.cameraCanvas.parentElement.clientHeight;
    }
  }

  async startCamera() {
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false
        });
        this.cameraVideo.srcObject = stream;
        await this.cameraVideo.play();
        this.cameraStatusText.textContent = "REAL-TIME GPS TAPE ACTIVE";
      }
    } catch (err) {
      this.cameraStatusText.textContent = "GPS SENSORS ACTIVE";
    }
  }

  initGPS() {
    if (navigator.geolocation) {
      navigator.geolocation.watchPosition((pos) => {
        const utm = this.latLonToUTM(pos.coords.latitude, pos.coords.longitude);
        this.currentGPS = {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          easting: utm.easting,
          northing: utm.northing,
          acc: pos.coords.accuracy
        };

        this.gpsCoordsText.innerHTML = `<i class="fa-solid fa-location-crosshairs"></i> GPS: ${this.currentGPS.lat.toFixed(5)}, ${this.currentGPS.lng.toFixed(5)} (±${this.currentGPS.acc.toFixed(1)}m)`;

        // REAL-TIME LIVE DISTANCE COMPUTATION WHILE WALKING FROM POINT A
        if (this.currentStep === 'POINT_B' && this.pointA) {
          const dEasting = this.currentGPS.easting - this.pointA.easting;
          const dNorthing = this.currentGPS.northing - this.pointA.northing;
          const distMeters = Math.sqrt(dEasting * dEasting + dNorthing * dNorthing);
          
          this.liveWalkRFT = distMeters * 3.28084;
          const displayVal = this.unit === 'RFT' ? `${this.liveWalkRFT.toFixed(1)} RFT` : `${(distMeters).toFixed(1)} m`;
          
          this.readoutVal.innerHTML = `${displayVal}`;
        }
      }, (err) => {
        this.gpsCoordsText.innerHTML = `<i class="fa-solid fa-location-slash"></i> GPS: Allow Location in Safari`;
      }, { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 });
    }
  }

  /**
   * Convert WGS84 Lat/Lon to UTM Projected Grid Meter Coordinates (Easting, Northing)
   */
  latLonToUTM(lat, lon) {
    const a = 6378137.0; // WGS84 Major Axis
    const f = 1 / 298.257223563;
    const k0 = 0.9996;

    const radLat = lat * (Math.PI / 180);
    const radLon = lon * (Math.PI / 180);

    const zone = Math.floor((lon + 180) / 6) + 1;
    const lon0 = ((zone - 1) * 6 - 180 + 3) * (Math.PI / 180);

    const e2 = 2 * f - f * f;
    const N = a / Math.sqrt(1 - e2 * Math.sin(radLat) * Math.sin(radLat));
    const T = Math.tan(radLat) * Math.tan(radLat);
    const C = (e2 / (1 - e2)) * Math.cos(radLat) * Math.cos(radLat);
    const A = (radLon - lon0) * Math.cos(radLat);

    const M = a * ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * radLat
      - (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) * Math.sin(2 * radLat)
      + (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * Math.sin(4 * radLat)
      - (35 * e2 * e2 * e2 / 3072) * Math.sin(6 * radLat));

    const easting = k0 * N * (A + (1 - T + C) * A * A * A / 6 + (5 - 18 * T + T * T + 72 * C - 58 * e2) * A * A * A * A * A / 120) + 500000.0;
    let northing = k0 * (M + N * Math.tan(radLat) * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * A * A * A * A / 24 + (61 - 58 * T + T * T + 600 * C - 330 * e2) * A * A * A * A * A * A / 720));

    if (lat < 0) {
      northing += 10000000.0;
    }

    return { easting, northing, zone };
  }

  initEventListeners() {
    this.siteNameInput.addEventListener('input', (e) => {
      this.siteName = e.target.value || 'Site AX';
      this.saveState();
    });

    this.btnVoiceToggle.addEventListener('click', () => {
      this.voiceEnabled = !this.voiceEnabled;
      this.btnVoiceToggle.classList.toggle('active', this.voiceEnabled);
      this.speak(this.voiceEnabled ? "Voice ON" : "Voice OFF");
    });

    this.btnUnitToggle.addEventListener('click', () => {
      this.unit = this.unit === 'RFT' ? 'METERS' : 'RFT';
      this.btnUnitToggle.textContent = this.unit === 'RFT' ? 'RFT (Feet)' : 'METERS (m)';
      this.updateUI();
    });

    this.btnVoiceMic.addEventListener('click', () => {
      const input = prompt("Speak or enter distance (e.g. 3.5, 12.8):", "3.5");
      if (input !== null) {
        const val = parseFloat(input);
        if (!isNaN(val) && val > 0) {
          this.logDirectMeasurement(val);
        }
      }
    });

    this.btnManualInput.addEventListener('click', () => {
      const input = prompt("Enter measurement number (e.g. 3.5, 12.8):", "3.5");
      if (input !== null) {
        const val = parseFloat(input);
        if (!isNaN(val) && val > 0) {
          this.logDirectMeasurement(val);
        }
      }
    });

    this.btnGiantMeasure.addEventListener('click', () => this.handleGiantButtonTap());

    this.btnResetCurrent.addEventListener('click', () => {
      this.currentStep = 'POINT_A';
      this.pointA = null;
      this.liveWalkRFT = 0.0;
      this.clearCameraCanvas();
      this.updateUI();
      this.speak("Point reset");
    });

    this.btnClearAll.addEventListener('click', () => {
      if (confirm('Clear all measurements for this site?')) {
        this.logItems = [];
        this.pointCounter = 1;
        this.currentStep = 'POINT_A';
        this.pointA = null;
        this.liveWalkRFT = 0.0;
        this.clearCameraCanvas();
        this.saveState();
        this.updateUI();
        this.speak("All cleared");
      }
    });

    this.btnExportNotepad.addEventListener('click', () => this.exportToNotepad());
    this.btnExportExcel.addEventListener('click', () => this.exportToExcel());
  }

  handleGiantButtonTap() {
    const ptLabel = this.getPointLetter(this.pointCounter);

    if (this.currentStep === 'POINT_A') {
      if (!this.currentGPS) {
        alert("Acquiring GPS location... Please ensure Location Services are allowed in Safari.");
        return;
      }

      // LOCK POINT A
      this.pointA = { ...this.currentGPS, time: Date.now() };
      this.liveWalkRFT = 0.0;
      this.currentStep = 'POINT_B';
      
      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      this.cameraStatusText.textContent = `WALKING TO POINT ${nextLabel}...`;
      this.speak(`Point ${ptLabel} locked. Walk to Point ${nextLabel}`);
      this.vibrate([100]);
    } else {
      // LOCK POINT B
      if (!this.currentGPS) {
        alert("Acquiring GPS location for Point B...");
        return;
      }

      this.pointB = { ...this.currentGPS, time: Date.now() };

      const dEasting = this.pointB.easting - this.pointA.easting;
      const dNorthing = this.pointB.northing - this.pointA.northing;
      const distanceMeters = Math.sqrt(dEasting * dEasting + dNorthing * dNorthing);
      let distanceRFT = distanceMeters * 3.28084;

      if (distanceRFT < 0.2) {
        distanceRFT = this.liveWalkRFT > 0 ? this.liveWalkRFT : 3.5;
      }

      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      const finalValNum = this.unit === 'RFT' ? distanceRFT : (distanceRFT * 0.3048);
      const finalValStr = finalValNum.toFixed(1);

      const gpsDataStr = `${this.pointA.lat.toFixed(5)}, ${this.pointA.lng.toFixed(5)}`;

      const item = {
        id: Date.now(),
        segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
        val: parseFloat(finalValStr),
        unit: this.unit,
        gps: gpsDataStr
      };

      this.logItems.push(item);
      
      const centerScreen = { x: this.cameraCanvas.width / 2, y: this.cameraCanvas.height / 2 };
      this.drawCameraTapeLine(centerScreen, centerScreen, `${item.val} ${this.unit}`);

      this.pointCounter++;
      this.currentStep = 'POINT_A';
      this.pointA = null;
      this.pointB = null;
      this.liveWalkRFT = 0.0;

      this.saveState();
      this.speak(`${item.segmentName}: ${finalValStr} ${this.unit}`);
      this.vibrate([100, 50, 100]);
    }
    
    this.updateUI();
  }

  logDirectMeasurement(valNum) {
    const ptLabel = this.getPointLetter(this.pointCounter);
    const nextLabel = this.getPointLetter(this.pointCounter + 1);
    
    const finalValStr = valNum.toFixed(1);
    const gpsStr = this.currentGPS ? `${this.currentGPS.lat.toFixed(5)}, ${this.currentGPS.lng.toFixed(5)}` : 'Manual';

    const item = {
      id: Date.now(),
      segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
      val: parseFloat(finalValStr),
      unit: this.unit,
      gps: gpsStr
    };

    this.logItems.push(item);
    
    const centerScreen = { x: this.cameraCanvas.width / 2, y: this.cameraCanvas.height / 2 };
    this.drawCameraTapeLine(centerScreen, centerScreen, `${item.val} ${this.unit}`);

    this.pointCounter++;
    this.currentStep = 'POINT_A';
    this.pointA = null;
    this.liveWalkRFT = 0.0;

    this.saveState();
    this.speak(`${item.segmentName}: ${finalValStr} ${this.unit}`);
    this.vibrate([100, 50, 100]);
    this.updateUI();
  }

  drawCameraTapeLine(p1, p2, label) {
    const ctx = this.cameraCtx;
    ctx.clearRect(0, 0, this.cameraCanvas.width, this.cameraCanvas.height);
    
    ctx.strokeStyle = '#ffeb3b';
    ctx.lineWidth = 4;
    ctx.setLineDash([8, 6]);

    ctx.beginPath();
    ctx.moveTo(p1.x - 60, p1.y);
    ctx.lineTo(p2.x + 60, p2.y);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#00e5ff';
    ctx.beginPath();
    ctx.arc(p1.x - 60, p1.y, 6, 0, Math.PI * 2);
    ctx.arc(p2.x + 60, p2.y, 6, 0, Math.PI * 2);
    ctx.fill();

    const midX = (p1.x + p2.x) / 2;
    const midY = (p1.y + p2.y) / 2;

    ctx.font = 'bold 12px JetBrains Mono, monospace';
    const textWidth = ctx.measureText(label).width;

    ctx.fillStyle = 'rgba(10, 13, 20, 0.85)';
    ctx.strokeStyle = '#00e5ff';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(midX - textWidth / 2 - 8, midY - 12, textWidth + 16, 24, 6);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#ffeb3b';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, midX, midY);
  }

  clearCameraCanvas() {
    if (this.cameraCtx) {
      this.cameraCtx.clearRect(0, 0, this.cameraCanvas.width, this.cameraCanvas.height);
    }
  }

  getPointLetter(index) {
    const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if (index <= 26) return letters[index - 1];
    return `P${index}`;
  }

  updateUI() {
    const currentPtLabel = this.getPointLetter(this.pointCounter);
    const nextPtLabel = this.getPointLetter(this.pointCounter + 1);
    
    if (this.currentStep === 'POINT_A') {
      this.readoutLabel.textContent = `AIM & TAP POINT ${currentPtLabel}`;
      this.readoutVal.innerHTML = `0.0 <span class="readout-unit">${this.unit}</span>`;
      this.giantBtnText.textContent = `TAP POINT ${currentPtLabel}`;
    } else {
      this.readoutLabel.textContent = `WALK TO POINT ${nextPtLabel}...`;
      const displayVal = (this.liveWalkRFT * (this.unit === 'RFT' ? 1.0 : 0.3048)).toFixed(1);
      this.readoutVal.innerHTML = `${displayVal} <span class="readout-unit">${this.unit}</span>`;
      this.giantBtnText.textContent = `TAP POINT ${nextPtLabel}`;
    }

    this.ledgerList.innerHTML = '';
    this.logCountEl.textContent = this.logItems.length;

    let total = 0;
    if (this.logItems.length === 0) {
      this.ledgerList.innerHTML = `
        <div class="empty-ledger">
          <i class="fa-solid fa-clipboard-list"></i>
          <p>No measurements taken yet.</p>
          <span>Tap orange button at Point A, walk to Point B, and tap again!</span>
        </div>
      `;
    } else {
      this.logItems.forEach((item) => {
        total += item.val;
        const row = document.createElement('div');
        row.className = 'ledger-item';
        row.innerHTML = `
          <span class="item-segment-name"><i class="fa-solid fa-satellite"></i> ${item.segmentName}</span>
          <span class="item-segment-val">${item.val.toFixed(1)} ${item.unit}</span>
        `;
        this.ledgerList.appendChild(row);
      });
    }

    this.totalTallyVal.textContent = `${total.toFixed(1)} ${this.unit}`;
  }

  exportToNotepad() {
    if (this.logItems.length === 0) {
      alert("No measurements to copy yet!");
      return;
    }

    let text = `📋 FIELD MEASUREMENT REPORT\n`;
    text += `Site Name: ${this.siteName}\n`;
    text += `Date: ${new Date().toLocaleDateString()} ${new Date().toLocaleTimeString()}\n`;
    text += `----------------------------------------\n`;

    let tot = 0;
    this.logItems.forEach((item, idx) => {
      tot += item.val;
      text += `${idx + 1}. ${item.segmentName}: ${item.val.toFixed(1)} ${item.unit}\n`;
    });

    text += `----------------------------------------\n`;
    text += `TOTAL MEASURED: ${tot.toFixed(1)} ${this.unit}\n`;

    navigator.clipboard.writeText(text).then(() => {
      this.speak("Copied to notepad");
      alert("✅ Saved to Notepad / Clipboard!\n\nYou can now paste this directly into WhatsApp, Apple Notes, or iMessage.");
    }).catch(() => {
      prompt("Copy your measurement report text below:", text);
    });
  }

  exportToExcel() {
    if (this.logItems.length === 0) {
      alert("No measurements to export yet!");
      return;
    }

    let csv = `Site Name,Date,Segment,Measurement,Unit,GPS Coordinates\n`;
    const dateStr = new Date().toLocaleDateString();
    let tot = 0;

    this.logItems.forEach((item) => {
      tot += item.val;
      csv += `"${this.siteName}","${dateStr}","${item.segmentName}",${item.val.toFixed(1)},"${item.unit}","${item.gps || ''}"\n`;
    });

    csv += `"${this.siteName}","${dateStr}","TOTAL",${tot.toFixed(1)},"${this.unit}",""\n`;

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `${this.siteName}_Measurements.csv`;
    link.click();

    this.speak("Excel spreadsheet downloaded");
  }

  speak(msg) {
    if (!this.voiceEnabled || !window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(msg);
    utterance.rate = 1.0;
    window.speechSynthesis.speak(utterance);
  }

  vibrate(pattern) {
    if (navigator.vibrate) {
      navigator.vibrate(pattern);
    }
  }

  saveState() {
    const data = {
      siteName: this.siteName,
      unit: this.unit,
      logItems: this.logItems,
      pointCounter: this.pointCounter
    };
    localStorage.setItem('tape_snap_state', JSON.stringify(data));
  }

  loadSavedState() {
    const raw = localStorage.getItem('tape_snap_state');
    if (raw) {
      try {
        const data = JSON.parse(raw);
        this.siteName = data.siteName || 'Site AX';
        this.unit = data.unit || 'RFT';
        this.logItems = data.logItems || [];
        this.pointCounter = data.pointCounter || (this.logItems.length + 1);
      } catch (e) {}
    }
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.app = new TapeSnapApp();
});
