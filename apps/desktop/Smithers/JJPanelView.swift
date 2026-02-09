import AppKit
import SwiftUI

// MARK: - Main JJ Panel

struct JJPanelView: View {
    @ObservedObject var workspace: WorkspaceState

    var body: some View {
        let theme = workspace.preferences.theme
        VStack(spacing: 0) {
            panelHeader(theme: theme)
            Divider().background(theme.dividerColor)

            if let jjService = workspace.jjService, jjService.isAvailable {
                ScrollView {
                    VStack(spacing: 0) {
                        workingCopySection(theme: theme)
                        Divider().background(theme.dividerColor)
                        changeLogSection(theme: theme)
                        Divider().background(theme.dividerColor)
                        bookmarksSection(theme: theme)
                        if !workspace.jjOperations.isEmpty {
                            Divider().background(theme.dividerColor)
                            operationLogSection(theme: theme)
                        }
                    }
                }
            } else {
                noVCSView(theme: theme)
            }
        }
        .background(theme.secondaryBackgroundColor)
    }

    // MARK: - Header

    private func panelHeader(theme: AppTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: Typography.base, weight: .semibold))
                .foregroundStyle(theme.foregroundColor)
            Text("Source Control")
                .font(.system(size: Typography.base, weight: .semibold))
                .foregroundStyle(theme.foregroundColor)
            Spacer()
            Button {
                Task { await workspace.refreshJJStatus() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Working Copy Section

    @ViewBuilder
    private func workingCopySection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Working Copy (@)", theme: theme)

            if workspace.jjModifiedFiles.isEmpty {
                Text("No changes")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(workspace.jjModifiedFiles) { file in
                    JJFileRow(file: file, theme: theme) {
                        workspace.openJJDiff(for: file)
                    }
                    .contextMenu {
                        Button("Open File") {
                            workspace.openFileFromJJPanel(file.path)
                        }
                        Button("View Diff") {
                            workspace.openJJDiff(for: file)
                        }
                        Divider()
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(file.path, forType: .string)
                        }
                        Divider()
                        Button("Revert File", role: .destructive) {
                            Task {
                                await workspace.revertJJFile(file.path)
                            }
                        }
                    }
                }
            }

            // Conflict warning
            if !workspace.jjConflicts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(workspace.jjConflicts.count) conflict(s)")
                        .font(.system(size: Typography.s, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button("Describe") {
                    workspace.showJJDescribePrompt()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Commit") {
                    Task { await workspace.jjCommit() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("New") {
                    Task { await workspace.jjNewChange() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Change Log Section

    @ViewBuilder
    private func changeLogSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Change Log", theme: theme)

            if workspace.jjChangeLog.isEmpty {
                Text("No changes")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(workspace.jjChangeLog) { change in
                    JJChangeRow(change: change, theme: theme) {
                        Task { await workspace.openJJChangeDiff(change) }
                    }
                    .contextMenu {
                        Button("View Diff") {
                            Task { await workspace.openJJChangeDiff(change) }
                        }
                        Button("Describe...") {
                            workspace.showJJDescribePromptForChange(change)
                        }
                        Divider()
                        Button("Squash into Parent") {
                            Task {
                                try? await workspace.jjService?.squash(revision: change.changeId)
                                await workspace.refreshJJStatus()
                            }
                        }
                        Button("Create Bookmark...") {
                            workspace.showJJBookmarkPrompt(for: change)
                        }
                        Divider()
                        Button("Abandon", role: .destructive) {
                            Task {
                                try? await workspace.jjService?.abandon(revision: change.changeId)
                                await workspace.refreshJJStatus()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bookmarks Section

    @ViewBuilder
    private func bookmarksSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("Bookmarks", theme: theme)
                Spacer()
                HStack(spacing: 4) {
                    Button {
                        Task {
                            try? await workspace.jjService?.gitFetch()
                            await workspace.refreshJJStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: Typography.xs))
                    }
                    .buttonStyle(.plain)
                    .help("Fetch")

                    Button {
                        Task {
                            try? await workspace.jjService?.gitPush(allTracked: true)
                            await workspace.refreshJJStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: Typography.xs))
                    }
                    .buttonStyle(.plain)
                    .help("Push")
                }
                .padding(.trailing, 12)
            }

            if workspace.jjBookmarks.isEmpty {
                Text("No bookmarks")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(workspace.jjBookmarks) { bookmark in
                    JJBookmarkRow(bookmark: bookmark, theme: theme)
                        .contextMenu {
                            Button("Push") {
                                Task {
                                    try? await workspace.jjService?.gitPush(bookmark: bookmark.name)
                                    await workspace.refreshJJStatus()
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                // bookmark delete not in spec but useful
                            }
                        }
                }
            }
        }
    }

    // MARK: - Operation Log Section

    @ViewBuilder
    private func operationLogSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Operations", theme: theme)

            ForEach(workspace.jjOperations.prefix(10)) { op in
                JJOperationRow(operation: op, theme: theme)
                    .contextMenu {
                        Button("Restore to this state") {
                            Task {
                                try? await workspace.jjService?.opRestore(operationId: op.operationId)
                                await workspace.refreshJJStatus()
                            }
                        }
                    }
            }
        }
    }

    // MARK: - No VCS View

    private func noVCSView(theme: AppTheme) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32))
                .foregroundStyle(theme.mutedForegroundColor)

            if workspace.jjService?.detectedVCSType == .gitOnly {
                Text("Git repository detected")
                    .font(.system(size: Typography.base))
                    .foregroundStyle(theme.foregroundColor)
                Text("Initialize jj for enhanced version control?")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
                Button("Initialize jj (colocated)") {
                    Task { await workspace.initJJRepo() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("No version control")
                    .font(.system(size: Typography.base))
                    .foregroundStyle(theme.foregroundColor)
                Text("Open a jj repository to see source control")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.mutedForegroundColor)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, theme: AppTheme) -> some View {
        Text(title)
            .font(.system(size: Typography.s, weight: .semibold))
            .foregroundStyle(theme.mutedForegroundColor)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Row Views

private struct JJFileRow: View {
    let file: JJFileDiff
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(file.status.rawValue)
                    .font(.system(size: Typography.s, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .frame(width: 16)

                Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                    .font(.system(size: Typography.s, design: .monospaced))
                    .foregroundStyle(theme.foregroundColor)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(parentPath(file.path))
                    .font(.system(size: Typography.xs))
                    .foregroundStyle(theme.mutedForegroundColor)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch file.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        }
    }

    private func parentPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/")
        }
        return ""
    }
}

private struct JJChangeRow: View {
    let change: JJChange
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                // Graph marker
                if change.isWorkingCopy {
                    Image(systemName: "circlebadge.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                        .frame(width: 12)
                        .padding(.top, 4)
                } else {
                    Image(systemName: "circlebadge")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.mutedForegroundColor)
                        .frame(width: 12)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(change.shortChangeId)
                            .font(.system(size: Typography.s, weight: .medium, design: .monospaced))
                            .foregroundStyle(change.isWorkingCopy ? .green : theme.accentColor)

                        if isAIGenerated(change) {
                            Image(systemName: "sparkles")
                                .font(.system(size: Typography.xs))
                                .foregroundStyle(.purple)
                        }

                        if !change.bookmarks.isEmpty {
                            ForEach(change.bookmarks, id: \.self) { bookmark in
                                Text(bookmark)
                                    .font(.system(size: Typography.xs, weight: .medium))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(theme.accentColor.opacity(0.2))
                                    .cornerRadius(3)
                            }
                        }
                    }

                    Text(change.firstLine.isEmpty ? "(no description)" : change.firstLine)
                        .font(.system(size: Typography.s))
                        .foregroundStyle(change.firstLine.isEmpty ? theme.mutedForegroundColor : theme.foregroundColor)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(change.authorName)
                            .font(.system(size: Typography.xs))
                            .foregroundStyle(theme.mutedForegroundColor)
                        Text(relativeTime(change.timestamp))
                            .font(.system(size: Typography.xs))
                            .foregroundStyle(theme.mutedForegroundColor)
                    }
                }

                Spacer()

                if change.isEmpty {
                    Text("empty")
                        .font(.system(size: Typography.xs))
                        .foregroundStyle(theme.mutedForegroundColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.mutedForegroundColor.opacity(0.1))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isAIGenerated(_ change: JJChange) -> Bool {
        change.description.hasPrefix("ai:") || change.description.hasPrefix("ai ")
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct JJBookmarkRow: View {
    let bookmark: JJBookmark
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: Typography.xs))
                .foregroundStyle(theme.accentColor)
                .frame(width: 12)

            Text(bookmark.name)
                .font(.system(size: Typography.s, weight: .medium))
                .foregroundStyle(theme.foregroundColor)

            Spacer()

            Text(bookmark.changeId)
                .font(.system(size: Typography.xs, design: .monospaced))
                .foregroundStyle(theme.mutedForegroundColor)

            if bookmark.isTracking {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: Typography.xs))
                    .foregroundStyle(theme.mutedForegroundColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

private struct JJOperationRow: View {
    let operation: JJOperation
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: Typography.xs))
                .foregroundStyle(theme.mutedForegroundColor)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(operation.description)
                    .font(.system(size: Typography.s))
                    .foregroundStyle(theme.foregroundColor)
                    .lineLimit(1)

                Text(relativeTime(operation.timestamp))
                    .font(.system(size: Typography.xs))
                    .foregroundStyle(theme.mutedForegroundColor)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Snapshot Browser

struct JJSnapshotBrowserView: View {
    @ObservedObject var workspace: WorkspaceState

    var body: some View {
        let theme = workspace.preferences.theme
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(theme.foregroundColor)
                Text("Snapshot Timeline")
                    .font(.system(size: Typography.base, weight: .semibold))
                    .foregroundStyle(theme.foregroundColor)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().background(theme.dividerColor)

            if workspace.jjSnapshots.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.mutedForegroundColor)
                    Text("No snapshots yet")
                        .foregroundStyle(theme.mutedForegroundColor)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(workspace.jjSnapshots) { snapshot in
                            JJSnapshotRow(snapshot: snapshot, workspace: workspace, theme: theme)
                            Divider().background(theme.dividerColor)
                        }
                    }
                }
            }
        }
        .background(theme.secondaryBackgroundColor)
    }
}

