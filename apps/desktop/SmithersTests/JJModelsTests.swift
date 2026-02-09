import XCTest
@testable import Smithers

final class JJModelsTests: XCTestCase {

    // MARK: - MergeQueue

    func testMergeQueue_enqueueOrdersByPriority() {
        var queue = MergeQueue()

        let lowEntry = MergeQueueEntry(
            id: "low", agentId: "low", changeId: "c1", task: "low priority",
            priority: .low, status: .waiting, enqueuedAt: Date()
        )
        let highEntry = MergeQueueEntry(
            id: "high", agentId: "high", changeId: "c2", task: "high priority",
            priority: .high, status: .waiting, enqueuedAt: Date()
        )
        let normalEntry = MergeQueueEntry(
            id: "normal", agentId: "normal", changeId: "c3", task: "normal priority",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )

        queue.enqueue(lowEntry)
        queue.enqueue(highEntry)
        queue.enqueue(normalEntry)

        XCTAssertEqual(queue.entries.count, 3)
        XCTAssertEqual(queue.entries[0].id, "high")
        XCTAssertEqual(queue.entries[1].id, "normal")
        XCTAssertEqual(queue.entries[2].id, "low")
    }

    func testMergeQueue_dequeueReturnsFirstWaiting() {
        var queue = MergeQueue()

        let entry1 = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task1",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        let entry2 = MergeQueueEntry(
            id: "e2", agentId: "a2", changeId: "c2", task: "task2",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.enqueue(entry1)
        queue.enqueue(entry2)

        let dequeued = queue.dequeue()
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(dequeued?.id, "e1")
        XCTAssertEqual(dequeued?.status, .merging)
        XCTAssertNotNil(dequeued?.startedAt)
    }

    func testMergeQueue_dequeueReturnsNilWhenEmpty() {
        var queue = MergeQueue()
        XCTAssertNil(queue.dequeue())
    }

    func testMergeQueue_dequeueSkipsNonWaiting() {
        var queue = MergeQueue()

        var entry = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task",
            priority: .normal, status: .merging, enqueuedAt: Date()
        )
        queue.entries.append(entry)

        entry = MergeQueueEntry(
            id: "e2", agentId: "a2", changeId: "c2", task: "task2",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.entries.append(entry)

        let dequeued = queue.dequeue()
        XCTAssertEqual(dequeued?.id, "e2")
    }

    func testMergeQueue_remove() {
        var queue = MergeQueue()

        let entry = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.enqueue(entry)
        XCTAssertEqual(queue.entries.count, 1)

        queue.remove(agentId: "a1")
        XCTAssertTrue(queue.entries.isEmpty)
    }

    func testMergeQueue_reprioritize() {
        var queue = MergeQueue()

        let entry1 = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task1",
            priority: .low, status: .waiting, enqueuedAt: Date()
        )
        let entry2 = MergeQueueEntry(
            id: "e2", agentId: "a2", changeId: "c2", task: "task2",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.enqueue(entry1)
        queue.enqueue(entry2)

        // a2 (normal) should be first
        XCTAssertEqual(queue.entries[0].agentId, "a2")

        // Bump a1 to urgent
        queue.reprioritize(agentId: "a1", priority: .urgent)
        XCTAssertEqual(queue.entries[0].agentId, "a1")
        XCTAssertEqual(queue.entries[0].priority, .urgent)
    }

    func testMergeQueue_updateStatus_setsCompletedAt() {
        var queue = MergeQueue()

        let entry = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.enqueue(entry)

        queue.updateStatus(agentId: "a1", status: .landed)
        XCTAssertEqual(queue.entries[0].status, .landed)
        XCTAssertNotNil(queue.entries[0].completedAt)
    }

    func testMergeQueue_updateStatus_noCompletedAtForMerging() {
        var queue = MergeQueue()

        let entry = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        queue.enqueue(entry)

        queue.updateStatus(agentId: "a1", status: .merging)
        XCTAssertEqual(queue.entries[0].status, .merging)
        XCTAssertNil(queue.entries[0].completedAt)
    }

    // MARK: - MergeQueuePriority

