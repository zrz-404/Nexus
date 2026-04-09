//
//  GlassPanel.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI
import AppKit

import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// The glass surface: blur layer + thin colour tint
struct GlassBackground: View {
    let tint: Color
    let opacity: Double
    var brightnessBoost: Double = 0.0
    var material: NSVisualEffectView.Material = .hudWindow

    var body: some View {
        ZStack {
            // 1. Desktop blur
            VisualEffectView(material: material, blendingMode: .behindWindow)

            // 2. White lift — only active on light themes
            if brightnessBoost > 0 {
                Rectangle().fill(Color.white.opacity(brightnessBoost))
            }

            // 3. Colour tint on top
            Rectangle().fill(tint.opacity(opacity))
        }
    }
}

extension View {
    func glassBackground(
        tint: Color,
        opacity: Double,
        cornerRadius: CGFloat = 0
    ) -> some View {
        background(
            GlassBackground(tint: tint, opacity: opacity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
    }
}
