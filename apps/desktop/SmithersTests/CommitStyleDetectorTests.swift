import XCTest
@testable import Smithers

final class CommitStyleDetectorTests: XCTestCase {

    // MARK: - Conventional Commits

    func testDetect_conventionalCommits() {
        let messages = [
            "feat: add user authentication",
            "fix: resolve login bug",
            "chore: update dependencies",
            "docs: add API documentation",
            "refactor: simplify auth flow",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .conventional)
    }

    func testDetect_conventionalWithScope() {
        let messages = [
            "feat(auth): add login",
            "fix(ui): resolve button alignment",
            "chore(deps): update packages",
            "test(auth): add unit tests",
            "other unrelated message",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .conventional)
    }

    // MARK: - Emoji Conventional

    func testDetect_emojiConventional() {
        let messages = [
            "✨ feat: add new feature",
            "🐛 fix: resolve bug",
            "♻️ refactor: clean up code",
            "📝 docs: update readme",
            "🔧 chore: update config",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .emojiConventional)
    }

    // MARK: - Ticket Prefixed

    func testDetect_ticketPrefixed() {
        let messages = [
            "PROJ-123: add authentication",
            "PROJ-456: fix login bug",
            "PROJ-789: update dependencies",
            "unrelated message",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        if case .ticketPrefixed(let prefix) = style {
            XCTAssertEqual(prefix, "PROJ")
        } else {
            XCTFail("Expected ticketPrefixed, got \(style)")
        }
    }

    func testDetect_ticketPrefixed_differentPrefixes() {
        let messages = [
            "ABC-1: first",
            "ABC-2: second",
            "ABC-3: third",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        if case .ticketPrefixed(let prefix) = style {
            XCTAssertEqual(prefix, "ABC")
        } else {
            XCTFail("Expected ticketPrefixed")
        }
    }

    // MARK: - Imperative

    func testDetect_imperative() {
        let messages = [
            "Add user authentication",
            "Fix login bug",
            "Update dependencies",
            "Remove unused imports",
            "Refactor auth module",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .imperative)
    }

    // MARK: - Freeform

    func testDetect_freeform() {
        let messages = [
            "updated the thing",
            "working on stuff",
            "more changes",
            "wip",
            "stuff",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .freeform)
    }

    // MARK: - Edge Cases

    func testDetect_emptyMessages() {
        let style = CommitStyleDetector.detect(from: [])
        XCTAssertEqual(style, .freeform)
    }

    func testDetect_allEmptyStrings() {
        let messages = ["", "  ", "\n"]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .freeform)
    }

    func testDetect_filtersEmptyDescriptions() {
        let messages = [
            "(empty) wip",
            "feat: real change",
            "fix: another one",
            "chore: third one",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        // "(empty)" prefixed messages are filtered out, so 3/3 conventional = 100%
        XCTAssertEqual(style, .conventional)
    }

    func testDetect_thresholdBehavior() {
        // 2 out of 5 conventional = 40% — exactly at threshold
        let messages = [
            "feat: first",
            "fix: second",
            "random message three",
            "random message four",
            "random message five",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .conventional)
    }

    func testDetect_belowThreshold() {
        // 1 out of 5 conventional = 20% — below threshold
        let messages = [
            "feat: first",
            "random two",
            "random three",
            "random four",
            "random five",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .freeform)
    }

    func testDetect_emojiTakesPriorityOverConventional() {
        // When both emoji+conventional and plain conventional reach threshold,
        // emoji should win because it's checked first
        let messages = [
            "✨ feat: add feature",
            "🐛 fix: fix bug",
            "📝 docs: add docs",
            "feat: plain conventional",
            "fix: plain fix",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .emojiConventional)
    }

    func testDetect_mixedStyles_highestWins() {
        // Mix of styles where no single style reaches 40%
        let messages = [
            "feat: conventional",
            "PROJ-1: ticket",
            "Add imperative",
            "random freeform",
            "another freeform",
        ]
        let style = CommitStyleDetector.detect(from: messages)
        XCTAssertEqual(style, .freeform)
    }
}
