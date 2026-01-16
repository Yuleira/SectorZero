//
//  TestMenuView.swift
//  EarthLord
//
//  Created by Claude on 05/01/2026.
//
//  开发测试入口菜单
//  显示所有测试模块的入口，包括 Supabase 测试和圈地测试
//

import SwiftUI

/// 开发测试入口菜单
/// 注意：此视图不需要套 NavigationStack，因为它已经在父级的导航栈内
struct TestMenuView: View {

    var body: some View {
        List {
            // Supabase 连接测试
            Section {
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    Label {
                        Text("Supabase 连接测试".localized)
                    } icon: {
                        Image(systemName: "network")
                            .foregroundColor(ApocalypseTheme.info)
                    }
                }

                // 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    Label {
                        Text("圈地功能测试".localized)
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
                
                // AI 物品生成测试
                NavigationLink {
                    AIDebugView()
                } label: {
                    Label {
                        Text("AI 物品生成测试".localized)
                    } icon: {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text("测试模块".localized)
            } footer: {
                Text("这些工具仅供开发调试使用".localized)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .navigationTitle("开发测试".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
