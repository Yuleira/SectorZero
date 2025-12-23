//
//  ContentView.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("Developed by Yuleira")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
