import Foundation

struct SkillModal: Identifiable, Equatable {
    let id: String
    let skill: SkillItem

    init(skill: SkillItem) {
        self.skill = skill
        self.id = skill.id
    }
}
