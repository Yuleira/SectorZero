//
//  TestView.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

#if DEBUG
import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.3)
                .ignoresSafeArea()

            Text("test_branch_universe_page")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
#endif
