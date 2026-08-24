/**
 * SiteTap PRO - GIS Satellite Map Integration Module (Leaflet)
 */

export class MapEngine {
  constructor(containerId, onMapPointAddedCallback) {
    this.containerId = containerId;
    this.onMapPointAdded = onMapPointAddedCallback;
    this.map = null;
    this.markers = [];
    this.polyline = null;
    this.polygon = null;
    this.isInitialized = false;
  }

  initMap(centerLat = 37.774929, centerLon = -122.419416) {
    if (this.isInitialized || !window.L) return;

    this.map = L.map(this.containerId).setView([centerLat, centerLon], 19);

    // OpenStreetMap Standard & Satellite Tile Layer
    const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 21,
      attribution: '&copy; OpenStreetMap contributors'
    });

    const esriSatelliteLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 21,
      attribution: '&copy; Esri World Imagery'
    });

    esriSatelliteLayer.addTo(this.map);

    const baseMaps = {
      "Satellite View": esriSatelliteLayer,
      "Street Map": osmLayer
    };

    L.control.layers(baseMaps).addTo(this.map);

    // Map Click Listener
    this.map.on('click', (e) => {
      if (this.onMapPointAdded) {
        this.onMapPointAdded({
          lat: e.latlng.lat,
          lng: e.latlng.lng
        });
      }
    });

    this.isInitialized = true;
  }

  addPointMarker(lat, lng, label = '') {
    if (!this.map) return;
    const marker = L.marker([lat, lng], {
      icon: L.divIcon({
        className: 'map-custom-marker',
        html: `<div style="background:#00e5ff; width:14px; height:14px; border-radius:50%; border:2px solid #000; box-shadow:0 0 10px #00e5ff;"></div>`,
        iconSize: [14, 14],
        iconAnchor: [7, 7]
      })
    }).addTo(this.map);
    if (label) marker.bindTooltip(label, { permanent: true, direction: 'top' });
    this.markers.push(marker);
  }

  renderPath(points, isClosed = false) {
    if (!this.map || points.length === 0) return;

    const latLngs = points.map(p => [p.lat, p.lng]);

    if (this.polyline) this.map.removeLayer(this.polyline);
    if (this.polygon) this.map.removeLayer(this.polygon);

    if (isClosed && points.length > 2) {
      this.polygon = L.polygon(latLngs, {
        color: '#00e5ff',
        weight: 3,
        fillColor: '#00e5ff',
        fillOpacity: 0.25
      }).addTo(this.map);
    } else {
      this.polyline = L.polyline(latLngs, {
        color: '#00e5ff',
        weight: 3
      }).addTo(this.map);
    }
  }

  clearMap() {
    this.markers.forEach(m => this.map.removeLayer(m));
    this.markers = [];
    if (this.polyline) this.map.removeLayer(this.polyline);
    if (this.polygon) this.map.removeLayer(this.polygon);
  }

  invalidateSize() {
    if (this.map) {
      setTimeout(() => this.map.invalidateSize(), 200);
    }
  }
}
