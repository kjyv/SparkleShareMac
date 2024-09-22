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
        // set dummy repo directories
        // TODO: Load configuration from file (application support probably)
        monitoredDirectories.append(URL(fileURLWithPath: "/Users/stefan/SparkleShare/syncbox.duckdns.org/notes/"))
        
        setupDirectoryMonitor()
        
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
                
                guard repository.commit(message: "/ \(changedFiles.first ?? "Sync")") else {
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
    
    func syncChangesDown(in directory: URL, changedFiles: [String]) {
        return
    }
        
    //
    //methods for managing synced remote projects
    //
        
    func addDirectory(_ url: URL) {
        monitoredDirectories.append(url)
        //TODO: Save the updated list to the configuration file
    }
        
    func forceUpdate(in directory: URL) {
        //TODO
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        VStack {
            Text("Synced remote projects:")
            List(viewModel.monitoredDirectories, id: \.self) { directory in
                Text(directory.path)
            }
            Button(action: {
                addRemoteProject()
            }) {
                Text("Sync with remote project")
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
