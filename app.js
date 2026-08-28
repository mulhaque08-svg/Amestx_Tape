/**
 * TapeSnap Express - Google / Esri High-Res Satellite Map Site Tape Logic
 * Enables instant pin-drop distance measurement right from high-res satellite imagery,
 * connected directly to Voice Readout, Excel export, and WhatsApp Notepad logging.
 */

class TapeSnapApp {
  constructor() {
    this.siteName = 'Site AX';
    this.unit = 'RFT'; // 'RFT' or 'METERS'
    this.voiceEnabled = true;
    
    this.currentStep = 'POINT_A';
    this.mapPinA = null; // { lat, lng, marker }
    this.mapPinB = null;
    
    this.map = null;
    this.mapMarkers = [];
    this.mapPolyline = null;

    this.logItems = [];
    this.pointCounter = 1;
    this.recognition = null;

    this.initDOM();
    this.initSatelliteMap();
    this.initSpeechRecognition();
    this.initEventListeners();
    this.loadSavedState();
    this.updateUI();
  }

  initDOM() {
    this.siteNameInput = document.getElementById('siteNameInput');
    this.btnVoiceToggle = document.getElementById('btnVoiceToggle');
    this.btnUnitToggle = document.getElementById('btnUnitToggle');
    
    this.mapStatusText = document.getElementById('mapStatusText');
    this.btnLocateMe = document.getElementById('btnLocateMe');
    this.btnClearMapPins = document.getElementById('btnClearMapPins');

    this.readoutLabel = document.getElementById('readoutLabel');
    this.readoutVal = document.getElementById('readoutVal');
    
    this.btnVoiceMic = document.getElementById('btnVoiceMic');
    this.btnManualInput = document.getElementById('btnManualInput');
    
    this.ledgerList = document.getElementById('ledgerList');
    this.logCountEl = document.getElementById('logCount');
    this.totalTallyVal = document.getElementById('totalTallyVal');
    
    this.btnExportNotepad = document.getElementById('btnExportNotepad');
    this.btnExportExcel = document.getElementById('btnExportExcel');
  }

