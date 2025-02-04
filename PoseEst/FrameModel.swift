import Vision
import CoreImage
import CoreVideo
import UIKit
import simd

 struct poseEstimations{
     var xTheta: Float = Float.infinity
     var yTheta: Float = Float.infinity
     var zTheta: Float = Float.infinity
     var distanceFromCam: Float = Float.infinity
     var confidence: Float = Float.infinity
}

class FrameModel: ObservableObject {

    @Published var currentPose : poseEstimations?
    @Published var groundTruth : poseEstimations?
    private var humanObservation: VNHumanBodyPose3DObservation? = nil
    
    public func updateCurrentPose(_ pixelBuffer: CVPixelBuffer) async{
        guard let currentFrame = pixelBufferToCGImage(pixelBuffer) else {return}
        await composePoseStruct(currentFrame)

        if var currentPoseAsset = self.currentPose,
            let groundTruthAsset = self.groundTruth
        {
            currentPoseAsset.xTheta = groundTruthAsset.xTheta - currentPoseAsset.xTheta
            currentPoseAsset.yTheta = groundTruthAsset.yTheta - currentPoseAsset.yTheta
            currentPoseAsset.zTheta = groundTruthAsset.zTheta - currentPoseAsset.zTheta
            currentPoseAsset.distanceFromCam = groundTruthAsset.distanceFromCam - currentPoseAsset.distanceFromCam
            self.currentPose = currentPoseAsset
        }
        else {return}
    }

    public func updateGroundTruth(){
        //guard let currentFrame = pixelBufferToCGImage(pixelBuffer: pixelBuffer) else { return }
        //await composePoseStruct(currentFrame)
        //guard let currentPoseAsset = self.currentPose else {return}
        self.groundTruth.xTheta = self.currentPose.xTheta
        self.groundTruth.yTheta = self.currentPose.yTheta
        self.groundTruth.zTheta = self.currentPose.zTheta
        self.groundTruth.distanceFromCam = self.currentPose.distanceFromCam
        self.groundTruth.confidence = self.currentPose.confidence
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
        guard let rootJoint = try? observation.recognizedPoint(.centerHead), 
            cameraMatrix = try? observation.cameraRelativePosition(.centerHead),
            let CameraPose3d = try? Pose3D(cameraMatrix.inverse),
                else { return }
        
        // Note: published vars must be updated in a main thread
        Task { @MainActor in
            


            // self.currentPose.xTheta = Float(atan2(rootJoint.z, rootJoint.y))
            // self.currentPose.yTheta = Float(atan2(rootJoint.x, rootJoint.z))
            // self.currentPose.zTheta = Float(atan2(rootJoint.y, rootJoint.x))
            
            // self.currentPose.distanceFromCam = Float(sqrt(
            //     pow(rootJoint.x, 2) + 
            //     pow(rootJoint.y, 2) + 
            //     pow(rootJoint.z, 2)
            // ))
            self.currentPose.confidence = rootJoint.confidence
        }
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

        return (roll, pitch, yaw)
    }

    public func extractDistance(from matrix: simd_float4x4) -> (dist: Float) {
        
    }

    
}
