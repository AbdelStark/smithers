import Foundation

@MainActor
final class ChatSessionState: ObservableObject, Identifiable {
    let id: String
    let title: String
    let createdAt: Date

    @Published var messages: [ChatMessage]
    @Published var draft: String
    @Published var draftImages: [ChatImage]
    @Published var isTurnInProgress: Bool
    @Published var activeDiffPreview: DiffPreview?
    @Published var activeSessionDiff: SessionDiffSnapshot?
    @Published var activeSkills: [ActiveSkill]

    var turnDiffs: [String: String]
    var turnDiffOrder: [String]
    var streamingTurnDiffs: [String: String]
    var turnHistoryOrder: [String]

    init(
        id: String,
        title: String,
        createdAt: Date = Date(),
        messages: [ChatMessage],
        draft: String = "",
        draftImages: [ChatImage] = [],
        isTurnInProgress: Bool = false,
        activeDiffPreview: DiffPreview? = nil,
        activeSessionDiff: SessionDiffSnapshot? = nil,
        activeSkills: [ActiveSkill] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.messages = messages
        self.draft = draft
        self.draftImages = draftImages
        self.isTurnInProgress = isTurnInProgress
        self.activeDiffPreview = activeDiffPreview
        self.activeSessionDiff = activeSessionDiff
        self.activeSkills = activeSkills
        self.turnDiffs = [:]
        self.turnDiffOrder = []
        self.streamingTurnDiffs = [:]
        self.turnHistoryOrder = []
    }
}
