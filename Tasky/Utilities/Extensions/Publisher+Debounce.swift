//
//  Publisher+Debounce.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import Combine
import Foundation

extension Publisher where Output == String {

    /// Debounces string publisher for text input
    /// Standard 300ms delay for search/filter text fields
    func debounceForTextInput() -> Publishers.Debounce<Self, RunLoop> {
        self.debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    }
}

extension Publisher {

    /// Debounces publisher with custom duration
    /// - Parameter milliseconds: Debounce delay in milliseconds
    func debounce(milliseconds: Int) -> Publishers.Debounce<Self, RunLoop> {
        self.debounce(for: .milliseconds(milliseconds), scheduler: RunLoop.main)
    }
}
