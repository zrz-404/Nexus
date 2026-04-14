//
//  ThemeManager.swift
//  Nexus - Phase 5
//
//  Theme management for consistent UI styling
//

import SwiftUI
import Combine

enum ThemeVariant: String, CaseIterable {
    case midnight = "Midnight"
    case forest = "Forest"
    case ocean = "Ocean"
    case sunset = "Sunset"
    
    var accentHex: String {
        switch self {
        case .midnight: return "#6366F1"
        case .forest:   return "#10B981"
        case .ocean:    return "#3B82F6"
        case .sunset:   return "#F59E0B"
        }
    }
}

struct AppTheme {
    let variant: ThemeVariant
    
    // Accent
    var accent: Color { Color(hex: accentHex) }
    let accentHex: String
    var accentSoft: Color { accent.opacity(0.15) }
    
    // Background
    var background: Color { Color.black }
    var panel: Color { Color.white.opacity(0.08) }
    var panelSoft: Color { Color.white.opacity(0.04) }
    
    // Text
    var textPrimary: Color { Color.white.opacity(0.9) }
    var textSecondary: Color { Color.white.opacity(0.6) }
    var textTertiary: Color { Color.white.opacity(0.4) }
    
    // Border
    var border: Color { Color.white.opacity(0.1) }
    
    // Glass
    var glassTint: Color { Color.black }
    var glassOpacity: CGFloat { 0.25 }
    var brightnessBoost: CGFloat { 0.02 }
}

class ThemeManager: ObservableObject {
    @Published var currentVariant: ThemeVariant = .midnight
    
    var current: AppTheme {
        AppTheme(variant: currentVariant, accentHex: currentVariant.accentHex)
    }
    
    init() {
        // Load saved theme preference
        if let savedVariant = UserDefaults.standard.string(forKey: "nexus_theme_variant"),
           let variant = ThemeVariant(rawValue: savedVariant) {
            currentVariant = variant
        }
    }
    
    func setVariant(_ variant: ThemeVariant) {
        currentVariant = variant
        UserDefaults.standard.set(variant.rawValue, forKey: "nexus_theme_variant")
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
