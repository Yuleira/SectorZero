//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {

    init() {
        // 验证配置（仅在 DEBUG 模式下输出）
        AppConfig.validateConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Google Sign-In URL 回调处理
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
