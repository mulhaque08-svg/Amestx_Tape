/**
 * SiteTap PRO - RTK GNSS NMEA Telemetry & Surveyor Parser
 * Parses NMEA 0183 ($GPGGA, $GPRMC) streams from surveyor rover poles
 * and converts WGS84 Geodetic coordinates to UTM projection for centimeter math.
 */

export class NMEAParserEngine {
  constructor() {
    this.currentPosition = {
      lat: 37.774929,
      lon: -122.419416,
      altitude: 15.4, // Meters
      fixQuality: 'RTK FIX',
      accuracy: 0.012, // 1.2 cm
      satellites: 24,
      hdop: 0.6
    };
  }

  /**
   * Parse standard $GPGGA NMEA Sentence
   * Example: $GPGGA,123519,4807.038,N,01131.000,E,4,08,0.9,545.4,M,46.9,M,,*47
   */
  parseGGA(nmeaLine) {
    if (!nmeaLine || !nmeaLine.startsWith('$GP') && !nmeaLine.startsWith('$GN')) return null;

    const parts = nmeaLine.split(',');
    if (parts.length < 10) return null;

    const latRaw = parts[2];
    const latDir = parts[3];
    const lonRaw = parts[4];
    const lonDir = parts[5];
    const fixType = parseInt(parts[6], 10);
    const numSats = parseInt(parts[7], 10);
    const hdop = parseFloat(parts[8]);
    const altitude = parseFloat(parts[9]);

    if (latRaw && lonRaw) {
      const lat = this.convertNMEAToDeg(latRaw, latDir);
      const lon = this.convertNMEAToDeg(lonRaw, lonDir);

      let fixQualityStr = 'INVALID';
      let accuracy = 5.0;

      switch (fixType) {
        case 4: // RTK Fixed
          fixQualityStr = 'RTK FIX';
          accuracy = 0.012; // 1.2 cm
          break;
        case 5: // RTK Float
          fixQualityStr = 'RTK FLOAT';
          accuracy = 0.18; // 18 cm
          break;
        case 2: // DGPS
          fixQualityStr = 'DGPS';
          accuracy = 0.8;
          break;
        case 1: // GPS SPS
          fixQualityStr = 'SINGLE GPS';
          accuracy = 2.5;
          break;
      }

      this.currentPosition = {
        lat,
        lon,
        altitude: isNaN(altitude) ? 0 : altitude,
        fixQuality: fixQualityStr,
        accuracy,
        satellites: isNaN(numSats) ? 12 : numSats,
        hdop: isNaN(hdop) ? 1.0 : hdop
      };

      return this.currentPosition;
    }
    return null;
  }

  convertNMEAToDeg(rawStr, direction) {
    if (!rawStr) return 0;
    const dotIdx = rawStr.indexOf('.');
    const degLen = dotIdx - 2;
    const deg = parseFloat(rawStr.substring(0, degLen));
    const min = parseFloat(rawStr.substring(degLen));
    let dec = deg + min / 60.0;
    if (direction === 'S' || direction === 'W') {
      dec = -dec;
    }
    return dec;
  }

  /**
   * Convert WGS84 Lat/Lon to UTM Projected Meter Coordinates (Easting, Northing)
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
}
