//
//  GitRepository.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import Foundation

class GitRepository {
    var repositoryPath: URL
    let authInfo: SSHAuthenticationInfo
    
    init(repositoryPath: URL) {
        self.repositoryPath = repositoryPath
        self.authInfo = SSHAuthenticationInfo()
    }
    
    func setRepositoryPath(to path: URL) {
        repositoryPath = path
    }

    @discardableResult
    private func runGitCommand(arguments: [String]) -> (success: Bool, output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = repositoryPath
        process.arguments = arguments
        let sshCommand = formatGitSSHCommand(authInfo: authInfo)
        let environment = ["GIT_SSH_COMMAND": sshCommand]
        process.environment = environment
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, "", "Failed to run git command: \(error)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if !output.isEmpty {
            print("Output of command \"git \(arguments.joined(separator: " ")) \(repositoryPath.path)\":")
            let lines = output.split(whereSeparator: \.isNewline)
            for line in lines {
                print(line)
            }
        }

        let success = process.terminationStatus == 0
        return (success, output, error)
    }
    
    @discardableResult
    private func runGitCommandWithProgress(_ arguments: [String], progressHandler: @escaping (String) -> Void) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = repositoryPath
        process.arguments = arguments
        let sshCommand = formatGitSSHCommand(authInfo: authInfo)
        let environment = ["GIT_SSH_COMMAND": sshCommand]
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe // Git outputs progress on stderr
        
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    progressHandler(output)
                }
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            outputHandle.readabilityHandler = nil
            return false
        }
        
        outputHandle.readabilityHandler = nil
        return process.terminationStatus == 0
    }

    func clone(from remoteURL: URL, progressHandler: @escaping (String) -> Void) -> Bool {
        let result = self.runGitCommandWithProgress(["clone", "--progress", remoteURL.absoluteString], progressHandler: progressHandler)
        if !result {
            print("Error during \"git clone\"")
        }
        return result
    }

    func addAll() -> Bool {
        let result = runGitCommand(arguments: ["add", "--all"])
        if !result.success && !result.error.isEmpty {
            print("Error during \"git add\": \(result.error)")
            return false
        }
        return true
    }

    func commit(message: String) -> Bool {
        let result = runGitCommand(arguments: ["commit", "-m", message])
        if !result.success && !result.error.isEmpty {
            print("Error during \"git commit\": \(result.error)")
            return false
        }
        return true
    }

    func push() -> Bool {
        let result = runGitCommand(arguments: ["push"])
        if !result.success && !result.error.isEmpty && result.error != "Everything up-to-date" {
            print("Error during \"git push\": \(result.error)")
            return false
        }
        return true
    }

    func pull() -> Bool {
        let result = runGitCommand(arguments: ["pull"])
        if !result.success && !result.error.isEmpty {
            print("Error during \"git pull\": \(result.error)")
            return false
        }
        return true
    }
}
