import Foundation

struct NvimTextChunk: Equatable {
    let text: String
    let highlightId: Int?
}

struct NvimCmdlineState: Equatable {
    var isVisible: Bool
    var level: Int
    var prompt: String
    var firstc: String
    var indent: Int
    var cursorPos: Int
    var chunks: [NvimTextChunk]

    var contentText: String {
        chunks.map(\.text).joined()
    }

    var displayText: String {
        let prefix = String(repeating: " ", count: max(0, indent))
        return prefix + prompt + contentText
    }

    static let empty = NvimCmdlineState(
        isVisible: false,
        level: 0,
        prompt: "",
        firstc: "",
        indent: 0,
        cursorPos: 0,
        chunks: []
    )
}

struct NvimPopupMenuItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let kind: String
    let menu: String
    let info: String
}

struct NvimPopupMenuState: Equatable {
    var isVisible: Bool
    var items: [NvimPopupMenuItem]
    var selected: Int
    var row: Int
    var col: Int
    var grid: Int

    var selectedItem: NvimPopupMenuItem? {
        guard selected >= 0, selected < items.count else { return nil }
        return items[selected]
    }

    static let empty = NvimPopupMenuState(
        isVisible: false,
        items: [],
        selected: -1,
        row: 0,
        col: 0,
        grid: 0
    )
}

enum NvimMessageEvent: String {
    case msgShow
    case msgShowMode
    case msgShowCmd
    case msgRuler
}

enum NvimMessageView: String {
    case mini
    case float
    case none
}

struct NvimMessageRoute: Equatable {
    var event: NvimMessageEvent
    var kinds: [String]?
    var view: NvimMessageView
    var timeout: TimeInterval?
    var minHeight: Int?
    var maxHeight: Int?

    func matches(event: NvimMessageEvent, kind: String, lineCount: Int) -> Bool {
        guard self.event == event else { return false }
        if let minHeight, lineCount < minHeight { return false }
        if let maxHeight, lineCount > maxHeight { return false }
        guard let kinds else { return true }
        return kinds.contains(kind)
    }

    static let defaultRoutes: [NvimMessageRoute] = [
        NvimMessageRoute(event: .msgShow, kinds: ["emsg", "echoerr", "lua_error", "rpc_error"], view: .float, timeout: 0),
        NvimMessageRoute(event: .msgShow, kinds: ["wmsg"], view: .float, timeout: 4),
        NvimMessageRoute(event: .msgShow, kinds: ["search_count"], view: .mini, timeout: 2),
        NvimMessageRoute(event: .msgShow, kinds: nil, view: .float, timeout: 4),
        NvimMessageRoute(event: .msgShowMode, kinds: nil, view: .mini, timeout: nil),
        NvimMessageRoute(event: .msgShowCmd, kinds: nil, view: .mini, timeout: nil),
        NvimMessageRoute(event: .msgRuler, kinds: nil, view: .mini, timeout: nil),
    ]
}

struct NvimMessage: Identifiable, Equatable {
    let id: UUID
    var kind: String
    var text: String
    var timestamp: Date
}

struct NvimMiniMessageState: Equatable {
    var showMode: String
    var showCmd: String
    var ruler: String
    var status: String

    static let empty = NvimMiniMessageState(showMode: "", showCmd: "", ruler: "", status: "")
}
