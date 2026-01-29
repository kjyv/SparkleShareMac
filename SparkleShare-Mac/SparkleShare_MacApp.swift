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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    static var shared: AppDelegate!
    weak var window: NSWindow?
    weak var errorWindow: NSWindow?
    var syncHandler = SyncHandler()
    var errorStore = ErrorStore()
    var operationTracker = OperationTracker()
    private var settingsViewModel = SettingsViewModel()
    var statusItem: NSStatusItem?
    var pullDirectoriesTimer: Timer?
    private var errorStoreSubscription: AnyCancellable?
    private var operationTrackerSubscription: AnyCancellable?
    private var viewErrorsMenuItem: NSMenuItem?
    private var syncStatusMenuItem: NSMenuItem?
    private var cancelSyncMenuItem: NSMenuItem?
    private var projectsMenuItem: NSMenuItem?
    private var statusUpdateTimer: Timer?

    override init() {
        super.init()
        AppDelegate.shared = self
        settingsViewModel.syncHandler = syncHandler
        syncHandler.errorStore = errorStore
        syncHandler.operationTracker = operationTracker

        // Subscribe to error store changes to update menu bar icon and menu item visibility
        errorStoreSubscription = errorStore.$errors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errors in
                self?.updateStatusIcon()
                self?.viewErrorsMenuItem?.isHidden = errors.isEmpty
            }

        // Subscribe to operation tracker changes to update menu items
        operationTrackerSubscription = operationTracker.$currentOperation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operation in
                self?.updateSyncStatusMenuItems(operation: operation)
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

        // Sync status menu item (shows current operation and elapsed time)
        syncStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        syncStatusMenuItem?.isHidden = true
        syncStatusMenuItem?.isEnabled = false
        menu.addItem(syncStatusMenuItem!)

        // Cancel sync menu item
        cancelSyncMenuItem = NSMenuItem(title: "Cancel Sync", action: #selector(cancelCurrentSync), keyEquivalent: "")
        cancelSyncMenuItem?.isHidden = true
        menu.addItem(cancelSyncMenuItem!)

        projectsMenuItem = NSMenuItem(title: "Projects", action: nil, keyEquivalent: "")
        let projectsSubmenu = NSMenu()
        projectsSubmenu.delegate = self
        projectsMenuItem?.submenu = projectsSubmenu
        menu.addItem(projectsMenuItem!)

        menu.addItem(NSMenuItem(title: "Sync now", action: #selector(syncAllDirectories), keyEquivalent: "s"))

        viewErrorsMenuItem = NSMenuItem(title: "View Errors", action: #selector(showErrorWindow), keyEquivalent: "e")
        viewErrorsMenuItem?.isHidden = true
        menu.addItem(viewErrorsMenuItem!)
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettingsWindow), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SparkleShare", action: #selector(quitApp), keyEquivalent: "q"))
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
        if !operationTracker.isOperationRunning {
            setIdleStatus()
        }
    }

    private func updateSyncStatusMenuItems(operation: OperationTracker.Operation?) {
        if operation != nil {
            syncStatusMenuItem?.title = operationTracker.statusText
            syncStatusMenuItem?.isHidden = false
            cancelSyncMenuItem?.isHidden = false
            startStatusUpdateTimer()
        } else {
            syncStatusMenuItem?.isHidden = true
            cancelSyncMenuItem?.isHidden = true
            stopStatusUpdateTimer()
        }
    }

    private func startStatusUpdateTimer() {
        stopStatusUpdateTimer()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.operationTracker.isOperationRunning {
                self.syncStatusMenuItem?.title = self.operationTracker.statusText
            }
        }
    }

    private func stopStatusUpdateTimer() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }

    @objc private func cancelCurrentSync() {
        operationTracker.cancelCurrentOperation()
        setIdleStatus()
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
        syncHandler.syncAllDirectories()
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

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == projectsMenuItem?.submenu else { return }

        menu.removeAllItems()

        if syncHandler.monitoredDirectories.isEmpty {
            let emptyItem = NSMenuItem(title: "No projects configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for directory in syncHandler.monitoredDirectories {
                let item = NSMenuItem(title: directory.lastPathComponent, action: #selector(openProjectInFinder(_:)), keyEquivalent: "")
                item.representedObject = directory
                menu.addItem(item)
            }
        }
    }

    @objc private func openProjectInFinder(_ sender: NSMenuItem) {
        guard let directory = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(directory)
    }

}

