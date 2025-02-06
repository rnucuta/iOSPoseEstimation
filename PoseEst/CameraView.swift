import SwiftUI
import AVFoundation
import Vision
//import CoreMotion
//import CoreImage
//import CoreGraphics

struct CameraView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var frameModel: FrameModel
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                
                // Pose overlay
                PoseOverlayView(observation: frameModel.humanObservation,
                              viewSize: geometry.size)
                
                // Capture button
                VStack {
                    Spacer()
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
            }
            .onAppear {
                viewSize = geometry.size
            }
        }
        .task {
            camera.checkPermissions()
        }
        .onDisappear {
            camera.stopSession()
        }
    }
//    
//    private func startMotionUpdates() {
//        if motionManager.isDeviceMotionAvailable {
//            motionManager.deviceMotionUpdateInterval = 0.2
//            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
//                guard let motion = motion else { return }
//                
//                // Check if phone is level using roll angle
//                // let rollAngle = abs(motion.attitude.roll * 180 / .pi)
//                // isLevelHorizontally = abs(rollAngle) < 3.0 // Consider level if within 3 degrees
//            }
//        }
//    }
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
