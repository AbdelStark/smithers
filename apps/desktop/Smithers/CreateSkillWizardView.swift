import SwiftUI

struct CreateSkillWizardView: View {
    @ObservedObject var workspace: WorkspaceState
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var scope: SkillScope = .project
    @State private var template: SkillTemplateKind = .general
    @State private var author: String = NSFullUserName()
    @State private var version: String = "0.1.0"
    @State private var category: String = ""
    @State private var allowedTools: String = ""
    @State private var argumentHint: String = ""
    @State private var includeScripts: Bool = false

    var body: some View {
        let theme = workspace.theme
        VStack(spacing: 0) {
            header(theme: theme)
            Divider()
                .background(theme.dividerColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formSection(theme: theme)
                    previewSection(theme: theme)
                    HStack {
                        Spacer()
                        Button("Create Skill") {
                            createSkill()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(theme.backgroundColor)
    }

    private func header(theme: AppTheme) -> some View {
        HStack {
            Text("Create Skill")
                .font(.system(size: Typography.l, weight: .semibold))
            Spacer()
        }
        .padding(12)
        .background(theme.secondaryBackgroundColor)
    }

    private func formSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: Typography.base, weight: .semibold))
            HStack(spacing: 12) {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            }
            HStack(spacing: 12) {
                Picker("Scope", selection: $scope) {
                    ForEach(SkillScope.allCases.filter { $0 != .system }, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .frame(width: 160)
                Picker("Template", selection: $template) {
                    ForEach(SkillTemplateKind.allCases) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                .frame(width: 200)
                Toggle("Include Scripts", isOn: $includeScripts)
            }
            HStack(spacing: 12) {
                TextField("Author", text: $author)
                TextField("Version", text: $version)
                TextField("Category", text: $category)
            }
            HStack(spacing: 12) {
                TextField("Allowed tools (space-separated)", text: $allowedTools)
                TextField("Argument hint", text: $argumentHint)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
        .background(theme.secondaryBackgroundColor)
        .cornerRadius(8)
    }

    private func previewSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.system(size: Typography.base, weight: .semibold))
            Text(previewMarkdown)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(theme.mutedForegroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(theme.panelBackgroundColor)
                .cornerRadius(8)
        }
    }

    private var previewMarkdown: String {
        let tools = parseAllowedTools()
        let hint = argumentHint.trimmingCharacters(in: .whitespacesAndNewlines)
        return SkillTemplateBuilder.buildMarkdown(
            name: name.isEmpty ? "SkillName" : name,
            description: description.isEmpty ? "Skill description" : description,
            template: template,
            author: author.isEmpty ? "Unknown" : author,
            version: version.isEmpty ? "0.1.0" : version,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category,
            allowedTools: tools,
            argumentHint: hint.isEmpty ? nil : hint,
            analysis: nil,
            selectedSuggestions: [],
            includeScripts: includeScripts
        )
    }

    private func createSkill() {
        let tools = parseAllowedTools()
        let hint = argumentHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdown = SkillTemplateBuilder.buildMarkdown(
            name: name,
            description: description,
            template: template,
            author: author,
            version: version,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category,
            allowedTools: tools,
            argumentHint: hint.isEmpty ? nil : hint,
            analysis: nil,
            selectedSuggestions: [],
            includeScripts: includeScripts
        )
        let scripts = includeScripts ? defaultScripts() : []
        if workspace.createSkill(name: name, scope: scope, contents: markdown, scripts: scripts) {
            workspace.refreshSkills(force: true)
            workspace.activeSkillModal = nil
        }
    }

    private func parseAllowedTools() -> [String] {
        allowedTools
            .split { $0.isWhitespace || $0 == "," }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private func defaultScripts() -> [SkillScriptTemplate] {
        [
            SkillScriptTemplate(
                name: "audit.sh",
                contents: "#!/bin/sh\nset -e\n\necho \"Run audits here\"\n",
                isExecutable: true
            ),
            SkillScriptTemplate(
                name: "setup.sh",
                contents: "#!/bin/sh\nset -e\n\necho \"Setup dependencies here\"\n",
                isExecutable: true
            )
        ]
    }
}