    func testMergeQueuePriority_ordering() {
        XCTAssertTrue(MergeQueuePriority.low < MergeQueuePriority.normal)
        XCTAssertTrue(MergeQueuePriority.normal < MergeQueuePriority.high)
        XCTAssertTrue(MergeQueuePriority.high < MergeQueuePriority.urgent)
    }

    // MARK: - CommitStyle

    func testCommitStyle_displayNames() {
        XCTAssertEqual(CommitStyle.conventional.displayName, "Conventional Commits")
        XCTAssertEqual(CommitStyle.emojiConventional.displayName, "Emoji + Conventional")
        XCTAssertEqual(CommitStyle.ticketPrefixed("PROJ").displayName, "Ticket Prefixed (PROJ)")
        XCTAssertEqual(CommitStyle.imperative.displayName, "Imperative Mood")
        XCTAssertEqual(CommitStyle.freeform.displayName, "Freeform")
    }

    func testCommitStyle_exampleFormats() {
        XCTAssertTrue(CommitStyle.conventional.exampleFormat.contains("feat:"))
        XCTAssertTrue(CommitStyle.emojiConventional.exampleFormat.contains("✨"))
        XCTAssertTrue(CommitStyle.ticketPrefixed("JIRA").exampleFormat.contains("JIRA-123"))
        XCTAssertTrue(CommitStyle.imperative.exampleFormat.hasPrefix("Add"))
        XCTAssertFalse(CommitStyle.freeform.exampleFormat.isEmpty)
    }

    // MARK: - AgentStatus

    func testAgentStatus_displayNames() {
        XCTAssertEqual(AgentStatus.running.displayName, "Running")
        XCTAssertEqual(AgentStatus.completed.displayName, "Completed")
        XCTAssertEqual(AgentStatus.failed.displayName, "Failed")
        XCTAssertEqual(AgentStatus.inQueue.displayName, "In Queue")
        XCTAssertEqual(AgentStatus.merging.displayName, "Merging")
        XCTAssertEqual(AgentStatus.merged.displayName, "Merged")
        XCTAssertEqual(AgentStatus.conflicted.displayName, "Conflicted")
        XCTAssertEqual(AgentStatus.cancelled.displayName, "Cancelled")
    }

    func testAgentStatus_icons() {
        XCTAssertEqual(AgentStatus.running.icon, "circle.fill")
        XCTAssertEqual(AgentStatus.failed.icon, "xmark.circle")
        XCTAssertEqual(AgentStatus.conflicted.icon, "exclamationmark.triangle")
    }

    func testAgentStatus_rawValues() {
        XCTAssertEqual(AgentStatus.running.rawValue, "running")
        XCTAssertEqual(AgentStatus.inQueue.rawValue, "inQueue")
        XCTAssertEqual(AgentStatus(rawValue: "merged"), .merged)
        XCTAssertNil(AgentStatus(rawValue: "invalid"))
    }

    // MARK: - VCSPreferences defaults

    func testVCSPreferences_defaults() {
        let prefs = VCSPreferences()
        XCTAssertTrue(prefs.snapshotOnSave)
        XCTAssertTrue(prefs.snapshotOnAIChange)
        XCTAssertTrue(prefs.autoDetectCommitStyle)
        XCTAssertNil(prefs.commitStyleOverride)
        XCTAssertFalse(prefs.showInlineBlame)
        XCTAssertTrue(prefs.aiCommitMessages)
        XCTAssertFalse(prefs.gitNotesOnCommit)
        XCTAssertEqual(prefs.defaultRemote, "origin")
        XCTAssertEqual(prefs.maxConcurrentAgents, 5)
        XCTAssertNil(prefs.agentWorkspaceBasePath)
        XCTAssertTrue(prefs.agentSetupCommands.isEmpty)
        XCTAssertTrue(prefs.mergeQueueAutoRun)
        XCTAssertNil(prefs.mergeQueueTestCommand)
        XCTAssertTrue(prefs.mergeQueueAutoResolveConflicts)
        XCTAssertFalse(prefs.mergeQueueSpeculativeMerging)
    }

    // MARK: - JJError

