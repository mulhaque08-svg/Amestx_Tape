/**
 * SiteTap PRO - 90° Vertical Plumb & Gyro Orientation Engine
 * Monitors phone vertical plumb angle and validates ground tap triggers.
 */

export class PlumbSensorEngine {
  constructor(onOrientationUpdateCallback) {
    this.onOrientationUpdate = onOrientationUpdateCallback;
    this.isEnabled = true;
    this.targetPlumbAngle = 90.0; // Vertical upright plumb
    this.tolerance = 2.5; // Default +/- 2.5 degrees
    
    this.currentPitch = 90.0;
    this.currentRoll = 0.0;
    this.isPlumbValid = true;
    
    this.initSensors();
  }

  initSensors() {
    if (window.DeviceOrientationEvent) {
      window.addEventListener('deviceorientation', (e) => this.handleOrientation(e), true);
    }
  }

  handleOrientation(event) {
    if (!this.isEnabled) return;
    
    // Beta: Pitch (-180 to 180), Gamma: Roll (-90 to 90)
    let pitch = event.beta !== null ? Math.abs(event.beta) : 90.0;
    let roll = event.gamma !== null ? Math.abs(event.gamma) : 0.0;
    
    this.currentPitch = pitch;
    this.currentRoll = roll;
    
    // Check if within 90 deg plumb tolerance
    const pitchDelta = Math.abs(pitch - 90.0);
    this.isPlumbValid = pitchDelta <= this.tolerance && roll <= (this.tolerance * 2);
    
    if (this.onOrientationUpdate) {
      this.onOrientationUpdate({
        pitch: this.currentPitch,
        roll: this.currentRoll,
        isValid: this.isPlumbValid,
        pitchDelta: pitchDelta
      });
    }
  }

  setTolerance(degrees) {
    this.tolerance = parseFloat(degrees) || 2.5;
  }
}
