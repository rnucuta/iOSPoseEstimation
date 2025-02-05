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
    var xTheta: Float
    var yTheta: Float
    var zTheta: Float
    var distanceFromCam: Float
    var confidence: Float
    
    init(xTheta: Float = Float.infinity, yTheta: Float = Float.infinity, zTheta: Float = Float.infinity,
         distanceFromCam: Float = Float.infinity, confidence: Float = Float.infinity) {
        self.xTheta = xTheta
        self.yTheta = yTheta
        self.zTheta = zTheta
        self.distanceFromCam = distanceFromCam
        self.confidence = confidence
    }
}


@MainActor
class FrameModel : ObservableObject {
    @Published var currentPose = PoseEstimations()
    @Published var groundTruth = PoseEstimations()
    private var humanObservation: VNHumanBodyPose3DObservation?
    
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
//        if currentPose.distanceFromCam != Float.infinity {
//            currentPose.xTheta = groundTruth.xTheta - currentPose.xTheta
//            currentPose.yTheta = groundTruth.yTheta - currentPose.yTheta
//            currentPose.zTheta = groundTruth.zTheta - currentPose.zTheta
//            currentPose.distanceFromCam = groundTruth.distanceFromCam - currentPose.distanceFromCam
////            self.currentPose = currentPoseAsset
//        }
//        else {return}
    }

    public func updateGroundTruth(){
        print("Called update ground truth")
        //guard let currentFrame = pixelBufferToCGImage(pixelBuffer: pixelBuffer) else { return }
        //await composePoseStruct(currentFrame)
        //guard let currentPoseAsset = self.currentPose else {return}
        self.groundTruth = self.currentPose
        print(self.groundTruth)
//        self.groundTruth.xTheta = self.currentPose.xTheta
//        self.groundTruth.yTheta = self.currentPose.yTheta
//        self.groundTruth.zTheta = self.currentPose.zTheta
//        self.groundTruth.distanceFromCam = self.currentPose.distanceFromCam
//        self.groundTruth.confidence = self.currentPose.confidence
    }

    private func pixelBufferToCGImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    private func composePoseStruct(_ image: CGImage) async {
        await Task(priority: .userInitiated) {
            //guard let assetImage = image else {
            //    return
            //}
            let request = VNDetectHumanBodyPose3DRequest()
            let requestHandler = VNImageRequestHandler(cgImage: image)
            do {
                try requestHandler.perform([request])
                if let returnedObservation = request.results?.first {
                    Task { @MainActor in
                        self.humanObservation = returnedObservation

                        calculatePoseAngles(observation: self.humanObservation!)
                    }
                }
            } catch {
                print("Unable to perform the request: \(error).")
            }
        }.value
    }

    private func calculatePoseAngles(observation: VNHumanBodyPose3DObservation) {
        guard let rootJoint = try? observation.recognizedPoint(.root),
              let cameraMatrix = try? observation.cameraRelativePosition(.root),
              let CameraPose3d = Pose3D(cameraMatrix.inverse)
        else { return }
        
        // Note: published vars must be updated in a main thread
//        Task { @MainActor in
            
            print(CameraPose3d)
            print(cameraMatrix)
            print(rootJoint)
            
            let eulerAngles = self.extractEulerAngles(from: cameraMatrix)
            
            self.currentPose = PoseEstimations(
                xTheta: eulerAngles.0,
                yTheta: eulerAngles.1,
                zTheta: eulerAngles.2,
                distanceFromCam: Float(sqrt(
                    pow(CameraPose3d.position.x, 2) +
                    pow(CameraPose3d.position.y, 2) +
                    pow(CameraPose3d.position.z, 2)
                )),
//                confidence: rootJoint.confidence
                confidence: 0.5
            )
        
        print(self.currentPose)
//        }
    }

    public func extractEulerAngles(from matrix: simd_float4x4) -> (roll: Float, pitch: Float, yaw: Float) {
        let sy = sqrt(matrix.columns.0.x * matrix.columns.0.x + matrix.columns.1.x * matrix.columns.1.x)
        let singular = sy < 1e-6  // Check for gimbal lock

        var roll: Float = 0
        var pitch: Float = 0
        var yaw: Float = 0

        if !singular {
            roll  = atan2(matrix.columns.2.y, matrix.columns.2.z)  // X-axis rotation
            pitch = atan2(-matrix.columns.2.x, sy)                 // Y-axis rotation
            yaw   = atan2(matrix.columns.1.x, matrix.columns.0.x)  // Z-axis rotation
        } else {
            roll  = atan2(-matrix.columns.1.z, matrix.columns.1.y)
            pitch = atan2(-matrix.columns.2.x, sy)
            yaw   = 0
        }

        return (roll * 57.2958, pitch * 57.2958, yaw * 57.2958)
    }

//    public func extractDistance(from matrix: simd_float4x4) -> (dist: Float) {
//        
//    }

    
}
