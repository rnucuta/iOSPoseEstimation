import SwiftUI
import AVFoundation
import Vision
import CoreMotion

struct CameraView: View {
    @EnvironmentObject var camera: CameraController
    private let motionManager = CMMotionManager()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: camera.capturePhoto) {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 65, height: 65)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 55, height: 55)
                    )
            }
            .padding(.bottom, 30)
        }
        .task {
            camera.checkPermissions()
            // startMotionUpdates()
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
            camera.stopSession()
        }
    }
    
    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion = motion else { return }
                
                // Check if phone is level using roll angle
                // let rollAngle = abs(motion.attitude.roll * 180 / .pi)
                // isLevelHorizontally = abs(rollAngle) < 3.0 // Consider level if within 3 degrees
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill

        DispatchQueue.main.async {
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.frame

        }
    }
}


class CameraController: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    // @Published var isCentered = false
    @Published var isSetup = false
    
    private var deviceInput: AVCaptureDeviceInput?
    // private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    let frameModel = FrameModel()
    // let imageAnalyzer = ImageAnalyzer()
    
    override init() {
        super.init()
    }
    
    deinit {
        stopSession()
    }
    
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
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            print("Failed to setup camera input")
            return
        }
        
        session.inputs.forEach { session.removeInput($0) }
        session.addInput(videoDeviceInput)
        deviceInput = videoDeviceInput
        
        session.outputs.forEach { session.removeOutput($0) }
        
        // if session.canAddOutput(photoOutput) {
        //     session.addOutput(photoOutput)
        //     if let photoConnection = photoOutput.connection(with: .video) {
        //         // Update for iOS 17
        //         if #available(iOS 17.0, *) {
        //             photoConnection.videoRotationAngle = 0 // For portrait
        //         } else {
        //             photoConnection.videoOrientation = .portrait
        //         }
        //     }
        // }
        
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
    }
    
    // func updateReferenceImages(_ images: [UIImage]) {
    //     imageAnalyzer.analyzeReferenceImages(images)
    // }
}

// Handle camera capture and face detection
// AVCapturePhotoCaptureDelegate,
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    //     guard let imageData = photo.fileDataRepresentation() else { return }
    //     guard let image = UIImage(data: imageData) else { return }
        
    //     // Fix orientation for captured photo
    //     let fixedImage: UIImage
    //     if image.imageOrientation != .up {
    //         UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    //         image.draw(in: CGRect(origin: .zero, size: image.size))
    //         if let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() {
    //             fixedImage = normalizedImage
    //         } else {
    //             fixedImage = image
    //         }
    //         UIGraphicsEndImageContext()
    //     } else {
    //         fixedImage = image
    //     }
        
    //     // Rotate the image to portrait orientation
    //     let rotatedImage = fixedImage.rotate(to: .right)
        
    //     // UIImageWriteToSavedPhotosAlbum(rotatedImage, nil, nil, nil)
    // }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
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
        DispatchQueue.main.async {
            self.frameModel.updateCurrentPose(pixelBuffer)
        }

        // DispatchQueue.main.async { [weak self] in
        //     self?.guidance = self?.imageAnalyzer.guidance ?? []
        //     self?.angleDirection = self?.imageAnalyzer.angleDirection
        // }
    }
}
