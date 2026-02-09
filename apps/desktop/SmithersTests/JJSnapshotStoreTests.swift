import XCTest
@testable import Smithers

@MainActor
final class JJSnapshotStoreTests: XCTestCase {

    private var tmpDir: URL!
    private var store: JJSnapshotStore!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Create .jj directory so the store can create .jj/smithers/snapshots.db
        let jjDir = tmpDir.appendingPathComponent(".jj")
        try? FileManager.default.createDirectory(at: jjDir, withIntermediateDirectories: true)

        store = JJSnapshotStore(workspacePath: tmpDir.path)
        try? store.setup()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - Setup

    func testSetup_createsDatabaseFile() throws {
        let dbPath = tmpDir
            .appendingPathComponent(".jj")
            .appendingPathComponent("smithers")
            .appendingPathComponent("snapshots.db")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbPath.path))
    }

    func testSetup_idempotent() throws {
        // Calling setup twice should not throw
        try store.setup()
    }

    // MARK: - Snapshot CRUD

    func testRecordSnapshot_andRetrieve() throws {
        try store.recordSnapshot(
            changeId: "change-1",
            commitId: "commit-1",
            description: "test snapshot",
            snapshotType: .aiChange,
            chatSessionId: "session-1",
            chatMessageIndex: 5
        )

        let snapshots = try store.snapshotsForWorkspace()
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].changeId, "change-1")
        XCTAssertEqual(snapshots[0].commitId, "commit-1")
        XCTAssertEqual(snapshots[0].description, "test snapshot")
        XCTAssertEqual(snapshots[0].snapshotType, .aiChange)
        XCTAssertEqual(snapshots[0].chatSessionId, "session-1")
        XCTAssertEqual(snapshots[0].chatMessageIndex, 5)
    }

    func testRecordSnapshot_multipleSnapshots() throws {
        try store.recordSnapshot(
            changeId: "c1", commitId: nil, description: "first",
            snapshotType: .aiChange
        )
        try store.recordSnapshot(
            changeId: "c2", commitId: nil, description: "second",
            snapshotType: .userSave
        )

        let snapshots = try store.snapshotsForWorkspace()
        XCTAssertEqual(snapshots.count, 2)
    }

    // MARK: - Query Methods

    func testSnapshotsForChat() throws {
        try store.recordSnapshot(
            changeId: "c1", commitId: nil, description: "msg1",
            snapshotType: .aiChange, chatSessionId: "session-A", chatMessageIndex: 0
        )
        try store.recordSnapshot(
            changeId: "c2", commitId: nil, description: "msg2",
            snapshotType: .aiChange, chatSessionId: "session-B", chatMessageIndex: 0
        )
        try store.recordSnapshot(
            changeId: "c3", commitId: nil, description: "msg3",
            snapshotType: .aiChange, chatSessionId: "session-A", chatMessageIndex: 1
        )

        let sessionA = try store.snapshotsForChat(sessionId: "session-A")
        XCTAssertEqual(sessionA.count, 2)
        // Should be ordered by createdAt ASC
        XCTAssertEqual(sessionA[0].changeId, "c1")
        XCTAssertEqual(sessionA[1].changeId, "c3")

        let sessionB = try store.snapshotsForChat(sessionId: "session-B")
        XCTAssertEqual(sessionB.count, 1)
    }

    func testSnapshotsForChange() throws {
        try store.recordSnapshot(
            changeId: "change-X", commitId: nil, description: "first",
            snapshotType: .aiChange
        )
        try store.recordSnapshot(
            changeId: "change-X", commitId: nil, description: "second",
            snapshotType: .userSave
        )
        try store.recordSnapshot(
            changeId: "change-Y", commitId: nil, description: "other",
            snapshotType: .aiChange
        )

        let forX = try store.snapshotsForChange(changeId: "change-X")
        XCTAssertEqual(forX.count, 2)
    }

    func testLatestSnapshot() throws {
        try store.recordSnapshot(
            changeId: "c1", commitId: nil, description: "old",
            snapshotType: .aiChange
        )
        try store.recordSnapshot(
            changeId: "c2", commitId: nil, description: "new",
            snapshotType: .userSave
        )

        let latest = try store.latestSnapshot()
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.changeId, "c2")
    }

    func testLatestSnapshot_empty() throws {
        let latest = try store.latestSnapshot()
        XCTAssertNil(latest)
    }

    func testSnapshotForMessage() throws {
        try store.recordSnapshot(
            changeId: "c1", commitId: nil, description: "msg0",
            snapshotType: .aiChange, chatSessionId: "s1", chatMessageIndex: 0
        )
        try store.recordSnapshot(
            changeId: "c2", commitId: nil, description: "msg3",
            snapshotType: .aiChange, chatSessionId: "s1", chatMessageIndex: 3
        )

        let found = try store.snapshotForMessage(sessionId: "s1", messageIndex: 3)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.changeId, "c2")

        let notFound = try store.snapshotForMessage(sessionId: "s1", messageIndex: 99)
        XCTAssertNil(notFound)
    }

    // MARK: - Agent Workspace Operations

    func testRecordAgentWorkspace_andRetrieve() throws {
        let record = AgentWorkspaceRecord(
            id: "agent-auth",
            workspacePath: "/tmp/agent-auth",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "Add authentication",
            chatSessionId: "session-1",
            status: AgentStatus.running.rawValue,
            priority: MergeQueuePriority.normal.rawValue,
            createdAt: Date()
        )

        try store.recordAgentWorkspace(record)
        let agents = try store.agentWorkspaces()
        XCTAssertEqual(agents.count, 1)
        XCTAssertEqual(agents[0].id, "agent-auth")
        XCTAssertEqual(agents[0].task, "Add authentication")
    }

    func testUpdateAgentStatus() throws {
        let record = AgentWorkspaceRecord(
            id: "agent-1",
            workspacePath: "/tmp/agent",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "task",
            chatSessionId: nil,
            status: AgentStatus.running.rawValue,
            priority: 1,
            createdAt: Date()
        )
        try store.recordAgentWorkspace(record)

        try store.updateAgentStatus(id: "agent-1", status: .completed)
        let agents = try store.agentWorkspaces()
        XCTAssertEqual(agents[0].status, AgentStatus.completed.rawValue)
        XCTAssertNotNil(agents[0].completedAt)
    }

    func testUpdateAgentStatus_merged_setsMergedAt() throws {
        let record = AgentWorkspaceRecord(
            id: "agent-1",
            workspacePath: "/tmp/agent",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "task",
            chatSessionId: nil,
            status: AgentStatus.running.rawValue,
            priority: 1,
            createdAt: Date()
        )
        try store.recordAgentWorkspace(record)

        try store.updateAgentStatus(id: "agent-1", status: .merged)
        let agents = try store.agentWorkspaces()
        XCTAssertNotNil(agents[0].mergedAt)
    }

    func testUpdateAgentStatus_withTestOutput() throws {
        let record = AgentWorkspaceRecord(
            id: "agent-1",
            workspacePath: "/tmp/agent",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "task",
            chatSessionId: nil,
            status: AgentStatus.running.rawValue,
            priority: 1,
            createdAt: Date()
        )
        try store.recordAgentWorkspace(record)

        try store.updateAgentStatus(id: "agent-1", status: .failed, testOutput: "Test error: assertion failed")
        let agents = try store.agentWorkspaces()
        XCTAssertEqual(agents[0].testOutput, "Test error: assertion failed")
    }

    func testAgentWorkspaces_filterByStatus() throws {
        let record1 = AgentWorkspaceRecord(
            id: "agent-1",
            workspacePath: "/tmp/a1",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "task1",
            chatSessionId: nil,
            status: AgentStatus.running.rawValue,
            priority: 1,
            createdAt: Date()
        )
        let record2 = AgentWorkspaceRecord(
            id: "agent-2",
            workspacePath: "/tmp/a2",
            mainWorkspacePath: tmpDir.path,
            changeId: "c2",
            task: "task2",
            chatSessionId: nil,
            status: AgentStatus.completed.rawValue,
            priority: 1,
            createdAt: Date()
        )
        try store.recordAgentWorkspace(record1)
        try store.recordAgentWorkspace(record2)

        let running = try store.agentWorkspaces(status: .running)
        XCTAssertEqual(running.count, 1)
        XCTAssertEqual(running[0].id, "agent-1")

        let completed = try store.agentWorkspaces(status: .completed)
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0].id, "agent-2")

        let all = try store.agentWorkspaces()
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - Merge Queue Log

    func testLogMergeQueueAction_andRetrieve() throws {
        // Need to create an agent workspace first (foreign key constraint)
        let record = AgentWorkspaceRecord(
            id: "agent-1",
            workspacePath: "/tmp/agent",
            mainWorkspacePath: tmpDir.path,
            changeId: "c1",
            task: "task",
            chatSessionId: nil,
            status: AgentStatus.running.rawValue,
            priority: 1,
            createdAt: Date()
        )
        try store.recordAgentWorkspace(record)

        try store.logMergeQueueAction(agentId: "agent-1", action: "spawned", details: "task details")
        try store.logMergeQueueAction(agentId: "agent-1", action: "enqueued")
        try store.logMergeQueueAction(agentId: "agent-1", action: "landed")

        let log = try store.mergeQueueLog(agentId: "agent-1")
        XCTAssertEqual(log.count, 3)
        // Should be ordered by timestamp ASC
        XCTAssertEqual(log[0].action, "spawned")
        XCTAssertEqual(log[0].details, "task details")
        XCTAssertEqual(log[1].action, "enqueued")
        XCTAssertNil(log[1].details)
        XCTAssertEqual(log[2].action, "landed")
    }

    func testMergeQueueLog_emptyForUnknownAgent() throws {
        let log = try store.mergeQueueLog(agentId: "nonexistent")
        XCTAssertTrue(log.isEmpty)
    }
}
