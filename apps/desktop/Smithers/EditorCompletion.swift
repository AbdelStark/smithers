import Foundation

struct EditorCompletionRequest: Sendable {
    let text: String
    let cursorOffset: Int
    let line: Int
    let column: Int
    let fileURL: URL?
    let languageName: String?
}

struct EditorEditLocation: Hashable, Sendable {
    let line: Int
    let column: Int
    let timestamp: Date
}
