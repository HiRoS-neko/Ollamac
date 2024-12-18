//
//  MessageViewModel.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import Foundation
import OllamaKit
import SwiftData

@MainActor
@Observable
final class MessageViewModel {
    private var modelContext: ModelContext
    private var generationTask: Task<Void, Never>?
    
    var messages: [Message] = []
    var tempResponse: String = ""
    var loading: MessageViewModelLoading?
    var error: MessageViewModelError?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func load(of chat: Chat?) {
        guard let chat = chat else { return }
        
        let chatId = chat.id
        let predicate = #Predicate<Message> { $0.chat?.id == chatId }
        let sortDescriptor = SortDescriptor(\Message.createdAt)
        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [sortDescriptor])
        
        self.loading = .load
        
        do {
            defer { self.loading = nil }
            self.messages = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = .load(error.localizedDescription)
        }
    }
    
    func generateAt(index: Int){
        let range = index..<self.messages.count
        removeInRange(range: range)
    }
    
    
    func generate(_ ollamaKit: OllamaKit, activeChat: Chat, prompt: String) {
        let message = Message(prompt: prompt)
        message.chat = activeChat
        self.messages.append(message)
        self.modelContext.insert(message)
        
        self.loading = .generate
        self.error = nil
        
        self.generationTask = Task {
            defer { self.loading = nil }
            
            do {
                let data = message.toOKChatRequestData(messages: self.messages)
                
                for try await chunk in ollamaKit.chat(data: data) {
                    if Task.isCancelled { break }
                    
                    self.tempResponse = self.tempResponse + (chunk.message?.content ?? "")
                    
                    if chunk.done {
                        message.response = self.tempResponse
                        activeChat.modifiedAt = .now
                        self.tempResponse = ""
                        
                        if self.messages.count == 1 {
                            self.generateTitle(ollamaKit, activeChat: activeChat)
                        }
                    }
                }
            } catch {
                self.error = .generate(error.localizedDescription)
            }
        }
    }
    
    func regenerateAt(_ ollamaKit: OllamaKit, activeChat: Chat, index: Int){
        let range = index+1..<self.messages.count
        removeInRange(range: range)
        regenerate(ollamaKit, activeChat: activeChat)
    }
    
    func removeInRange(range : Range<Int>){
        for index in range {
            let message = self.messages[index]
            modelContext.delete(message)
        }
        self.messages.removeLast(range.count)
    }
    
    func regenerate(_ ollamaKit: OllamaKit, activeChat: Chat) {
        guard let lastMessage = messages.last else { return }
        lastMessage.response = nil
        
        self.loading = .generate
        self.error = nil
        
        self.generationTask = Task {
            defer { self.loading = nil }
            do {
                let data = lastMessage.toOKChatRequestData(messages: self.messages)
                
                for try await chunk in ollamaKit.chat(data: data) {
                    if Task.isCancelled { break }
                    
                    self.tempResponse = self.tempResponse + (chunk.message?.content ?? "")
                    
                    if chunk.done {
                        lastMessage.response = self.tempResponse
                        activeChat.modifiedAt = .now
                        self.tempResponse = ""
                    }
                }
            } catch {
                self.error = .generate(error.localizedDescription)
            }
        }
    }
    
    private func generateTitle(_ ollamaKit: OllamaKit, activeChat: Chat) {
        var requestMessages = [OKChatRequestData.Message]()
        
        for message in self.messages {
            let userMessage = OKChatRequestData.Message(role: .user, content: message.prompt)
            let assistantMessage = OKChatRequestData.Message(role: .assistant, content: message.response ?? "")
            
            requestMessages.append(userMessage)
            requestMessages.append(assistantMessage)
        }
        
        let userMessage = OKChatRequestData.Message(role: .user, content: "Just reply with a short title about this conversation.")
        requestMessages.append(userMessage)
        
        self.generationTask = Task {
            defer { self.loading = nil }
            
            do {
                for try await chunk in ollamaKit.chat(data: OKChatRequestData(model: activeChat.model, messages: requestMessages)) {
                    if Task.isCancelled { break }
                    
                    if activeChat.name == "New Chat" {
                        activeChat.name = ""
                        activeChat.name += chunk.message?.content ?? ""
                    } else {
                        activeChat.name += chunk.message?.content ?? ""
                    }
                    
                    if chunk.done {
                        activeChat.modifiedAt = .now
                    }
                }
            } catch {
                self.error = .generateTitle(error.localizedDescription)
            }
        }
    }
    
    func cancelGeneration() {
        self.generationTask?.cancel()
        self.loading = .generate
    }
}

enum MessageViewModelLoading {
    case load
    case generate
}

enum MessageViewModelError: Error {
    case load(String)
    case generate(String)
    case generateTitle(String)
}
