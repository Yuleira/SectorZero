//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Yu Lei on 31/12/2025.
//
//  Late-Binding Localization Strategy
//  Thin wrapper for language management using Apple's native String Catalog
//

import Foundation
import SwiftUI
import Combine

// MARK: - Supported Languages

/// 支持的语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称（Late-Binding: 返回 LocalizedStringResource）
    /// Note: Native language names use string literals, not localized
    var displayName: LocalizedStringResource {
        switch self {
        case .system:
            return "language_follow_system"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 语言代码 (nil for system = use device preference)
    var languageCode: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        }
    }
}

// MARK: - Language Manager

/// 语言管理器 - Late-Binding Localization Strategy
/// - Stores only the selected language preference
/// - Provides currentLocale for SwiftUI environment injection
/// - All translations use Apple's native String Catalog (Localizable.xcstrings)
final class LanguageManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = LanguageManager()
    
    // MARK: - Storage Key
    private let storageKey = "selected_language"
    
    // MARK: - Published Properties
    
    /// The user's selected language preference
    @Published var selectedLanguage: AppLanguage = .system
    
    /// Unique ID for forcing view refresh on language change
    @Published var refreshID = UUID()
    
    // MARK: - Computed Properties
    
    /// The effective language code (resolves "system" to actual device language)
    var effectiveLanguageCode: String {
        if let code = selectedLanguage.languageCode {
            return code
        }
        // Resolve system preference to supported language
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") || preferred.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }
    
    /// The current Locale for SwiftUI environment injection
    /// This Locale identifier must match xcstrings column names exactly
    var currentLocale: Locale {
        Locale(identifier: effectiveLanguageCode)
    }
    
    // MARK: - Initialization
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: saved) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
    }
    
    // MARK: - Public Methods
    
    /// Set the app language
    func setLanguage(_ language: AppLanguage) {
        guard language != selectedLanguage else { return }
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        // Force all views to re-render and re-query String Catalog
        refreshID = UUID()
    }
    
    /// Translate a LocalizedStringResource using the current locale
    /// Use this for programmatic translations outside of SwiftUI views
    func translate(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
    
    /// Translate a key string using the current locale
    func translate(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: currentLocale)
    }
}

// MARK: - View Extension

extension View {
    /// Apply language environment and refresh binding
    /// Use this at the root of your view hierarchy
    func withLanguageEnvironment() -> some View {
        let manager = LanguageManager.shared
        return self
            .environment(\.locale, manager.currentLocale)
            .id(manager.refreshID)
    }
}

