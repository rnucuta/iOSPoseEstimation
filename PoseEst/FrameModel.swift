import Vision
import SwiftUICore
import CoreImage
import CoreVideo
import UIKit
import simd
import Spatial

//@MainActor
//class PoseEstimations: ObservableObject {
//    @Published var xTheta: Float
//    @Published var yTheta: Float
//    @Published var zTheta: Float
//    @Published var distanceFromCam: Float
//    @Published var confidence: Float
//    
//    init(xTheta: Float = Float.infinity, yTheta: Float = Float.infinity, zTheta: Float = Float.infinity,
//         distanceFromCam: Float = Float.infinity, confidence: Float = Float.infinity) {
//        self.xTheta = xTheta
//        self.yTheta = yTheta
//        self.zTheta = zTheta
//        self.distanceFromCam = distanceFromCam
//        self.confidence = confidence
//    }
//}

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
         yaw : YawOrientation = .yawgood, distance: DistanceOrientation = .distgood) {
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
        self.distance = distance
    }
}

@MainActor
class FrameModel : ObservableObject {
    @Published var currentPose = PoseEstimations()
    @Published var groundTruth = PoseEstimations()
    @Published var orientations = OrientationInstructions()
    public var humanObservation: VNHumanBodyPose3DObservation?
    
//    init(_ cp: PoseEstimations,_ gt: PoseEstimations){
//        self.currentPose = cp
//        self.groundTruth = gt
//        
//    }
    
    public func updateCurrentPose(_ currentFrame: CGImage) async{
        print("Called update current pose")
        await composePoseStruct(currentFrame)

//        if var currentPoseAsset = self.currentPose,
//            let groundTruthAsset = self.groundTruth
//        {
        if groundTruth.distanceFromCam != Float.infinity {
            self.currentPose = PoseEstimations(
                roll: groundTruth.roll - currentPose.roll,
                pitch: groundTruth.pitch - currentPose.pitch,
                yaw: groundTruth.yaw - currentPose.yaw,
                distanceFromCam: groundTruth.distanceFromCam - currentPose.distanceFromCam
            )

            orientations = OrientationInstructions(
                roll: getRollOrientation(self.currentPose.roll, threshold: 10),
                pitch: getPitchOrientation(self.currentPose.pitch, threshold: 10),
                yaw: getYawOrientation(self.currentPose.yaw, threshold: 10),
                distance: getDistanceOrientation(self.currentPose.distanceFromCam, threshold: 0.3)
            )
        }
        
//        print(orientations.distance)
//        print(orientations.roll)
//        print(orientations.pitch)
//        print(orientations.yaw)
    }

    public func updateGroundTruth(){
        print("Called update ground truth")
        self.groundTruth = self.currentPose
    }

    private func pixelBufferToCGImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    private func composePoseStruct(_ image: CGImage) async {
        await Task(priority: .userInitiated) {
            let request = VNDetectHumanBodyPose3DRequest()
            let requestHandler = VNImageRequestHandler(cgImage: image)
            do {
                try requestHandler.perform([request]) // high memory issue
                if let returnedObservation = request.results?.first {
                    Task { @MainActor in
                        self.humanObservation = returnedObservation

                        calculatePoseAngles(observation: self.humanObservation!)
                    }
                }
            } catch {
//                currentPose = PoseEstimations()
                print("Unable to perform the request: \(error).")
            }
        }.value
    }

    private func calculatePoseAngles(observation: VNHumanBodyPose3DObservation) {
        guard let rootJoint = try? observation.recognizedPoint(.root),
              let cameraMatrix = try? observation.cameraRelativePosition(.centerHead).inverse,
              let CameraPose3d = Pose3D(cameraMatrix.inverse)
        else { return }
        
        print("frame model???", observation.availableJointNames)
        // Note: published vars must be updated in a main thread
//        Task { @MainActor in
            
//            print(CameraPose3d)
//            print(cameraMatrix)
//            print(rootJoint)
            
            let eulerAngles = self.extractEulerAngles(from: cameraMatrix)
            
            self.currentPose = PoseEstimations(
                roll: eulerAngles.0,
                pitch: eulerAngles.1,
                yaw: eulerAngles.2,
                distanceFromCam: self.extractDistance(from: cameraMatrix)
            )
        
//        print(self.currentPose)

    }

    public func extractEulerAngles(from matrix: simd_float4x4) -> (roll: Float, pitch: Float, yaw: Float) {
        let sy = sqrt(matrix.columns.0.x * matrix.columns.0.x + matrix.columns.1.x * matrix.columns.1.x)
        let singular = sy < 1e-6  // Check for gimbal lock

        var roll: Float = 0
        var pitch: Float = 0
        var yaw: Float = 0

        if !singular {
            yaw  = atan2(matrix.columns.2.y, matrix.columns.2.z)
            pitch = atan2(-matrix.columns.2.x, sy)
            roll = atan2(matrix.columns.1.x, matrix.columns.0.x)
        } else {
            yaw  = atan2(-matrix.columns.1.z, matrix.columns.1.y)
            pitch = atan2(-matrix.columns.2.x, sy)
            roll = 0
        }

        return (roll * 57.2958, pitch * 57.2958, yaw * 57.2958)
    }

    public func extractDistance(from matrix: simd_float4x4) -> Float {
        return Float(sqrt(pow(matrix.columns.3.x, 2) + pow(matrix.columns.3.y, 2) + pow(matrix.columns.3.z, 2)))
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
