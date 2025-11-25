//
//  ChatMessageComponents.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// Chat bubble for displaying user and assistant messages
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.role == .user ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "AI Assistant"): \(message.content)")
    }
}

/// Animated typing indicator for assistant responses
struct TypingIndicator: View {
    @State private var animationPhase = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
            )

            Spacer()
        }
        .accessibilityLabel("AI is typing")
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.default) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Previews
#Preview("Message Bubble - User") {
    MessageBubble(
        message: ChatMessage(
            id: UUID(),
            role: .user,
            content: "Create a task to buy groceries",
            timestamp: Date()
        )
    )
    .padding()
}

#Preview("Message Bubble - Assistant") {
    MessageBubble(
        message: ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "I've created a task \"Buy groceries\" for you.",
            timestamp: Date()
        )
    )
    .padding()
}

#Preview("Typing Indicator") {
    TypingIndicator()
        .padding()
}
