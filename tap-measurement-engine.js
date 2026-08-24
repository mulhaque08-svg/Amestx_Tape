/**
 * SiteTap PRO - Precision Geometry, Slope Grade & Material Calculation Engine
 */

export class TapMeasurementEngine {
  constructor() {
    this.unitSystem = 'metric'; // 'metric' (meters) or 'imperial' (feet)
  }

  setUnitSystem(system) {
    this.unitSystem = system;
  }

  /**
   * Calculate 2D True Horizontal distance between 2 points (meters)
   */
  calc2DDistance(p1, p2) {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  /**
   * Calculate 3D Slope distance considering elevation delta (z)
   */
  calc3DSlopeDistance(p1, p2) {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    const dz = (p2.z || 0) - (p1.z || 0);
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /**
   * Calculate Elevation Delta (dz) and Slope Grade %
   */
  calcSlopeGrade(p1, p2) {
    const dh = this.calc2DDistance(p1, p2);
    const dz = (p2.z || 0) - (p1.z || 0);
    const slopePercent = dh > 0 ? (dz / dh) * 100 : 0;
    const angleDegrees = Math.atan2(Math.abs(dz), dh) * (180 / Math.PI);

    return {
      horizontalDist: dh,
      elevationDelta: dz,
      slopePercent: slopePercent,
      angleDegrees: angleDegrees,
      slopeDist3D: Math.sqrt(dh * dh + dz * dz)
    };
  }

  /**
   * Calculate Shoelace Polygon Area (square meters)
   */
  calcPolygonArea(points) {
    if (points.length < 3) return 0;
    let area = 0;
    for (let i = 0; i < points.length; i++) {
      const j = (i + 1) % points.length;
      area += points[i].x * points[j].y;
      area -= points[j].x * points[i].y;
    }
    return Math.abs(area) / 2.0;
  }

  /**
   * Calculate Total Perimeter Length (meters)
   */
  calcPolygonPerimeter(points, isClosed = true) {
    if (points.length < 2) return 0;
    let len = 0;
    for (let i = 0; i < points.length - 1; i++) {
      len += this.calc2DDistance(points[i], points[i + 1]);
    }
    if (isClosed && points.length > 2) {
      len += this.calc2DDistance(points[points.length - 1], points[0]);
    }
    return len;
  }

  /**
   * Calculate Cubic Volume and Material Estimates
   */
  calcMaterialEstimate(areaSqMeters, depthMeters, materialType, costPerUnit, wastePercent = 5) {
    const volumeM3 = areaSqMeters * depthMeters;
    const grossVolumeM3 = volumeM3 * (1 + wastePercent / 100);

    // Material Densities (Tons per M3)
    let densityFactor = 2.4; // Concrete ~ 2.4 tons/m3
    if (materialType === 'asphalt') densityFactor = 2.3;
    if (materialType === 'gravel') densityFactor = 1.6;
    if (materialType === 'dirt') densityFactor = 1.5;
    if (materialType === 'sod') densityFactor = 0.05;

    const estimatedWeightTons = grossVolumeM3 * densityFactor;
    const totalCost = grossVolumeM3 * costPerUnit;

    return {
      netVolumeM3: volumeM3,
      grossVolumeM3: grossVolumeM3,
      estimatedWeightTons: estimatedWeightTons,
      totalCost: totalCost
    };
  }

  /**
   * Convert Meters to Active Unit (m or ft)
   */
  formatLength(meters) {
    if (this.unitSystem === 'imperial') {
      const feet = meters * 3.28084;
      return `${feet.toFixed(2)} ft`;
    }
    return `${meters.toFixed(2)} m`;
  }

  /**
   * Convert Square Meters to Active Unit (m² or sq ft / acres)
   */
  formatArea(sqMeters) {
    if (this.unitSystem === 'imperial') {
      const sqFt = sqMeters * 10.7639;
      if (sqFt > 43560) {
        const acres = sqFt / 43560;
        return `${acres.toFixed(3)} acres`;
      }
      return `${sqFt.toFixed(2)} sq ft`;
    }
    if (sqMeters > 10000) {
      const hectares = sqMeters / 10000;
      return `${hectares.toFixed(3)} ha`;
    }
    return `${sqMeters.toFixed(2)} m²`;
  }

  /**
   * Convert Volume M3 to Active Unit (m³ or cu yd)
   */
  formatVolume(cuMeters) {
    if (this.unitSystem === 'imperial') {
      const cuYd = cuMeters * 1.30795;
      return `${cuYd.toFixed(2)} cu yd`;
    }
    return `${cuMeters.toFixed(2)} m³`;
  }
}
