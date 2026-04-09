//
//  GenrePickerView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

struct GenrePickerView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: StudyGenre? = nil
    @State private var appeared = false

    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("What is the primary subject of your world?")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(StudyGenre.allCases, id: \.self) { genre in
                    GenreChip(genre: genre, isSelected: selected == genre) {
                        withAnimation(.spring(response: 0.25)) {
                            selected = genre
                            appState.pendingGenre = genre.rawValue
                        }
                    }
                }
            }
            .frame(maxWidth: 680)
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)

            HStack(spacing: 12) {
                Button("Back")     { appState.currentScreen = .worldCreation }.buttonStyle(SecondaryButtonStyle())
                Button("Continue") { appState.currentScreen = .radioStation  }.buttonStyle(PrimaryButtonStyle())
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { appeared = true } }
    }
}

struct GenreChip: View {
    let genre: StudyGenre
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: genre.icon).font(.system(size: 11))
                Text(genre.rawValue).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.07))
                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.1), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.spring(response: 0.22), value: isSelected)
    }
}
