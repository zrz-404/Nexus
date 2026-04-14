//
//  GlassPanel.swift
//  Nexus - Phase 5
//

import SwiftUI

struct GlassPanelView<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}
