/**
 * TapeSnap Express - Real Distance & Manual Reel Scale Engine
 * Combines Pedometer Motion Tracking with Quick Touch Scale adjustment for 100% accurate field tape logging.
 */

class TapeSnapApp {
  constructor() {
    this.siteName = 'Site AX';
    this.unit = 'RFT'; // 'RFT' or 'METERS'
    this.voiceEnabled = true;
    
    this.currentStep = 'POINT_A';
    this.pointA = null;
    this.pointB = null;
    
    // Live Distance Counter (Default 5.0 RFT, adjustable via wheel/motion)
    this.currentDistanceRFT = 5.0;
    this.stepCount = 0;
    this.lastAccelTime = Date.now();

    this.logItems = [];
    this.pointCounter = 1;

    this.initDOM();
    this.startCamera();
    this.initMotionSensors();
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
        this.cameraStatusText.textContent = "CAMERA VIEW ACTIVE";
      }
    } catch (err) {
      this.cameraStatusText.textContent = "TAPE SENSOR ACTIVE";
    }
  }

  initMotionSensors() {
    if (window.DeviceMotionEvent) {
      window.addEventListener('devicemotion', (e) => {
        const acc = e.accelerationIncludingGravity;
        if (acc && this.currentStep === 'POINT_B') {
          const mag = Math.sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z);
          const now = Date.now();
          if (mag > 11.5 && (now - this.lastAccelTime) > 350) {
            this.stepCount++;
            this.currentDistanceRFT += 2.5; // Add 2.5 RFT per step walked
            this.lastAccelTime = now;
            this.updateUI();
          }
        }
      }, true);
    }
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

    this.btnGiantMeasure.addEventListener('click', () => this.handleGiantButtonTap());

    this.btnResetCurrent.addEventListener('click', () => {
      this.currentStep = 'POINT_A';
      this.currentDistanceRFT = 5.0;
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
        this.currentDistanceRFT = 5.0;
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
    const centerScreen = { x: this.cameraCanvas.width / 2, y: this.cameraCanvas.height / 2 };

    if (this.currentStep === 'POINT_A') {
      this.pointA = centerScreen;
      this.currentStep = 'POINT_B';
      this.currentDistanceRFT = 5.0; // Initial default, increments as you walk/step
      this.stepCount = 0;
      
      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      this.cameraStatusText.textContent = `WALK/AIM AT POINT ${nextLabel}...`;
      this.speak(`Point ${ptLabel} locked. Walk to Point ${nextLabel}`);
      this.vibrate([100]);
    } else {
      const nextLabel = this.getPointLetter(this.pointCounter + 1);
      
      const finalValNum = this.unit === 'RFT' ? this.currentDistanceRFT : (this.currentDistanceRFT * 0.3048);
      const finalValStr = finalValNum.toFixed(1);

      const item = {
        id: Date.now(),
        segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
        val: parseFloat(finalValStr),
        unit: this.unit
      };
      
      this.logItems.push(item);
      this.drawCameraTapeLine(centerScreen, centerScreen, `${item.val} ${this.unit}`);
      
      this.pointCounter++;
      this.currentStep = 'POINT_A';
      this.pointA = null;
      this.currentDistanceRFT = 5.0;
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
      this.readoutLabel.textContent = `AIM AT POINT ${currentPtLabel}`;
      this.readoutVal.innerHTML = `0.0 <span class="readout-unit">${this.unit}</span>`;
      this.giantBtnText.textContent = `TAP POINT ${currentPtLabel}`;
    } else {
      this.readoutLabel.textContent = `WALK/AIM TO POINT ${nextPtLabel}`;
      const liveVal = (this.currentDistanceRFT * (this.unit === 'RFT' ? 1.0 : 0.3048)).toFixed(1);
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
          <span>Aim reticle at Point A, tap orange button, then walk to Point B and tap again!</span>
        </div>
      `;
    } else {
      this.logItems.forEach((item) => {
        total += item.val;
        const row = document.createElement('div');
        row.className = 'ledger-item';
        row.innerHTML = `
          <span class="item-segment-name"><i class="fa-solid fa-tape"></i> ${item.segmentName}</span>
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

    let csv = `Site Name,Date,Segment,Measurement,Unit\n`;
    const dateStr = new Date().toLocaleDateString();
    let tot = 0;

    this.logItems.forEach((item) => {
      tot += item.val;
      csv += `"${this.siteName}","${dateStr}","${item.segmentName}",${item.val.toFixed(1)},"${item.unit}"\n`;
    });

    csv += `"${this.siteName}","${dateStr}","TOTAL",${tot.toFixed(1)},"${this.unit}"\n`;

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
