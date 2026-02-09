import Foundation

struct SkillTemplateBuilder {
    static func buildMarkdown(
        name: String,
        description: String,
        template: SkillTemplateKind,
        author: String,
        version: String,
        category: String?,
        allowedTools: [String],
        argumentHint: String?,
        analysis: CodebaseAnalysis?,
        selectedSuggestions: [SkillSuggestion],
        includeScripts: Bool
    ) -> String {
        var frontmatter: [String] = []
        frontmatter.append("---")
        frontmatter.append("name: \(name)")
        frontmatter.append("description: \"\(description)\"")
        frontmatter.append("license: MIT")
        frontmatter.append("metadata:")
        frontmatter.append("  author: \"\(author)\"")
        frontmatter.append("  version: \"\(version)\"")
        if let category, !category.isEmpty {
            frontmatter.append("  category: \"\(category)\"")
        }
        if !allowedTools.isEmpty {
            frontmatter.append("allowed-tools: \(allowedTools.joined(separator: " "))")
        }
        if let argumentHint, !argumentHint.isEmpty {
            frontmatter.append("argument-hint: \"\(argumentHint)\"")
        }
        frontmatter.append("---\n")

        let body = buildBody(template: template, analysis: analysis, suggestions: selectedSuggestions, includeScripts: includeScripts)
        return (frontmatter + [body]).joined(separator: "\n")
    }

    private static func buildBody(
        template: SkillTemplateKind,
        analysis: CodebaseAnalysis?,
        suggestions: [SkillSuggestion],
        includeScripts: Bool
    ) -> String {
        var lines: [String] = []
        switch template {
        case .observability:
            lines.append("# Observability Skill\n")
            lines.append("## When to Use")
            lines.append("- After adding features (ensure logs/metrics exist)")
            lines.append("- When debugging production issues")
            lines.append("- During code review for coverage\n")
            lines.append("## Logging Levels")
            lines.append("- TRACE: method entry/exit, fine-grained debug")
            lines.append("- DEBUG: diagnostics for development")
            lines.append("- INFO: normal operations and state changes")
            lines.append("- WARN: recoverable issues and degraded state")
            lines.append("- ERROR: failures requiring attention")
            lines.append("- FATAL: unrecoverable failures\n")
            lines.append("## Audit Checklist")
            lines.append("- [ ] Request/response logging for key entry points")
            lines.append("- [ ] Error paths include context")
            lines.append("- [ ] Background jobs log start/finish")
            lines.append("- [ ] Health checks and monitoring are present\n")
        case .testing:
            lines.append("# Testing Skill\n")
            lines.append("## When to Use")
            lines.append("- Before releases or risky refactors")
            lines.append("- When adding new modules")
            lines.append("- In CI build failures\n")
            lines.append("## Checklist")
            lines.append("- [ ] Unit tests cover core logic")
            lines.append("- [ ] Integration tests cover critical paths")
            lines.append("- [ ] Tests run in CI")
            lines.append("- [ ] Flaky tests are quarantined\n")
        case .security:
            lines.append("# Security Skill\n")
            lines.append("## When to Use")
            lines.append("- Before shipping external-facing changes")
            lines.append("- When handling auth/permissions")
            lines.append("- During dependency updates\n")
            lines.append("## Checklist")
            lines.append("- [ ] Validate input and sanitize output")
            lines.append("- [ ] Protect secrets and credentials")
            lines.append("- [ ] Check dependency vulnerabilities")
            lines.append("- [ ] Review auth and permission flows\n")
        case .general:
            lines.append("# Skill Instructions\n")
            lines.append("## When to Use")
            lines.append("- When this workflow improves consistency")
            lines.append("- When onboarding new contributors\n")
            lines.append("## Checklist")
            lines.append("- [ ] Review relevant files")
            lines.append("- [ ] Apply standard patterns")
            lines.append("- [ ] Validate changes and update docs\n")
        }

        if let analysis, !analysis.stack.isEmpty {
            lines.append("## Stack-Specific Guidance")
            lines.append("Detected stack: \(analysis.stack.joined(separator: " • "))\n")
        }

        if !suggestions.isEmpty {
            lines.append("## Recommended Additions")
            for suggestion in suggestions where suggestion.isSelected {
                lines.append("- \(suggestion.title)")
            }
            lines.append("")
        }

        if includeScripts {
            lines.append("## Scripts")
            lines.append("- `scripts/audit.sh` — Audit coverage")
            lines.append("- `scripts/setup.sh` — Install dependencies")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
