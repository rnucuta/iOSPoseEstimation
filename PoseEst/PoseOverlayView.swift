import SwiftUI
import Vision

struct PoseOverlayView: UIViewRepresentable {
    var observation: VNHumanBodyPose3DObservation?
    var viewSize: CGSize
    var jointGroupNames : [VNHumanBodyPose3DObservation.JointsGroupName] =
        [.head, .leftArm, .leftLeg, .rightArm, .rightLeg, .torso]
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard let observation = observation else { return }
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 3
        
        let path = UIBezierPath()
        
        try? observation.recognizedPoints(.all).forEach { (joint, point) in
//            print("pose view point", viewSize)
            if let viewPoint = try? observation.pointInImage(joint).location{
                let circle = UIBezierPath(arcCenter: CGPoint(x: viewPoint.y * viewSize.width,
                                                             y: viewPoint.x * viewSize.height),
                                        radius: 4,
                                        startAngle: 0,
                                        endAngle: 2 * .pi,
                                        clockwise: true)
                path.append(circle)
            }
        }
        
        self.drawSkeletonConnections(observation: observation, path: path)
        
        shapeLayer.path = path.cgPath
        uiView.layer.addSublayer(shapeLayer)
    }
    
    private func drawSkeletonConnections(observation: VNHumanBodyPose3DObservation, path: UIBezierPath) {
//        for jointGroup in observation.availableJointsGroupNames {
//        print("pose view point", try? observation.recognizedPoints(.head))
        for jointGroup in jointGroupNames {
            if let jointGroupPointsArr = try? observation.recognizedPoints(jointGroup) {
                print("***???", jointGroupPointsArr)
                let jointNames = Array(jointGroupPointsArr.keys)
                for i in 0..<jointGroupPointsArr.count - 1 {
                    guard let viewPoint1 = try? observation.pointInImage(jointNames[i]).location,
                          let viewPoint2 = try? observation.pointInImage(jointNames[i + 1]).location
                    else { continue }
                    
                    path.move(to: CGPoint(x: viewPoint1.y * viewSize.width,
                                          y: viewPoint1.x * viewSize.height))
                    path.addLine(to: CGPoint(x: viewPoint2.y * viewSize.width,
                                             y: viewPoint2.x * viewSize.height))
                }
            }
        }
    }
}
