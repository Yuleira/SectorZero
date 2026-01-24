//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Yu Lei on 31/12/2025.
//
//  Thin wrapper for language management using Apple's native String Catalog
//

import Foundation
import SwiftUI
import Combine

/// 支持的语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "language_follow_system")
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 语言代码
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}

/// 语言管理器
/// Thin wrapper for UserDefaults and Locale environment injection
/// All translations now use Apple's native String Catalog (Localizable.xcstrings)
final class LanguageManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = LanguageManager()
    
    // MARK: - 存储键
    private let languageKey = "app_language"
    
    // MARK: - 发布属性
    @Published var currentLanguage: AppLanguage = .system
    @Published var refreshID = UUID()
    
    // MARK: - 初始化
    
    private init() {
            if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
               let language = AppLanguage(rawValue: savedLanguage) {
                self.currentLanguage = language
            } else {
                self.currentLanguage = .system
            }
        }
    
    // MARK: - 公共方法
    
    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
            guard language != currentLanguage else { return }
            currentLanguage = language
            saveLanguage()
            // 🚀 核心：切换时改变 UUID，强制所有 View 重绘并重新查表
            refreshID = UUID()
        }
    
    /// 获取实际使用的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        }
        // 跟随系统时，获取系统首选语言
        let preferred = Locale.preferredLanguages.first ?? "en"
                return (preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") || preferred.hasPrefix("zh")) ? "zh-Hans" : "en"
        }
    
    /// 获取当前的 Locale 对象（用于注入SwiftUI环境）
    var currentLocale: Locale {
        // 核心：这里的 Locale 必须与 xcstrings 的列名完全对应
                return Locale(identifier: effectiveLanguageCode)
            }
            
            private func saveLanguage() {
                UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            }
        }
    
    // MARK: - String 扩展 (大师级修复版)
    
    extension String {

        /// 🚀 修复后的本地化计算属性
            var localized: String {
                // 不要返回 self！要调用系统查表逻辑。
                // 使用这个初始化方法，它能识别我们在 ContentView 注入的 .environment(\.locale)
                return String(localized: LocalizationValue(self))
            }
            
            /// 🚀 修复后的带参数本地化
            func localized(_ arguments: CVarArg...) -> String {
                let format = String(localized: LocalizationValue(self))
                return String(format: format, arguments: arguments)
            }
        }
    
    // MARK: - View 扩展
    
    extension View {
        /// 监听语言变化并刷新视图
        func onLanguageChange() -> some View {
            self.id(LanguageManager.shared.refreshID)
        }
    }

