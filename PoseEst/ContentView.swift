//
//  ContentView.swift
//  PoseEst
//
//  Created by Raymond Nucuta on 1/28/25.
//

import SwiftUI
import SceneKit
import UIKit
import Vision
import simd

struct ContentView: View {
    @StateObject private var frameModel : FrameModel
    @StateObject private var camera: CameraController
    
    init() {
        let fm = FrameModel()
        _frameModel = StateObject(wrappedValue: fm)
        _camera = StateObject(wrappedValue: CameraController(fm))
    }
    
    var body: some View {
        VStack {
            CameraView()
                .environmentObject(camera)
            PoseDataView(frameModel: frameModel)
        }
        .environmentObject(frameModel)
        .padding()
    }
}

#Preview {
    ContentView()
}
