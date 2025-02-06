//
//  CameraModel.swift
//  PoseEst
//
//  Created by Raymond Nucuta on 2/5/25.
//

import SwiftUI
import AVFoundation
import Vision
import CoreMotion
import CoreImage
import CoreGraphics

@MainActor
class CameraController: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSetup = false
    
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var frameModel : FrameModel
    private var frameCount : Int8 = 0
    
    init(_ fm: FrameModel) {
        self.frameModel = fm
        super.init()
    }
    
//    deinit {
//        stopSession()
//    }
//
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func checkPermissions() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                await MainActor.run {
                    setupCamera()
                    startSession()
                }
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    await MainActor.run {
                        setupCamera()
                        startSession()
                    }
                }
            default:
                break
            }
        }
    }
    
    private func setupCamera() {
        guard !isSetup else { return }
//        session.sessionPreset = .photo
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                        position: .unspecified),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            print("Failed to setup camera input")
            return
        }
        session.inputs.forEach { session.removeInput($0) }
        session.beginConfiguration()
        session.addInput(videoDeviceInput)
        deviceInput = videoDeviceInput
        session.outputs.forEach { session.removeOutput($0) }
        
//         if session.canAddOutput(photoOutput) {
//             session.addOutput(photoOutput)
//             session.sessionPreset = .photo
////             if let photoConnection = photoOutput.connection(with: .video) {
////                 // Update for iOS 17
////                 if #available(iOS 17.0, *) {
////                     photoConnection.videoRotationAngle = 0 // For portrait
////                 } else {
////                     photoConnection.videoOrientation = .portrait
////                 }
////             }
//             photoOutput.isDepthDataDeliveryEnabled = true
////             print(photoOutput.isDepthDataDeliverySupported)
////             print(photoOutput.isDepthDataDeliveryEnabled)
//         }
//        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if let videoConnection = videoOutput.connection(with: .video) {
                // Update for iOS 17
                if #available(iOS 17.0, *) {
                    videoConnection.videoRotationAngle = 0 // For portrait
                } else {
                    videoConnection.videoOrientation = .portrait
                }
            }
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
           
        }
        
        session.commitConfiguration()
        isSetup = true
        print("Camera setup completed")
    }
    
    func capturePhoto() {
        frameModel.updateGroundTruth()
//        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
//        photoSettings.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
//        print(photoSettings.isDepthDataDeliveryEnabled)
//        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    // func updateReferenceImages(_ images: [UIImage]) {
    //     imageAnalyzer.analyzeReferenceImages(images)
    // }
}

// Handle camera capture and face detection
// AVCapturePhotoCaptureDelegate,
extension CameraController: AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
//     func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//         guard let imageData = photo.fileDataRepresentation() else { return }
//         guard let image = UIImage(data: imageData) else { return }
//         if let depthData = photo.depthData?.converting(toDepthDataType:
//                                                             kCVPixelFormatType_DisparityFloat32),
//            let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) {
//             let depthImage = CIImage( cvImageBuffer: depthData.depthDataMap,
//                                       options: [ .auxiliaryDisparity: true ] )
////             depthMapData = context.tiffRepresentation(of: depthImage,
////                                                       format: .Lf,
////                                                       colorSpace: colorSpace,
////                                                       options: [.disparityImage: depthImage])
//             
//            // let imgToSave = UIImage(ciImage: depthImage)
//            // UIImageWriteToSavedPhotosAlbum(imgToSave, nil, nil, nil)
//             let context = CIContext(options: nil)
//            if let cgImage = context.createCGImage(depthImage, from: depthImage.extent) {
//                 // Then create UIImage from CGImage
//                 let uiImage = UIImage(cgImage: cgImage)
//                 // Save to photo album
//                 UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
//             }
//         }
        
//          Fix orientation for captured photo
//         let fixedImage: UIImage
//         if image.imageOrientation != .up {
//             UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
//             image.draw(in: CGRect(origin: .zero, size: image.size))
//             if let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() {
//                 fixedImage = normalizedImage
//             } else {
//                 fixedImage = image
//             }
//             UIGraphicsEndImageContext()
//         } else {
//             fixedImage = image
//         }
//        
//         // Rotate the image to portrait orientation
//         let rotatedImage = fixedImage.rotate(to: .right)
//        
//          UIImageWriteToSavedPhotosAlbum(rotatedImage, nil, nil, nil)
//     }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        return
        frameCount = (frameCount + 1) % 20
        if frameCount == 0 {
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
               let currentFrame = pixelBufferToCGImage(pixelBuffer){
                Task {
                    await self.frameModel.updateCurrentPose(currentFrame)
                }
            }
        }
        return
        
        
        // Force portrait orientation for analysis
        // let imageOrientation: CGImagePropertyOrientation = .right  // This is portrait orientation
        
        // let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
        //                                          orientation: imageOrientation)
        
        // let faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
        //     guard let observations = request.results as? [VNFaceObservation] else { return }
            
        //     DispatchQueue.main.async {
        //         if let face = observations.first {
        //             let centerX = face.boundingBox.midX
        //             let centerThreshold: CGFloat = 0.1
        //             self?.isCentered = abs(centerX - 0.5) < centerThreshold
        //         } else {
        //             self?.isCentered = false
        //         }
        //     }
        // }
        
        // try? requestHandler.perform([faceDetectionRequest])
        
        // Pass the orientation to analyzeLiveFrame

        // DispatchQueue.main.async { [weak self] in
        //     self?.guidance = self?.imageAnalyzer.guidance ?? []
        //     self?.angleDirection = self?.imageAnalyzer.angleDirection
        // }
    }
    private func pixelBufferToCGImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
