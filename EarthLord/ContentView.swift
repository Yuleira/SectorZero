//
//  ContentView.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Text("Developed by Yuleira")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 30)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
