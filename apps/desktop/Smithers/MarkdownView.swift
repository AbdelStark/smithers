import SwiftUI

struct MarkdownView: View {
    let text: String
    let theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(makeAttributed(text))
                    .font(.system(size: Typography.base))
                    .foregroundStyle(theme.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
    }

    private func makeAttributed(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text) {
            return attributed
        }
        return AttributedString(text)
    }
}
