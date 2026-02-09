import SwiftUI

struct FileTreeSidebar: View {
    @ObservedObject var workspace: WorkspaceState

    var body: some View {
        let theme = workspace.theme
        let topInset: CGFloat = 38
        Group {
            if workspace.fileTree.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: Typography.iconL))
                        .foregroundStyle(.secondary)
                    Text("No Folder Open")
                        .font(.system(size: Typography.l, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("NoFolderLabel")
                    Button {
                        workspace.openFolderPanel()
                    } label: {
                        Text("Open Folder...")
                            .frame(minWidth: 120)
                    }
                    .controlSize(.large)
                    .accessibilityIdentifier("OpenFolderButton")
                    Text("⌘⇧O")
                        .font(.system(size: Typography.s))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.secondaryBackgroundColor)
            } else {
                List(selection: $workspace.selectedFileURL) {
                    Section(workspace.rootDirectory?.lastPathComponent ?? "Files") {
                        ForEach(workspace.fileTree) { item in
                            FileTreeRow(item: item, workspace: workspace, level: 0)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(theme.secondaryBackgroundColor)
                .accessibilityIdentifier("FileTreeList")
                .onChange(of: workspace.selectedFileURL) { _, newValue in
                    if let url = newValue {
                        workspace.selectFile(url)
                    }
                }
            }
        }
        .padding(.top, topInset)
    }
}


struct FileTreeRow: View {
    let item: FileItem
    @ObservedObject var workspace: WorkspaceState
    let level: Int
    @State private var isExpanded = false
    @State private var isHovered = false
    private let indentWidth: CGFloat = 16

    var body: some View {
        if item.isFolder {
            folderRow
        } else {
            rowChrome {
                fileLabel
            }
            .contextMenu { fileContextMenu }
                .tag(item.id)
                .accessibilityIdentifier("FileTreeItem_\(item.name)")
        }
    }

    @ViewBuilder
    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowChrome {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Typography.s, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                        .frame(width: 20, height: 20)
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundStyle(.blue)
                        .font(.system(size: Typography.base))
                    Text(item.name)
                        .font(.system(size: Typography.base))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .background(isHovered ? workspace.theme.selectionBackgroundColor.opacity(0.3) : Color.clear)
                .onTapGesture {
                    if !isExpanded {
                        workspace.expandFolder(item)
                    }
                    isExpanded.toggle()
                }
                .onHover { isHovered = $0 }
                .accessibilityIdentifier("FileTreeItem_\(item.name)")
            }
            .contextMenu { folderContextMenu }

            if isExpanded, let children = item.children {
                let visibleChildren = children.filter { !$0.isLazyPlaceholder }
                ForEach(visibleChildren) { child in
                    FileTreeRow(item: child, workspace: workspace, level: level + 1)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var fileLabel: some View {
        let isModified = workspace.isFileModified(item.id)
        let dotColor = workspace.selectedFileURL == item.id
            ? workspace.theme.tabSelectedForegroundColor
            : workspace.theme.accentColor

        return HStack(spacing: 6) {
            Image(systemName: iconForFile(item.name))
                .foregroundStyle(colorForFile(item.name)?.opacity(0.8) ?? .secondary)
                .font(.system(size: Typography.base))
            Text(item.name)
                .font(.system(size: Typography.base))
                .lineLimit(1)
                .truncationMode(.middle)
            if isModified {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Unsaved changes")
            }
            Spacer()
        }
    }

    private var fileContextMenu: some View {
        Group {
            Button("Copy Path") { workspace.copyFilePath(item.id) }
            Button("Copy Relative Path") { workspace.copyRelativeFilePath(item.id) }
            Divider()
            Button("Reveal in Finder") { workspace.revealInFinder(item.id) }
            Button("Open in Terminal") { workspace.openInTerminal(item.id) }
            Divider()
            Button("Rename...") { workspace.renameItem(item) }
            Button("Delete", role: .destructive) { workspace.deleteItem(item) }
        }
    }

    private var folderContextMenu: some View {
        Group {
            Button("New File") { workspace.createFile(in: item.id) }
            Button("New Folder") { workspace.createFolder(in: item.id) }
            Divider()
            Button("Copy Path") { workspace.copyFilePath(item.id) }
            Button("Copy Relative Path") { workspace.copyRelativeFilePath(item.id) }
            Divider()
            Button("Reveal in Finder") { workspace.revealInFinder(item.id) }
            Button("Open in Terminal") { workspace.openInTerminal(item.id) }
            Divider()
            Button("Rename...") { workspace.renameItem(item) }
            Button("Delete", role: .destructive) { workspace.deleteItem(item) }
        }
    }

    private var rowIndent: CGFloat {
        CGFloat(level) * indentWidth
    }

    @ViewBuilder
    private func rowChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.leading, rowIndent)
            .background(alignment: .leading) {
                if level > 0 {
                    IndentGuides(
                        level: level,
                        indent: indentWidth,
                        color: workspace.theme.dividerColor.opacity(0.35)
                    )
                }
            }
    }
}

private struct IndentGuides: View {
    let level: Int
    let indent: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                for index in 0..<level {
                    let x = indent * CGFloat(index) + (indent / 2)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(color, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
