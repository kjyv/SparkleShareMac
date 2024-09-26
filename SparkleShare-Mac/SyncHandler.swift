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
   
    private var directoryMonitor: DirectoryMonitor!
    private var gitRepositories: [GitRepository] = []
    
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
        
        changedDirectories.forEach {changedDirectory in
            self.syncChangesUp(in: changedDirectory, changedFiles: changedFilesForDirectory[changedDirectory] ?? [])
        }
    }
    
    func syncChangesUp(in directory: URL, changedFiles: [String]) {
        appDelegate().setSyncStatus()
        gitRepositories
            .filter { $0.repositoryPath.path.hasPrefix(directory.path) }
            .forEach { repository in
                guard repository.addAll() else {
                    print("Error adding changes for \(repository.repositoryPath.path)")
                    return
                }
                //remove configured directory prefix from first filename for commit message
                var message = changedFiles.first ?? "Sync"
                message.replace(directory.path, with: "")
                
                guard repository.commit(message: "/ '\(message)'") else {
                    print("Error committing changes for \(repository.repositoryPath.path)")
                    return
                }
                
                guard repository.push() else {
                    print("Error pushing changes for \(repository.repositoryPath.path)")
                    return
                }
                
                print("Changes pushed for \(repository.repositoryPath.path)")
            }
        appDelegate().setIdleStatus()
    }
    
    func syncChangesDown(in directory: URL) {
        appDelegate().setSyncStatus()
        gitRepositories.filter { $0.repositoryPath.path.hasPrefix(directory.path)}
        .forEach { repository in
            guard repository.pull() else {
                print("Error pulling changes for \(repository.repositoryPath.path)")
                return
            }
            
            print("Pulled changes for \(repository.repositoryPath.path)")
        }
        appDelegate().setIdleStatus()
    }
        
    func pullAllDirectories() {
        for directory in monitoredDirectories {
            syncChangesDown(in: directory)
        }
    }
    
    func pushAllDirectories() {
        for directory in monitoredDirectories {
            syncChangesUp(in: directory, changedFiles: [])
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

