//
//  NexusApp.swift
//  Nexus - Phase 5
//
//  Main app entry point
//

import SwiftUI

@main
struct NexusApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .userCreation:
                UserCreationView()
            case .worldCreation:
                WorldCreationView()
            case .genrePicker:
                GenrePickerView()
            case .radioStation:
                RadioStationView()
            case .main:
                MainAppView()
            }
        }
    }
}

// MARK: - User Creation View
struct UserCreationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var username = ""
    
    var body: some View {
        ZStack {
            AtmosphericBackground(accent: themeManager.current.accent, variant: themeManager.current.variant)
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 64))
                    .foregroundColor(themeManager.current.accent)
                
                Text("Welcome to Nexus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your personal knowledge universe")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 16) {
                    NexusTextField(placeholder: "Enter your name", text: $username, icon: "person")
                        .frame(width: 280)
                    
                    Button("Get Started") {
                        appState.saveUser(username)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - World Creation View
struct WorldCreationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            AtmosphericBackground(accent: themeManager.current.accent, variant: themeManager.current.variant)
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("Create Your First World")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("A world is a container for your study materials")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 16) {
                    NexusTextField(
                        placeholder: "World name (e.g., Biology 101)",
                        text: $appState.pendingWorldName,
                        icon: "globe"
                    )
                    .frame(width: 280)
                    
                    // Genre picker
                    GenreSelector(selectedGenre: $appState.pendingGenre)
                    
                    Button("Create World") {
                        appState.createWorld()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(appState.pendingWorldName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Genre Selector
struct GenreSelector: View {
    @Binding var selectedGenre: String
    
    let genres = [
        ("Medicine", "cross.circle", "#EF4444"),
        ("Sciences", "atom", "#3B82F6"),
        ("Computer Science", "laptopcomputer", "#6366F1"),
        ("Mathematics", "function", "#10B981"),
        ("History", "clock.arrow.circlepath", "#F59E0B"),
        ("Literature", "book", "#8B5CF6"),
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
            ForEach(genres, id: \.0) { genre, icon, color in
                GenreButton(
                    genre: genre,
                    icon: icon,
                    color: Color(hex: color),
                    isSelected: selectedGenre == genre
                ) {
                    selectedGenre = genre
                }
            }
        }
        .frame(width: 280)
    }
}

struct GenreButton: View {
    let genre: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.05))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? color : .white.opacity(0.6))
                }
                
                Text(genre)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Genre Picker View
struct GenrePickerView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        // Placeholder - integrated into world creation
        Color.clear.onAppear {
            appState.currentScreen = .worldCreation
        }
    }
}

// MARK: - Radio Station View
struct RadioStationView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        // Placeholder - integrated into main app
        Color.clear.onAppear {
            appState.currentScreen = .main
        }
    }
}
