import Combine
import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var radio = RadioPlayerManager.shared
    @State private var showRadioPopover = false
    @Binding var showWorldSwitcher: Bool

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
//            GlassBackground(
//                tint: theme.glassTint,
//                opacity: theme.glassOpacity,
//                brightnessBoost: theme.brightnessBoost
//            )

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    TopBarIconButton(
                        icon: "sidebar.left",
                        isActive: appState.sidebarVisible,
                        action: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                appState.sidebarVisible.toggle()
                            }
                        }
                    )

                    TopBarIconButton(
                        icon: "house.fill",
                        isActive: appState.currentTab == .home,
                        action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                appState.currentTab = .home
                            }
                        }
                    )
                }
                
                .padding(.leading, 14)

                Spacer()

                HStack(spacing: 2) {
                    ForEach([WorkspaceTab.home, .world, .wiki, .quill, .echo], id: \.self) { tab in
                        TabPill(
                            tab: tab,
                            isSelected: appState.currentTab == tab,
                            action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    appState.currentTab = tab
                                }
                            }
                        )
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(theme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                )

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        showRadioPopover.toggle()
                    } label: {
                        ZStack {
                            Image(systemName: radio.isPlaying ? "radio.fill" : "radio")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(radio.isPlaying ? theme.accent : theme.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(radio.isPlaying ? theme.accentSoft : theme.panelSoft)
                                )

                            if radio.isPlaying {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 5, height: 5)
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showRadioPopover, arrowEdge: .top) {
                        RadioPopover()
                            .environmentObject(themeManager)
                    }

                    TopBarIconButton(
                        icon: "globe.europe.africa",
                        isActive: showWorldSwitcher,
                        action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                showWorldSwitcher.toggle()
                            }
                        }
                    )
                }
                .padding(.trailing, 14)
            }
            .frame(height: 44)
            .padding(.horizontal, 4)
        }
        .frame(height: 50)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }
}

struct TabPill: View {
    @EnvironmentObject var themeManager: ThemeManager

    let tab: WorkspaceTab
    let isSelected: Bool
    let action: () -> Void

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .medium))

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? theme.accentSoft : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isSelected ? theme.border.opacity(1) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TopBarIconButton: View {
    @EnvironmentObject var themeManager: ThemeManager

    let icon: String
    var isActive: Bool = false
    let action: () -> Void

    @State private var hovered = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? theme.textPrimary : theme.textSecondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isActive
                                ? theme.accentSoft
                                : (hovered ? theme.panel : theme.panelSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isActive ? theme.border : theme.border.opacity(0.65), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.12)) {
                hovered = isHovered
            }
        }
    }
}

struct RadioPopover: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var radio = RadioPlayerManager.shared
    @State private var volume: Double = 0.7

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "radio")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)

                Text("Radio")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if radio.isPlaying {
                    Button {
                        radio.stop()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .overlay(theme.border)

            if let station = radio.currentStation {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.accentSoft)
                            .frame(width: 36, height: 36)

                        Image(systemName: station.icon)
                            .font(.system(size: 14))
                            .foregroundColor(theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textPrimary)

                        Text(station.description)
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    Button {
                        radio.togglePlayPause()
                    } label: {
                        Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(theme.panelSoft)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()
                    .overlay(theme.border)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                ForEach(defaultStations) { station in
                    RadioStationTile(
                        station: station,
                        isActive: radio.currentStation?.id == station.id,
                        action: {
                            radio.play(station)
                        }
                    )
                }
            }
            .padding(12)

            Divider()
                .overlay(theme.border)

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTertiary)

                Slider(value: $volume, in: 0...1) { _ in
                    radio.setVolume(Float(volume))
                }
                .tint(theme.accent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(GlassBackground(
            tint: theme.glassTint,
            opacity: theme.glassOpacity,
            brightnessBoost: theme.brightnessBoost
        ))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            volume = Double(radio.volume)
        }
    }
}

struct RadioStationTile: View {
    @EnvironmentObject var themeManager: ThemeManager

    let station: RadioStation
    let isActive: Bool
    let action: () -> Void

    @State private var hovered = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: station.icon)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? theme.accent : theme.textSecondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isActive ? theme.textPrimary : theme.textSecondary)

                    Text(station.description)
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isActive {
                    RadioMiniVisualizer()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? theme.accentSoft : (hovered ? theme.panel : theme.panelSoft))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isActive ? theme.border : theme.border.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct RadioMiniVisualizer: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var heights: [CGFloat] = [0.4, 0.7, 0.5, 0.9, 0.3]
    let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent.opacity(0.9))
                    .frame(width: 2, height: max(3, h * 14))
                    .animation(.easeInOut(duration: 0.18), value: h)
            }
        }
        .onReceive(timer) { _ in
            heights = (0..<5).map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }
}