    func testJJError_descriptions() {
        XCTAssertEqual(JJError.notAJJRepo.errorDescription, "Not a jj repository")
        XCTAssertTrue(JJError.commandFailed("oops").errorDescription!.contains("oops"))
        XCTAssertTrue(JJError.parseError("bad data").errorDescription!.contains("bad data"))
        XCTAssertTrue(JJError.conflictsDetected(["a.swift"]).errorDescription!.contains("a.swift"))
        XCTAssertTrue(JJError.workspaceNotFound("agent-1").errorDescription!.contains("agent-1"))
    }

    // MARK: - Snapshot.SnapshotType

    func testSnapshotType_rawValues() {
        XCTAssertEqual(Snapshot.SnapshotType.aiChange.rawValue, "ai_change")
        XCTAssertEqual(Snapshot.SnapshotType.userSave.rawValue, "user_save")
        XCTAssertEqual(Snapshot.SnapshotType.manualCommit.rawValue, "manual_commit")
    }

    // MARK: - SmithersNotePayload

    func testSmithersNotePayload_encodesAndDecodes() throws {
        let note = SmithersNotePayload(
            sessionId: "session-123",
            prompts: [
                SmithersNotePayload.PromptRecord(role: "user", content: "Add auth", timestamp: Date())
            ],
            model: "gpt-4",
            filesChanged: ["auth.swift"],
            snapshotIds: ["snap1"]
        )

        XCTAssertEqual(note.version, 1)
        XCTAssertEqual(note.smithersSessionId, "session-123")

        let data = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(SmithersNotePayload.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.smithersSessionId, "session-123")
        XCTAssertEqual(decoded.filesChanged, ["auth.swift"])
        XCTAssertEqual(decoded.prompts.count, 1)
        XCTAssertEqual(decoded.model, "gpt-4")
    }

    // MARK: - JJChange Codable

    func testJJChange_codableRoundTrip() throws {
        let change = JJChange(
            changeId: "abc", commitId: "def", description: "test",
            authorName: "Test", authorEmail: "test@test.com",
            timestamp: Date(timeIntervalSince1970: 1700000000),
            isEmpty: false, isWorkingCopy: true,
            parents: ["p1", "p2"], bookmarks: ["main"]
        )

        let data = try JSONEncoder().encode(change)
        let decoded = try JSONDecoder().decode(JJChange.self, from: data)
        XCTAssertEqual(decoded.changeId, "abc")
        XCTAssertEqual(decoded.commitId, "def")
        XCTAssertEqual(decoded.parents, ["p1", "p2"])
        XCTAssertEqual(decoded.bookmarks, ["main"])
    }

    // MARK: - AgentWorkspace equality

    func testAgentWorkspace_equalityBasedOnIdAndStatus() {
        let ws1 = AgentWorkspace(
            id: "agent-1", directory: URL(fileURLWithPath: "/tmp/a"),
            changeId: "c1", task: "task1", chatSessionId: "s1",
            status: .running, createdAt: Date(), filesChanged: []
        )
        var ws2 = AgentWorkspace(
            id: "agent-1", directory: URL(fileURLWithPath: "/tmp/b"),
            changeId: "c2", task: "task2", chatSessionId: "s2",
            status: .running, createdAt: Date(), filesChanged: []
        )

        XCTAssertEqual(ws1, ws2, "Same id + status should be equal")

        ws2 = AgentWorkspace(
            id: "agent-1", directory: URL(fileURLWithPath: "/tmp/b"),
            changeId: "c2", task: "task2", chatSessionId: "s2",
            status: .completed, createdAt: Date(), filesChanged: []
        )
        XCTAssertNotEqual(ws1, ws2, "Same id but different status should not be equal")
    }

    // MARK: - MergeQueueEntry

    func testMergeQueueEntry_defaultOptionals() {
        let entry = MergeQueueEntry(
            id: "e1", agentId: "a1", changeId: "c1", task: "task",
            priority: .normal, status: .waiting, enqueuedAt: Date()
        )
        XCTAssertNil(entry.mergeChangeId)
        XCTAssertNil(entry.testResult)
        XCTAssertNil(entry.conflictFiles)
        XCTAssertNil(entry.startedAt)
        XCTAssertNil(entry.completedAt)
    }
}
