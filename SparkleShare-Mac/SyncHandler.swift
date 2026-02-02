//
//  SyncHandler.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//

import SwiftUI
import AppKit

class SyncHandler: ObservableObject {
    var monitoredDirectories: [URL] = []
    var errorStore: ErrorStore?
    var operationTracker: OperationTracker?

    private var directoryMonitor: DirectoryMonitor!
    private var gitRepositories: [GitRepository] = []
    private let syncQueue = DispatchQueue(label: "com.sparklesharemac.sync", qos: .userInitiated, attributes: .concurrent)

    // Timer for delayed syncing after file changes were detected
    private var syncTimers: [URL: Timer] = [:]
    private let syncDelay: TimeInterval = 5.0

    deinit {
        // Invalidate all pending timers when the object is deallocated
        for timer in syncTimers.values {
            timer.invalidate()
        }
        syncTimers.removeAll()
    }

    func appDelegate() -> AppDelegate {
        guard let delegate = AppDelegate.shared else {
            fatalError("Could not get app delegate")
        }
        return delegate
     }

    init() {
        monitoredDirectories = loadDirectoriesFromPlist()
       
        updateGitRepositories()
        setupDirectoryMonitor()
    }
    
    func updateGitRepositories() {
        gitRepositories.removeAll()
        // create Git handlers for all directories
        monitoredDirectories.forEach { localPathURL in
            gitRepositories.append(GitRepository(repositoryPath: localPathURL))
        }
    }
    
    private func setupDirectoryMonitor() {
        // set up monitor for all directories
        directoryMonitor = DirectoryMonitor(directories: monitoredDirectories) { changedPaths in
            self.handleDirectoryChanges(changedPaths)
        }
    }
    
    private func handleDirectoryChanges(_ changes: [String]) {
        //remove duplicates
        let uniqueChanges = Array(Set(changes))
        uniqueChanges.forEach { change in
            print("Detected change in \(change)")
        }

        // Find all unique prefixes that are also present in monitoredDirectories
        let changedDirectories = self.monitoredDirectories.filter { monitoredDirectory in
            uniqueChanges.contains { change in
                change.hasPrefix(monitoredDirectory.path)
            }
        }

        // for each changed directory, find all changed files in that directory
        var changedFilesForDirectory: [URL: [String]] = [:]
        changedDirectories.forEach { changedDirectory in
            // find all entries in uniqueChanges that have this directory as prefix
            let changedFiles = uniqueChanges.filter { change in
                change.hasPrefix(changedDirectory.path)
            }
            changedFilesForDirectory[changedDirectory] = changedFiles
        }

        // Schedule delayed sync for each changed directory, resetting the timer if it already exists
        changedDirectories.forEach { changedDirectory in
            scheduleDelayedSync(for: changedDirectory, changedFiles: changedFilesForDirectory[changedDirectory] ?? [])
        }
    }
    
    // Schedule a delayed sync operation for the given directory
    private func scheduleDelayedSync(for directory: URL, changedFiles: [String]) {
        // Cancel any existing timer for this directory
        if let existingTimer = syncTimers[directory] {
            existingTimer.invalidate()
        }

        // Create a new timer that will trigger the sync after the delay
        let timer = Timer(timeInterval: syncDelay, repeats: false) { [self] _ in
            // Remove the timer from the dictionary
            syncTimers.removeValue(forKey: directory)

            // Perform the sync operation
            performSync(for: directory, changedFiles: changedFiles)
        }

        // Add timer to the main run loop to ensure it fires reliably
        RunLoop.main.add(timer, forMode: .common)

        syncTimers[directory] = timer
    }

