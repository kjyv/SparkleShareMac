//
//  SparkleShare_MacApp.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import SwiftUI

@main
struct SparkleShare: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    var body: some Scene {
        //dummy view for no window at start
        Settings {
            Text("Settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    weak var window: NSWindow?
    var syncHandler = SyncHandler()
    private var directoryViewModel = AddDirectoryViewModel()
    var statusItem: NSStatusItem?
    var pullDirectoriesTimer: Timer?
    
    override init() {
        super.init()
        AppDelegate.shared = self
        directoryViewModel.syncHandler = syncHandler
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        ProcessInfo.processInfo.disableAutomaticTermination("file watcher needs to run")
        // hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        //setup observer on sleep wakeup to pull changes right away
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(handleWakeFromSleep),
                                                          name: NSWorkspace.didWakeNotification,
                                                          object: nil)
        setupPullDirectoriesTimer()
        print("Checking all remote directories for changes...")
        pullAllDirectories()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIdleStatus()
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "SparkleShare Mac", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showAddDirectoryWindow), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "Force sync", action: #selector(pullAllDirectories), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func setSyncStatus() {
        // Set loading icon
        DispatchQueue.main.async {
            //run on UI thread
            self.statusItem?.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Syncing")
        }
    }
    
    @objc func setIdleStatus() {
        // Set original icon after sync
        DispatchQueue.main.async {
            self.statusItem?.button?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Idle")
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
            newWindow.setFrameAutosaveName("Settings")
            newWindow.title = "SparkleShare Settings"
            newWindow.contentView = NSHostingView(rootView: AddDirectoryView().environmentObject(directoryViewModel).environmentObject(syncHandler))
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }
        //bring window to front
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func pullAllDirectories() {
        syncHandler.pullAllDirectories()
    }

    private func setupPullDirectoriesTimer() {
        pullDirectoriesTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(pullAllDirectories), userInfo: nil, repeats: true)
    }
    
    @objc private func handleWakeFromSleep(notification: Notification) {
        print("Detected wake from sleep, checking for updates")
        pullAllDirectories()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}

