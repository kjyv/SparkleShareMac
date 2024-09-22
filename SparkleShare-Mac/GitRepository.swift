//
//  GitRepository.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import Foundation

class GitRepository {
    let repositoryPath: URL

    init(repositoryPath: URL) {
        self.repositoryPath = repositoryPath
    }

    @discardableResult
    private func runGitCommand(_ arguments: [String]) -> (output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = repositoryPath
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ("", "Failed to run git command: \(error)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if !output.isEmpty {
            print("Output of command $ git \(arguments.joined(separator: " ")) \(repositoryPath.path): ")
            let lines = output.split(whereSeparator: \.isNewline)
            for line in lines {
                print(line)
            }
        }

        return (output, error)
    }

    func clone(from remoteURL: URL) -> Bool {
        let result = runGitCommand(["clone", remoteURL.absoluteString, repositoryPath.path])
        if !result.error.isEmpty {
            print("Git Clone Error: \(result.error)")
            return false
        }
        return true
    }

    func addAll() -> Bool {
        let result = runGitCommand(["add", "--all"])
        if !result.error.isEmpty {
            print("Git Add Error: \(result.error)")
            return false
        }
        return true
    }

    func commit(message: String) -> Bool {
        let result = runGitCommand(["commit", "-m", message])
        if !result.error.isEmpty {
            print("Git Commit Error: \(result.error)")
            return false
        }
        return true
    }

    func push() -> Bool {
        let result = runGitCommand(["push"])
        if !result.error.isEmpty && result.error != "Everything up-to-date" {
            print("Git Push Error: \(result.error)")
            return false
        }
        return true
    }

    func pull() -> Bool {
        let result = runGitCommand(["pull"])
        if !result.error.isEmpty {
            print("Git Pull Error: \(result.error)")
            return false
        }
        return true
    }
}

// Usage Example
//let gitRepo = GitRepository(repositoryPath: URL(fileURLWithPath: "/path/to/repo"))
//gitRepo.clone(from: URL(string: "https://github.com/username/repo.git")!)
//gitRepo.addAll()
//gitRepo.commit(message: "Initial commit")
//gitRepo.push()