    // Perform the actual sync operation (pull first, then commit + push together)
    private func performSync(for directory: URL, changedFiles: [String]) {
        print("Starting sync operation for \(directory.lastPathComponent)")
        let repoName = directory.lastPathComponent
        let operationId = operationTracker?.startOperation(repositoryName: repoName, operationType: "Syncing")

        DispatchQueue.main.async {
            self.appDelegate().setSyncStatus()
        }

        print("About to pull changes for \(directory.lastPathComponent)")
        // First pull any remote changes, then commit and push
        syncChangesDownInternal(in: directory, operationId: operationId) { [self] in
            print("Pull completed for \(directory.lastPathComponent), now committing and pushing...")
            // After pulling, commit and push the local changes
            syncChangesUpInternal(in: directory, changedFiles: changedFiles, operationId: operationId) {
                print("Commit and push completed for \(directory.lastPathComponent)")
                DispatchQueue.main.async {
                    if let opId = operationId {
                        self.operationTracker?.endOperation(id: opId)
                    }
                    self.appDelegate().setIdleStatus()
                }
            }
        }
    }

    private func syncChangesUpInternal(in directory: URL, changedFiles: [String], operationId: UUID? = nil, completion: @escaping () -> Void) {
        syncQueue.async { [self] in
            let repositories = self.gitRepositories.filter { $0.repositoryPath.path.hasPrefix(directory.path) }

            for repository in repositories {
                let addResult = repository.addAll { [self] process in
                    if let opId = operationId {
                        self.operationTracker?.setProcess(process, for: opId)
                    }
                }
                guard addResult.success else {
                    print("Error adding changes for \(repository.repositoryPath.path)")
                    self.errorStore?.addError(
                        repositoryPath: repository.repositoryPath.path,
                        operationType: .add,
                        errorMessage: addResult.error.isEmpty ? "Failed to add changes to staging area" : addResult.error
                    )
                    continue
                }

                var message = changedFiles.first ?? "Sync"
                message.replace(directory.path, with: "")

                let commitResult = repository.commit(message: "/ '\(message)'") { [self] process in
                    if let opId = operationId {
                        self.operationTracker?.setProcess(process, for: opId)
                    }
                }
                guard commitResult.success else {
                    print("Error committing changes for \(repository.repositoryPath.path)")
                    self.errorStore?.addError(
                        repositoryPath: repository.repositoryPath.path,
                        operationType: .commit,
                        errorMessage: commitResult.error.isEmpty ? "Failed to commit changes" : commitResult.error
                    )
                    continue
                }

                let pushResult = repository.push { [self] process in
                    if let opId = operationId {
                        self.operationTracker?.setProcess(process, for: opId)
                    }
                }
                guard pushResult.success else {
                    print("Error pushing changes for \(repository.repositoryPath.path)")
                    self.errorStore?.addError(
                        repositoryPath: repository.repositoryPath.path,
                        operationType: .push,
                        errorMessage: pushResult.error.isEmpty ? "Failed to push changes to remote" : pushResult.error
                    )
                    continue
                }

                print("Changes pushed for \(repository.repositoryPath.path)")
            }

            completion()
        }
    }
    
    private func syncChangesDownInternal(in directory: URL, operationId: UUID? = nil, completion: @escaping () -> Void) {
        syncQueue.async { [self] in
            let repositories = self.gitRepositories.filter { $0.repositoryPath.path.hasPrefix(directory.path) }

            for repository in repositories {
                let pullResult = repository.pull { [self] process in
                    if let opId = operationId {
                        self.operationTracker?.setProcess(process, for: opId)
                    }
                }
                guard pullResult.success else {
                    print("Error pulling changes for \(repository.repositoryPath.path)")
                    self.errorStore?.addError(
                        repositoryPath: repository.repositoryPath.path,
                        operationType: .pull,
                        errorMessage: pullResult.error.isEmpty ? "Failed to pull changes from remote" : pullResult.error
                    )
                    continue
                }

                print("Pulled changes for \(repository.repositoryPath.path)")
            }

            completion()
        }
    }
        
