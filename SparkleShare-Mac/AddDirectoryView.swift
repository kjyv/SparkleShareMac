//
//  AddDirectoryView.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//


import SwiftUI

class AddDirectoryViewModel: ObservableObject {
    var syncHandler: SyncHandler!
    @Published var isShowingCloneSheet = false // New state variable
    
    func addDirectoryUsingPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.addDirectory(url)
            }
        }
    }
    
    func removeDirectory(_ directory: URL) {
        objectWillChange.send()
        syncHandler.monitoredDirectories.removeAll { $0 == directory }
        syncHandler.saveDirectoriesToPlist()
        syncHandler.updateGitRepositories()
    }
    
    func addDirectory(_ url: URL) {
        objectWillChange.send() // Notify SwiftUI of the upcoming change
        syncHandler.monitoredDirectories.append(url)
        syncHandler.saveDirectoriesToPlist()
        syncHandler.updateGitRepositories()
    }
}

struct AddDirectoryView: View {
    @EnvironmentObject var viewModel: AddDirectoryViewModel
    @EnvironmentObject var syncHandler: SyncHandler
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Synced Projects")
                .font(.headline)
            
            List {
                ForEach(syncHandler.monitoredDirectories, id: \.self) { directory in
                    HStack {
                        Text(directory.path)
                        Spacer()
                        Button(action: {
                            viewModel.removeDirectory(directory)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .frame(height: 30)
                }
                .onDelete(perform: deleteDirectory)
            }
            .frame(minWidth: 400, minHeight: 200)
            .presentationSizing(.fitted)

            HStack {
                Button("Add remote project") {
                    viewModel.isShowingCloneSheet.toggle()
                }
                Spacer()
                Button("Add existing directory") {
                    viewModel.addDirectoryUsingPanel()
                }
                .padding()
            }
        }
        .padding()
        .sheet(isPresented: $viewModel.isShowingCloneSheet) {
            CloneRepositoryView()
                .environmentObject(viewModel)
                .environmentObject(syncHandler)
        }
    }
    
    private func deleteDirectory(at offsets: IndexSet) {
        for index in offsets {
            let directory = syncHandler.monitoredDirectories[index]
            viewModel.removeDirectory(directory)
        }
    }
}
