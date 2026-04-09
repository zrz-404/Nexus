//
//  GraphModel.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import Foundation
import SwiftUI
import Combine

struct GraphNode: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var type: String
    var x: Double = 0
    var y: Double = 0
    var documentId: UUID? = nil

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
}

struct GraphEdge: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceId: UUID
    var targetId: UUID
}

class GraphViewModel: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []

    func populate(from documents: [StudyDocument]) {
        for doc in documents {
            if !nodes.contains(where: { $0.documentId == doc.id }) {
                nodes.append(GraphNode(title: doc.title, type: doc.type, documentId: doc.id))
            }
        }
        layoutRadial()
    }

    func layoutRadial() {
        guard !nodes.isEmpty else { return }
        let center = CGPoint(x: 500, y: 380)
        nodes[0].position = center
        guard nodes.count > 1 else { return }
        let radius: CGFloat = 220
        for i in 1..<nodes.count {
            let angle = (CGFloat(i - 1) / CGFloat(nodes.count - 1)) * 2 * .pi
            nodes[i].position = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }

    func addNode(title: String, type: DocumentType, at position: CGPoint) {
        var node = GraphNode(title: title, type: type.rawValue)
        node.position = position
        nodes.append(node)
    }

    func addEdge(from sourceId: UUID, to targetId: UUID) {
        guard !edges.contains(where: { $0.sourceId == sourceId && $0.targetId == targetId }) else { return }
        edges.append(GraphEdge(sourceId: sourceId, targetId: targetId))
    }

    func removeNode(_ id: UUID) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.sourceId == id || $0.targetId == id }
    }
}
