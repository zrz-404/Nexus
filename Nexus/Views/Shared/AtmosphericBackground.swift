//
//  AtmosphericBackground.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

struct AtmosphericBackground: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Full-window blur of the desktop
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Very light full-app tint — Phase 5: swap for Image("wallpaper") here
            Rectangle()
                .fill(themeManager.current.glassTint.opacity(themeManager.current.glassOpacity * 0.4))
                .ignoresSafeArea()
                //.animation(.easeInOut(duration: 0.45), value: themeManager.current.rawValue)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AtmosphericBackground()

            Group {
                switch appState.currentScreen {
                case .userCreation:  UserCreationView()
                case .worldCreation: WorldCreationView()
                case .genrePicker:   GenrePickerView()
                case .radioStation:  RadioStationView()
                case .main:          MainAppView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: 0.35), value: appState.currentScreen)
        .background(TransparentWindow()) // ← this is what enables everything
    }
}