private struct JJSnapshotRow: View {
    let snapshot: Snapshot
    let workspace: WorkspaceState
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                snapshotTypeIcon
                Text(snapshot.description)
                    .font(.system(size: Typography.s, weight: .medium))
                    .foregroundStyle(theme.foregroundColor)
                    .lineLimit(1)
                Spacer()
                Text(timeString)
                    .font(.system(size: Typography.xs))
                    .foregroundStyle(theme.mutedForegroundColor)
            }

            if snapshot.chatSessionId != nil {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: Typography.xs))
                        .foregroundStyle(.purple)
                    Text("AI-generated")
                        .font(.system(size: Typography.xs))
                        .foregroundStyle(.purple)
                }
            }

            HStack(spacing: 8) {
                Button("Revert") {
                    Task { await workspace.revertToSnapshot(snapshot) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button("View Diff") {
                    Task { await workspace.viewSnapshotDiff(snapshot) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                if snapshot.chatSessionId != nil {
                    Button("Chat") {
                        workspace.navigateToSnapshotChat(snapshot)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var snapshotTypeIcon: some View {
        switch snapshot.snapshotType {
        case .aiChange:
            Image(systemName: "sparkles")
                .font(.system(size: Typography.s))
                .foregroundStyle(.purple)
        case .userSave:
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: Typography.s))
                .foregroundStyle(.blue)
        case .manualCommit:
            Image(systemName: "checkmark.circle")
                .font(.system(size: Typography.s))
                .foregroundStyle(.green)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: snapshot.createdAt)
    }
}
