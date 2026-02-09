import SwiftUI
import Dispatch
import Foundation

private enum PaletteSelection: Hashable {
    case file(URL)
    case folder(URL)
}

struct CommandPaletteView: View {
    @ObservedObject var workspace: WorkspaceState
    @FocusState private var searchFocused: Bool
    @State private var selectedEntry: PaletteSelection?
    @State private var selectedCommandID: String?

    var body: some View {
        ZStack {
            overlayBackground
            CommandPalettePanel(
                workspace: workspace,
                selectedEntry: $selectedEntry,
                selectedCommandID: $selectedCommandID,
                searchFocused: $searchFocused
            )
        }
        .onExitCommand {
            workspace.hideCommandPalette()
        }
    }

    private var overlayBackground: some View {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
            .onTapGesture {
                workspace.hideCommandPalette()
            }
    }

}

private struct CommandPalettePanel: View {
    @ObservedObject var workspace: WorkspaceState
    @Binding var selectedEntry: PaletteSelection?
    @Binding var selectedCommandID: String?
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        let theme = workspace.theme
        let content = VStack(spacing: 0) {
            header
            Divider()
                .background(theme.dividerColor)
            paletteContent
        }

        let sized = AnyView(
            content
                .frame(width: 560, height: 360)
                .background(theme.panelBackgroundColor)
        )

        let decorated = AnyView(
            sized
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.panelBorderColor)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)
        )

        let panel = decorated
            .onAppear {
                selectedEntry = firstAvailableSelection()
                selectedCommandID = workspace.paletteCommands.first?.id
                DispatchQueue.main.async {
                    searchFocused.wrappedValue = true
                }
            }
            .onChange(of: workspace.fileSearchResults) { _, newValue in
                updateSelectionIfNeeded()
            }
        .onChange(of: workspace.paletteCommands.map(\.id)) { _, newValue in
            if let selectedCommandID, newValue.contains(selectedCommandID) {
                return
            }
            selectedCommandID = newValue.first
        }
        .onChange(of: workspace.recentFileEntries.map(\.url)) { _, _ in
            updateSelectionIfNeeded()
        }
        .onChange(of: workspace.recentFolderEntries.map(\.url)) { _, _ in
            updateSelectionIfNeeded()
        }
        .onChange(of: workspace.fileSearchQuery) { _, _ in
            updateSelectionIfNeeded()
        }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("CommandPaletteOverlay")

        return panel
    }

    private var header: some View {
        HStack(spacing: 10) {
            if workspace.isCommandMode {
                Text(">")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            TextField("Go to File...", text: $workspace.fileSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .focused(searchFocused)
                .accessibilityIdentifier("CommandPaletteSearchField")
                .onSubmit {
                    openSelection()
                }
            Button {
                workspace.hideCommandPalette()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var paletteContent: AnyView {
        if workspace.isCommandMode {
            return AnyView(commandContent)
        }
        return AnyView(fileContent)
    }

    @ViewBuilder
    private var commandContent: some View {
        if workspace.paletteCommands.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("No matching commands")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedCommandID) {
                ForEach(workspace.paletteCommands) { command in
                    HStack(spacing: 8) {
                        Image(systemName: command.icon)
                            .foregroundStyle(.secondary)
                        Text(command.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(command.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        run(command)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("CommandPaletteResults")
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        let showRecents = shouldShowRecents
        let recentFiles = workspace.recentFileEntries
        let recentFolders = workspace.recentFolderEntries
        let fileResults = workspace.fileSearchResults
        let hasResults = !fileResults.isEmpty
        let hasRecents = !recentFiles.isEmpty || !recentFolders.isEmpty
        if !hasResults && !(showRecents && hasRecents) {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("No matching files")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedEntry) {
                if showRecents {
                    if !recentFiles.isEmpty {
                        Section("Recent Files") {
                            ForEach(recentFiles) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: iconForFile(entry.displayPath))
                                        .foregroundStyle(.secondary)
                                    Text(entry.displayPath)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .tag(PaletteSelection.file(entry.url))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    open(.file(entry.url))
                                }
                            }
                        }
                    }
                    if !recentFolders.isEmpty {
                        Section("Recent Folders") {
                            ForEach(recentFolders) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    Text(entry.displayPath)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .tag(PaletteSelection.folder(entry.url))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    open(.folder(entry.url))
                                }
                            }
                        }
                    }
                    if !fileResults.isEmpty {
                        Section("Files") {
                            ForEach(fileResults) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: iconForFile(entry.displayPath))
                                        .foregroundStyle(.secondary)
                                    Text(entry.displayPath)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .tag(PaletteSelection.file(entry.url))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    open(.file(entry.url))
                                }
                            }
                        }
                    }
                } else {
                    ForEach(fileResults) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: iconForFile(entry.displayPath))
                                .foregroundStyle(.secondary)
                            Text(entry.displayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .tag(PaletteSelection.file(entry.url))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            open(.file(entry.url))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("CommandPaletteResults")
        }
    }

    private func openSelection() {
        if workspace.isCommandMode {
            if let selectedCommandID,
               let command = workspace.paletteCommands.first(where: { $0.id == selectedCommandID }) {
                run(command)
                return
            }
            if let first = workspace.paletteCommands.first {
                run(first)
            }
            return
        }
        if let selectedEntry {
            open(selectedEntry)
            return
        }
        if let first = firstAvailableSelection() {
            open(first)
        }
    }

    private func open(_ entry: PaletteSelection) {
        switch entry {
        case .file(let url):
            workspace.selectFile(url)
        case .folder(let url):
            workspace.openDirectory(url)
        }
        workspace.hideCommandPalette()
    }

    private func run(_ command: PaletteCommand) {
        command.action()
        workspace.hideCommandPalette()
    }
}
