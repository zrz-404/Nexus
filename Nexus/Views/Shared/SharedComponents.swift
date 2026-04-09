//
//  SharedComponents.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

// MARK: - Text Field
struct NexusTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "text.cursor"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
}

// MARK: - Buttons
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.72 : 0.88) : 0.25)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule()
                .fill(Color.white.opacity(configuration.isPressed ? 0.07 : 0.04))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Glass panel
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 14
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
    }
}

// MARK: - Canvas dot grid (used by graph, canvas, mindmap views)
struct CanvasGrid: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                let step: CGFloat = 24
                let dot = Color.white.opacity(0.045)
                var col: CGFloat = 0
                while col <= size.width {
                    var row: CGFloat = 0
                    while row <= size.height {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: col - 0.8, y: row - 0.8, width: 1.6, height: 1.6)),
                            with: .color(dot)
                        )
                        row += step
                    }
                    col += step
                }
            }
        }
        .ignoresSafeArea()
    }
}
