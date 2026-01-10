//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Yu Lei on 31/12/2025.
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
            return "跟随系统".localized
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
/// 负责管理 App 内语言切换，不依赖系统设置
final class LanguageManager: ObservableObject {

    // MARK: - 单例
    static let shared = LanguageManager()

    // MARK: - 存储键
    private let languageKey = "app_language"

    // MARK: - 发布属性
    @Published var currentLanguage: AppLanguage = .system
    @Published var refreshID = UUID()

    // MARK: - 私有属性

    /// 翻译字典 [key: [languageCode: translation]]
    private var translations: [String: [String: String]] = [:]

    /// 源语言
    private var sourceLanguage: String = "zh-Hans"

    // MARK: - 初始化

    private init() {
        // 加载翻译文件
        loadTranslations()

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
            print("🌐 [语言切换] 语言未变化，跳过")
            return
        }

        print("🌐 [语言切换] 开始切换语言: \(currentLanguage.rawValue) -> \(language.rawValue)")
        currentLanguage = language
        saveLanguage()
        refreshID = UUID()
    }

    /// 获取本地化字符串
    func localizedString(for key: String) -> String {
        let targetLanguage = effectiveLanguageCode

        // 如果目标语言是源语言，直接返回 key
        if targetLanguage == sourceLanguage {
            return key
        }

        // 查找翻译
        if let langTranslations = translations[key],
           let translation = langTranslations[targetLanguage] {
            return translation
        }

        // 没有找到翻译，返回原始 key
        return key
    }

    /// 获取实际使用的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        }
        // 跟随系统时，获取系统首选语言
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh-Hans") || preferredLanguage.hasPrefix("zh-CN") {
            return "zh-Hans"
        } else if preferredLanguage.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }

    // MARK: - 私有方法

    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("🌐 [语言管理器] 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 加载翻译
    private func loadTranslations() {
        // 首先尝试从 xcstrings 文件加载
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
           let data = try? Data(contentsOf: url),
           loadFromXCStrings(data: data) {
            return
        }

        // 如果文件不存在，使用内置翻译
        print("🌐 [语言管理器] 使用内置翻译数据")
        loadBuiltInTranslations()
    }

    /// 从 xcstrings 数据加载
    private func loadFromXCStrings(data: Data) -> Bool {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let strings = json["strings"] as? [String: Any] {

                if let source = json["sourceLanguage"] as? String {
                    sourceLanguage = source
                }

                for (key, value) in strings {
                    guard let entry = value as? [String: Any],
                          let localizations = entry["localizations"] as? [String: Any] else {
                        continue
                    }

                    var langDict: [String: String] = [:]
                    for (langCode, langValue) in localizations {
                        if let langEntry = langValue as? [String: Any],
                           let stringUnit = langEntry["stringUnit"] as? [String: Any],
                           let translation = stringUnit["value"] as? String {
                            langDict[langCode] = translation
                        }
                    }

                    if !langDict.isEmpty {
                        translations[key] = langDict
                    }
                }

                print("🌐 [语言管理器] ✅ 从文件加载 \(translations.count) 条翻译")
                return true
            }
        } catch {
            print("🌐 [语言管理器] ❌ 解析翻译文件失败: \(error)")
        }
        return false
    }

    /// 内置翻译数据
    private func loadBuiltInTranslations() {
        translations = [
            // 导航
            "地图": ["en": "Map"],
            "领地": ["en": "Territory"],
            "资源": ["en": "Resources"],
            "个人": ["en": "Profile"],
            "更多": ["en": "More"],

            // 设置
            "设置": ["en": "Settings"],
            "语言": ["en": "Language"],
            "语言设置": ["en": "Language Settings"],
            "跟随系统": ["en": "System"],
            "切换语言后界面将立即更新": ["en": "Interface will update immediately after switching"],

            // 账户
            "账户": ["en": "Account"],
            "退出登录": ["en": "Sign Out"],
            "退出": ["en": "Sign Out"],
            "删除账户": ["en": "Delete Account"],
            "确认删除": ["en": "Confirm Delete"],
            "确认删除账户": ["en": "Confirm Account Deletion"],
            "删除失败": ["en": "Delete Failed"],
            "取消": ["en": "Cancel"],
            "确定": ["en": "OK"],

            // 删除账户相关
            "此操作不可撤销！": ["en": "This action cannot be undone!"],
            "删除账户后，以下数据将被永久删除：": ["en": "The following data will be permanently deleted:"],
            "删除账户后，您的所有数据将被永久删除且无法恢复。": ["en": "After deleting your account, all your data will be permanently deleted and cannot be recovered."],
            "您的个人资料信息": ["en": "Your profile information"],
            "所有游戏进度和数据": ["en": "All game progress and data"],
            "登录凭证和认证信息": ["en": "Login credentials and authentication info"],

            // 个人页面
            "确认退出": ["en": "Confirm Sign Out"],
            "确定要退出登录吗？退出后需要重新登录。": ["en": "Are you sure you want to sign out? You will need to sign in again."],
            "账号安全": ["en": "Account Security"],
            "账号安全（待开发）": ["en": "Account Security (Coming Soon)"],
            "通知设置": ["en": "Notifications"],
            "通知设置（待开发）": ["en": "Notifications (Coming Soon)"],
            "关于我们": ["en": "About Us"],
            "关于我们（待开发）": ["en": "About Us (Coming Soon)"],

            // 占位视图
            "探索和圈占领地": ["en": "Explore and claim territories"],
            "管理你的领地": ["en": "Manage your territories"],

            // 开发者工具
            "开发者工具": ["en": "Developer Tools"],
            "Supabase 连接测试": ["en": "Supabase Connection Test"],
            "测试连接": ["en": "Test Connection"],
            "测试中...": ["en": "Testing..."],
            "验证数据表": ["en": "Verify Tables"],
            "验证中...": ["en": "Verifying..."],

            // 加载
            "加载中...": ["en": "Loading..."],

            // 认证
            "忘记密码？": ["en": "Forgot Password?"],
            "找回密码": ["en": "Reset Password"],
            "设置新密码": ["en": "Set New Password"],
            "设置登录密码": ["en": "Set Login Password"],
            "请设置一个安全的密码以完成注册": ["en": "Please set a secure password to complete registration"],
            "两次输入的密码不一致": ["en": "Passwords do not match"],
            "或者使用以下方式登录": ["en": "Or sign in with"],
            "通过 Apple 登录": ["en": "Sign in with Apple"],
            "通过 Google 登录": ["en": "Sign in with Google"],
            "输入注册邮箱": ["en": "Enter your email"],
            "输入邮箱获取验证码": ["en": "Enter email to get verification code"],
            "输入验证码": ["en": "Enter Code"],
            "请输入6位验证码": ["en": "Enter 6-digit code"],
            "重新发送验证码": ["en": "Resend Code"],
            "返回上一步": ["en": "Go Back"],

            // 地图定位
            "正在定位...": ["en": "Locating..."],
            "无法获取位置": ["en": "Cannot Get Location"],
            "《地球新主》需要获取您的位置才能显示您在末日世界中的坐标。请在设置中开启定位权限。": ["en": "Earth Lord needs your location to show your coordinates in the post-apocalyptic world. Please enable location access in Settings."],
            "前往设置": ["en": "Go to Settings"],

            // 圈地功能
            "开始圈地": ["en": "Start Claiming"],
            "停止圈地": ["en": "Stop Claiming"],
            "圈地成功！领地已标记": ["en": "Claim successful! Territory marked"],
            "定位": ["en": "Location"],
            "探索": ["en": "Explore"],
            "探索中...": ["en": "Exploring..."],

            // 测试模块
            "开发测试": ["en": "Developer Tests"],
            "测试模块": ["en": "Test Modules"],
            "这些工具仅供开发调试使用": ["en": "These tools are for development debugging only"],
            "圈地功能测试": ["en": "Territory Claiming Test"],
            "圈地测试": ["en": "Territory Test"],
            "追踪中": ["en": "Tracking"],
            "未追踪": ["en": "Not Tracking"],
            "条日志": ["en": " logs"],
            "暂无日志": ["en": "No Logs"],
            "开始圈地追踪后，日志将在此显示": ["en": "Logs will appear here after starting territory tracking"],
            "清空日志": ["en": "Clear Logs"],
            "导出日志": ["en": "Export Logs"],

            // 资源相关
            "资源分段": ["en": "Resource Segments"],
            "背包": ["en": "Backpack"],
            "已购": ["en": "Purchased"],
            "交易": ["en": "Trade"],
            "领地资源": ["en": "Territory Resources"],
            "POI列表": ["en": "POI List"],
            "交易市场": ["en": "Trading Market"],
            "功能开发中": ["en": "Feature in Development"],

            // 其他
            "地球新主": ["en": "Earth Lord"],
            "用脚步丈量世界，用领地征服地球": ["en": "Measure the world with your steps, conquer the Earth with your territories"],
        ]

        print("🌐 [语言管理器] ✅ 已加载 \(translations.count) 条内置翻译")
    }
}

// MARK: - String 扩展

extension String {
    /// 获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }

    /// 获取本地化字符串（带参数）
    func localized(_ arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(for: self)
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
