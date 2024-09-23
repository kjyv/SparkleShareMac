//
//  SparkleShare_MacApp.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import SwiftUI

@main
struct SparkleShare: App {
    @StateObject private var viewModel = AppViewModel()
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    init() {
        appDelegate.viewModel = viewModel
        appDelegate.setup()
    }
    
    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(viewModel)
//                .onAppear {
//                    appDelegate.viewModel = viewModel
//                    appDelegate.setup()
//                }
//        }
//        .commands {
//            CommandMenu("SparkleShare Mac") {
//                Button("Quit") {
//                    NSApplication.shared.terminate(nil)
//                }
//                .keyboardShortcut("q")
//            }
//        }
        Settings { // Optional settings view or an empty scene
            Text("Settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var window: NSWindow?
    var viewModel: AppViewModel!
    
    var statusItem: NSStatusItem?
    var pullDirectoriesTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        ProcessInfo.processInfo.disableAutomaticTermination("file watcher needs to run")
        // hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    func setup() {
        setupPullDirectoriesTimer()
        print("Checking all remote directories for changes...")
        pullAllDirectories()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Monitor")
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Add directory", action: #selector(showAddDirectoryWindow), keyEquivalent: "a"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Force sync", action: #selector(pullAllDirectories), keyEquivalent: "s"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
        }
    }
    
    @objc func showAddDirectoryWindow() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false
            )
            newWindow.delegate = self
            newWindow.center()
            newWindow.setFrameAutosaveName("SparkleShare: Add Directory")
            newWindow.contentView = NSHostingView(rootView: ContentView().environmentObject(viewModel))
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }
        //bring window to front
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupPullDirectoriesTimer() {
        pullDirectoriesTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(pullAllDirectories), userInfo: nil, repeats: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func pullAllDirectories() {
        viewModel.pullAllDirectories()
    }
}

