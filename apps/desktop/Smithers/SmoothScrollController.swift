import AppKit
import QuartzCore

@MainActor
final class SmoothScrollController {
    enum ScrollDirection {
        case up
        case down

        var nvimAction: String {
            switch self {
            case .up: return "up"
            case .down: return "down"
            }
        }
    }

    struct Config {
        var preciseMultiplier: CGFloat
        var maxPendingScrolls: Int
        var maxScrollsPerEvent: Int
        var maxDiscreteScrolls: Int
        var fastScrollThresholdMultiplier: CGFloat
        var springDamping: CGFloat
        var springStiffness: CGFloat
        var springMass: CGFloat
        var springMaxDuration: CFTimeInterval
        var snapEpsilon: CGFloat
        var stuckResetDelay: TimeInterval

        static let `default` = Config(
            preciseMultiplier: 2.0,
            maxPendingScrolls: 8,
            maxScrollsPerEvent: 3,
            maxDiscreteScrolls: 10,
            fastScrollThresholdMultiplier: 1.25,
            springDamping: 28,
            springStiffness: 220,
            springMass: 1,
            springMaxDuration: 0.22,
            snapEpsilon: 0.5,
            stuckResetDelay: 0.25
        )
    }

    var config: Config
    var scrollSender: ((ScrollDirection, Int64, Int, Int) -> Void)?
    var gridResolver: ((Int, Int) -> (gridId: Int64, row: Int, col: Int))?
    var canScroll: ((ScrollDirection) -> Bool)?

    private weak var terminalView: GhosttyTerminalView?
    private weak var overlayView: NSView?
    private var cellSize: CGSize = .zero
    private var scrollOffset: CGFloat = 0
    private var pendingSentScrolls: Int = 0
    private var pendingResetWorkItem: DispatchWorkItem?
    private var lastAppliedOffset: CGFloat = 0

    init(terminalView: GhosttyTerminalView, config: Config = .default) {
        self.terminalView = terminalView
        self.config = config
    }

    func updateCellSize(_ size: CGSize) {
        cellSize = size
        if size.height <= 0 {
            reset(animated: false)
        }
    }

    func setOverlayView(_ view: NSView?) {
        overlayView = view
    }

    func reset(animated: Bool = false) {
        scrollOffset = 0
        pendingSentScrolls = 0
        cancelPendingReset()
        applyOffset(0, animated: animated)
    }

    func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard let terminalView else { return false }
        guard let metrics = terminalView.gridMetrics() else { return false }
        guard scrollSender != nil else { return false }

        if cellSize.height <= 0 {
            cellSize = metrics.cellSize
        }
        guard cellSize.height > 0 else { return false }

        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX
        guard abs(deltaY) >= abs(deltaX), deltaY != 0 else { return false }

        let rowHeight = max(cellSize.height, 1)
        let baseCell = gridCell(at: terminalView.convert(event.locationInWindow, from: nil), metrics: metrics)
        let resolved = gridResolver?(baseCell.row, baseCell.col) ?? (gridId: 1, row: baseCell.row, col: baseCell.col)
        let direction: ScrollDirection = deltaY > 0 ? .up : .down

        if let canScroll, !canScroll(direction), pendingSentScrolls == 0 {
            reset(animated: true)
            terminalView.onScrollActivity?()
            return true
        }

        if !event.hasPreciseScrollingDeltas || resolved.gridId != 1 {
            handleDiscreteScroll(
                deltaY: deltaY,
                gridId: resolved.gridId,
                row: resolved.row,
                col: resolved.col,
                rowHeight: rowHeight,
                resetOffset: resolved.gridId == 1
            )
            terminalView.onScrollActivity?()
            return true
        }

        let delta = deltaY * config.preciseMultiplier
        let fastThreshold = rowHeight * config.fastScrollThresholdMultiplier
        if abs(delta) >= fastThreshold {
            handleDiscreteScroll(
                deltaY: delta,
                gridId: resolved.gridId,
                row: resolved.row,
                col: resolved.col,
                rowHeight: rowHeight,
                resetOffset: true
            )
            terminalView.onScrollActivity?()
            return true
        }

        scrollOffset += delta
        let maxOffset = rowHeight * CGFloat(config.maxPendingScrolls + 2)
        if scrollOffset > maxOffset {
            scrollOffset = maxOffset
        } else if scrollOffset < -maxOffset {
            scrollOffset = -maxOffset
        }

        var checkOffset = scrollOffset
        var sent = 0
        while abs(checkOffset) >= rowHeight,
              pendingSentScrolls < config.maxPendingScrolls,
              sent < config.maxScrollsPerEvent {
            let scrollDirection: ScrollDirection = checkOffset > 0 ? .up : .down
            if let canScroll, !canScroll(scrollDirection) {
                break
            }
            sendScroll(direction: scrollDirection, gridId: resolved.gridId, row: resolved.row, col: resolved.col)
            pendingSentScrolls += 1
            sent += 1
            checkOffset = checkOffset > 0 ? (checkOffset - rowHeight) : (checkOffset + rowHeight)
        }

