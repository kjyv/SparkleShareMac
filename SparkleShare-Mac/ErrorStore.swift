//
//  ErrorStore.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 28.01.26.
//

import Foundation
import SwiftUI

enum GitOperationType: String, Codable {
    case add = "Add"
    case commit = "Commit"
    case push = "Push"
    case pull = "Pull"
    case clone = "Clone"
}

struct SyncError: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let repositoryPath: String
    let operationType: GitOperationType
    let errorMessage: String

    init(repositoryPath: String, operationType: GitOperationType, errorMessage: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.repositoryPath = repositoryPath
        self.operationType = operationType
        self.errorMessage = errorMessage
    }
}

class ErrorStore: ObservableObject {
    @Published var errors: [SyncError] = []
    @Published var ignoredErrorMessages: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(ignoredErrorMessages), forKey: "ignoredErrorMessages")
        }
    }

    private static let ignoredMessagesKey = "ignoredErrorMessages"

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.ignoredMessagesKey) {
            ignoredErrorMessages = Set(saved)
        }
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }

    var hasIgnoredErrors: Bool {
        !ignoredErrorMessages.isEmpty
    }

    var filteredErrors: [SyncError] {
        errors.filter { error in
            !ignoredErrorMessages.contains(error.errorMessage)
        }
    }

    var hasVisibleErrors: Bool {
        !filteredErrors.isEmpty
    }

    func addError(repositoryPath: String, operationType: GitOperationType, errorMessage: String) {
        let error = SyncError(repositoryPath: repositoryPath, operationType: operationType, errorMessage: errorMessage)
        DispatchQueue.main.async {
            self.errors.append(error)
        }
    }

    func removeError(_ error: SyncError) {
        DispatchQueue.main.async {
            self.errors.removeAll { $0.id == error.id }
        }
    }

    func clearErrors() {
        DispatchQueue.main.async {
            self.errors.removeAll()
        }
    }

    func ignoreError(_ error: SyncError) {
        DispatchQueue.main.async {
            self.ignoredErrorMessages.insert(error.errorMessage)
        }
    }

    func resetIgnoredErrors() {
        DispatchQueue.main.async {
            self.ignoredErrorMessages.removeAll()
        }
    }
}
