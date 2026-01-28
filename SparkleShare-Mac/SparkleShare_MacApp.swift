//
//  SparkleShare_MacApp.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import SwiftUI
import Combine

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
    weak var errorWindow: NSWindow?
    var syncHandler = SyncHandler()
    var errorStore = ErrorStore()
    private var settingsViewModel = SettingsViewModel()
    var statusItem: NSStatusItem?
    var pullDirectoriesTimer: Timer?
    private var errorStoreSubscription: AnyCancellable?
    private var viewErrorsMenuItem: NSMenuItem?

    override init() {
        super.init()
        AppDelegate.shared = self
        settingsViewModel.syncHandler = syncHandler
        syncHandler.errorStore = errorStore

        // Subscribe to error store changes to update menu bar icon and menu item visibility
        errorStoreSubscription = errorStore.$errors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errors in
                self?.updateStatusIcon()
                self?.viewErrorsMenuItem?.isHidden = errors.isEmpty
            }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        ProcessInfo.processInfo.disableAutomaticTermination("file watcher needs to run")
        // hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize launch at login (defaults to ON on first launch)
        _ = LaunchAtLoginManager.shared

        //setup observer on sleep wakeup to pull changes right away
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(handleWakeFromSleep),
                                                          name: NSWorkspace.didWakeNotification,
                                                          object: nil)
        setupPullDirectoriesTimer()
        print("Checking all directories for changes...")
        syncAllDirectories()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIdleStatus()
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "SparkleShare Mac", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettingsWindow), keyEquivalent: "a"))

        viewErrorsMenuItem = NSMenuItem(title: "View Errors", action: #selector(showErrorWindow), keyEquivalent: "e")
        viewErrorsMenuItem?.isHidden = true
        menu.addItem(viewErrorsMenuItem!)

        menu.addItem(NSMenuItem(title: "Force sync", action: #selector(syncAllDirectories), keyEquivalent: "s"))
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
        // Set original icon after sync (or error icon if there are errors)
        DispatchQueue.main.async {
            if self.errorStore.hasErrors {
                self.setErrorStatus()
            } else {
                self.statusItem?.button?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Idle")
            }
        }
    }

    @objc func setErrorStatus() {
        DispatchQueue.main.async {
            self.statusItem?.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Errors")
        }
    }

    private func updateStatusIcon() {
        // Only update if not currently syncing
        if self.statusItem?.button?.image?.name() != "arrow.triangle.2.circlepath" {
            setIdleStatus()
        }
    }
    
    @objc func showSettingsWindow() {
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
            newWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(settingsViewModel).environmentObject(syncHandler))
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }
        //bring window to front
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showErrorWindow() {
        if errorWindow == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false
            )
            newWindow.delegate = self
            newWindow.center()
            newWindow.setFrameAutosaveName("Errors")
            newWindow.title = "Sync Errors"
            newWindow.contentView = NSHostingView(rootView: ErrorListView().environmentObject(errorStore))
            newWindow.isReleasedWhenClosed = false
            errorWindow = newWindow
        }
        //bring window to front
        errorWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func pullAllDirectories() {
        syncHandler.pullAllDirectories()
    }

    @objc private func syncAllDirectories() {
        syncHandler.pullAllDirectories()
        syncHandler.pushAllDirectories()
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

