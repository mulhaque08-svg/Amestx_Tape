import Foundation
import Capacitor
import ARKit
import SceneKit

/**
 * Native iOS Swift ARKit Measure Plugin for TapeSnap Pro
 * Uses Apple ARKit 3D Laser Raycasting & LiDAR Depth Engine
 */
@objc(ARKitMeasurePlugin)
public class ARKitMeasurePlugin: CAPPlugin, ARSessionDelegate {

    var arSession: ARSession?
    var pointAWorldPosition: SCNVector3?
    var pointBWorldPosition: SCNVector3?

    @objc func startARSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard ARWorldTrackingConfiguration.isSupported else {
                call.reject("ARKit 3D LiDAR is not supported on this device.")
                return
            }

            self.arSession = ARSession()
            self.arSession?.delegate = self

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }

            self.arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            call.resolve([
                "status": "ARKit 3D LiDAR Session Started",
                "isLiDARSupported": ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
            ])
        }
    }

    @objc func lockPointA(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let session = self.arSession, let currentFrame = session.currentFrame else {
                call.reject("ARKit session active frame not available.")
                return
            }

            // Raycast into 3D AR World at Center Reticle Screen (0.5, 0.5)
            let centerPoint = CGPoint(x: 0.5, y: 0.5)
            
            if let query = currentFrame.raycastQuery(from: centerPoint, allowing: .estimatedPlane, alignment: .any) {
                let results = session.raycast(query)
                if let firstResult = results.first {
                    let transform = firstResult.worldTransform
                    let pos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                    self.pointAWorldPosition = pos
                    call.resolve([
                        "x": pos.x,
                        "y": pos.y,
                        "z": pos.z,
                        "status": "Point A Locked"
                    ])
                    return
                }
            }

            // Fallback camera transform position
            let camTransform = currentFrame.camera.transform
            let pos = SCNVector3(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
            self.pointAWorldPosition = pos
            call.resolve(["x": pos.x, "y": pos.y, "z": pos.z, "status": "Point A Locked (Camera Pos)"])
        }
    }

    @objc func lockPointBAndMeasure(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let session = self.arSession, let currentFrame = session.currentFrame else {
                call.reject("ARKit session active frame not available.")
                return
            }

            guard let ptA = self.pointAWorldPosition else {
                call.reject("Point A not locked yet.")
                return
            }

            let centerPoint = CGPoint(x: 0.5, y: 0.5)
            var ptB = ptA

            if let query = currentFrame.raycastQuery(from: centerPoint, allowing: .estimatedPlane, alignment: .any) {
                let results = session.raycast(query)
                if let firstResult = results.first {
                    let transform = firstResult.worldTransform
                    ptB = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                }
            } else {
                let camTransform = currentFrame.camera.transform
                ptB = SCNVector3(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
            }

            self.pointBWorldPosition = ptB

            // Calculate Exact 3D Spatial Distance Formula D = √((ΔX)² + (ΔY)² + (ΔZ)²)
            let dx = ptB.x - ptA.x
            let dy = ptB.y - ptA.y
            let dz = ptB.z - ptA.z
            let distanceMeters = sqrt(dx*dx + dy*dy + dz*dz)
            
            // Convert to Running Feet (1 meter = 3.28084 feet)
            let distanceRFT = distanceMeters * 3.28084

            call.resolve([
                "distanceRFT": distanceRFT,
                "distanceMeters": distanceMeters,
                "status": "Point B Measured Successfully"
            ])
        }
    }
}
