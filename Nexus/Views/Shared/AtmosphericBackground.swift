//
//  AtmosphericBackground.swift
//  Nexus - Phase 5
//

import SwiftUI

struct AtmosphericBackgroundView: View {
    let accentColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep space background
                Color.black
                
                // Gradient overlay
                RadialGradient(
                    colors: [
                        accentColor.opacity(0.15),
                        Color.black.opacity(0.8),
                        Color.black
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.8
                )
                
                // Subtle noise texture
                Color.white.opacity(0.02)
                    .blendMode(.overlay)
            }
        }
        .ignoresSafeArea()
    }
}
