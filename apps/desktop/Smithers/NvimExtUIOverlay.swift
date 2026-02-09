import SwiftUI

struct NvimExtUIOverlay: View {
    @ObservedObject var workspace: WorkspaceState

    var body: some View {
        GeometryReader { proxy in
            if let layout = NvimGridLayout(metrics: workspace.nvimGridMetrics, containerSize: proxy.size) {
                ZStack(alignment: .topLeading) {
                    NvimMessagesOverlayView(
                        messages: workspace.nvimMessages,
                        miniState: workspace.nvimMiniMessageState,
                        theme: workspace.preferences.theme,
                        cellSize: layout.cellSize,
                        gridSize: layout.gridSize
                    )
                    .frame(width: layout.gridSize.width, height: layout.gridSize.height)

                    if workspace.nvimCmdlineState.isVisible {
                        VStack {
                            Spacer()
                            HStack {
                                NvimCmdlineView(
                                    state: workspace.nvimCmdlineState,
                                    theme: workspace.preferences.theme,
                                    cellSize: layout.cellSize
                                )
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.bottom, 6)
                        }
                        .frame(width: layout.gridSize.width, height: layout.gridSize.height)
                        .zIndex(2)
                    }

                    if workspace.nvimPopupMenuState.isVisible, !workspace.nvimPopupMenuState.items.isEmpty {
                        NvimPopupMenuView(
                            state: workspace.nvimPopupMenuState,
                            theme: workspace.preferences.theme,
                            cellSize: layout.cellSize,
                            gridSize: layout.gridSize,
                            cmdlineHeight: cmdlineHeight(cellHeight: layout.cellSize.height)
                        )
                        .zIndex(3)
                    }
                }
                .frame(width: layout.gridSize.width, height: layout.gridSize.height, alignment: .topLeading)
                .offset(x: layout.origin.x, y: layout.origin.y)
            }
        }
        .accessibilityHidden(true)
    }

    private func cmdlineHeight(cellHeight: CGFloat) -> CGFloat {
        let contentHeight = max(cellHeight, 14)
        return contentHeight + 12
    }
}

private struct NvimGridLayout {
    let metrics: GhosttyGridMetrics
    let containerSize: CGSize

    var cellSize: CGSize {
        metrics.cellSize
    }

    var gridSize: CGSize {
        CGSize(
            width: CGFloat(metrics.columns) * metrics.cellSize.width,
            height: CGFloat(metrics.rows) * metrics.cellSize.height
        )
    }

    var origin: CGPoint {
        let height = gridSize.height
        let top = containerSize.height - metrics.origin.y - height
        return CGPoint(x: metrics.origin.x, y: max(0, top))
    }

    init?(metrics: GhosttyGridMetrics?, containerSize: CGSize) {
        guard let metrics else { return nil }
        guard metrics.columns > 0, metrics.rows > 0 else { return nil }
        self.metrics = metrics
        self.containerSize = containerSize
    }
}

private struct NvimCmdlineView: View {
    let state: NvimCmdlineState
    let theme: AppTheme
    let cellSize: CGSize

    var body: some View {
        let text = cmdlineText()
        let fontSize = max(12, cellSize.height * 0.75)
        HStack(spacing: 8) {
            if !state.firstc.isEmpty {
                Text(state.firstc)
                    .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.accentColor)
            }
            Text(text)
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.foregroundColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.panelBackgroundColor.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.panelBorderColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private func cmdlineText() -> String {
        let display = state.displayText
        let cursorBase = max(0, state.indent + state.prompt.count)
        let cursorPos = min(max(0, state.cursorPos + cursorBase), display.count)
        return insertCursor(in: display, position: cursorPos)
    }

    private func insertCursor(in text: String, position: Int) -> String {
        let safePos = min(max(0, position), text.count)
        let index = text.index(text.startIndex, offsetBy: safePos)
        return String(text[..<index]) + "|" + String(text[index...])
    }
}

private struct NvimPopupMenuView: View {
    let state: NvimPopupMenuState
    let theme: AppTheme
    let cellSize: CGSize
    let gridSize: CGSize
    let cmdlineHeight: CGFloat

