/**
 * SiteTap PRO - AR Crosshair & Camera Screen Click Module
 * Provides camera feed integration and target crosshair tracking
 * (Apple Measure App workflow)
 */

export class ARCrosshairEngine {
  constructor(videoElement, hudOverlayElement, onPointTappedCallback) {
    this.video = videoElement;
    this.hud = hudOverlayElement;
    this.onPointTapped = onPointTappedCallback;
    this.stream = null;
    this.isActive = false;
  }

  async startCamera() {
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        this.stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: { ideal: 'environment' },
            width: { ideal: 1920 },
            height: { ideal: 1080 }
          },
          audio: false
        });
        this.video.srcObject = this.stream;
        await this.video.play();
        this.isActive = true;
        return true;
      }
    } catch (err) {
      console.warn("Camera stream unavailable, defaulting to Virtual AR Grid Mode:", err);
      this.isActive = false;
      return false;
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
    this.isActive = false;
  }

  /**
   * Get the current target point coordinates on screen canvas
   */
  getCrosshairScreenPoint(canvas) {
    const rect = canvas.getBoundingClientRect();
    return {
      x: rect.width / 2,
      y: rect.height / 2
    };
  }

  /**
   * Trigger screen point tap (Simulates tapping point under crosshair)
   */
  triggerTap(canvas) {
    const screenPoint = this.getCrosshairScreenPoint(canvas);
    if (this.onPointTapped) {
      this.onPointTapped(screenPoint);
    }
    return screenPoint;
  }
}
