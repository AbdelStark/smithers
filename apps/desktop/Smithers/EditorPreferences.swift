import SwiftUI
import AppKit
import Foundation

@MainActor
final class EditorPreferences: ObservableObject {
    var onApplyWindowAppearance: (() -> Void)?
    var onScheduleNvimSettingsSync: (() -> Void)?
    var onUpdateTerminalOptionAsMeta: (() -> Void)?
    var onShowToast: ((String) -> Void)?

    @Published var theme: AppTheme = .default {
        didSet {
            onApplyWindowAppearance?()
        }
    }
    @Published var editorFontName: String = {
        if let value = UserDefaults.standard.string(forKey: EditorPreferences.editorFontNameKey),
           !value.isEmpty {
            return value
        }
        return EditorPreferences.defaultEditorFontName
    }() {
        didSet {
            let normalized = Self.normalizeEditorFontName(editorFontName, size: editorFontSize)
            if normalized != editorFontName {
                editorFontName = normalized
                return
            }
            UserDefaults.standard.set(editorFontName, forKey: Self.editorFontNameKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var editorFontSize: Double = {
        let value = UserDefaults.standard.double(forKey: EditorPreferences.editorFontSizeKey)
        return value > 0 ? value : EditorPreferences.defaultEditorFontSize
    }() {
        didSet {
            let clamped = Self.clampEditorFontSize(editorFontSize)
            if clamped != editorFontSize {
                editorFontSize = clamped
                return
            }
            UserDefaults.standard.set(editorFontSize, forKey: Self.editorFontSizeKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var editorLigaturesEnabled: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.editorLigaturesEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.editorLigaturesEnabledKey)
    }() {
        didSet {
            UserDefaults.standard.set(editorLigaturesEnabled, forKey: Self.editorLigaturesEnabledKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var editorLineSpacing: Double = {
        guard UserDefaults.standard.object(forKey: EditorPreferences.editorLineSpacingKey) != nil else {
            return EditorPreferences.defaultEditorLineSpacing
        }
        let value = UserDefaults.standard.double(forKey: EditorPreferences.editorLineSpacingKey)
        return EditorPreferences.clampEditorLineSpacing(value)
    }() {
        didSet {
            let clamped = Self.clampEditorLineSpacing(editorLineSpacing)
            if clamped != editorLineSpacing {
                editorLineSpacing = clamped
                return
            }
            UserDefaults.standard.set(editorLineSpacing, forKey: Self.editorLineSpacingKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var editorCharacterSpacing: Double = {
        guard UserDefaults.standard.object(forKey: EditorPreferences.editorCharacterSpacingKey) != nil else {
            return EditorPreferences.defaultEditorCharacterSpacing
        }
        let value = UserDefaults.standard.double(forKey: EditorPreferences.editorCharacterSpacingKey)
        return EditorPreferences.clampEditorCharacterSpacing(value)
    }() {
        didSet {
            let clamped = Self.clampEditorCharacterSpacing(editorCharacterSpacing)
            if clamped != editorCharacterSpacing {
                editorCharacterSpacing = clamped
                return
            }
            UserDefaults.standard.set(editorCharacterSpacing, forKey: Self.editorCharacterSpacingKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var preferredNvimPath: String = {
        UserDefaults.standard.string(forKey: EditorPreferences.nvimPathKey) ?? ""
    }() {
        didSet {
            UserDefaults.standard.set(preferredNvimPath, forKey: Self.nvimPathKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var optionAsMeta: OptionAsMeta = {
        if let raw = UserDefaults.standard.string(forKey: EditorPreferences.optionAsMetaKey),
           let value = OptionAsMeta(rawValue: raw) {
            return value
        }
        return .both
    }() {
        didSet {
            UserDefaults.standard.set(optionAsMeta.rawValue, forKey: Self.optionAsMetaKey)
            onUpdateTerminalOptionAsMeta?()
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var scrollbarVisibilityMode: ScrollbarVisibilityMode = {
        if let raw = UserDefaults.standard.string(forKey: EditorPreferences.scrollbarVisibilityModeKey),
           let value = ScrollbarVisibilityMode(rawValue: raw) {
            return value
        }
        return .automatic
    }() {
        didSet {
            UserDefaults.standard.set(scrollbarVisibilityMode.rawValue, forKey: Self.scrollbarVisibilityModeKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var showLineNumbers: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.showLineNumbersKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.showLineNumbersKey)
    }() {
        didSet {
            UserDefaults.standard.set(showLineNumbers, forKey: Self.showLineNumbersKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var highlightCurrentLine: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.highlightCurrentLineKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.highlightCurrentLineKey)
    }() {
        didSet {
            UserDefaults.standard.set(highlightCurrentLine, forKey: Self.highlightCurrentLineKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var showIndentGuides: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.showIndentGuidesKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.showIndentGuidesKey)
    }() {
        didSet {
            UserDefaults.standard.set(showIndentGuides, forKey: Self.showIndentGuidesKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var showMinimap: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.showMinimapKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.showMinimapKey)
    }() {
        didSet {
            UserDefaults.standard.set(showMinimap, forKey: Self.showMinimapKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var nvimFloatingBlurEnabled: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.nvimFloatingBlurEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.nvimFloatingBlurEnabledKey)
    }() {
        didSet {
            UserDefaults.standard.set(nvimFloatingBlurEnabled, forKey: Self.nvimFloatingBlurEnabledKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var nvimFloatingBlurRadius: Double = {
        if UserDefaults.standard.object(forKey: EditorPreferences.nvimFloatingBlurRadiusKey) == nil {
            return EditorPreferences.defaultFloatingBlurRadius
        }
        return UserDefaults.standard.double(forKey: EditorPreferences.nvimFloatingBlurRadiusKey)
    }() {
        didSet {
            let clamped = Self.clampFloatingBlurRadius(nvimFloatingBlurRadius)
            if clamped != nvimFloatingBlurRadius {
                nvimFloatingBlurRadius = clamped
                return
            }
            UserDefaults.standard.set(nvimFloatingBlurRadius, forKey: Self.nvimFloatingBlurRadiusKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var nvimFloatingCornerRadius: Double = {
        if UserDefaults.standard.object(forKey: EditorPreferences.nvimFloatingCornerRadiusKey) == nil {
            return EditorPreferences.defaultFloatingCornerRadius
        }
        return UserDefaults.standard.double(forKey: EditorPreferences.nvimFloatingCornerRadiusKey)
    }() {
        didSet {
            let clamped = Self.clampFloatingCornerRadius(nvimFloatingCornerRadius)
            if clamped != nvimFloatingCornerRadius {
                nvimFloatingCornerRadius = clamped
                return
            }
            UserDefaults.standard.set(nvimFloatingCornerRadius, forKey: Self.nvimFloatingCornerRadiusKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var nvimFloatingShadowEnabled: Bool = {
        if UserDefaults.standard.object(forKey: EditorPreferences.nvimFloatingShadowEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: EditorPreferences.nvimFloatingShadowEnabledKey)
    }() {
        didSet {
            UserDefaults.standard.set(nvimFloatingShadowEnabled, forKey: Self.nvimFloatingShadowEnabledKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var nvimFloatingShadowRadius: Double = {
        if UserDefaults.standard.object(forKey: EditorPreferences.nvimFloatingShadowRadiusKey) == nil {
            return EditorPreferences.defaultFloatingShadowRadius
        }
        return UserDefaults.standard.double(forKey: EditorPreferences.nvimFloatingShadowRadiusKey)
    }() {
        didSet {
            let clamped = Self.clampFloatingShadowRadius(nvimFloatingShadowRadius)
            if clamped != nvimFloatingShadowRadius {
                nvimFloatingShadowRadius = clamped
                return
            }
            UserDefaults.standard.set(nvimFloatingShadowRadius, forKey: Self.nvimFloatingShadowRadiusKey)
            onScheduleNvimSettingsSync?()
        }
    }
    @Published var isWindowTransparencyEnabled: Bool = UserDefaults.standard.bool(
        forKey: EditorPreferences.windowTransparencyEnabledKey
    ) {
        didSet {
            UserDefaults.standard.set(isWindowTransparencyEnabled, forKey: Self.windowTransparencyEnabledKey)
            onApplyWindowAppearance?()
        }
    }
    @Published var windowOpacity: Double = {
        let value = UserDefaults.standard.double(forKey: EditorPreferences.windowOpacityKey)
        let initial = value > 0 ? value : 1.0
        return clampWindowOpacity(initial)
    }() {
        didSet {
            let clamped = Self.clampWindowOpacity(windowOpacity)
            if clamped != windowOpacity {
                windowOpacity = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Self.windowOpacityKey)
            onApplyWindowAppearance?()
        }
    }
#if DEBUG
    @Published var isPerformanceOverlayEnabled: Bool = UserDefaults.standard.bool(
        forKey: EditorPreferences.performanceOverlayEnabledKey
    ) {
        didSet {
            UserDefaults.standard.set(isPerformanceOverlayEnabled, forKey: Self.performanceOverlayEnabledKey)
            PerformanceMonitor.shared.setOverlayEnabled(isPerformanceOverlayEnabled)
            onShowToast?(isPerformanceOverlayEnabled ? "Performance Overlay On" : "Performance Overlay Off")
        }
    }
    @Published var isPerformanceLoggingEnabled: Bool = UserDefaults.standard.bool(
        forKey: EditorPreferences.performanceLoggingEnabledKey
    ) {
        didSet {
            UserDefaults.standard.set(isPerformanceLoggingEnabled, forKey: Self.performanceLoggingEnabledKey)
            PerformanceMonitor.shared.setLoggingEnabled(isPerformanceLoggingEnabled)
            if isPerformanceLoggingEnabled {
                if let logURL = PerformanceMonitor.shared.logFileURL {
                    onShowToast?("Logging perf metrics: \(logURL.lastPathComponent)")
                } else {
                    onShowToast?("Performance logging on")
                }
            } else {
                onShowToast?("Performance logging off")
            }
        }
    }
#endif

    init() {
#if DEBUG
        PerformanceMonitor.shared.setOverlayEnabled(isPerformanceOverlayEnabled)
        PerformanceMonitor.shared.setLoggingEnabled(isPerformanceLoggingEnabled)
#endif
    }

    var editorFont: NSFont {
        Self.resolveEditorFont(name: editorFontName, size: editorFontSize)
    }

    var editorFontDisplayName: String {
        editorFont.displayName ?? editorFontName
    }

    var availableEditorFonts: [String] {
        Self.monospacedFontNames
    }

    var nvimGuifont: String {
        let displayName = editorFont.displayName ?? editorFontName
        let escaped = Self.escapeGuifontName(displayName)
        let size = Int(editorFontSize.rounded())
        return "\(escaped):h\(size)"
    }

    var nvimPathStatusMessage: String {
        if preferredNvimPath.isEmpty {
            return "Using PATH lookup"
        }
        let expanded = expandedNvimPath
        if FileManager.default.isExecutableFile(atPath: expanded) {
            return "Using \(expanded)"
        }
        return "Neovim path is not executable"
    }

    var nvimPathStatusIsError: Bool {
        !preferredNvimPath.isEmpty && !FileManager.default.isExecutableFile(atPath: expandedNvimPath)
    }

    var expandedNvimPath: String {
        (preferredNvimPath as NSString).expandingTildeInPath
    }

    func chooseNvimPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            preferredNvimPath = url.path
        }
    }

    func clearNvimPath() {
        preferredNvimPath = ""
    }

    static let minEditorFontSize: Double = 9
    static let maxEditorFontSize: Double = 32
    static let editorLineSpacingRange: ClosedRange<Double> = 0...12
    static let editorCharacterSpacingRange: ClosedRange<Double> = 0...4
    static let windowOpacityRange: ClosedRange<Double> = 0.7...1.0
    static let floatingBlurRadiusRange: ClosedRange<Double> = 0...30
    static let floatingCornerRadiusRange: ClosedRange<Double> = 0...20
    static let floatingShadowRadiusRange: ClosedRange<Double> = 0...30
    static let defaultFloatingShadowOpacity: Float = 0.25

    private static let editorFontNameKey = "smithers.editorFontName"
    private static let editorFontSizeKey = "smithers.editorFontSize"
    private static let editorLigaturesEnabledKey = "smithers.editorLigaturesEnabled"
    private static let editorLineSpacingKey = "smithers.editorLineSpacing"
    private static let editorCharacterSpacingKey = "smithers.editorCharacterSpacing"
    private static let nvimPathKey = "smithers.nvimPath"
    private static let optionAsMetaKey = "smithers.optionAsMeta"
    private static let scrollbarVisibilityModeKey = "smithers.scrollbarVisibilityMode"
    private static let showLineNumbersKey = "smithers.showLineNumbers"
    private static let highlightCurrentLineKey = "smithers.highlightCurrentLine"
    private static let showIndentGuidesKey = "smithers.showIndentGuides"
    private static let showMinimapKey = "smithers.showMinimap"
    private static let nvimFloatingBlurEnabledKey = "smithers.nvimFloatingBlurEnabled"
    private static let nvimFloatingBlurRadiusKey = "smithers.nvimFloatingBlurRadius"
    private static let nvimFloatingCornerRadiusKey = "smithers.nvimFloatingCornerRadius"
    private static let nvimFloatingShadowEnabledKey = "smithers.nvimFloatingShadowEnabled"
    private static let nvimFloatingShadowRadiusKey = "smithers.nvimFloatingShadowRadius"
    private static let windowTransparencyEnabledKey = "smithers.windowTransparencyEnabled"
    private static let windowOpacityKey = "smithers.windowOpacity"
#if DEBUG
    private static let performanceOverlayEnabledKey = "smithers.performanceOverlayEnabled"
    private static let performanceLoggingEnabledKey = "smithers.performanceLoggingEnabled"
#endif
    private static let defaultEditorFontSize: Double = 13
    private static let defaultEditorFontName: String = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).fontName
    private static let defaultEditorLineSpacing: Double = 0
    private static let defaultEditorCharacterSpacing: Double = 0
    private static let defaultFloatingBlurRadius: Double = 12
    private static let defaultFloatingCornerRadius: Double = 8
    private static let defaultFloatingShadowRadius: Double = 12

    private static let monospacedFontNames: [String] = {
        let size = CGFloat(defaultEditorFontSize)
        let names = NSFontManager.shared.availableFonts
        var results: [String] = []
        results.reserveCapacity(names.count / 4)
        for name in names {
            guard let font = NSFont(name: name, size: size) else { continue }
            guard font.isFixedPitch else { continue }
            results.append(name)
        }
        if !results.contains(defaultEditorFontName) {
            results.append(defaultEditorFontName)
        }
        return Array(Set(results)).sorted()
    }()

    private static func resolveEditorFont(name: String, size: Double) -> NSFont {
        let clamped = clampEditorFontSize(size)
        if let font = NSFont(name: name, size: CGFloat(clamped)) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: CGFloat(clamped), weight: .regular)
    }

    private static func escapeGuifontName(_ name: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(name.count)
        for ch in name {
            switch ch {
            case " ", "\\", ",", ":":
                escaped.append("\\")
                escaped.append(ch)
            default:
                escaped.append(ch)
            }
        }
        return escaped
    }

    private static func normalizeEditorFontName(_ name: String, size: Double) -> String {
        if NSFont(name: name, size: CGFloat(size)) != nil {
            return name
        }
        return defaultEditorFontName
    }

    private static func clampEditorFontSize(_ size: Double) -> Double {
        min(max(size, minEditorFontSize), maxEditorFontSize)
    }

    private static func clampEditorLineSpacing(_ value: Double) -> Double {
        min(max(value, editorLineSpacingRange.lowerBound), editorLineSpacingRange.upperBound)
    }

    private static func clampEditorCharacterSpacing(_ value: Double) -> Double {
        min(max(value, editorCharacterSpacingRange.lowerBound), editorCharacterSpacingRange.upperBound)
    }

    static func clampWindowOpacity(_ value: Double) -> Double {
        min(max(value, windowOpacityRange.lowerBound), windowOpacityRange.upperBound)
    }

    private static func clampFloatingBlurRadius(_ value: Double) -> Double {
        min(max(value, floatingBlurRadiusRange.lowerBound), floatingBlurRadiusRange.upperBound)
    }

    private static func clampFloatingCornerRadius(_ value: Double) -> Double {
        min(max(value, floatingCornerRadiusRange.lowerBound), floatingCornerRadiusRange.upperBound)
    }

    private static func clampFloatingShadowRadius(_ value: Double) -> Double {
        min(max(value, floatingShadowRadiusRange.lowerBound), floatingShadowRadiusRange.upperBound)
    }
}
