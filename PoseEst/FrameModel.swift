import Vision
import CoreImage
import CoreVideo
import UIKit

 struct poseEstimations{
    var xTheta: Float?
    var yTheta: Float?
    var zTheta: Float?
    var distanceFromCam: Float?
    var.confidence: Float?
}

class FrameModel: ObservableObject {

    @Published var currentPose = poseEstimations()
    @Published var groundTruth = poseEstimations()
    private var humanObservation: VNHumanBodyPose3DObservation? = nil
    
    public func updateCurrentPose(_ pixelBuffer: CVPixelBuffer){
        guard let currentFrame = pixelBufferToCGImage(pixelBuffer: pixelBuffer) else {return}
        await composePoseStruct(currentFrame)

        guard let currentPoseAsset = self.currentPose else {return}

        if let groundTruthAsset = self.groundTruth {
            self.currentPose.xTheta = self.groundTruth.xTheta - self.currentPose.xTheta
            self.currentPose.yTheta = self.groundTruth.yTheta - self.currentPose.yTheta
            self.currentPose.zTheta = self.groundTruth.zTheta - self.currentPose.zTheta
            self.currentPose.distanceFromCam = self.groundTruth.distanceFromCam - self.currentPose.distanceFromCam
        }        
    }

    public func updateGroundTruth(_ pixelBuffer: CVPixelBuffer){
        guard let currentFrame = pixelBufferToCGImage(pixelBuffer: pixelBuffer) else { return }
        await composePoseStruct(currentFrame)
        guard let currentPoseAsset = self.currentPose else {return}
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
            guard let assetImage = image else {
                return
            }
            let request = VNDetectHumanBodyPose3DRequest()
            let requestHandler = VNImageRequestHandler(cgImage: image)
            do {
                try requestHandler.perform([request])
                if let returnedObservation = request.results?.first {
                    Task { @MainActor in
                        self.humanObservation = returnedObservation

                        calculatePoseAngles(observation: self.humanObservation)
                    }
                }
            } catch {
                print("Unable to perform the request: \(error).")
            }
        }.value
    }

    private func calculatePoseAngles(observation: VNHumanBodyPose3DObservation) {
        guard let rootJoint = try? observation.recognizedPoint(.root) else { return }
        
        // Note: published vars must be updated in a main thread
        Task { @MainActor in
            self.currentPose.xTheta = Float(atan2(rootJoint.z, rootJoint.y))
            self.currentPose.yTheta = Float(atan2(rootJoint.x, rootJoint.z))
            self.currentPose.zTheta = Float(atan2(rootJoint.y, rootJoint.x))
            
            self.currentPose.distanceFromCam = Float(sqrt(
                pow(rootJoint.x, 2) + 
                pow(rootJoint.y, 2) + 
                pow(rootJoint.z, 2)
            ))
            self.currentPose.confidence = rootJoint.confidence
        }
    }
    
}