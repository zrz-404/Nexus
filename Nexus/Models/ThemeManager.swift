//
//  ThemeManager.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import Foundation
import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Codable {
    case nebula   = "Nebula"
    case ember    = "Ember"
    case forest   = "Forest"
    case wind     = "Wind"
    case dusk     = "Dusk"
    case midnight = "Midnight"

    // MARK: - Light / Dark
    var isDarkTheme: Bool {
        switch self {
        case .nebula, .dusk, .midnight: return true
        case .ember, .forest, .wind:    return false
        }
    }

    // MARK: - Background gradient
    // Phase 5: swap this for Image("wallpaper").resizable().scaledToFill()
    var backgroundGradient: LinearGradient {
        switch self {
        case .nebula:
            return LinearGradient(
                colors: [Color(hex: "#0E0A1C"), Color(hex: "#121436"), Color(hex: "#1C0F30")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dusk:
            return LinearGradient(
                colors: [Color(hex: "#180D22"), Color(hex: "#28122A"), Color(hex: "#1C0F1E")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .midnight:
            return LinearGradient(
                colors: [Color(hex: "#07101E"), Color(hex: "#0C1830"), Color(hex: "#08101E")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .forest:
            return LinearGradient(
                colors: [Color(hex: "#8DB88A"), Color(hex: "#BDDCB4"), Color(hex: "#A4C89C")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ember:
            return LinearGradient(
                colors: [Color(hex: "#C0784A"), Color(hex: "#E8BF9A"), Color(hex: "#D4946A")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wind:
            return LinearGradient(
                colors: [Color(hex: "#72AEC2"), Color(hex: "#BAD8E8"), Color(hex: "#88C0D4")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - Glass
    /// Applied as a colour tint over the material blur. Tune this to adjust glass strength.
    var glassTint: Color {
        switch self {
        case .nebula:   return Color(hex: "#6B4FCC")
        case .dusk:     return Color(hex: "#9B4A8F")
        case .midnight: return Color(hex: "#2D5CB8")
        case .forest:   return Color(hex: "#4A7A52")
        case .ember:    return Color(hex: "#B46540")
        case .wind:     return Color(hex: "#4A8FA8")
        }
    }

    /// Base tint opacity for panels. Increase for more colour, decrease for clearer glass.
    var glassOpacity: Double {
        isDarkTheme ? 0.05 : 0.4
    }
    /// Adds a white luminosity layer for light themes so the UI stays bright
    /// even over dark desktop content. 0 = no boost (dark themes).
    var brightnessBoost: Double {
        switch self {
        case .nebula, .dusk, .midnight: return 0.1
        case .forest, .ember, .wind:    return 0.55
        }
    }

    // MARK: - Flat tinted surfaces (inner elements: cards, search fields, hover states)
    var panel: Color       { glassTint.opacity(isDarkTheme ? 0.13 : 0.15) }
    var panelStrong: Color { glassTint.opacity(isDarkTheme ? 0.22 : 0.26) }
    var panelSoft: Color   { glassTint.opacity(isDarkTheme ? 0.07 : 0.09) }

    // MARK: - Border
    var border: Color { glassTint.opacity(isDarkTheme ? 0.24 : 0.22) }

    // MARK: - Text
    var textPrimary: Color {
        isDarkTheme ? .white.opacity(0.88) : Color(hex: "#1A1A1A").opacity(0.85)
    }

    var textSecondary: Color {
        isDarkTheme ? .white.opacity(0.55) : Color(hex: "#1A1A1A").opacity(0.55)
    }

    var textTertiary: Color {
        isDarkTheme ? .white.opacity(0.30) : Color(hex: "#1A1A1A").opacity(0.35)
    }

    // MARK: - Accent
    var accent: Color {
        switch self {
        case .nebula:   return Color(hex: "#B89CFF")
        case .dusk:     return Color(hex: "#F09AD7")
        case .midnight: return Color(hex: "#7EA8FF")
        case .forest:   return Color(hex: "#4A8C50")
        case .ember:    return Color(hex: "#D07248")
        case .wind:     return Color(hex: "#4A96B8")
        }
    }

    var accentSoft: Color { accent.opacity(isDarkTheme ? 0.18 : 0.16) }

    // MARK: - Theme chip preview (blob1/blob2 used only in ThemeChip gradient)
    var blob1: Color {
        switch self {
        case .nebula:   return Color(hex: "#7A5CFF")
        case .dusk:     return Color(hex: "#A15C9B")
        case .midnight: return Color(hex: "#3D6CC9")
        case .forest:   return Color(hex: "#5A8C60")
        case .ember:    return Color(hex: "#C47850")
        case .wind:     return Color(hex: "#5A9AB5")
        }
    }

    var blob2: Color {
        switch self {
        case .nebula:   return Color(hex: "#3A8BE0")
        case .dusk:     return Color(hex: "#D07BB5")
        case .midnight: return Color(hex: "#5A92E6")
        case .forest:   return Color(hex: "#8ABF7A")
        case .ember:    return Color(hex: "#F0AA6A")
        case .wind:     return Color(hex: "#82C4DC")
        }
    }

    // MARK: - Icon
    var icon: String {
        switch self {
        case .nebula:   return "sparkles"
        case .ember:    return "flame"
        case .forest:   return "leaf"
        case .wind:     return "wind"
        case .dusk:     return "moon.stars"
        case .midnight: return "moon"
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .nebula

    init() {
        if let saved = UserDefaults.standard.string(forKey: "nexus_theme"),
           let theme = AppTheme(rawValue: saved) {
            current = theme
        }
    }

    func set(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "nexus_theme")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, ((int >> 8) & 0xF) * 17, ((int >> 4) & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
