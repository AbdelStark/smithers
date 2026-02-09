import SwiftUI
import AppKit
import Foundation

extension WorkspaceState {
    @available(*, deprecated, message: "Use workspace.preferences.theme")
    var theme: AppTheme {
        get { preferences.theme }
        set { preferences.theme = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorFontName")
    var editorFontName: String {
        get { preferences.editorFontName }
        set { preferences.editorFontName = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorFontSize")
    var editorFontSize: Double {
        get { preferences.editorFontSize }
        set { preferences.editorFontSize = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorLigaturesEnabled")
    var editorLigaturesEnabled: Bool {
        get { preferences.editorLigaturesEnabled }
        set { preferences.editorLigaturesEnabled = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorLineSpacing")
    var editorLineSpacing: Double {
        get { preferences.editorLineSpacing }
        set { preferences.editorLineSpacing = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorCharacterSpacing")
    var editorCharacterSpacing: Double {
        get { preferences.editorCharacterSpacing }
        set { preferences.editorCharacterSpacing = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.preferredNvimPath")
    var preferredNvimPath: String {
        get { preferences.preferredNvimPath }
        set { preferences.preferredNvimPath = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.optionAsMeta")
    var optionAsMeta: OptionAsMeta {
        get { preferences.optionAsMeta }
        set { preferences.optionAsMeta = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.scrollbarVisibilityMode")
    var scrollbarVisibilityMode: ScrollbarVisibilityMode {
        get { preferences.scrollbarVisibilityMode }
        set { preferences.scrollbarVisibilityMode = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.showLineNumbers")
    var showLineNumbers: Bool {
        get { preferences.showLineNumbers }
        set { preferences.showLineNumbers = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.highlightCurrentLine")
    var highlightCurrentLine: Bool {
        get { preferences.highlightCurrentLine }
        set { preferences.highlightCurrentLine = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.showIndentGuides")
    var showIndentGuides: Bool {
        get { preferences.showIndentGuides }
        set { preferences.showIndentGuides = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.showMinimap")
    var showMinimap: Bool {
        get { preferences.showMinimap }
        set { preferences.showMinimap = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimFloatingBlurEnabled")
    var nvimFloatingBlurEnabled: Bool {
        get { preferences.nvimFloatingBlurEnabled }
        set { preferences.nvimFloatingBlurEnabled = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimFloatingBlurRadius")
    var nvimFloatingBlurRadius: Double {
        get { preferences.nvimFloatingBlurRadius }
        set { preferences.nvimFloatingBlurRadius = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimFloatingCornerRadius")
    var nvimFloatingCornerRadius: Double {
        get { preferences.nvimFloatingCornerRadius }
        set { preferences.nvimFloatingCornerRadius = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimFloatingShadowEnabled")
    var nvimFloatingShadowEnabled: Bool {
        get { preferences.nvimFloatingShadowEnabled }
        set { preferences.nvimFloatingShadowEnabled = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimFloatingShadowRadius")
    var nvimFloatingShadowRadius: Double {
        get { preferences.nvimFloatingShadowRadius }
        set { preferences.nvimFloatingShadowRadius = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.isWindowTransparencyEnabled")
    var isWindowTransparencyEnabled: Bool {
        get { preferences.isWindowTransparencyEnabled }
        set { preferences.isWindowTransparencyEnabled = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.windowOpacity")
    var windowOpacity: Double {
        get { preferences.windowOpacity }
        set { preferences.windowOpacity = newValue }
    }

#if DEBUG
    @available(*, deprecated, message: "Use workspace.preferences.isPerformanceOverlayEnabled")
    var isPerformanceOverlayEnabled: Bool {
        get { preferences.isPerformanceOverlayEnabled }
        set { preferences.isPerformanceOverlayEnabled = newValue }
    }

    @available(*, deprecated, message: "Use workspace.preferences.isPerformanceLoggingEnabled")
    var isPerformanceLoggingEnabled: Bool {
        get { preferences.isPerformanceLoggingEnabled }
        set { preferences.isPerformanceLoggingEnabled = newValue }
    }
#endif

    @available(*, deprecated, message: "Use workspace.preferences.editorFont")
    var editorFont: NSFont {
        preferences.editorFont
    }

    @available(*, deprecated, message: "Use workspace.preferences.editorFontDisplayName")
    var editorFontDisplayName: String {
        preferences.editorFontDisplayName
    }

    @available(*, deprecated, message: "Use workspace.preferences.availableEditorFonts")
    var availableEditorFonts: [String] {
        preferences.availableEditorFonts
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimGuifont")
    var nvimGuifont: String {
        preferences.nvimGuifont
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimPathStatusMessage")
    var nvimPathStatusMessage: String {
        preferences.nvimPathStatusMessage
    }

    @available(*, deprecated, message: "Use workspace.preferences.nvimPathStatusIsError")
    var nvimPathStatusIsError: Bool {
        preferences.nvimPathStatusIsError
    }

    @available(*, deprecated, message: "Use workspace.preferences.chooseNvimPath()")
    func chooseNvimPath() {
        preferences.chooseNvimPath()
    }

    @available(*, deprecated, message: "Use workspace.preferences.clearNvimPath()")
    func clearNvimPath() {
        preferences.clearNvimPath()
    }

    @available(*, deprecated, message: "Use EditorPreferences.minEditorFontSize")
    static let minEditorFontSize = EditorPreferences.minEditorFontSize

    @available(*, deprecated, message: "Use EditorPreferences.maxEditorFontSize")
    static let maxEditorFontSize = EditorPreferences.maxEditorFontSize

    @available(*, deprecated, message: "Use EditorPreferences.editorLineSpacingRange")
    static let editorLineSpacingRange = EditorPreferences.editorLineSpacingRange

    @available(*, deprecated, message: "Use EditorPreferences.editorCharacterSpacingRange")
    static let editorCharacterSpacingRange = EditorPreferences.editorCharacterSpacingRange

    @available(*, deprecated, message: "Use EditorPreferences.windowOpacityRange")
    static let windowOpacityRange = EditorPreferences.windowOpacityRange

    @available(*, deprecated, message: "Use EditorPreferences.floatingBlurRadiusRange")
    static let floatingBlurRadiusRange = EditorPreferences.floatingBlurRadiusRange

    @available(*, deprecated, message: "Use EditorPreferences.floatingCornerRadiusRange")
    static let floatingCornerRadiusRange = EditorPreferences.floatingCornerRadiusRange

    @available(*, deprecated, message: "Use EditorPreferences.floatingShadowRadiusRange")
    static let floatingShadowRadiusRange = EditorPreferences.floatingShadowRadiusRange
}