        applyOffset(scrollOffset, animated: false)
        schedulePendingResetIfNeeded()
        terminalView.onScrollActivity?()
        return true
    }

    func handleGridScroll(gridId: Int64, rows: Int) {
        guard gridId == 1 else { return }
        guard rows != 0 else { return }
        guard cellSize.height > 0 else { return }

        let rowHeight = cellSize.height
        let rowsAbs = abs(rows)

        if pendingSentScrolls > 0 {
            if rowsAbs >= pendingSentScrolls {
                pendingSentScrolls = 0
                scrollOffset = 0
                cancelPendingReset()
            } else {
                pendingSentScrolls -= rowsAbs
                let previousOffset = scrollOffset
                scrollOffset += CGFloat(rows) * rowHeight
                if scrollOffset.sign != previousOffset.sign {
                    scrollOffset = 0
                }
                if abs(scrollOffset) < config.snapEpsilon {
                    scrollOffset = 0
                }
                if pendingSentScrolls == 0 {
                    cancelPendingReset()
                }
            }
        } else {
            scrollOffset = 0
        }

        applyOffset(scrollOffset, animated: true)
    }

    private func handleDiscreteScroll(
        deltaY: CGFloat,
        gridId: Int64,
        row: Int,
        col: Int,
        rowHeight: CGFloat,
        resetOffset: Bool
    ) {
        let steps = max(1, Int(abs(deltaY / rowHeight).rounded(.toNearestOrAwayFromZero)))
        let count = min(steps, config.maxDiscreteScrolls)
        let direction: ScrollDirection = deltaY > 0 ? .up : .down

        for _ in 0..<count {
            sendScroll(direction: direction, gridId: gridId, row: row, col: col)
        }

        if resetOffset {
            scrollOffset = 0
            pendingSentScrolls = 0
            cancelPendingReset()
            applyOffset(0, animated: true)
        }
    }

    private func sendScroll(direction: ScrollDirection, gridId: Int64, row: Int, col: Int) {
        scrollSender?(direction, gridId, row, col)
    }

    private func gridCell(at point: CGPoint, metrics: GhosttyGridMetrics) -> (row: Int, col: Int) {
        let cellWidth = max(metrics.cellSize.width, 1)
        let cellHeight = max(metrics.cellSize.height, 1)
        let gridWidth = CGFloat(metrics.columns) * cellWidth
        let gridHeight = CGFloat(metrics.rows) * cellHeight

        let x = min(max(point.x - metrics.origin.x, 0), max(gridWidth - 1, 0))
        let y = min(max(point.y - metrics.origin.y, 0), max(gridHeight - 1, 0))

        let col = Int(floor(x / cellWidth))
        let rowFromBottom = Int(floor(y / cellHeight))
        let row = metrics.rows - 1 - rowFromBottom
        return (
            row: min(max(row, 0), max(metrics.rows - 1, 0)),
            col: min(max(col, 0), max(metrics.columns - 1, 0))
        )
    }

    private func schedulePendingResetIfNeeded() {
        guard pendingSentScrolls > 0 else { return }
        pendingResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.pendingSentScrolls > 0 else { return }
            self.scrollOffset = 0
            self.pendingSentScrolls = 0
            self.applyOffset(0, animated: true)
        }
        pendingResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.stuckResetDelay, execute: workItem)
    }

    private func cancelPendingReset() {
        pendingResetWorkItem?.cancel()
        pendingResetWorkItem = nil
    }

    private func applyOffset(_ offset: CGFloat, animated: Bool) {
        if abs(offset - lastAppliedOffset) < 0.01 { return }
        lastAppliedOffset = offset
        let translation = -offset
        applyTranslation(translation, to: terminalView, animated: animated)
        applyTranslation(translation, to: overlayView, animated: animated)
    }

    private func applyTranslation(_ translation: CGFloat, to view: NSView?, animated: Bool) {
        guard let layer = view?.layer else { return }
        let key = "smoothScrollTranslation"

        if animated {
            let current = (layer.presentation()?.value(forKeyPath: "transform.translation.y") as? CGFloat)
                ?? (layer.value(forKeyPath: "transform.translation.y") as? CGFloat)
                ?? 0
            let animation = CASpringAnimation(keyPath: "transform.translation.y")
            animation.fromValue = current
            animation.toValue = translation
            animation.damping = config.springDamping
            animation.stiffness = config.springStiffness
            animation.mass = config.springMass
            animation.initialVelocity = 0
            animation.duration = min(animation.settlingDuration, config.springMaxDuration)
            layer.removeAnimation(forKey: key)
            layer.add(animation, forKey: key)
        } else {
            layer.removeAnimation(forKey: key)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setValue(translation, forKeyPath: "transform.translation.y")
        CATransaction.commit()
    }
}
