//
//  ChatView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 8/2/24.
//

import ChatField
import Defaults
import OllamaKit
import SwiftUI
import ViewCondition

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    @State private var ollamaKit: OllamaKit
    @State private var prompt: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented: Bool = false
    
    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                List(messageViewModel.messages) { message in
                    let lastMessageId = messageViewModel.messages.last?.id
                    
                    UserMessageView(
                        content: message.prompt,
                        identifier: message.id,
                        copyAction: self.copyAction,
                        generateAtAction: self.generateAtAction
                    )
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                    
                    AssistantMessageView(
                        content: message.response ?? messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        isLastMessage: lastMessageId == message.id,
                        identifier: message.id,
                        copyAction: self.copyAction,
                        regenerateAction: self.regenerateAction,
                        regenerateAtAction: self.regenerateAtAction
                    )
                    .id(message)
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                    .if(lastMessageId == message.id) { view in
                        view.padding(.bottom)
                    }
                }
                
                VStack {
                    ChatField("Write your message here", text: $prompt) {
                        if messageViewModel.loading != .generate {
                            generateAction()
                        }
                    } trailingAccessory: {
                        CircleButton(systemImage: messageViewModel.loading == .generate ? "stop.fill" : "arrow.up", action: generateAction)
                    } footer: {
                        if chatViewModel.loading != nil {
                            ProgressView()
                                .controlSize(.small)
                        } else if case .fetchModels(let message) = chatViewModel.error {
                            HStack {
                                Text(message)
                                    .foregroundStyle(.red)
                                
                                Button("Try Again", action: onActiveChatChanged)
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.blue)
                            }
                            .font(.callout)
                        } else if messageViewModel.messages.isEmpty == false {
                            ChatFieldFooterView("\u{2318}+R to regenerate the response")
                                .foregroundColor(.secondary)
                        } else {
                            ChatFieldFooterView("AI can make mistakes. Please double-check responses.")
                                .foregroundColor(.secondary)
                        }
                    }
                    .chatFieldStyle(.capsule)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.horizontal)
                .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
            }
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: chatViewModel.activeChat?.id) {
                self.onActiveChatChanged()
            }
            .onChange(of: messageViewModel.tempResponse) {
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .navigationTitle(chatViewModel.activeChat?.name ?? "Ollamac")
        .navigationSubtitle(chatViewModel.activeChat?.model ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Show Preferences", systemImage: "sidebar.trailing") {
                    isPreferencesPresented.toggle()
                }
            }
        }
        .inspector(isPresented: $isPreferencesPresented) {
            ChatPreferencesView(ollamaKit: $ollamaKit)
                .inspectorColumnWidth(min: 320, ideal: 320)
        }
    }
    
    private func onActiveChatChanged() {
        prompt = ""
        
        if let activeChat = chatViewModel.activeChat, let host = activeChat.host, let baseURL = URL(string: host) {
            ollamaKit = OllamaKit(baseURL: baseURL)
            chatViewModel.fetchModels(ollamaKit)
        }
    }
    
    private func copyAction(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func generateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: prompt)
        }
        
        prompt = ""
    }
    
    private func generateAtAction(_ identifier: UUID) {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard chatViewModel.activeChat != nil else { return }
            
            if let i = messageViewModel.messages.firstIndex(where: { $0.id == identifier }) {
                let prompt = messageViewModel.messages[i].prompt
                messageViewModel.generateAt(index: i)
                self.prompt = prompt
            }
        }
    }
    
    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            messageViewModel.regenerate(ollamaKit, activeChat: activeChat)
        }
        
        prompt = ""
    }

    private func regenerateAtAction(_ identifier: UUID) {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            if let i = messageViewModel.messages.firstIndex(where: { $0.id == identifier }) {
                messageViewModel.regenerateAt(ollamaKit, activeChat: activeChat, index: i)
            }
        }
        
        prompt = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard messageViewModel.messages.count > 0 else { return }
        guard let lastMessage = messageViewModel.messages.last else { return }
        
        DispatchQueue.main.async {
            proxy.scrollTo(lastMessage, anchor: .bottom)
        }
    }
}
