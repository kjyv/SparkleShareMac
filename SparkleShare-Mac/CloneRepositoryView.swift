//
//  CloneRepositoryView.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//


import SwiftUI

struct CloneRepositoryView: View {
    @EnvironmentObject var viewModel: AddDirectoryViewModel
    @EnvironmentObject var syncHandler: SyncHandler
    
    @State private var gitURL: String = ""
    @State private var isCloning: Bool = false
    @State private var errorMessage: String?
    @State private var localParentPath: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Clone remote project")
                .font(.headline)
                .padding(.bottom, 10)
            
            HStack {
                TextField("Enter local parent path", text: $localParentPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)
                Spacer()
                Button(action: { selectLocalParentPath() }) {
                    Text("...")
                }
                    .padding(.bottom, 10)
                    .disabled(isCloning)
            }
                
            TextField("Enter Git Repository URL", text: $gitURL)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, 10)
        
            if let errorMessage = errorMessage {
                Text(errorMessage)
                .foregroundColor(.red)
                .padding(.bottom, 10)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Button(action: { closeView() }) {
                    Text("Cancel")
                }
                .disabled(isCloning)
                Spacer()
                Button(action: { cloneRepository() }) {
                    if isCloning {
                        ProgressView()
                        .padding(.trailing, 5)
                        .controlSize(.small)
                    }
                    Text("Clone")
                }
                .disabled(gitURL.isEmpty || isCloning)
            }
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 450)
        .presentationSizing(.fitted)
        .onAppear {
            localParentPath = getDefaultLocalParentPath()
        }
    }
    
    private func getDefaultLocalParentPath() -> String {
        let path = FileManager.default.homeDirectoryForCurrentUser
        return path.appendingPathComponent("SparkleShare").path
    }
    
    private func selectLocalParentPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                localParentPath = url.path
            }
        }
    }
    
    private func cloneRepository() {
        guard let url = URL(string: gitURL) else {
            errorMessage = "Invalid URL"
            return
        }
        isCloning = true
        errorMessage = nil
        let localParentUrl = URL(fileURLWithPath: localParentPath)
        
        DispatchQueue.global().async {
            var gitErrorMessage = ""
            let clonedDirectory = self.syncHandler.cloneRepository(from: url, to: localParentUrl, errorMessage: &gitErrorMessage)
            if (clonedDirectory == nil) {
                self.errorMessage = "Failed to clone repository:\n" + gitErrorMessage
            }
            self.isCloning = false
            
            if self.errorMessage == nil {
                DispatchQueue.main.async {
                    self.viewModel.isShowingCloneSheet.toggle()
                }
            }
        }
    }
    
    private func closeView() {
        viewModel.isShowingCloneSheet.toggle()
    }
}
