import XCTest
@testable import Smithers

@MainActor
final class JJServiceTests: XCTestCase {

    private var service: JJService!

    override func setUp() {
        super.setUp()
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        service = JJService(workingDirectory: tmpDir)
    }

    // MARK: - VCS Detection

    func testDetectVCS_noVCS() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let svc = JJService(workingDirectory: tmpDir)
        let result = svc.detectVCS()
        XCTAssertEqual(result, .none)
        XCTAssertFalse(svc.isAvailable)
    }

    func testDetectVCS_gitOnly() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let svc = JJService(workingDirectory: tmpDir)
        let result = svc.detectVCS()
        XCTAssertEqual(result, .gitOnly)
        XCTAssertFalse(svc.isAvailable)
    }

    func testDetectVCS_jjNative() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent(".jj"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let svc = JJService(workingDirectory: tmpDir)
        let result = svc.detectVCS()
        XCTAssertEqual(result, .jjNative)
        XCTAssertTrue(svc.isAvailable)
    }

    func testDetectVCS_jjColocated() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent(".jj"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let svc = JJService(workingDirectory: tmpDir)
        let result = svc.detectVCS()
        XCTAssertEqual(result, .jjColocated)
        XCTAssertTrue(svc.isAvailable)
    }

    // MARK: - parseChanges

    func testParseChanges_singleChange() throws {
        let json = """
        {"change_id": "abc12345", "commit_id": "def67890", "description": "feat: add auth", "author_name": "Test User", "author_email": "test@example.com", "timestamp": "2025-01-15T10:30:00Z", "empty": false, "working_copy": true, "parents": "parent1", "bookmarks": "main dev"}
        """
        let changes = try service.parseChanges(json)
        XCTAssertEqual(changes.count, 1)

        let change = changes[0]
        XCTAssertEqual(change.changeId, "abc12345")
        XCTAssertEqual(change.commitId, "def67890")
        XCTAssertEqual(change.description, "feat: add auth")
        XCTAssertEqual(change.authorName, "Test User")
        XCTAssertEqual(change.authorEmail, "test@example.com")
        XCTAssertFalse(change.isEmpty)
        XCTAssertTrue(change.isWorkingCopy)
        XCTAssertEqual(change.parents, ["parent1"])
        XCTAssertEqual(change.bookmarks, ["main", "dev"])
    }

    func testParseChanges_multipleChanges() throws {
        let json = """
        {"change_id": "aaa", "commit_id": "bbb", "description": "first", "author_name": "A", "author_email": "a@b.c", "timestamp": "2025-01-15T10:30:00Z", "empty": false, "working_copy": true, "parents": "", "bookmarks": ""}
        {"change_id": "ccc", "commit_id": "ddd", "description": "second", "author_name": "B", "author_email": "b@b.c", "timestamp": "2025-01-15T11:30:00Z", "empty": true, "working_copy": false, "parents": "aaa", "bookmarks": "main"}
        """
        let changes = try service.parseChanges(json)
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(changes[0].changeId, "aaa")
        XCTAssertEqual(changes[1].changeId, "ccc")
        XCTAssertTrue(changes[1].isEmpty)
        XCTAssertFalse(changes[1].isWorkingCopy)
    }

    func testParseChanges_emptyOutput() throws {
        let changes = try service.parseChanges("")
        XCTAssertTrue(changes.isEmpty)
    }

    func testParseChanges_invalidJSON_skipped() throws {
        let json = """
        not valid json
        {"change_id": "abc", "commit_id": "def", "description": "valid", "author_name": "", "author_email": "", "timestamp": "2025-01-15T10:30:00Z", "empty": false, "working_copy": false, "parents": "", "bookmarks": ""}
        """
        let changes = try service.parseChanges(json)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].changeId, "abc")
    }

    func testParseChange_throwsOnEmpty() {
        XCTAssertThrowsError(try service.parseChange("")) { error in
            guard case JJError.parseError = error else {
                XCTFail("Expected parseError, got \(error)")
                return
            }
        }
    }

    // MARK: - parseDiffSummary

    func testParseDiffSummary_allStatuses() {
        let output = """
        M src/main.swift
        A src/new.swift
        D src/old.swift
        R src/renamed.swift => src/newname.swift
        """
        let files = service.parseDiffSummary(output)
        XCTAssertEqual(files.count, 4)

        XCTAssertEqual(files[0].status, .modified)
        XCTAssertEqual(files[0].path, "src/main.swift")

        XCTAssertEqual(files[1].status, .added)
        XCTAssertEqual(files[1].path, "src/new.swift")

        XCTAssertEqual(files[2].status, .deleted)
        XCTAssertEqual(files[2].path, "src/old.swift")

        XCTAssertEqual(files[3].status, .renamed)
        XCTAssertEqual(files[3].path, "src/newname.swift")
        XCTAssertEqual(files[3].oldPath, "src/renamed.swift")
    }

    func testParseDiffSummary_emptyOutput() {
        let files = service.parseDiffSummary("")
        XCTAssertTrue(files.isEmpty)
    }

    func testParseDiffSummary_unknownStatusSkipped() {
        let output = "X unknown/file.txt\nM valid/file.txt"
        let files = service.parseDiffSummary(output)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path, "valid/file.txt")
    }

    func testParseDiffSummary_shortLineSkipped() {
        let output = "M\nA valid.swift"
        let files = service.parseDiffSummary(output)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path, "valid.swift")
    }

    // MARK: - parseConflicts

    func testParseConflicts_detectsConflictLines() {
        let output = """
        Working copy changes:
        M src/main.swift
        C src/conflict.swift
        C src/another.swift
        """
        let conflicts = service.parseConflicts(output)
        XCTAssertEqual(conflicts.count, 2)
        XCTAssertEqual(conflicts[0], "src/conflict.swift")
        XCTAssertEqual(conflicts[1], "src/another.swift")
    }

    func testParseConflicts_noConflicts() {
        let output = "Working copy changes:\nM src/main.swift"
        let conflicts = service.parseConflicts(output)
        XCTAssertTrue(conflicts.isEmpty)
    }

    // MARK: - parseOperations

    func testParseOperations_parsesCorrectly() {
        let json = """
        {"operation_id": "op123", "description": "describe change", "timestamp": "2025-01-15T10:30:00Z", "user": "test@host"}
        {"operation_id": "op456", "description": "new change", "timestamp": "2025-01-15T11:00:00Z", "user": "test@host"}
        """
        let ops = service.parseOperations(json)
        XCTAssertEqual(ops.count, 2)
        XCTAssertEqual(ops[0].operationId, "op123")
        XCTAssertEqual(ops[0].description, "describe change")
        XCTAssertEqual(ops[0].user, "test@host")
        XCTAssertEqual(ops[1].operationId, "op456")
    }

    func testParseOperations_emptyOutput() {
        let ops = service.parseOperations("")
        XCTAssertTrue(ops.isEmpty)
    }

    // MARK: - parseBookmarks

    func testParseBookmarks_parsesCorrectly() {
        let json = """
        {"name": "main", "change_id": "abc12345", "is_tracking": true, "remote": "origin"}
        {"name": "feature", "change_id": "def67890", "is_tracking": false, "remote": ""}
        """
        let bookmarks = service.parseBookmarks(json)
        XCTAssertEqual(bookmarks.count, 2)

        XCTAssertEqual(bookmarks[0].name, "main")
        XCTAssertEqual(bookmarks[0].changeId, "abc12345")
        XCTAssertTrue(bookmarks[0].isTracking)
        XCTAssertEqual(bookmarks[0].remote, "origin")

        XCTAssertEqual(bookmarks[1].name, "feature")
        XCTAssertFalse(bookmarks[1].isTracking)
        XCTAssertNil(bookmarks[1].remote)
    }

    func testParseBookmarks_emptyRemoteIsNil() {
        let json = """
        {"name": "test", "change_id": "aaa", "is_tracking": false, "remote": ""}
        """
        let bookmarks = service.parseBookmarks(json)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertNil(bookmarks[0].remote)
    }

    // MARK: - parseWorkspaceList

    func testParseWorkspaceList_parsesCorrectly() {
        let output = """
        default: abc12345 /path/to/repo
        agent-auth: def67890 /path/to/agent (stale)
        """
        let workspaces = service.parseWorkspaceList(output)
        XCTAssertEqual(workspaces.count, 2)

        XCTAssertEqual(workspaces[0].name, "default")
        XCTAssertEqual(workspaces[0].workingCopyChangeId, "abc12345")
        XCTAssertFalse(workspaces[0].isStale)

        XCTAssertEqual(workspaces[1].name, "agent-auth")
        XCTAssertEqual(workspaces[1].workingCopyChangeId, "def67890")
        XCTAssertTrue(workspaces[1].isStale)
    }

    func testParseWorkspaceList_emptyOutput() {
        let workspaces = service.parseWorkspaceList("")
        XCTAssertTrue(workspaces.isEmpty)
    }

    // MARK: - JJChange helpers

    func testJJChange_shortChangeId() {
        let change = JJChange(
            changeId: "abcdefghijklmnop",
            commitId: "", description: "", authorName: "", authorEmail: "",
            timestamp: Date(), isEmpty: false, isWorkingCopy: false,
            parents: [], bookmarks: []
        )
        XCTAssertEqual(change.shortChangeId, "abcdefgh")
    }

    func testJJChange_firstLine() {
        let change = JJChange(
            changeId: "abc", commitId: "", description: "first line\nsecond line",
            authorName: "", authorEmail: "", timestamp: Date(),
            isEmpty: false, isWorkingCopy: false, parents: [], bookmarks: []
        )
        XCTAssertEqual(change.firstLine, "first line")
    }

    func testJJChange_firstLine_singleLine() {
        let change = JJChange(
            changeId: "abc", commitId: "", description: "only line",
            authorName: "", authorEmail: "", timestamp: Date(),
            isEmpty: false, isWorkingCopy: false, parents: [], bookmarks: []
        )
        XCTAssertEqual(change.firstLine, "only line")
    }

    // MARK: - JJFileDiff helpers

    func testJJFileDiff_statusIcon() {
        XCTAssertEqual(JJFileDiff(status: .modified, path: "f", oldPath: nil).statusIcon, "pencil")
        XCTAssertEqual(JJFileDiff(status: .added, path: "f", oldPath: nil).statusIcon, "plus")
        XCTAssertEqual(JJFileDiff(status: .deleted, path: "f", oldPath: nil).statusIcon, "minus")
        XCTAssertEqual(JJFileDiff(status: .renamed, path: "f", oldPath: nil).statusIcon, "arrow.right")
    }

    func testJJFileDiff_statusColor() {
        XCTAssertEqual(JJFileDiff(status: .modified, path: "f", oldPath: nil).statusColor, "orange")
        XCTAssertEqual(JJFileDiff(status: .added, path: "f", oldPath: nil).statusColor, "green")
        XCTAssertEqual(JJFileDiff(status: .deleted, path: "f", oldPath: nil).statusColor, "red")
        XCTAssertEqual(JJFileDiff(status: .renamed, path: "f", oldPath: nil).statusColor, "blue")
    }
}
