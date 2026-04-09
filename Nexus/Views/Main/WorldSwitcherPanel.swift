import SwiftUI

// MARK: - In-window world switcher panel
// Rendered as a ZStack overlay in MainAppView — completely avoids NSPopover/XPC boundary
struct WorldSwitcherPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var currentTheme: AppTheme
    let dismiss: () -> Void

    @State private var showThemePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("Worlds")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Button {
                    appState.pendingWorldName = ""
                    appState.pendingGenre = ""
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        appState.currentScreen = .worldCreation
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10))
                        Text("New").font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.07))

            // World list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(appState.worlds) { world in
                        WorldPanelRow(
                            world: world,
                            isCurrent: appState.currentWorld?.id == world.id,
                            onSelect: {
                                appState.switchToWorld(world)
                                dismiss()
                            },
                            onDelete: {
                                // Post to MainAppView which owns the .alert — stays in main process
                                NotificationCenter.default.post(
                                    name: .deleteWorldRequested,
                                    object: world.id
                                )
                                dismiss()
                            }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)

            Divider().background(Color.white.opacity(0.07))

            // Theme section
            Button {
                withAnimation(.spring(response: 0.28)) { showThemePicker.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: currentTheme.icon)
                        .font(.system(size: 11))
                        .foregroundColor(currentTheme.accent)
                    Text("Theme: \(currentTheme.rawValue)")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Image(systemName: showThemePicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if showThemePicker {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeChip(theme: theme, isSelected: currentTheme == theme) {
                            // Plain value write — no object reference crossing any boundary
                            currentTheme = theme
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.09, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
    }
}

// MARK: - World row (panel version)
struct WorldPanelRow: View {
    let world: StudyWorld
    let isCurrent: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(isCurrent ? 0.14 : 0.07))
                            .frame(width: 28, height: 28)
                        Text(String(world.name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isCurrent ? .white : .white.opacity(0.6))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(world.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isCurrent ? .white : .white.opacity(0.65))
                        Text(world.genre.isEmpty ? "No genre" : world.genre)
                            .font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            if hovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 9)).foregroundColor(.red.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.red.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(isCurrent ? Color.white.opacity(0.08) : Color.white.opacity(hovered ? 0.05 : 0)))
        .onHover { hovered = $0 }
    }
}

// MARK: - Theme chip
struct ThemeChip: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [theme.blob1.opacity(0.8), theme.blob2.opacity(0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.1),
                                    lineWidth: isSelected ? 1.5 : 1))
                    Image(systemName: theme.icon)
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                }
                Text(theme.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(isSelected ? 0.8 : 0.4))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(response: 0.22), value: isSelected)
    }
}
