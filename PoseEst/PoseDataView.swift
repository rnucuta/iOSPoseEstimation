import SwiftUI

struct PoseDataView: View {
    @ObservedObject var frameModel: FrameModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Current Pose:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("X: \(frameModel.currentPose.xTheta, specifier: "%.1f")°")
                    Text("Y: \(frameModel.currentPose.yTheta, specifier: "%.1f")°")
                    Text("Z: \(frameModel.currentPose.zTheta, specifier: "%.1f")°")
                    Text("Distance: \(frameModel.currentPose.distanceFromCam, specifier: "%.2f")m")
                    Text("Confidence: \(frameModel.currentPose.confidence, specifier: "%.2f")")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Ground Truth:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("X: \(frameModel.groundTruth.xTheta, specifier: "%.1f")°")
                    Text("Y: \(frameModel.groundTruth.yTheta, specifier: "%.1f")°")
                    Text("Z: \(frameModel.groundTruth.zTheta, specifier: "%.1f")°")
                    Text("Distance: \(frameModel.groundTruth.distanceFromCam, specifier: "%.2f")m")
                    Text("Confidence: \(frameModel.groundTruth.confidence, specifier: "%.2f")")
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
    }
}
