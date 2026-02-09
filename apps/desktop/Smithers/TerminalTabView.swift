import SwiftUI

struct TerminalTabView: NSViewRepresentable {
    let view: GhosttyTerminalView
    var scrollbarMode: ScrollbarVisibilityMode = .automatic
    var scrollbarMetrics: ScrollbarMetrics?
    var theme: AppTheme = .default
    var onScrollToOffset: ((CGFloat) -> Void)?
    var onPageScroll: ((Int) -> Void)?

    func makeNSView(context: Context) -> ScrollbarHostingView {
        let scrollbarView = ScrollbarOverlayView()
        scrollbarView.showMode = scrollbarMode
        scrollbarView.theme = theme
        scrollbarView.updateMetrics(scrollbarMetrics)
        scrollbarView.onScrollToOffset = onScrollToOffset
        scrollbarView.onPageScroll = onPageScroll
        view.onScrollActivity = { [weak scrollbarView] in
            scrollbarView?.notifyScrollActivity()
        }
        return ScrollbarHostingView(contentView: view, scrollbarView: scrollbarView)
    }

    func updateNSView(_ containerView: ScrollbarHostingView, context: Context) {
        let scrollbarView = containerView.scrollbarView
        let previousMetrics = scrollbarView.metrics
        scrollbarView.showMode = scrollbarMode
        scrollbarView.theme = theme
        scrollbarView.updateMetrics(scrollbarMetrics)
        scrollbarView.onScrollToOffset = onScrollToOffset
        scrollbarView.onPageScroll = onPageScroll
        if scrollbarMetrics != nil, scrollbarMetrics != previousMetrics {
            scrollbarView.notifyScrollActivity()
        }
        view.onScrollActivity = { [weak scrollbarView] in
            scrollbarView?.notifyScrollActivity()
        }
    }
}

struct TerminalTabBarItem: View {
    @ObservedObject var view: GhosttyTerminalView
    let isSelected: Bool
    let theme: AppTheme
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        let title = view.title.isEmpty ? "Terminal" : view.title
        let subtitle = view.pwd ?? "Terminal"
        TabBarItem(
            title: title,
            subtitle: subtitle,
            icon: "terminal",
            isSelected: isSelected,
            isModified: false,
            isDropTarget: false,
            theme: theme,
            onSelect: onSelect,
            onClose: onClose
        )
    }
}
