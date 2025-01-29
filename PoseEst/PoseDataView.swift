import SwiftUI

struct PoseDataView: View {
    let currentPose : poseEstimations
    let groundTruthPose : poseEstimations

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Current Pose:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("X: \(currentPose.xTheta ?? "NaN")°")
                    Text("Y: \(currentPose.yTheta ?? "NaN")°")
                    Text("Z: \(currentPose.zTheta ?? "NaN")°")
                    Text("Distance: \(currentPose.distanceFromCam ?? "NaN")m")
                    Text("Confidence: \(currentPose.confidence ?? "NaN")")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Ground Truth:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("X: \(groundTruthPose.xTheta ?? "NaN")°")
                    Text("Y: \(groundTruthPose.yTheta ?? "NaN")°")
                    Text("Z: \(groundTruthPose.zTheta ?? "NaN")°")
                    Text("Distance: \(groundTruthPose.distanceFromCam ?? "NaN")m")
                    Text("Confidence: \(groundTruthPose.Confidence ?? "NaN")")
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
    }
}