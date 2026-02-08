import SwiftUI
import AppKit
import Foundation

struct FileIndexEntry: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let displayPath: String
    let lowercasedPath: String

    init(url: URL, displayPath: String) {
        self.id = url
        self.url = url
        self.displayPath = displayPath
        self.lowercasedPath = displayPath.lowercased()
    }
}

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let icon: String
    let action: () -> Void
}

@MainActor
class WorkspaceState: ObservableObject {
    @Published var rootDirectory: URL?
    @Published var fileTree: [FileItem] = []
    @Published var openFiles: [URL] = []
    @Published var selectedFileURL: URL?
    @Published var terminalViews: [URL: GhosttyTerminalView] = [:]
    @Published var editorText: String = """
    func hello() {
        print("Hello, Smithers!")
    }

    hello()
    """
    {
        didSet {
            guard !suppressEditorTextUpdate else { return }
            guard let selectedFileURL,
                  !isChatURL(selectedFileURL),
                  !isTerminalURL(selectedFileURL)
            else { return }
            openFileContents[selectedFileURL] = editorText
        }
    }
    @Published var currentLanguage: SupportedLanguage?
    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(role: .assistant, kind: .text("Chat ready. Ask me anything."))
    ]
    @Published var chatDraft: String = ""
    @Published var isTurnInProgress: Bool = false
    @Published var isCommandPalettePresented: Bool = false
    @Published var fileSearchQuery: String = "" {
        didSet {
            scheduleSearch()
        }
    }
    @Published private(set) var fileSearchResults: [FileIndexEntry] = []
    @Published private(set) var paletteCommands: [PaletteCommand] = []
    private var fileLoadTask: Task<Void, Never>?
    private var fileIndex: [FileIndexEntry] = []
    private var fileIndexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var openFileContents: [URL: String] = [:]
    private var suppressEditorTextUpdate = false
    private static let chatURL = URL(string: "smithers-chat://current")!
    private static let terminalScheme = "smithers-terminal"
    private var terminalCounter = 0
    private let ghosttyApp = GhosttyApp.shared
    private var codexService: CodexService?
    private var codexEventsTask: Task<Void, Never>?
    nonisolated private static let maxSearchResults = 200
    nonisolated private static let skipDirectoryNames: Set<String> = [
        ".git",
        ".svn",
        ".hg",
        ".DS_Store",
        "node_modules",
        "DerivedData",
        "build",
        "dist"
    ]

    func openDirectory(_ url: URL) {
        stopCodexService()
        closeAllTerminals()
        rootDirectory = url
        fileTree = FileItem.loadTree(at: url)
        openFiles = []
        selectedFileURL = nil
        setEditorText("")
        currentLanguage = nil
        fileLoadTask?.cancel()
        openFileContents = [:]
        fileIndex = []
        fileSearchResults = []
        openChat()
        rebuildFileIndex()
        startCodexService(cwd: url.path)
    }

    func selectFile(_ url: URL) {
        if isChatURL(url) {
            openChat()
            return
        }
        if isTerminalURL(url) {
            selectedFileURL = url
            currentLanguage = nil
            setEditorText("")
            return
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        if !openFiles.contains(url) {
            openFiles.append(url)
        }
        selectedFileURL = url
        currentLanguage = SupportedLanguage.fromFileName(url.lastPathComponent)
        fileLoadTask?.cancel()
        if let cached = openFileContents[url] {
            setEditorText(cached)
            return
        }
        setEditorText("")
        let requestedURL = url
        fileLoadTask = Task { [weak self] in
            let text = await Task.detached(priority: .userInitiated) {
                (try? String(contentsOf: requestedURL, encoding: .utf8)) ?? ""
            }.value
            guard !Task.isCancelled, let self else { return }
            if self.openFileContents[requestedURL] == nil {
                self.openFileContents[requestedURL] = text
            }
            guard self.selectedFileURL == requestedURL else { return }
            self.setEditorText(text)
        }
    }

    func closeFile(_ url: URL) {
        guard let index = openFiles.firstIndex(of: url) else { return }
        let wasSelected = selectedFileURL == url
        openFiles.remove(at: index)
        if isTerminalURL(url) {
            closeTerminal(url)
        } else {
            openFileContents.removeValue(forKey: url)
        }

        guard wasSelected else { return }
        fileLoadTask?.cancel()
        if openFiles.isEmpty {
            selectedFileURL = nil
            currentLanguage = nil
            setEditorText("")
            return
        }
        let nextIndex = min(index, openFiles.count - 1)
        let nextURL = openFiles[nextIndex]
        selectFile(nextURL)
    }

    func isChatURL(_ url: URL) -> Bool {
        url == Self.chatURL
    }

    func isTerminalURL(_ url: URL) -> Bool {
        url.scheme == Self.terminalScheme
    }

    var isCommandMode: Bool {
        fileSearchQuery.hasPrefix(">")
    }

    func showCommandPalette() {
        guard rootDirectory != nil else {
            openFolderPanel()
            return
        }
        if fileIndex.isEmpty {
            rebuildFileIndex()
        }
        fileSearchQuery = ""
        isCommandPalettePresented = true
        scheduleSearch()
    }

    func hideCommandPalette() {
        isCommandPalettePresented = false
    }

    func expandFolder(_ item: FileItem) {
        guard item.needsLoading else { return }
        let children = FileItem.loadShallowChildren(of: item.id)
        var updated = fileTree
        FileItem.replaceChildren(in: &updated, for: item.id, with: children)
        fileTree = updated
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openDirectory(url)
        }
    }

    func displayPath(for url: URL) -> String {
        if isChatURL(url) {
            return "Current chat"
        }
        if isTerminalURL(url) {
            return terminalViews[url]?.pwd ?? "Terminal"
        }
        guard let rootDirectory else { return url.lastPathComponent }
        let rootPath = rootDirectory.path
        let fullPath = url.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }

    func sendChatMessage() {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatMessages.append(ChatMessage(role: .user, kind: .text(text)))
        chatDraft = ""
        guard let codexService else {
            appendErrorMessage("Codex service is not running.")
            return
        }
        isTurnInProgress = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await codexService.sendMessage(text)
            } catch {
                self.appendErrorMessage("Failed to send message: \(error.localizedDescription)")
                self.isTurnInProgress = false
            }
        }
    }

    func interruptTurn() {
        guard let codexService else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await codexService.interrupt()
            } catch {
                self.appendErrorMessage("Failed to interrupt: \(error.localizedDescription)")
            }
        }
    }

    func openTerminal() {
        let url = URL(string: "\(Self.terminalScheme)://\(terminalCounter)")!
        terminalCounter += 1
        let workingDirectory = rootDirectory?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        let view = GhosttyTerminalView(app: ghosttyApp, workingDirectory: workingDirectory)
        view.onClose = { [weak self] in
            self?.closeFile(url)
        }
        terminalViews[url] = view
        openFiles.append(url)
        selectedFileURL = url
        currentLanguage = nil
        setEditorText("")
    }

    private func buildCommandList() -> [PaletteCommand] {
        [
            PaletteCommand(
                id: "new-terminal",
                title: "New Terminal",
                icon: "terminal",
                action: { [weak self] in
                    self?.openTerminal()
                }
            ),
            PaletteCommand(
                id: "open-folder",
                title: "Open Folder...",
                icon: "folder",
                action: { [weak self] in
                    self?.openFolderPanel()
                }
            ),
            PaletteCommand(
                id: "open-chat",
                title: "Open Chat",
                icon: "bubble.left.and.bubble.right",
                action: { [weak self] in
                    self?.openChat()
                }
            ),
        ]
    }

    private func rebuildFileIndex() {
        fileIndexTask?.cancel()
        guard let rootDirectory else { return }
        let rootPath = rootDirectory.path
        let rootPathPrefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        let skipNames = Self.skipDirectoryNames
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        fileIndexTask = Task { [weak self] in
            let entries = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(
                    at: rootDirectory,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    return [FileIndexEntry]()
                }
                var entries: [FileIndexEntry] = []
                while let url = enumerator.nextObject() as? URL {
                    if Task.isCancelled { return entries }
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    if values?.isDirectory == true {
                        if skipNames.contains(url.lastPathComponent) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                    guard values?.isRegularFile == true else { continue }
                    let fullPath = url.path
                    let displayPath: String
                    if fullPath.hasPrefix(rootPathPrefix) {
                        displayPath = String(fullPath.dropFirst(rootPathPrefix.count))
                    } else {
                        displayPath = url.lastPathComponent
                    }
                    entries.append(FileIndexEntry(url: url, displayPath: displayPath))
                }
                entries.sort { lhs, rhs in
                    lhs.displayPath.localizedStandardCompare(rhs.displayPath) == .orderedAscending
                }
                return entries
            }.value
            guard let self, !Task.isCancelled else { return }
            self.fileIndex = entries
            self.scheduleSearch()
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let rawQuery = fileSearchQuery
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.hasPrefix(">") {
            let commandQuery = String(trimmedQuery.dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let commands = buildCommandList()
            let results: [PaletteCommand]
            if commandQuery.isEmpty {
                results = commands
            } else {
                var scored: [(PaletteCommand, Int)] = []
                scored.reserveCapacity(commands.count)
                for command in commands {
                    if let score = Self.scoreMatch(query: commandQuery, in: command.title.lowercased()) {
                        scored.append((command, score))
                    }
                }
                scored.sort { lhs, rhs in
                    if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                    return lhs.0.title.localizedStandardCompare(rhs.0.title) == .orderedAscending
                }
                results = scored.map { $0.0 }
            }
            paletteCommands = results
            fileSearchResults = []
            return
        }

        let query = trimmedQuery.lowercased()
        let entries = fileIndex
        searchTask = Task { [weak self] in
            let results = await Task.detached(priority: .userInitiated) {
                if query.isEmpty {
                    return Array(entries.prefix(Self.maxSearchResults))
                }
                var scored: [(FileIndexEntry, Int)] = []
                scored.reserveCapacity(entries.count / 2)
                for entry in entries {
                    if Task.isCancelled { return [FileIndexEntry]() }
                    if let score = Self.scoreMatch(query: query, in: entry.lowercasedPath) {
                        scored.append((entry, score))
                    }
                }
                scored.sort { lhs, rhs in
                    if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                    return lhs.0.displayPath.localizedStandardCompare(rhs.0.displayPath) == .orderedAscending
                }
                return scored.prefix(Self.maxSearchResults).map { $0.0 }
            }.value
            guard let self else { return }
            let currentQuery = self.fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard currentQuery == query else { return }
            self.fileSearchResults = results
            self.paletteCommands = []
        }
    }

    nonisolated private static func scoreMatch(query: String, in text: String) -> Int? {
        if let range = text.range(of: query) {
            let offset = text.distance(from: text.startIndex, to: range.lowerBound)
            return offset
        }
        var score = 0
        var searchIndex = text.startIndex
        for ch in query {
            guard let found = text[searchIndex...].firstIndex(of: ch) else {
                return nil
            }
            score += text.distance(from: text.startIndex, to: found)
            searchIndex = text.index(after: found)
        }
        return 1000 + score
    }

    private func startCodexService(cwd: String) {
        stopCodexService()
        let service = CodexService()
        codexService = service

        codexEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in service.events {
                self.handleCodexEvent(event)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.start(cwd: cwd)
                if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty {
                    try await service.login(apiKey: apiKey)
                }
            } catch {
                self.appendErrorMessage("Codex failed to start: \(error.localizedDescription)")
                self.stopCodexService()
            }
        }
    }

    private func stopCodexService() {
        codexEventsTask?.cancel()
        codexEventsTask = nil
        codexService?.stop()
        codexService = nil
        isTurnInProgress = false
    }

    private func handleCodexEvent(_ event: CodexEvent) {
        switch event {
        case .turnStarted:
            isTurnInProgress = true
        case .agentMessageDelta(let text):
            applyAgentMessageDelta(text)
        case .agentMessageCompleted(let text):
            finalizeAgentMessage(text: text)
        case .commandStarted(let itemId, let command, let cwd):
            appendCommandMessage(itemId: itemId, command: command, cwd: cwd)
        case .commandOutput(let itemId, let text):
            appendCommandOutput(itemId: itemId, text: text)
        case .commandCompleted(let itemId, let exitCode):
            completeCommand(itemId: itemId, exitCode: exitCode)
        case .turnCompleted(let status):
            isTurnInProgress = false
            finalizeAgentMessage(text: nil)
            if status == "failed" {
                appendErrorMessage("Turn failed.")
            } else if status == "interrupted" {
                appendErrorMessage("Turn interrupted.")
            } else if status != "completed" {
                appendErrorMessage("Turn finished with status: \(status)")
            }
        case .error(let message):
            isTurnInProgress = false
            appendErrorMessage(message)
        }
    }

    private func applyAgentMessageDelta(_ delta: String) {
        if let index = chatMessages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            var message = chatMessages[index]
            message.appendText(delta)
            chatMessages[index] = message
        } else {
            let message = ChatMessage(role: .assistant, kind: .text(delta), isStreaming: true)
            chatMessages.append(message)
        }
    }

    private func finalizeAgentMessage(text: String?) {
        guard let index = chatMessages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) else { return }
        var message = chatMessages[index]
        if let text {
            message.setText(text)
        }
        message.isStreaming = false
        chatMessages[index] = message
    }

    private func appendCommandMessage(itemId: String, command: String, cwd: String) {
        let info = CommandExecutionInfo(itemId: itemId, command: command, cwd: cwd, output: "", exitCode: nil, status: .running)
        let message = ChatMessage(role: .assistant, kind: .command(info))
        chatMessages.append(message)
    }

    private func appendCommandOutput(itemId: String, text: String) {
        guard let index = chatMessages.lastIndex(where: { $0.commandItemId == itemId }) else {
            appendCommandMessage(itemId: itemId, command: "command", cwd: "", output: text)
            return
        }
        var message = chatMessages[index]
        message.appendCommandOutput(text)
        chatMessages[index] = message
    }

    private func completeCommand(itemId: String, exitCode: Int?) {
        guard let index = chatMessages.lastIndex(where: { $0.commandItemId == itemId }) else { return }
        var message = chatMessages[index]
        message.completeCommand(exitCode: exitCode)
        chatMessages[index] = message
    }

    private func appendCommandMessage(itemId: String, command: String, cwd: String, output: String) {
        let info = CommandExecutionInfo(itemId: itemId, command: command, cwd: cwd, output: output, exitCode: nil, status: .running)
        let message = ChatMessage(role: .assistant, kind: .command(info))
        chatMessages.append(message)
    }

    private func appendErrorMessage(_ message: String) {
        chatMessages.append(ChatMessage(role: .assistant, kind: .status(message)))
    }

    private func openChat() {
        if !openFiles.contains(Self.chatURL) {
            openFiles.insert(Self.chatURL, at: 0)
        }
        selectedFileURL = Self.chatURL
        currentLanguage = nil
        setEditorText("")
    }

    private func closeTerminal(_ url: URL) {
        if let view = terminalViews[url] {
            view.shutdown()
        }
        terminalViews.removeValue(forKey: url)
    }

    private func closeAllTerminals() {
        for (_, view) in terminalViews {
            view.shutdown()
        }
        terminalViews.removeAll()
        openFiles.removeAll(where: { isTerminalURL($0) })
    }

    private func setEditorText(_ text: String) {
        suppressEditorTextUpdate = true
        editorText = text
        suppressEditorTextUpdate = false
    }


}

