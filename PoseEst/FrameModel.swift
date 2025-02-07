import Vision
import SwiftUICore
import CoreImage
import CoreVideo
import UIKit
import simd
import Spatial

enum PitchOrientation {
    case pitchgood
    case lookup
    case lookdown
}

enum RollOrientation {
    case rollgood
    case rollleft
    case rollright
}

enum YawOrientation {
    case yawgood
    case yawleft
    case yawright
}

enum DistanceOrientation {
    case distgood
    case distback
    case distforward
}

struct OrientationInstructions {
    var pitch: PitchOrientation
    var roll: RollOrientation
    var yaw: YawOrientation
    var distance: DistanceOrientation

    init(roll: RollOrientation = .rollgood, pitch: PitchOrientation = .pitchgood,
         yaw: YawOrientation = .yawgood, distance: DistanceOrientation = .distgood) {
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
        self.distance = distance
    }
}

struct PoseEstimations {
    var roll: Float
    var pitch: Float
    var yaw: Float
    var distanceFromCam: Float
    
    init(roll: Float = Float.infinity, pitch: Float = Float.infinity, yaw: Float = Float.infinity,
         distanceFromCam: Float = Float.infinity) {
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
        self.distanceFromCam = distanceFromCam
    }
}

@MainActor
class FrameModel: ObservableObject {
    @Published var currentPose: simd_float4x4?
    var groundTruth: simd_float4x4?
    @Published var currentPoseInstr = PoseEstimations()
    @Published var orientations = OrientationInstructions()
    public var humanObservation: VNHumanBodyPose3DObservation?

    public func updateCurrentPose(_ currentFrame: CGImage) async {
        print("Called update current pose")
        await composePoseStruct(currentFrame)

        if let cP = currentPose, let gT = groundTruth {
            computeOrientations(currentPose: cP, groundTruth: gT)
        }
    }

    public func updateGroundTruth() {
        if let cP = currentPose {
            print("Setting ground truth matrix.")
            groundTruth = cP
        }
    }

    private func composePoseStruct(_ image: CGImage) async {
        await Task(priority: .userInitiated) {
            let request = VNDetectHumanBodyPose3DRequest()
            let requestHandler = VNImageRequestHandler(cgImage: image)
            do {
                try requestHandler.perform([request])
                if let returnedObservation = request.results?.first {
                    Task { @MainActor in
                        self.humanObservation = returnedObservation
                        
                        calculatePoseAngles(observation: self.humanObservation!)
                        
                        self.currentPose = returnedObservation.cameraOriginMatrix
                    }
                }
            } catch {
                print("Unable to perform the request: \(error).")
            }
        }.value
    }
    
    private func calculatePoseAngles(observation: VNHumanBodyPose3DObservation) {
        guard let rootJoint = try? observation.recognizedPoint(.root),
              let cameraMatrix = try? observation.cameraRelativePosition(.centerHead).inverse,
              let CameraPose3d = Pose3D(cameraMatrix.inverse)
        else { return }
    }

    /// Computes the relative transformation from `currentPose` to `groundTruth`
    private func computeOrientations(currentPose: simd_float4x4, groundTruth: simd_float4x4) {
        let relativeMatrix = groundTruth * currentPose.inverse

        // Extract rotation and translation
        let (axis, angle) = rotationMatrixToAxisAngle(simd_float3x3(
            simd_float3(relativeMatrix.columns.0.x, relativeMatrix.columns.0.y, relativeMatrix.columns.0.z),
            simd_float3(relativeMatrix.columns.1.x, relativeMatrix.columns.1.y, relativeMatrix.columns.1.z),
            simd_float3(relativeMatrix.columns.2.x, relativeMatrix.columns.2.y, relativeMatrix.columns.3.z)
        ))

        let translation = simd_make_float3(
            relativeMatrix.columns.3.x,
            relativeMatrix.columns.3.y,
            relativeMatrix.columns.3.z
        )

        currentPoseInstr = PoseEstimations(
            roll: axis.x * angle,
            pitch: axis.z * angle,
            yaw: axis.y * angle,
            distanceFromCam: sqrt(pow(translation.x, 2) + pow(translation.y, 2) + pow(translation.z, 2))
        )
        
        // Update enums
        orientations.roll = getRollOrientation(axis.x * angle, threshold: 15)
        orientations.pitch = getPitchOrientation(axis.z * angle, threshold: 15)
        orientations.yaw = getYawOrientation(axis.y * angle, threshold: 15)
        orientations.distance = getDistanceOrientation(sqrt(pow(translation.x, 2) + pow(translation.y, 2) + pow(translation.z, 2)), threshold: 0.3)

        print("Updated orientations: \(orientations)")
    }

    /// Converts a 3x3 rotation matrix to an axis-angle representation
    private func rotationMatrixToAxisAngle(_ R: simd_float3x3) -> (axis: simd_float3, angle: Float) {
        print("Deugg", R, R[2,0])
        let trace = R[0, 0] + R[1, 1] + R[2, 2]
        let angle = acos((trace - 1) / 2)

        if angle == 0 {
            return (simd_float3(1, 0, 0), 0) // No rotation needed
        }

        let x = R[2, 1] - R[1, 2]
        let y = R[0, 2] - R[2, 0]
        let z = R[1, 0] - R[0, 1]
        let axis = simd_normalize(simd_float3(x, y, z))

        return (axis, angle * 57.2958) // Convert to degrees
    }

    private func getRollOrientation(_ value: Float, threshold: Float) -> RollOrientation {
        switch value {
        case ..<(-threshold): return .rollright
        case threshold...: return .rollleft
        default: return .rollgood
        }
    }

    private func getPitchOrientation(_ value: Float, threshold: Float) -> PitchOrientation {
        switch value {
        case ..<(-threshold): return .lookdown
        case threshold...: return .lookup
        default: return .pitchgood
        }
    }

    private func getYawOrientation(_ value: Float, threshold: Float) -> YawOrientation {
        switch value {
        case ..<(-threshold): return .yawright
        case threshold...: return .yawleft
        default: return .yawgood
        }
    }

    private func getDistanceOrientation(_ value: Float, threshold: Float) -> DistanceOrientation {
        switch value {
        case ..<(-threshold): return .distforward
        case threshold...: return .distback
        default: return .distgood
        }
    }
}
