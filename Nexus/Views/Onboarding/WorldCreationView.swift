//
//  WorldCreationView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

struct WorldCreationView: View {
    @EnvironmentObject var appState: AppState
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 6) {
                Text("Every great place needs a name")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundColor(.white.opacity(0.88))
                Text("Name your new world")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.38))
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)

            NexusTextField(placeholder: "World name...", text: $appState.pendingWorldName, icon: "globe")
                .frame(maxWidth: 320)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)

            HStack(spacing: 12) {
                Button("Back")     { appState.currentScreen = .userCreation  }.buttonStyle(SecondaryButtonStyle())
                Button("Continue") { appState.currentScreen = .genrePicker   }.buttonStyle(PrimaryButtonStyle())
                    .disabled(appState.pendingWorldName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { appeared = true } }
    }
}
