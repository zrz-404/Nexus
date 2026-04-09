// MainAppView.swift

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showWorldSwitcher = false
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if appState.sidebarVisible {
                    SidebarView()
                        .frame(width: 216)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.glassTint.opacity(theme.isDarkTheme ? 0.08 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                VStack(spacing: 8) {
                    TopBarView(showWorldSwitcher: $showWorldSwitcher)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.glassTint.opacity(theme.isDarkTheme ? 0.08 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ZStack {
                        switch appState.currentTab {
                        case .home:  HomeView()
                        case .world: WorldWorkspaceView()
                        case .wiki:  WikiView()
                        case .quill: QuillView()
                        case .echo:  EchoView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                }
            }
            .padding(10)

            // World switcher overlay
            if showWorldSwitcher {
                WorldSwitcherPanel(
                    currentTheme: Binding(
                        get: { themeManager.current },
                        set: { themeManager.set($0) }
                    ),
                    dismiss: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showWorldSwitcher = false
                        }
                    }
                )
                .environmentObject(themeManager)
                .padding(.top, 58)
                .padding(.trailing, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.currentTab)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: appState.sidebarVisible)
        .alert("Delete world?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = worldToDelete { appState.deleteWorld(id: id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteWorldRequested)) { note in
            if let id = note.object as? UUID {
                worldToDelete = id
                showDeleteAlert = true
            }
        }
    }

    @State private var showDeleteAlert = false
    @State private var worldToDelete: UUID? = nil
}
