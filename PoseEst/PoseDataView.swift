import SwiftUI

struct PoseDataView: View {
    @ObservedObject var frameModel: FrameModel
    
    var body: some View {
        VStack {
            Spacer()  // Pushes content down
            HStack() {
                VStack(alignment: .leading) {
                    Text("Current Pose:")
                        .bold()
                    VStack(alignment: .leading) {
                        Text("X: \(frameModel.currentPose.roll, specifier: "%.1f")°")
                        Text("Y: \(frameModel.currentPose.pitch, specifier: "%.1f")°")
                        Text("Z: \(frameModel.currentPose.yaw, specifier: "%.1f")°")
                        Text("Distance: \(frameModel.currentPose.distanceFromCam, specifier: "%.2f")m")
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Ground Truth:")
                        .bold()
                    VStack(alignment: .leading) {
                        Text("X: \(frameModel.groundTruth.roll, specifier: "%.1f")°")
                        Text("Y: \(frameModel.groundTruth.pitch, specifier: "%.1f")°")
                        Text("Z: \(frameModel.groundTruth.yaw, specifier: "%.1f")°")
                        Text("Distance: \(frameModel.groundTruth.distanceFromCam, specifier: "%.2f")m")
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Advice:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("Roll: \(getRollText(frameModel.orientations.roll))")
                    Text("Pitch: \(getPitchText(frameModel.orientations.pitch))")
                    Text("Yaw: \(getYawText(frameModel.orientations.yaw))")
                    Text("Distance: \(getDistanceText(frameModel.orientations.distance))")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, -170)
        .frame(maxHeight: 50, alignment: .bottom)
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    private func getRollText(_ orientation: RollOrientation) -> String {
        switch orientation {
        case .rollgood: return "Good"
        case .rollleft: return "Roll Left"
        case .rollright: return "Roll Right"
        }
    }
    
    private func getPitchText(_ orientation: PitchOrientation) -> String {
        switch orientation {
        case .pitchgood: return "Good"
        case .lookup: return "Look Up"
        case .lookdown: return "Look Down"
        }
    }
    
    private func getYawText(_ orientation: YawOrientation) -> String {
        switch orientation {
        case .yawgood: return "Good"
        case .yawleft: return "Turn Left"
        case .yawright: return "Turn Right"
        }
    }
    
    private func getDistanceText(_ orientation: DistanceOrientation) -> String {
        switch orientation {
        case .distgood: return "Good"
        case .distback: return "Move Back"
        case .distforward: return "Move Forward"
        }
    }
}
