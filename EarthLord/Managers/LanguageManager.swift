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
        // 从 UserDefaults 加载保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("🌐 [语言管理器] 从存储加载语言设置: \(language.rawValue)")
        } else {
            self.currentLanguage = .system
            print("🌐 [语言管理器] 使用默认设置: 跟随系统")
        }
    }

    // MARK: - 公共方法

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else {
            return
        }

        print("🌐 [语言切换] \(currentLanguage.rawValue) -> \(language.rawValue)")
        currentLanguage = language
        saveLanguage()
        refreshID = UUID()
    }

    /// 获取实际使用的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        }
        // 跟随系统时，获取系统首选语言
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh-Hans") || preferredLanguage.hasPrefix("zh-CN") || preferredLanguage.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }

    /// 获取当前的 Locale 对象（用于注入SwiftUI环境）
    var currentLocale: Locale {
        if let code = currentLanguage.languageCode {
            return Locale(identifier: code)
        }
        return Locale.current
    }

    // MARK: - 私有方法

    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("🌐 [语言管理器] 语言设置已保存: \(currentLanguage.rawValue)")
    }
}

// MARK: - String 扩展

extension String {
    /// 获取本地化字符串
    var localized: String {
        // ❌ 删掉 LanguageManager.sharedString...
        // ✅ 改成标准写法：直接翻译自己
        return NSLocalizedString(self, comment: "")
    }
    
    /// 获取本地化字符串（带参数）
    func localized(_ arguments: CVarArg...) -> String {
        // ❌ 删掉 self.rawValue (字符串本身没有 rawValue)
        // ✅ 改成直接用 self
        let format = NSLocalizedString(self, comment: "")
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
