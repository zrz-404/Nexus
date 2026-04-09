//
//  SidebarView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var search = ""

    private var theme: AppTheme { themeManager.current }

    var rootDocuments: [StudyDocument] {
        appState.documents
            .filter { $0.parentId == nil }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // World header
            HStack(spacing: 8) {
                if let world = appState.currentWorld {
                    ZStack {
                        Circle().fill(theme.accentSoft).frame(width: 26, height: 26)
                        Text(String(world.name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }
                    Text(world.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                SidebarIconBtn(icon: "slider.horizontal.3") {}
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            // Search
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11)).foregroundColor(theme.textTertiary)
                TextField("Search...", text: $search)
                    .textFieldStyle(.plain).font(.system(size: 11))
                    .foregroundColor(theme.textPrimary)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11)).foregroundColor(theme.textTertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.border, lineWidth: 1))
            )
            .padding(.horizontal, 10).padding(.bottom, 8)

            // File tree — List gives free drag reorder
            List {
                Section {
                    ForEach(search.isEmpty ? appState.documents.filter { $0.parentId == nil } : rootDocuments) { doc in
                        SidebarRow(document: doc)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    }
                    .onMove(perform: appState.moveDocuments)
                } header: {
                    Text("DOCUMENTS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textTertiary)
                        .tracking(0.8)
                        .padding(.leading, 2)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
//            .environment(\.editMode, .constant(.active)) // enables drag reorder always

            Spacer(minLength: 0)

            // New document
            Button {
                appState.createDocument(title: "Untitled Card", type: .card)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                    Text("New Document").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.border).frame(height: 1)
            }
        }
    }
}

// MARK: - Row
struct SidebarRow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }
    var docType: DocumentType { DocumentType(rawValue: document.type) ?? .card }

    var body: some View {
        Button { appState.openDocument(document) } label: {
            HStack(spacing: 7) {
                Image(systemName: docType.icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 14)
                Text(document.title)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered ? theme.panelSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                hovered = isHovered
            }
        }
        // Right-click delete
        .contextMenu {
            Button(role: .destructive) {
                appState.deleteDocument(id: document.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                appState.openDocument(document)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
        }
        // Drag to workspace
        //        .onDrag {
        //            NSItemProvider(object: document.id.uuidString as NSString)
        .draggable(document.id.uuidString)
        }
    }


// MARK: - Icon button
struct SidebarIconBtn: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String; let action: () -> Void
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? theme.panelSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
