//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发者工具") {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        Label("Supabase 连接测试", systemImage: "network")
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
