//
//  TopBarView.swift
//  Nexus - Phase 5
//
//  Top navigation bar with tab switching
//

import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar toggle
            Button {
                withAnimation(.spring(response: 0.25)) {
                    appState.sidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.panelSoft)
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            
            // Tab buttons
            HStack(spacing: 4) {
                ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                    TabButton(
                        icon: tab.icon,
                        label: tab.rawValue,
                        isActive: appState.currentTab == tab,
                        theme: theme
                    ) {
                        withAnimation(.spring(response: 0.2)) {
                            appState.currentTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // World switcher
            WorldSwitcherButton()
            
            // Settings
            Button {
                // Show settings
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.panelSoft)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 10)
        .background(theme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let theme: AppTheme
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .foregroundColor(isActive ? theme.accent : (isHovered ? theme.textPrimary : theme.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? theme.accentSoft : (isHovered ? theme.panelSoft : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct WorldSwitcherButton: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showMenu = false
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        Menu {
            Section("Current World") {
                if let world = appState.currentWorld {
                    Label(world.name, systemImage: "checkmark")
                }
            }
            
            Section("Switch World") {
                ForEach(appState.worlds.filter { $0.id != appState.currentWorld?.id }) { world in
                    Button(world.name) {
                        appState.switchToWorld(world)
                    }
                }
            }
            
            Divider()
            
            Button("Create New World...") {
                // Navigate to world creation
            }
        } label: {
            HStack(spacing: 6) {
                if let world = appState.currentWorld {
                    ZStack {
                        Circle()
                            .fill(theme.accentSoft)
                            .frame(width: 22, height: 22)
                        Text(String(world.name.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.accent)
                    }
                    
                    Text(world.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
            )
        }
        .menuStyle(.borderlessButton)
    }
}
