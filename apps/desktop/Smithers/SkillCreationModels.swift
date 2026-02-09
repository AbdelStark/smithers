import Foundation

struct SkillScriptTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let contents: String
    let isExecutable: Bool
}

struct SkillSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    var isSelected: Bool
}

struct CodebaseAnalysis {
    let stack: [String]
    var suggestions: [SkillSuggestion]
}

enum SkillTemplateKind: String, CaseIterable, Identifiable {
    case general = "General"
    case observability = "Observability"
    case testing = "Testing"
    case security = "Security"

    var id: String { rawValue }
}
