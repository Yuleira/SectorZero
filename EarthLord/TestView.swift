//
//  TestView.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.3)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
