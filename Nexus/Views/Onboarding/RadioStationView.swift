//
//  RadioStationView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI
import Combine

struct RadioStationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: RadioStation? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Pick a station to get you in the zone")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.white.opacity(0.88))
                .opacity(appeared ? 1 : 0)

            // Radio widget
            GlassPanel(cornerRadius: 18) {
                VStack(spacing: 0) {
                    // Station scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(defaultStations) { station in
                                RadioTab(station: station, isSelected: selected?.id == station.id) {
                                    withAnimation(.spring(response: 0.25)) { selected = station }
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.top, 12)
                    }
                    // Visualizer
                    RadioVisualizer(isPlaying: selected != nil)
                        .frame(height: 44)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    // Status
                    HStack {
                        Text(selected?.description ?? "No station selected")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
                        Spacer()
                        Image(systemName: "shuffle").font(.system(size: 11)).foregroundColor(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
            .frame(maxWidth: 460)
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)

            // Note: real audio playback wired up in next iteration
            Text("🔇 Audio playback coming in the next iteration")
                .font(.system(size: 10)).foregroundColor(.white.opacity(0.2))

            HStack(spacing: 12) {
                Button("Back") { appState.currentScreen = .genrePicker }.buttonStyle(SecondaryButtonStyle())
                Button("Skip") { appState.createWorld() }.buttonStyle(SecondaryButtonStyle())
                Button("Continue") { appState.createWorld() }.buttonStyle(PrimaryButtonStyle())
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { appeared = true } }
    }
}

struct RadioTab: View {
    let station: RadioStation
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: station.icon).font(.system(size: 10))
                Text(station.name).font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.14) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct RadioVisualizer: View {
    let isPlaying: Bool
    @State private var heights: [CGFloat] = Array(repeating: 0.15, count: 36)
    let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.orange.opacity(0.65))
                    .frame(width: 3, height: isPlaying ? max(4, h * 36) : 4)
                    .animation(.easeInOut(duration: 0.12), value: h)
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            heights = (0..<36).map { _ in CGFloat.random(in: 0.1...1.0) }
        }
    }
}
