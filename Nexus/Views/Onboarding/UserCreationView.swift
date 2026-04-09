//
//  UserCreationView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

struct UserCreationView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle().fill(Color.white.opacity(0.07)).frame(width: 72, height: 72)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
            }
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("A new home for your studies")
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .foregroundColor(.white.opacity(0.88))
                Text("Choose a username to get started")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.38))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            NexusTextField(placeholder: "Your username", text: $username, icon: "person")
                .frame(maxWidth: 320)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Button("Begin") { appState.saveUser(username) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { appeared = true }
        }
    }
}
