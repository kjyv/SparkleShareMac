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
    @EnvironmentObject var syncHandler: SyncHandler
    
    func addDirectory(_ url: URL) {
        objectWillChange.send() // Notify SwiftUI of the upcoming change
        syncHandler.monitoredDirectories.append(url)
        syncHandler.saveDirectoriesToPlist()
        syncHandler.updateGitRepositories()
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var syncHandler: SyncHandler
    
    var body: some View {
        VStack {
            List(syncHandler.monitoredDirectories, id: \.self) { directory in
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
