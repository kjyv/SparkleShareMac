//
//  OperationTracker.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 28.01.26.
//

import Foundation
import Combine

class OperationTracker: ObservableObject {
    struct Operation: Identifiable {
        let id: UUID
        let repositoryName: String
        let operationType: String  // "Syncing", "Pulling", "Pushing"
        let startTime: Date
        var process: Process?

        var elapsedTime: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
    }

    @Published private(set) var currentOperation: Operation?

    private let queue = DispatchQueue(label: "com.sparklesharemac.operationtracker")

    var isOperationRunning: Bool {
        currentOperation != nil
    }

    var elapsedTimeString: String {
        guard let operation = currentOperation else { return "" }
        let elapsed = operation.elapsedTime

        if elapsed < 60 {
            return "\(Int(elapsed))s"
        } else {
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    var statusText: String {
        guard let operation = currentOperation else { return "" }
        return "\(operation.operationType) \(operation.repositoryName)... (\(elapsedTimeString))"
    }

    func startOperation(repositoryName: String, operationType: String, process: Process? = nil) -> UUID {
        let id = UUID()
        let operation = Operation(
            id: id,
            repositoryName: repositoryName,
            operationType: operationType,
            startTime: Date(),
            process: process
        )

        DispatchQueue.main.async {
            self.currentOperation = operation
        }

        return id
    }

    func setProcess(_ process: Process, for operationId: UUID) {
        DispatchQueue.main.async {
            if self.currentOperation?.id == operationId {
                self.currentOperation?.process = process
            }
        }
    }

    func endOperation(id: UUID) {
        DispatchQueue.main.async {
            if self.currentOperation?.id == id {
                self.currentOperation = nil
            }
        }
    }

    func cancelCurrentOperation() {
        DispatchQueue.main.async {
            if let process = self.currentOperation?.process, process.isRunning {
                process.terminate()
            }
            self.currentOperation = nil
        }
    }
}
