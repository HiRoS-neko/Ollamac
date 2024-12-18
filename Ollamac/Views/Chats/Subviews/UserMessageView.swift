//
//  UserMessageView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 8/2/24.
//

import Defaults
import SwiftUI
import ViewCondition

struct UserMessageView: View {
    @Default(.fontSize) private var fontSize

    private let windowWidth = NSApplication.shared.windows.first?.frame.width ?? 0
    private let content: String
    private let identifier: UUID
    private let copyAction: (_ content: String) -> Void
    private let generateAtAction: (_ identifier: UUID) -> Void
    
    init(content: String, identifier : UUID, copyAction: @escaping (_ content: String) -> Void, generateAtAction: @escaping (_ identifier: UUID) -> Void) {
        self.content = content
        self.copyAction = copyAction
        self.identifier = identifier
        self.generateAtAction = generateAtAction
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(content)
                    .padding(8)
                    .background(.accent)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .font(Font.system(size: fontSize))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(spacing: 16){
                    MessageButton("Copy", systemImage: "doc.on.doc", action: { copyAction(content) })
                    MessageButton("Edit", systemImage: "square.and.pencil", action: { generateAtAction(identifier) })
                }
            }
            .frame(maxWidth: windowWidth / 2, alignment: .trailing)
        }
    }
}