    var body: some View {
        let layout = PopupMenuLayout(state: state, cellSize: cellSize, gridSize: gridSize, cmdlineHeight: cmdlineHeight)
        if layout.menuSize.width <= 0 || layout.menuSize.height <= 0 {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: layout.docSpacing) {
                if layout.showsDocs && layout.docsOnLeft {
                    docsPanel(layout: layout)
                }
                menuPanel(layout: layout)
                if layout.showsDocs && !layout.docsOnLeft {
                    docsPanel(layout: layout)
                }
            }
            .frame(width: layout.totalSize.width, height: layout.totalSize.height, alignment: .topLeading)
            .offset(x: layout.origin.x, y: layout.origin.y)
        }
    }

    private func menuPanel(layout: PopupMenuLayout) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(state.items.enumerated()), id: \.offset) { index, item in
                        popupRow(item: item, isSelected: index == state.selected, layout: layout)
                            .id(index)
                    }
                }
                .padding(.vertical, layout.menuPaddingY)
            }
            .frame(width: layout.menuSize.width, height: layout.menuSize.height, alignment: .topLeading)
            .background(theme.panelBackgroundColor.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.panelBorderColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onChange(of: state.selected) { _, newValue in
                guard newValue >= 0 else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func popupRow(item: NvimPopupMenuItem, isSelected: Bool, layout: PopupMenuLayout) -> some View {
        let fontSize = max(12, cellSize.height * 0.7)
        let rowBackground = isSelected ? theme.accentColor.opacity(0.85) : Color.clear
        let textColor = isSelected ? theme.tabSelectedForegroundColor : theme.foregroundColor
        return HStack(spacing: layout.columnSpacing) {
            Text(item.word)
                .frame(width: layout.wordWidth, alignment: .leading)
            if layout.kindWidth > 0 {
                Text(item.kind)
                    .frame(width: layout.kindWidth, alignment: .leading)
                    .foregroundStyle(isSelected ? textColor : theme.mutedForegroundColor)
            }
            if layout.menuWidth > 0 {
                Text(item.menu)
                    .frame(width: layout.menuWidth, alignment: .leading)
                    .foregroundStyle(isSelected ? textColor : theme.mutedForegroundColor)
            }
        }
        .font(.system(size: fontSize, weight: .regular, design: .monospaced))
        .foregroundStyle(textColor)
        .lineLimit(1)
        .frame(height: layout.rowHeight, alignment: .leading)
        .padding(.horizontal, layout.menuPaddingX)
        .background(rowBackground)
    }

    private func docsPanel(layout: PopupMenuLayout) -> some View {
        let info = state.selectedItem?.info ?? ""
        let fontSize = max(12, cellSize.height * 0.7)
        return ScrollView(.vertical) {
            Text(info)
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.menuPaddingX)
                .padding(.vertical, layout.menuPaddingY)
        }
        .frame(width: layout.docSize.width, height: layout.docSize.height, alignment: .topLeading)
        .background(theme.panelBackgroundColor.opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.panelBorderColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private struct PopupMenuLayout {
        let origin: CGPoint
        let menuSize: CGSize
        let docSize: CGSize
        let rowHeight: CGFloat
        let menuPaddingX: CGFloat
        let menuPaddingY: CGFloat
        let columnSpacing: CGFloat
        let wordWidth: CGFloat
        let kindWidth: CGFloat
        let menuWidth: CGFloat
        let showsDocs: Bool
        let docsOnLeft: Bool
        let docSpacing: CGFloat

        var totalSize: CGSize {
            let width = menuSize.width + (showsDocs ? docSize.width + docSpacing : 0)
            let height = max(menuSize.height, docSize.height)
            return CGSize(width: width, height: height)
        }

        init(state: NvimPopupMenuState, cellSize: CGSize, gridSize: CGSize, cmdlineHeight: CGFloat) {
            let rowHeight = max(cellSize.height, 16)
            let paddingX: CGFloat = 8
            let paddingY: CGFloat = 4
            let spacing: CGFloat = 12
            let docSpacing: CGFloat = 8

            let wordMax = state.items.map { $0.word.count }.max() ?? 0
            let kindMax = state.items.map { $0.kind.count }.max() ?? 0
            let menuMax = state.items.map { $0.menu.count }.max() ?? 0

            let charWidth = max(cellSize.width, 6)
            let wordWidth = CGFloat(wordMax) * charWidth
            let kindWidth = CGFloat(kindMax) * charWidth
            let menuWidth = CGFloat(menuMax) * charWidth

            var contentWidth = wordWidth
            if kindMax > 0 {
                contentWidth += spacing + kindWidth
            }
            if menuMax > 0 {
                contentWidth += spacing + menuWidth
            }
            contentWidth = max(contentWidth, charWidth * 8)

            let visibleCount = min(max(state.items.count, 1), 10)
            let menuHeight = CGFloat(visibleCount) * rowHeight + paddingY * 2
            let menuWidthTotal = contentWidth + paddingX * 2

            let info = state.selectedItem?.info.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let showsDocs = !info.isEmpty
            let docWidth = showsDocs ? min(max(220, gridSize.width * 0.28), 360) : 0
            let infoLines = max(1, info.split(separator: "\n", omittingEmptySubsequences: false).count)
            let docHeight = showsDocs
                ? min(max(menuHeight, CGFloat(infoLines) * rowHeight + paddingY * 2), gridSize.height * 0.6)
                : 0

            let totalWidth = menuWidthTotal + (showsDocs ? docWidth + docSpacing : 0)
            let totalHeight = max(menuHeight, docHeight)

            let baseX = max(0, CGFloat(state.col) * cellSize.width)
            let baseY = state.row < 0
                ? max(0, gridSize.height - cmdlineHeight - totalHeight - 4)
                : max(0, CGFloat(state.row) * cellSize.height)

            let docsOnLeft = showsDocs && baseX + totalWidth > gridSize.width && baseX - (docWidth + docSpacing) >= 0
            var originX = docsOnLeft ? baseX - (docWidth + docSpacing) : baseX
            var originY = baseY

            if originX + totalWidth > gridSize.width {
                originX = max(0, gridSize.width - totalWidth)
            }
            if originY + totalHeight > gridSize.height {
                let flipped = baseY - totalHeight
                if flipped >= 0 {
                    originY = flipped
                } else {
                    originY = max(0, gridSize.height - totalHeight)
                }
            }

            self.origin = CGPoint(x: originX, y: originY)
            self.menuSize = CGSize(width: menuWidthTotal, height: menuHeight)
            self.docSize = CGSize(width: docWidth, height: docHeight)
            self.rowHeight = rowHeight
            self.menuPaddingX = paddingX
            self.menuPaddingY = paddingY
            self.columnSpacing = spacing
            self.wordWidth = wordWidth
            self.kindWidth = kindWidth
            self.menuWidth = menuWidth
            self.showsDocs = showsDocs
            self.docsOnLeft = docsOnLeft
            self.docSpacing = docSpacing
        }
    }
}

private struct NvimMessagesOverlayView: View {
    let messages: [NvimMessage]
    let miniState: NvimMiniMessageState
    let theme: AppTheme
    let cellSize: CGSize
    let gridSize: CGSize

    var body: some View {
        ZStack {
            if !messages.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            ForEach(messages) { message in
                                messageBubble(message)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }

            if !miniTextLeading.isEmpty || !miniTextTrailing.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Text(miniTextLeading)
                            .lineLimit(1)
                        Spacer()
                        Text(miniTextTrailing)
                            .lineLimit(1)
                    }
                    .font(.system(size: max(11, cellSize.height * 0.65), weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.foregroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.panelBackgroundColor.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.bottom, 4)
                    .padding(.horizontal, 6)
                }
            }
        }
        .frame(width: gridSize.width, height: gridSize.height)
    }

    private var miniTextLeading: String {
        [miniState.showMode, miniState.status]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    private var miniTextTrailing: String {
        [miniState.showCmd, miniState.ruler]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    private func messageBubble(_ message: NvimMessage) -> some View {
        let fontSize = max(12, cellSize.height * 0.7)
        return Text(message.text)
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.panelBackgroundColor.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.panelBorderColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: gridSize.width * 0.55, alignment: .leading)
    }
}
