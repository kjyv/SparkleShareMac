//
//  SettingsView.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//


import SwiftUI
import ServiceManagement

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                enableLaunchAtLogin()
            } else {
                disableLaunchAtLogin()
            }
        }
    }

    private init() {
        // Check current status from system
        let status = SMAppService.mainApp.status
        let currentlyEnabled = (status == .enabled)

        // Check if this is first launch (no user preference saved yet)
        let hasLaunchedBefore = UserDefaults.standard.object(forKey: "hasLaunchedBefore") != nil

        if !hasLaunchedBefore {
            // First launch: default to ON
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            self.isEnabled = true
            enableLaunchAtLogin()
        } else {
            self.isEnabled = currentlyEnabled
        }
    }

    private func enableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }

    private func disableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }
}

class SettingsViewModel: ObservableObject {
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

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @EnvironmentObject var syncHandler: SyncHandler
    @ObservedObject var launchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        TabView {
            ProjectsTab(viewModel: viewModel, syncHandler: syncHandler, launchAtLoginManager: launchAtLoginManager)
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 450, minHeight: 350)
        .onDisappear(perform: hide)
        .sheet(isPresented: $viewModel.isShowingCloneSheet) {
            CloneRepositoryView()
                .environmentObject(viewModel)
                .environmentObject(syncHandler)
        }
    }

    func hide() {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct ProjectsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var syncHandler: SyncHandler
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

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
            .frame(minHeight: 150)

            HStack {
                Button("Add remote project") {
                    viewModel.isShowingCloneSheet.toggle()
                }
                Spacer()
                Button("Add existing directory") {
                    viewModel.addDirectoryUsingPanel()
                }
            }

            Spacer()
                .frame(height: 16)

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLoginManager.isEnabled)
                .padding(.top, 12)
        }
        .padding(20)
    }

    private func deleteDirectory(at offsets: IndexSet) {
        for index in offsets {
            let directory = syncHandler.monitoredDirectories[index]
            viewModel.removeDirectory(directory)
        }
    }
}

struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("SparkleShare")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Link(destination: URL(string: "https://github.com/kjyv/SparkleShareMac")!) {
                HStack {
                    Image(systemName: "link")
                    Text("View on GitHub")
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
