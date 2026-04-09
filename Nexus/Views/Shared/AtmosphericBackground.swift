import SwiftUI

struct AtmosphericBackground: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Rectangle()
                .fill(themeManager.current.glassTint.opacity(themeManager.current.glassOpacity * 0.4))
                .ignoresSafeArea()
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AtmosphericBackground()

            contentView
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: 0.35), value: appState.currentScreen)
        .background(TransparentWindow())
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.currentScreen {
        case .userCreation:  UserCreationView()
        case .worldCreation: WorldCreationView()
        case .genrePicker:   GenrePickerView()
        case .radioStation:  RadioStationView()
        case .main:          MainAppView()
        }
    }
}
