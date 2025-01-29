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
    var body: some View {
        ZStack {
            // Image(systemName: "globe")
            //     .imageScale(.large)
            //     .foregroundStyle(.tint)
            // Text("Hello, world!")
            CameraView()
            PoseDataView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
