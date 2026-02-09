import SwiftUI
import AppKit
import Foundation

struct PreferencesView: View {
    @ObservedObject var workspace: WorkspaceState

    var body: some View {
        TabView {
            generalPane
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            editorPane
                .tabItem {
                    Label("Editor", systemImage: "textformat")
                }
            neovimPane
                .tabItem {
                    Label("Neovim", systemImage: "terminal")
                }
        }
        .padding(20)
        .frame(width: 600, height: 460)
    }

    private var generalPane: some View {
        Form {
            Section("Files") {
                Toggle("Warn before closing with unsaved changes", isOn: $workspace.isCloseWarningEnabled)
                Toggle("Auto Save", isOn: $workspace.isAutoSaveEnabled)
                Picker("Auto Save Interval", selection: $workspace.autoSaveInterval) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                .disabled(!workspace.isAutoSaveEnabled)
            }

            Section("Updates") {
                Picker("Channel", selection: $workspace.updateChannel) {
                    ForEach(UpdateChannel.allCases) { channel in
                        Text(channel.label)
                            .tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                Text("Snapshot updates may include unfinished features.")
                    .font(.system(size: Typography.s))
                    .foregroundStyle(.secondary)
            }

            Section("Window") {
                Toggle("Transparent window", isOn: $workspace.preferences.isWindowTransparencyEnabled)
                HStack {
                    Text("Opacity")
                    Spacer()
                    Slider(
                        value: $workspace.preferences.windowOpacity,
                        in: EditorPreferences.windowOpacityRange,
                        step: 0.05
                    )
                    .frame(maxWidth: 140)
                    Text("\(Int((workspace.preferences.windowOpacity * 100).rounded()))%")
                        .font(.system(size: Typography.s, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .disabled(!workspace.preferences.isWindowTransparencyEnabled)
            }

#if DEBUG
            Section("Developer") {
                Toggle("Show Performance Overlay", isOn: $workspace.preferences.isPerformanceOverlayEnabled)
                Toggle("Log Performance Metrics", isOn: $workspace.preferences.isPerformanceLoggingEnabled)
                if workspace.preferences.isPerformanceLoggingEnabled,
                   let logURL = PerformanceMonitor.shared.logFileURL {
                    Button("Reveal Performance Log") {
                        workspace.revealInFinder(logURL)
                    }
                    Text(logURL.path)
                        .font(.system(size: Typography.xs, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
#endif
        }
    }

    private var editorPane: some View {
        Form {
            Section("Font") {
                Picker("Font", selection: $workspace.preferences.editorFontName) {
                    ForEach(workspace.preferences.availableEditorFonts, id: \.self) { name in
                        Text(displayName(for: name))
                            .tag(name)
                    }
                }
                HStack {
                    Text("Size")
                    Spacer()
                    Stepper(
                        value: $workspace.preferences.editorFontSize,
                        in: EditorPreferences.minEditorFontSize...EditorPreferences.maxEditorFontSize,
                        step: 1
                    ) {
                        Text("\(Int(workspace.preferences.editorFontSize)) pt")
                            .font(.system(size: Typography.base, weight: .semibold))
                    }
                }
                Toggle("Enable ligatures", isOn: $workspace.preferences.editorLigaturesEnabled)
                HStack {
                    Text("Line spacing")
                    Spacer()
                    Stepper(
                        value: $workspace.preferences.editorLineSpacing,
                        in: EditorPreferences.editorLineSpacingRange,
                        step: 0.5
                    ) {
                        Text(String(format: "%.1f pt", workspace.preferences.editorLineSpacing))
                            .font(.system(size: Typography.base, weight: .semibold))
                    }
                }
                HStack {
                    Text("Character spacing")
                    Spacer()
                    Stepper(
                        value: $workspace.preferences.editorCharacterSpacing,
                        in: EditorPreferences.editorCharacterSpacingRange,
                        step: 0.5
                    ) {
                        Text(String(format: "%.1f pt", workspace.preferences.editorCharacterSpacing))
                            .font(.system(size: Typography.base, weight: .semibold))
                    }
                }
            }

            Section("Appearance") {
                Toggle("Show line numbers", isOn: $workspace.preferences.showLineNumbers)
                Toggle("Highlight current line", isOn: $workspace.preferences.highlightCurrentLine)
                Toggle("Show indent guides", isOn: $workspace.preferences.showIndentGuides)
                Toggle("Show minimap", isOn: $workspace.preferences.showMinimap)
            }

            Section("Scrollbar") {
                Picker("Visibility", selection: $workspace.preferences.scrollbarVisibilityMode) {
                    ForEach(ScrollbarVisibilityMode.allCases) { mode in
                        Text(mode.label)
                            .tag(mode)
                    }
                }
            }

            Section("Progress Bar") {
                HStack {
                    Text("Height")
                    Spacer()
                    Stepper(
                        value: $workspace.progressBarHeight,
                        in: WorkspaceState.progressBarHeightRange,
                        step: 1
                    ) {
                        Text("\(Int(workspace.progressBarHeight)) pt")
                            .font(.system(size: Typography.base, weight: .semibold))
                    }
                }
                HStack {
                    ColorPicker(
                        "Fill",
                        selection: progressColorBinding(
                            $workspace.progressBarFillColor,
                            fallback: workspace.preferences.theme.accent
                        ),
                        supportsOpacity: true
                    )
                    Spacer()
                    Button("Use Theme") {
                        workspace.progressBarFillColor = nil
                    }
                }
                HStack {
                    ColorPicker(
                        "Track",
                        selection: progressColorBinding(
                            $workspace.progressBarTrackColor,
                            fallback: workspace.preferences.theme.divider.withAlphaComponent(0.35)
                        ),
                        supportsOpacity: true
                    )
                    Spacer()
                    Button("Use Theme") {
                        workspace.progressBarTrackColor = nil
                    }
                }
            }
        }
    }

    private var neovimPane: some View {
        Form {
            Section("Neovim") {
                HStack(spacing: 8) {
                    TextField("/path/to/nvim", text: $workspace.preferences.preferredNvimPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: Typography.base, design: .monospaced))
                    Button("Choose...") {
                        workspace.preferences.chooseNvimPath()
                    }
                }
                HStack {
                    Text(workspace.preferences.nvimPathStatusMessage)
                        .font(.system(size: Typography.s))
                        .foregroundStyle(workspace.preferences.nvimPathStatusIsError ? Color.red : Color.secondary)
                    Spacer()
                    Button("Use Default") {
                        workspace.preferences.clearNvimPath()
                    }
                }
            }

            Section("Keys") {
                Picker("Option as Meta", selection: $workspace.preferences.optionAsMeta) {
                    ForEach(OptionAsMeta.allCases) { option in
                        Text(option.label)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Floating Windows") {
                Toggle("Blur background", isOn: $workspace.preferences.nvimFloatingBlurEnabled)
                HStack {
                    Text("Blur Radius")
                    Spacer()
                    Slider(
                        value: $workspace.preferences.nvimFloatingBlurRadius,
                        in: EditorPreferences.floatingBlurRadiusRange,
                        step: 1
                    )
                    .frame(maxWidth: 140)
                    Text("\(Int(workspace.preferences.nvimFloatingBlurRadius)) pt")
                        .font(.system(size: Typography.s, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .disabled(!workspace.preferences.nvimFloatingBlurEnabled)

                Toggle("Shadow", isOn: $workspace.preferences.nvimFloatingShadowEnabled)
                HStack {
                    Text("Shadow Radius")
                    Spacer()
                    Slider(
                        value: $workspace.preferences.nvimFloatingShadowRadius,
                        in: EditorPreferences.floatingShadowRadiusRange,
                        step: 1
                    )
                    .frame(maxWidth: 140)
                    Text("\(Int(workspace.preferences.nvimFloatingShadowRadius)) pt")
                        .font(.system(size: Typography.s, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .disabled(!workspace.preferences.nvimFloatingShadowEnabled)

                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Slider(
                        value: $workspace.preferences.nvimFloatingCornerRadius,
                        in: EditorPreferences.floatingCornerRadiusRange,
                        step: 1
                    )
                    .frame(maxWidth: 140)
                    Text("\(Int(workspace.preferences.nvimFloatingCornerRadius)) pt")
                        .font(.system(size: Typography.s, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func displayName(for name: String) -> String {
        if let font = NSFont(name: name, size: 12) {
            return font.displayName ?? name
        }
        return name
    }

    private func progressColorBinding(_ color: Binding<NSColor?>, fallback: NSColor) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: color.wrappedValue ?? fallback) },
            set: { newValue in
                let nsColor = NSColor(newValue)
                color.wrappedValue = nsColor.usingColorSpace(.sRGB) ?? nsColor
            }
        )
    }
}
