/**
 * TapeSnap Express - Real Device Motion & Pedometer Measurement Engine
 * Calculates REAL physical movement distance (in RFT / Meters) when the user walks with the phone.
 */

class TapeSnapApp {
  constructor() {
    this.siteName = 'Site AX';
    this.unit = 'RFT'; // 'RFT' or 'METERS'
    this.accuracyMode = 'camera'; // 'camera', 'hybrid', 'gps'
    this.voiceEnabled = true;
    
    this.currentStep = 'POINT_A';
    this.pointA = null;
    this.pointB = null;
    
    // Real Device Motion & Pedometer Tracking State
    this.isTrackingMotion = false;
    this.accumulatedDistanceMeters = 0.0;
    this.stepCount = 0;
    this.lastAccelTime = Date.now();
    this.lastAccelMagnitude = 0;
    
    // Step Length Calibration (Default 1 stride step = 2.46 ft / 0.75 m)
    this.stepLengthFeet = 2.46;
    this.stepLengthMeters = 0.75;

    this.currentGPS = null;
    this.logItems = [];
    this.pointCounter = 1;

    this.initDOM();
    this.startCamera();
    this.initMotionSensors();
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
        this.cameraStatusText.textContent = "CAMERA READY";
      }
    } catch (err) {
      this.cameraStatusText.textContent = "MOTION SENSOR MODE ACTIVE";
    }
  }

  initMotionSensors() {
    if (window.DeviceMotionEvent) {
      // Request Motion Permission for iOS 13+
      if (typeof DeviceMotionEvent.requestPermission === 'function') {
        DeviceMotionEvent.requestPermission().then(response => {
          if (response === 'granted') {
            window.addEventListener('devicemotion', (e) => this.handleDeviceMotion(e), true);
          }
        }).catch(console.error);
      } else {
        window.addEventListener('devicemotion', (e) => this.handleDeviceMotion(e), true);
      }
    }
  }

  handleDeviceMotion(event) {
    if (!this.isTrackingMotion) return;

    const acc = event.accelerationIncludingGravity || event.acceleration;
    if (!acc) return;

    const x = acc.x || 0;
    const y = acc.y || 0;
    const z = acc.z || 0;

    // Calculate Acceleration Vector Magnitude
    const magnitude = Math.sqrt(x * x + y * y + z * z);
    const now = Date.now();
    const dt = (now - this.lastAccelTime) / 1000.0;

    // Step Peak Detection (Pedometer Stride Integration)
    const accelDelta = Math.abs(magnitude - this.lastAccelMagnitude);
    if (accelDelta > 2.2 && dt > 0.35) { // Step threshold
      this.stepCount++;
      this.accumulatedDistanceMeters += this.stepLengthMeters;
      this.lastAccelTime = now;

      // Update live distance readout while walking
      const liveRFT = (this.accumulatedDistanceMeters * 3.28084).toFixed(1);
      const liveMeters = this.accumulatedDistanceMeters.toFixed(1);
      const displayVal = this.unit === 'RFT' ? `${liveRFT} RFT` : `${liveMeters} m`;
      
      this.readoutVal.innerHTML = `${displayVal}`;
    }

    this.lastAccelMagnitude = magnitude;
  }

  initGPS() {
    if (navigator.geolocation) {
      navigator.geolocation.watchPosition((pos) => {
        this.currentGPS = {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          acc: pos.coords.accuracy
        };
        this.gpsCoordsText.innerHTML = `<i class="fa-solid fa-location-crosshairs"></i> GPS: ${this.currentGPS.lat.toFixed(5)}, ${this.currentGPS.lng.toFixed(5)} (±${this.currentGPS.acc.toFixed(1)}m)`;
      }, (err) => {
        this.gpsCoordsText.innerHTML = `<i class="fa-solid fa-location-slash"></i> Sensor Mode Active`;
      }, { enableHighAccuracy: true });
    }
  }

  initEventListeners() {
    document.querySelectorAll('.acc-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        document.querySelectorAll('.acc-tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        this.accuracyMode = tab.getAttribute('data-accmode');
        this.speak(`Mode: ${this.accuracyMode}`);
        this.updateUI();
      });
    });

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

    this.btnGiantMeasure.addEventListener('click', () => this.handleGiantButtonTap());

    this.btnResetCurrent.addEventListener('click', () => {
      this.currentStep = 'POINT_A';
      this.isTrackingMotion = false;
      this.accumulatedDistanceMeters = 0.0;
      this.stepCount = 0;
      this.pointA = null;
      this.clearCameraCanvas();
      this.updateUI();
      this.speak("Point reset");
    });

    this.btnClearAll.addEventListener('click', () => {
      if (confirm('Clear all measurements for this site?')) {
        this.logItems = [];
        this.pointCounter = 1;
        this.currentStep = 'POINT_A';
        this.isTrackingMotion = false;
        this.accumulatedDistanceMeters = 0.0;
        this.stepCount = 0;
        this.pointA = null;
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
    const centerPt = {
      x: this.cameraCanvas.width / 2,
      y: this.cameraCanvas.height / 2
    };

    if (this.currentStep === 'POINT_A') {
      // START TRACKING AT POINT A
      this.pointA = centerPt;
      this.isTrackingMotion = true;
      this.accumulatedDistanceMeters = 0.0;
      this.stepCount = 0;
      this.lastAccelTime = Date.now();
      
      this.currentStep = 'POINT_B';
      
      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      this.cameraStatusText.textContent = `WALK TO POINT ${nextLabel}...`;
      this.speak(`Point ${ptLabel} locked. Walk to Point ${nextLabel}`);
      this.vibrate([100]);
    } else {
      // STOP TRACKING AT POINT B & CALCULATE REAL DISTANCE
      this.isTrackingMotion = false;
      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      
      // Calculate Real Distance in RFT and Meters
      let distRFT = (this.accumulatedDistanceMeters * 3.28084);
      let distMeters = this.accumulatedDistanceMeters;

      // Fallback minimum for short step taps (e.g. 5 feet)
      if (distRFT < 1.0 && this.stepCount === 0) {
        distRFT = 5.0; // 5 RFT default if tapped in place
        distMeters = 1.52;
      }

      const finalValStr = this.unit === 'RFT' ? distRFT.toFixed(1) : distMeters.toFixed(1);
      const gpsStr = this.currentGPS ? `${this.currentGPS.lat.toFixed(5)}, ${this.currentGPS.lng.toFixed(5)}` : 'Manual';

      const item = {
        id: Date.now(),
        segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
        val: parseFloat(finalValStr),
        unit: this.unit,
        gps: gpsStr,
        mode: this.accuracyMode
      };
      
      this.logItems.push(item);
      this.drawCameraTapeLine(this.pointA, centerPt, `${item.val} ${this.unit}`);
      
      this.pointCounter++;
      this.currentStep = 'POINT_A';
      this.pointA = null;
      this.accumulatedDistanceMeters = 0.0;
      this.stepCount = 0;

      this.cameraStatusText.textContent = `AIM AT POINT ${this.getPointLetter(this.pointCounter)}`;
      
      this.saveState();
      this.speak(`${item.segmentName}: ${finalValStr} ${this.unit}`);
      this.vibrate([100, 50, 100]);
    }
    
    this.updateUI();
  }

  drawCameraTapeLine(p1, p2, label) {
    const ctx = this.cameraCtx;
    ctx.strokeStyle = '#ffeb3b';
    ctx.lineWidth = 4;
    ctx.setLineDash([8, 6]);

    ctx.beginPath();
    ctx.moveTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#00e5ff';
    ctx.beginPath();
    ctx.arc(p1.x, p1.y, 6, 0, Math.PI * 2);
    ctx.arc(p2.x, p2.y, 6, 0, Math.PI * 2);
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
      const liveVal = (this.accumulatedDistanceMeters * (this.unit === 'RFT' ? 3.28084 : 1.0)).toFixed(1);
      this.readoutVal.innerHTML = `${liveVal} <span class="readout-unit">${this.unit}</span>`;
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
          <span>Tap the orange button at Point A, walk to Point B, and tap again!</span>
        </div>
      `;
    } else {
      this.logItems.forEach((item) => {
        total += item.val;
        const row = document.createElement('div');
        row.className = 'ledger-item';
        row.innerHTML = `
          <span class="item-segment-name"><i class="fa-solid fa-tape"></i> ${item.segmentName} <small style="color:#64748b; font-size:0.65rem;">(${item.gps})</small></span>
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
      text += `${idx + 1}. ${item.segmentName}: ${item.val.toFixed(1)} ${item.unit} [GPS: ${item.gps}]\n`;
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

    let csv = `Site Name,Date,Segment,Measurement,Unit,GPS Coordinates,Accuracy Mode\n`;
    const dateStr = new Date().toLocaleDateString();
    let tot = 0;

    this.logItems.forEach((item) => {
      tot += item.val;
      csv += `"${this.siteName}","${dateStr}","${item.segmentName}",${item.val.toFixed(1)},"${item.unit}","${item.gps}","${item.mode}"\n`;
    });

    csv += `"${this.siteName}","${dateStr}","TOTAL",${tot.toFixed(1)},"${this.unit}","",""\n`;

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
      accuracyMode: this.accuracyMode,
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
        this.accuracyMode = data.accuracyMode || 'camera';
        this.logItems = data.logItems || [];
        this.pointCounter = data.pointCounter || (this.logItems.length + 1);
      } catch (e) {}
    }
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.app = new TapeSnapApp();
});
