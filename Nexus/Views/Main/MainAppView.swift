//
//  MainAppView.swift
//  Nexus - Phase 5
//
//  Updated with Echo tab and per-world document scoping
//

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var radioManager = RadioPlayerManager.shared

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if appState.sidebarVisible {
                SidebarView()
                    .frame(width: 240)
                    .background(
                        GlassPanel(cornerRadius: 0) {}
                            .background(theme.panel.opacity(0.95))
                    )
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(theme.border).frame(width: 1)
                    }
            }

            // Main content area
            VStack(spacing: 0) {
                // Top bar
                TopBarView()

                // Tab content
                ZStack {
                    switch appState.currentTab {
                    case .home:
                        HomeView()
                    case .world:
                        WorldWorkspaceView()
                    case .wiki:
                        WikiView()
                    case .quill:
                        QuillView()
                    case .echo:
                        EchoSessionView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            AtmosphericBackground(
                accent: theme.accent,
                variant: theme.variant
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .bottom) {
            // Radio mini player
            if radioManager.currentStation != nil {
                RadioMiniPlayer()
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Radio Mini Player
struct RadioMiniPlayer: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var radioManager = RadioPlayerManager.shared
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        HStack(spacing: 12) {
            // Station icon
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 36, height: 36)
                
                if let station = radioManager.currentStation {
                    Image(systemName: station.icon)
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                }
            }
            
            // Station info
            VStack(alignment: .leading, spacing: 2) {
                if let station = radioManager.currentStation {
                    Text(station.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    
                    HStack(spacing: 4) {
                        if radioManager.isBuffering {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            Text("Buffering...")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textSecondary)
                        } else if let error = radioManager.errorMessage {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "#EF4444"))
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .lineLimit(1)
                        } else {
                            Circle()
                                .fill(radioManager.isPlaying ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                                .frame(width: 6, height: 6)
                            Text(radioManager.isPlaying ? "Playing" : "Paused")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
                // Volume slider
                HStack(spacing: 4) {
                    Image(systemName: radioManager.volume > 0 ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                    
                    Slider(value: .init(
                        get: { Double(radioManager.volume) },
                        set: { radioManager.setVolume(Float($0)) }
                    ), in: 0...1)
                    .frame(width: 60)
                    .tint(theme.accent)
                }
                
                Divider()
                    .frame(height: 20)
                
                // Play/Pause
                Button {
                    radioManager.togglePlayPause()
                } label: {
                    Image(systemName: radioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(theme.panelSoft)
                        )
                }
                .buttonStyle(.plain)
                
                // Stop
                Button {
                    radioManager.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.panel.opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome header
                welcomeSection
                
                // Stats row
                statsSection
                
                // Recent documents
                recentDocumentsSection
                
                // Quick actions
                quickActionsSection
                
                // Radio stations
                radioStationsSection
            }
            .padding(24)
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let user = appState.user {
                Text("Welcome back, \(user.username)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }
            
            if let world = appState.currentWorld {
                HStack(spacing: 8) {
                    Text(world.name)
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                    
                    if !world.genre.isEmpty {
                        Text("•")
                            .foregroundColor(theme.textTertiary)
                        Text(world.genre)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "doc.text",
                value: "\(appState.currentWorldDocuments.count)",
                label: "Documents"
            )
            
            StatCard(
                icon: "rectangle.on.rectangle",
                value: "\(appState.echoCards.filter { card in
                    appState.documents.first { $0.id == card.documentId }?.worldId == appState.currentWorld?.id
                }.count)",
                label: "Flashcards"
            )
            
            StatCard(
                icon: "waveform",
                value: "\(appState.dueEchoCards.count)",
                label: "Due for Review"
            )
            
            StatCard(
                icon: "flame.fill",
                value: "\(appState.echoStats.streakDays)",
                label: "Day Streak"
            )
        }
    }
    
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Documents")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Button("View All") {
                    appState.currentTab = .world
                }
                .font(.system(size: 12))
                .foregroundColor(theme.accent)
                .buttonStyle(.plain)
            }
            
            if appState.recentItems.isEmpty {
                Text("No recent documents")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(appState.recentItems.prefix(4)) { doc in
                        RecentDocumentCard(document: doc)
                    }
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.rectangle",
                    label: "New Card",
                    color: theme.accent
                ) {
                    appState.createDocument(title: "Untitled Card", type: .card)
                }
                
                QuickActionButton(
                    icon: "circle.hexagongrid",
                    label: "New Mind Map",
                    color: Color(hex: "#8B5CF6")
                ) {
                    appState.createDocument(title: "Untitled Mind Map", type: .mindmap)
                }
                
                QuickActionButton(
                    icon: "waveform",
                    label: "Study Echo",
                    color: Color(hex: "#10B981")
                ) {
                    appState.currentTab = .echo
                }
                
                QuickActionButton(
                    icon: "headphones",
                    label: "Radio",
                    color: Color(hex: "#F59E0B")
                ) {
                    // Show radio picker
                }
            }
        }
    }
    
    private var radioStationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Radio")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(defaultStations.prefix(4)) { station in
                    RadioStationCard(station: station)
                }
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let value: String
    let label: String
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.panelSoft)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
        )
    }
}

// MARK: - Recent Document Card
struct RecentDocumentCard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument
    
    private var theme: AppTheme { themeManager.current }
    var dtype: DocumentType { DocumentType(rawValue: document.type) ?? .card }
    
    var body: some View {
        Button {
            appState.openDocument(document)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.accentSoft)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: dtype.icon)
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(dtype.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.current.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.current.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.current.border, lineWidth: 1))
            )
            .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Radio Station Card
struct RadioStationCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var radioManager = RadioPlayerManager.shared
    let station: RadioStation
    
    @State private var isHovered = false
    
    private var theme: AppTheme { themeManager.current }
    private var isPlaying: Bool {
        radioManager.currentStation?.id == station.id && radioManager.isPlaying
    }
    
    var body: some View {
        Button {
            if isPlaying {
                radioManager.stop()
            } else {
                radioManager.play(station)
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isPlaying ? theme.accentSoft : theme.panelSoft)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: station.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isPlaying ? theme.accent : theme.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(station.description)
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent)
                        .symbolEffect(.pulse)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? theme.accentSoft.opacity(0.3) : theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isPlaying ? theme.accent.opacity(0.3) : theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(!station.isPlayable)
        .opacity(station.isPlayable ? 1 : 0.5)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}
