//
//  ContentView.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import SwiftUI
import AppKit
import Combine


class AppViewModel: ObservableObject {
    var monitoredDirectories: [URL] = []
   
    private var directoryMonitor: DirectoryMonitor!
    private var gitRepositories: [GitRepository] = []
    

    init() {
        monitoredDirectories = loadDirectoriesFromPlist()
       
        updateGitRepositories()
        setupDirectoryMonitor()
    }
    
    private func updateGitRepositories() {
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
    
    func handleDirectoryChanges(_ changes: [String]) {
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
        gitRepositories
            .filter { $0.repositoryPath.path.hasPrefix(directory.path) }
            .forEach { repository in
                guard repository.addAll() else {
                    print("Error adding changes in \(repository.repositoryPath.path)")
                    return
                }
                //remove configured directory prefix from first filename for commit message
                var message = changedFiles.first ?? "Sync"
                message.replace(directory.path, with: "")
                
                guard repository.commit(message: "/ '\(message)'") else {
                    print("Error committing changes to \(repository.repositoryPath.path)")
                    return
                }
                
                guard repository.push() else {
                    print("Error pushing changes to \(repository.repositoryPath.path)")
                    return
                }
                
                print("Changes pushed to \(repository.repositoryPath.path)")
            }
    }
    
    func syncChangesDown(in directory: URL) {
        gitRepositories.filter { $0.repositoryPath.path.hasPrefix(directory.path)}
            .forEach { repository in
                guard repository.pull() else {
                    print("Error pulling changes from \(repository.repositoryPath.path)")
                    return
                }
                
                print("Pulled changes from \(repository.repositoryPath.path)")
            }
    }
        
    //
    //methods for managing synced remote projects
    //
        
    func addDirectory(_ url: URL) {
        objectWillChange.send() // Notify SwiftUI of the upcoming change
        monitoredDirectories.append(url)
        saveDirectoriesToPlist(directories: monitoredDirectories)
        updateGitRepositories()
    }
        
    func pullAllDirectories() {
        for directory in monitoredDirectories {
            syncChangesDown(in: directory)
        }
    }
    
    struct MonitoredDirectory: Codable {
        let directory: String
    }

    func saveDirectoriesToPlist(directories: [URL], fileName: String = "monitoredDirs.plist") {
        let entries = directories.map { MonitoredDirectory(directory: $0.path) }
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


struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        VStack {
            List(viewModel.monitoredDirectories, id: \.self) { directory in
                Text(directory.path)
            }
            Button("Add existing directory") {
                addRemoteProject()
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func addRemoteProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.addDirectory(url)
            }
        }
    }
}
