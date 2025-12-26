//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    private var authManager = AuthManager.shared
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    HStack(spacing: 16) {
                        // 头像
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(username)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 统计数据
                Section("我的数据") {
                    Label("领地数量: 0", systemImage: "flag.fill")
                    Label("总面积: 0 m²", systemImage: "square.dashed")
                    Label("发现 POI: 0", systemImage: "mappin.circle.fill")
                }

                // 账号操作
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("个人")
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }

    private var username: String {
        authManager.currentUser?.userMetadata["username"]?.stringValue ?? "幸存者"
    }

    private var email: String {
        authManager.currentUser?.email ?? ""
    }
}

#Preview {
    ProfileTabView()
}
