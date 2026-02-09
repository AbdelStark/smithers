import SwiftUI

struct SkillDetailView: View {
    let skill: SkillItem
    @ObservedObject var workspace: WorkspaceState
    @State private var markdown: String = ""
    @State private var fileTree: [String] = []
    @State private var isLoading = false

    var body: some View {
        let theme = workspace.preferences.theme
        VStack(spacing: 0) {
            header(theme: theme)
            Divider()
                .background(theme.dividerColor)
            content(theme: theme)
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(theme.backgroundColor)
        .onAppear {
            loadDetails()
        }
    }

    private func header(theme: AppTheme) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.system(size: Typography.l, weight: .semibold))
                Text(skill.description)
                    .font(.system(size: Typography.s))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(skill.scope.rawValue)
                    if let license = skill.license { Text(license) }
                    if let installedAt = skill.installedAt {
                        Text("Installed \(installedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.system(size: Typography.xs))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reveal in Finder") {
                workspace.revealInFinder(skill.path)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(theme.secondaryBackgroundColor)
    }

    @ViewBuilder
    private func content(theme: AppTheme) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                if !fileTree.isEmpty {
                    Text("Files")
                        .font(.system(size: Typography.base, weight: .semibold))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(fileTree, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: Typography.s, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 220)
            .padding(12)
            Divider()
                .background(theme.dividerColor)
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading skill...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MarkdownView(text: markdown.isEmpty ? "(No SKILL.md available)" : markdown, theme: theme)
            }
        }
    }

    private func loadDetails() {
        isLoading = true
        Task {
            let skillFile = skill.path.appendingPathComponent("SKILL.md")
            let text = (try? String(contentsOf: skillFile, encoding: .utf8)) ?? ""
            let tree = buildFileTree()
            await MainActor.run {
                markdown = text
                fileTree = tree
                isLoading = false
            }
        }
    }

    private func buildFileTree() -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: skill.path,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var results: [String] = []
        let base = skill.path.standardizedFileURL.path
        for case let url as URL in enumerator {
            let path = url.standardizedFileURL.path
            let relative = path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : url.lastPathComponent
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            results.append(isDir ? "\(relative)/" : relative)
            if results.count > 200 { break }
        }
        return results.sorted()
    }
}