  initSatelliteMap() {
    if (!window.L) return;

    // Default center (Houston, TX area or user location)
    const defaultLat = 29.7604;
    const defaultLng = -95.3698;

    this.map = L.map('satelliteMap', {
      center: [defaultLat, defaultLng],
      zoom: 18,
      zoomControl: false
    });

    // High-Resolution Esri World Imagery Satellite Tiles
    const esriSatellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 21,
      attribution: '&copy; Esri World Imagery'
    }).addTo(this.map);

    const osmStreet = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 21,
      attribution: '&copy; OpenStreetMap'
    });

    L.control.layers({
      "Satellite": esriSatellite,
      "Street Map": osmStreet
    }, null, { position: 'topright' }).addTo(this.map);

    L.control.zoom({ position: 'bottomleft' }).addTo(this.map);

    // Map Click Listener for Pin-Drop Distance Measurement
    this.map.on('click', (e) => {
      this.handleMapClick(e.latlng.lat, e.latlng.lng);
    });

    // Auto locate user location on startup
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition((pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        this.map.setView([lat, lng], 19);
      }, () => {});
    }
  }

  handleMapClick(lat, lng) {
    const ptLabel = this.getPointLetter(this.pointCounter);
    const nextLabel = this.getPointLetter(this.pointCounter + 1);

    if (this.currentStep === 'POINT_A') {
      // DROP PIN A
      this.clearMapPins();
      
      this.mapPinA = { lat, lng };
      const markerA = L.marker([lat, lng], {
        icon: L.divIcon({
          className: 'custom-map-pin',
          html: `<div class="map-pin-inner">${ptLabel}</div>`,
          iconSize: [22, 22],
          iconAnchor: [11, 11]
        })
      }).addTo(this.map);
      this.mapMarkers.push(markerA);

      this.currentStep = 'POINT_B';
      this.mapStatusText.textContent = `PIN ${ptLabel} SET. TAP MAP FOR PIN ${nextLabel}`;
      this.speak(`Point ${ptLabel} pinned. Tap map for Point ${nextLabel}`);
      this.vibrate([100]);
    } else {
      // DROP PIN B & CALCULATE EXACT GEODESIC SATELLITE DISTANCE
      this.mapPinB = { lat, lng };
      const markerB = L.marker([lat, lng], {
        icon: L.divIcon({
          className: 'custom-map-pin',
          html: `<div class="map-pin-inner pin-b">${nextLabel}</div>`,
          iconSize: [22, 22],
          iconAnchor: [11, 11]
        })
      }).addTo(this.map);
      this.mapMarkers.push(markerB);

      // Draw Neon Measurement Line Between Pin A and Pin B
      this.mapPolyline = L.polyline([[this.mapPinA.lat, this.mapPinA.lng], [lat, lng]], {
        color: '#ffeb3b',
        weight: 4,
        dashArray: '8, 6'
      }).addTo(this.map);

      // Compute Exact Geodesic Distance Math (Haversine Formula)
      const distanceMeters = this.calcHaversineDistance(this.mapPinA.lat, this.mapPinA.lng, lat, lng);
      const distanceRFT = distanceMeters * 3.28084; // Meters to Running Feet

      const finalValNum = this.unit === 'RFT' ? distanceRFT : distanceMeters;
      const finalValStr = finalValNum.toFixed(1);

      const item = {
        id: Date.now(),
        segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
        val: parseFloat(finalValStr),
        unit: this.unit,
        gps: `${lat.toFixed(5)}, ${lng.toFixed(5)}`
      };

      this.logItems.push(item);
      this.pointCounter++;
      this.currentStep = 'POINT_A';
      this.mapPinA = null;
      this.mapPinB = null;

      this.mapStatusText.textContent = `TAP MAP TO DROP PIN ${this.getPointLetter(this.pointCounter)}`;
      this.saveState();
      this.speak(`${item.segmentName}: ${finalValStr} ${this.unit}`);
      this.vibrate([100, 50, 100]);
    }

    this.updateUI();
  }

  /**
   * Calculate Exact Haversine Geodesic Earth Distance between 2 Lat/Lon Points (in meters)
   * Exact math formula used by Google Maps & Apple Maps
   */
  calcHaversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000.0; // Earth radius in meters
    const dLat = (lat2 - lat1) * (Math.PI / 180.0);
    const dLon = (lon2 - lon1) * (Math.PI / 180.0);

    const a = Math.sin(dLat / 2.0) * Math.sin(dLat / 2.0) +
              Math.cos(lat1 * (Math.PI / 180.0)) * Math.cos(lat2 * (Math.PI / 180.0)) *
              Math.sin(dLon / 2.0) * Math.sin(dLon / 2.0);

    const c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
    return R * c;
  }

  clearMapPins() {
    this.mapMarkers.forEach(m => this.map.removeLayer(m));
    this.mapMarkers = [];
    if (this.mapPolyline) {
      this.map.removeLayer(this.mapPolyline);
      this.mapPolyline = null;
    }
  }

  initSpeechRecognition() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SpeechRecognition) {
      this.recognition = new SpeechRecognition();
      this.recognition.continuous = false;
      this.recognition.interimResults = false;
      this.recognition.lang = 'en-US';

      this.recognition.onstart = () => {
        this.btnVoiceMic.classList.add('listening');
        this.btnVoiceMic.querySelector('span').textContent = "LISTENING... SPEAK NOW";
        this.speak("Listening... speak measurement number");
      };

      this.recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript;
        const match = transcript.match(/[-+]?[0-9]*\.?[0-9]+/);
        if (match) {
          this.logDirectMeasurement(parseFloat(match[0]));
        } else {
          const wordsToNum = { "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10 };
          const lower = transcript.toLowerCase().trim();
          if (wordsToNum[lower]) {
            this.logDirectMeasurement(wordsToNum[lower]);
          } else {
            alert(`Voice heard: "${transcript}". Please say a clear number (e.g., "45.2").`);
          }
        }
      };

      this.recognition.onend = () => {
        this.btnVoiceMic.classList.remove('listening');
        this.btnVoiceMic.querySelector('span').textContent = "SPEAK DISTANCE";
      };

      this.recognition.onerror = () => {
        this.btnVoiceMic.classList.remove('listening');
        this.btnVoiceMic.querySelector('span').textContent = "SPEAK DISTANCE";
      };
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

    // Locate My Current GPS Position
    this.btnLocateMe.addEventListener('click', () => {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition((pos) => {
          const lat = pos.coords.latitude;
          const lng = pos.coords.longitude;
          this.map.setView([lat, lng], 19);
          this.speak("Located your site position");
        }, () => {
          alert("GPS location unavailable. Allow location access in Safari.");
        });
      }
    });

    // Reset Map Pins
    this.btnClearMapPins.addEventListener('click', () => {
      this.clearMapPins();
      this.currentStep = 'POINT_A';
      this.mapPinA = null;
      this.mapPinB = null;
      this.updateUI();
      this.speak("Map pins reset");
    });

    // Voice Mic Button
    this.btnVoiceMic.addEventListener('click', () => {
      if (this.recognition) {
        this.recognition.start();
      } else {
        const input = prompt("Speak or enter distance (e.g. 45.2):", "45.2");
        if (input !== null) {
          const val = parseFloat(input);
          if (!isNaN(val) && val > 0) this.logDirectMeasurement(val);
        }
      }
    });

    // Enter Number Manually
    this.btnManualInput.addEventListener('click', () => {
      const input = prompt("Enter measurement number (e.g. 45.2):", "45.2");
      if (input !== null) {
        const val = parseFloat(input);
        if (!isNaN(val) && val > 0) {
          this.logDirectMeasurement(val);
        }
      }
    });

    this.btnExportNotepad.addEventListener('click', () => this.exportToNotepad());
    this.btnExportExcel.addEventListener('click', () => this.exportToExcel());
  }

  logDirectMeasurement(valNum) {
    const ptLabel = this.getPointLetter(this.pointCounter);
    const nextLabel = this.getPointLetter(this.pointCounter + 1);
    
    const finalValStr = valNum.toFixed(1);

    const item = {
      id: Date.now(),
      segmentName: `Point ${ptLabel} ➔ Point ${nextLabel}`,
      val: parseFloat(finalValStr),
      unit: this.unit
    };

    this.logItems.push(item);
    this.pointCounter++;
    this.currentStep = 'POINT_A';

    this.saveState();
    this.speak(`${item.segmentName}: ${finalValStr} ${this.unit}`);
    this.vibrate([100, 50, 100]);
    this.updateUI();
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
      this.readoutLabel.textContent = `TAP SATELLITE MAP FOR PIN ${currentPtLabel}`;
      this.readoutVal.innerHTML = `0.0 <span class="readout-unit">${this.unit}</span>`;
    } else {
      this.readoutLabel.textContent = `TAP SATELLITE MAP FOR PIN ${nextPtLabel}`;
    }

    this.ledgerList.innerHTML = '';
    this.logCountEl.textContent = this.logItems.length;

    let total = 0;
    if (this.logItems.length === 0) {
      this.ledgerList.innerHTML = `
        <div class="empty-ledger">
          <i class="fa-solid fa-map-location-dot"></i>
          <p>No measurements taken yet.</p>
          <span>Tap satellite map to drop Point A & Point B, or speak distance to log into Excel!</span>
        </div>
      `;
    } else {
      this.logItems.forEach((item) => {
        total += item.val;
        const row = document.createElement('div');
        row.className = 'ledger-item';
        row.innerHTML = `
          <span class="item-segment-name"><i class="fa-solid fa-map-pin"></i> ${item.segmentName}</span>
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
