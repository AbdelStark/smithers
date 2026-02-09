import Foundation

final class CodebaseAnalyzer {
    func analyze(rootDirectory: URL?) async -> CodebaseAnalysis {
        guard let rootDirectory else { return CodebaseAnalysis(stack: [], suggestions: []) }
        let markers = await scanMarkers(rootDirectory: rootDirectory)
        var stack: [String] = []

        if markers.hasPackageSwift {
            stack.append("Swift")
        }
        if markers.hasZig {
            stack.append("Zig")
        }
        if markers.hasNode {
            stack.append("Node.js")
        }
        if markers.hasRust {
            stack.append("Rust")
        }
        if markers.hasGo {
            stack.append("Go")
        }
        if markers.hasPython {
            stack.append("Python")
        }
        if markers.hasSQLite {
            stack.append("SQLite")
        }
        if markers.hasXcode || markers.hasInfoPlist {
            stack.append("macOS")
        }
        if markers.hasDocker {
            stack.append("Docker")
        }

        var suggestions: [SkillSuggestion] = []
        if !markers.hasTests {
            suggestions.append(SkillSuggestion(
                id: "testing",
                title: "Add testing coverage",
                detail: "Create testing routines and coverage checks.",
                isSelected: true
            ))
        }
        if !markers.hasCI {
            suggestions.append(SkillSuggestion(
                id: "ci",
                title: "Set up CI/CD",
                detail: "Automate builds and tests with a CI pipeline.",
                isSelected: false
            ))
        }
        if stack.contains("Swift") {
            suggestions.append(SkillSuggestion(
                id: "oslog",
                title: "OSLog structured logging",
                detail: "Use native macOS Logger for structured logs.",
                isSelected: true
            ))
        }
        if stack.contains("SQLite") {
            suggestions.append(SkillSuggestion(
                id: "sqlite-tracing",
                title: "SQLite query tracing",
                detail: "Enable SQLITE_TRACE to profile queries.",
                isSelected: true
            ))
        }
        if markers.hasBackend {
            suggestions.append(SkillSuggestion(
                id: "request-logging",
                title: "Request/response logging",
                detail: "Capture backend request and response metadata.",
                isSelected: false
            ))
        }
        if markers.hasAppleApp {
            suggestions.append(SkillSuggestion(
                id: "crash-reporting",
                title: "Crash reporting",
                detail: "Add MetricKit or crash reporting hooks.",
                isSelected: false
            ))
        }

        return CodebaseAnalysis(stack: stack, suggestions: suggestions)
    }

    private func scanMarkers(rootDirectory: URL) async -> MarkerScan {
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var markers = MarkerScan()
            let keys: [URLResourceKey] = [.isDirectoryKey]
            guard let enumerator = fm.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return markers
            }

            var inspectedFiles = 0
            while let url = enumerator.nextObject() as? URL {
                if inspectedFiles > 5000 { break }
                let name = url.lastPathComponent
                if name == "Package.swift" { markers.hasPackageSwift = true }
                if name == "build.zig" || name == "build.zig.zon" { markers.hasZig = true }
                if name == "Cargo.toml" { markers.hasRust = true }
                if name == "go.mod" { markers.hasGo = true }
                if name == "package.json" { markers.hasNode = true }
                if name == "requirements.txt" || name == "pyproject.toml" { markers.hasPython = true }
                if name == "docker-compose.yml" || name == "Dockerfile" { markers.hasDocker = true }
                if name == ".gitlab-ci.yml" || name == "azure-pipelines.yml" { markers.hasCI = true }
                if name == "Info.plist" { markers.hasInfoPlist = true }
                if name.hasSuffix(".xcodeproj") { markers.hasXcode = true }
                if name == ".github" {
                    let workflows = url.appendingPathComponent("workflows")
                    if fm.fileExists(atPath: workflows.path) {
                        markers.hasCI = true
                    }
                }
                if name.lowercased().contains("test") || name == "Tests" || name == "__tests__" {
                    markers.hasTests = true
                }
                if name.hasSuffix(".sqlite") || name.hasSuffix(".db") {
                    markers.hasSQLite = true
                }
                if name.lowercased().contains("server") || name.lowercased().contains("backend") {
                    markers.hasBackend = true
                }
                if name.hasSuffix(".app") || name == "Contents" {
                    markers.hasAppleApp = true
                }
                inspectedFiles += 1
            }
            return markers
        }.value
    }
}

private struct MarkerScan {
    var hasPackageSwift = false
    var hasZig = false
    var hasNode = false
    var hasRust = false
    var hasGo = false
    var hasPython = false
    var hasSQLite = false
    var hasDocker = false
    var hasCI = false
    var hasTests = false
    var hasXcode = false
    var hasInfoPlist = false
    var hasBackend = false
    var hasAppleApp = false
}