    func pullAllDirectories() {
        guard !monitoredDirectories.isEmpty else { return }

        let operationId = operationTracker?.startOperation(repositoryName: "All", operationType: "Pulling")
        DispatchQueue.main.async {
            self.appDelegate().setSyncStatus()
        }

        pullAllDirectoriesInternal {
            DispatchQueue.main.async {
                if let opId = operationId {
                    self.operationTracker?.endOperation(id: opId)
                }
                self.appDelegate().setIdleStatus()
            }
        }
    }

    private func pullAllDirectoriesInternal(completion: @escaping () -> Void) {
        guard !monitoredDirectories.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for directory in monitoredDirectories {
            group.enter()
            syncChangesDownInternal(in: directory) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    func pushAllDirectories() {
        guard !monitoredDirectories.isEmpty else { return }

        let operationId = operationTracker?.startOperation(repositoryName: "All", operationType: "Syncing")
        DispatchQueue.main.async {
            self.appDelegate().setSyncStatus()
        }

        pushAllDirectoriesInternal {
            DispatchQueue.main.async {
                if let opId = operationId {
                    self.operationTracker?.endOperation(id: opId)
                }
                self.appDelegate().setIdleStatus()
            }
        }
    }

    private func pushAllDirectoriesInternal(completion: @escaping () -> Void) {
        guard !monitoredDirectories.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for directory in monitoredDirectories {
            group.enter()
            syncChangesUpInternal(in: directory, changedFiles: []) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    func syncAllDirectories() {
        guard !monitoredDirectories.isEmpty else { return }

        let operationId = operationTracker?.startOperation(repositoryName: "All", operationType: "Syncing")
        DispatchQueue.main.async {
            self.appDelegate().setSyncStatus()
        }

        // For each directory: pull then push (sequential per directory, parallel across directories)
        let group = DispatchGroup()
        for directory in monitoredDirectories {
            group.enter()
            syncDirectoryInternal(directory: directory) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let opId = operationId {
                self.operationTracker?.endOperation(id: opId)
            }
            self.appDelegate().setIdleStatus()
        }
    }

    /// Syncs a single directory: pull first, then push (sequentially)
    private func syncDirectoryInternal(directory: URL, completion: @escaping () -> Void) {
        syncChangesDownInternal(in: directory) {
            self.syncChangesUpInternal(in: directory, changedFiles: []) {
                completion()
            }
        }
    }
    
    func cloneRepository(from url: URL, to localParentUrl: URL, progressHandler: @escaping (String) -> Void) -> URL? {
        let gitRepository = GitRepository(repositoryPath: localParentUrl)
        let result = gitRepository.clone(from: url, progressHandler: { output in            
            progressHandler(output)
        })
        gitRepository.setRepositoryPath(to: localParentUrl.appendingPathComponent(url.lastPathComponent))
        
        if result == true {
            gitRepositories.append(gitRepository)
            monitoredDirectories.append(gitRepository.repositoryPath)
            return gitRepository.repositoryPath
        } else {
            return nil
        }
    }
    
    
    // Save and Load to plist functionality
    //
    struct MonitoredDirectory: Codable {
        let directory: String
    }

    func saveDirectoriesToPlist(fileName: String = "monitoredDirs.plist") {
        let entries = monitoredDirectories.map { MonitoredDirectory(directory: $0.path) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        do {
            let data = try encoder.encode(entries)
            if let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let directoryPath = appSupportPath.appendingPathComponent("SparkleShareMac")
                try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
                let plistPath = directoryPath.appendingPathComponent(fileName)
                try data.write(to: plistPath)
                print("Directories saved to plist at: \(plistPath)")
            }
        } catch {
            print("Error saving directories to plist: \(error)")
        }
    }
    
    func loadDirectoriesFromPlist(fileName: String = "monitoredDirs.plist") -> [URL] {
        if let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let plistPath = appSupportPath.appendingPathComponent("SparkleShareMac").appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: plistPath) {
                let decoder = PropertyListDecoder()
                if let directories = try? decoder.decode([MonitoredDirectory].self, from: data) {
                    return directories.map { URL(fileURLWithPath: $0.directory) }
                }
            }
        }
        return []
    }
}

