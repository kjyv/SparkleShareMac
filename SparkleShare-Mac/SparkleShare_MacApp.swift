//
//  SparkleShare_MacApp.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import SwiftUI

@main
struct SparkleShare: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .commands {
            CommandMenu("SparkleShare Clone") {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var viewModel = AppViewModel()
    var pullDirectoriesTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        ProcessInfo.processInfo.disableAutomaticTermination("file watcher needs to run")
        
        setupPullDirectoriesTimer()
        print("Checking all remote directories for changes...")
        pullAllDirectories()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Monitor")
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Open App", action: #selector(openApp), keyEquivalent: "o"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Force sync", action: #selector(pullAllDirectories), keyEquivalent: "c"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
        }
    }
    
    private func setupPullDirectoriesTimer() {
        pullDirectoriesTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(pullAllDirectories), userInfo: nil, repeats: true)
    }
    
    @objc func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        
        //bring possibly open window to the front
        NSApp.keyWindow?.orderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func pullAllDirectories() {
        viewModel.pullAllDirectories()
    }
}

