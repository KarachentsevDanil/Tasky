//
//  LoadingState.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Generic loading state for async operations
/// Provides better UX through explicit state handling
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)

    /// Whether the state is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Whether the state has loaded data
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// Whether the state has an error
    var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Get the loaded data if available
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }

    /// Get the error if available
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Equatable
extension LoadingState: Equatable where T: Equatable {
    static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsData), .loaded(let rhsData)):
            return lhsData == rhsData
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
