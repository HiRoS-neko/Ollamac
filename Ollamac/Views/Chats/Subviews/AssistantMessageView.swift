//
//  AssistantMessageView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 8/2/24.
//

import Defaults
import MarkdownUI
import SwiftUI
import ViewCondition

struct AssistantMessageView: View {
    private let content: String
    private let identifier: UUID
    private let isGenerating: Bool
    private let isLastMessage: Bool
    private let copyAction: (_ content: String) -> Void
    private let regenerateAction: () -> Void
    private let regenerateAtAction: (_ identifier: UUID) -> Void
    
    init(content: String, isGenerating: Bool, isLastMessage: Bool, identifier: UUID, copyAction: @escaping (_ content: String) -> Void, regenerateAction: @escaping () -> Void, regenerateAtAction: @escaping (_ identifier: UUID) -> Void) {
        self.content = content
        self.identifier = identifier
        self.isGenerating = isGenerating
        self.isLastMessage = isLastMessage
        self.copyAction = copyAction
        self.regenerateAction = regenerateAction
        self.regenerateAtAction = regenerateAtAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assistant")
                .fontWeight(.semibold)
            
            if isGenerating && content.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else {
                Markdown(content)
                    .markdownTextStyle {
                        FontSize(10)
                    }
                    .textSelection(.enabled)
                    .markdownTheme(.ollamac)
                    .if(Defaults[.experimentalCodeHighlighting]) { view in
                        view.markdownCodeSyntaxHighlighter(.ollamac)
                    }
                    .padding(8)
                    .background(.regularMaterial)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 16) {
                    MessageButton("Copy", systemImage: "doc.on.doc", action: { copyAction(content) })
                    
                    MessageButton("Regenerate", systemImage: "arrow.triangle.2.circlepath", action: regenerateAction)
                        .keyboardShortcut("r", modifiers: [.command])
                        .visible(if: isLastMessage, removeCompletely: true)
                    MessageButton("Regenerate", systemImage: "arrow.triangle.2.circlepath", action: { regenerateAtAction(identifier) })
                        .visible(if: !isLastMessage, removeCompletely: true)
                }
                .hide(if: isLastMessage && isGenerating)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
