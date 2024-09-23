//
//  DirectoryMonitor.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 22.09.24.
//

import Foundation
import CoreServices

class DirectoryMonitor {
    private var eventStream: FSEventStreamRef?
    private var monitoredDirectories: [URL]
    private var callback: (([String]) -> Void)?
    private let queue = DispatchQueue(label: "DirectoryMonitorQueue", attributes: .concurrent)

    init(directories: [URL], callback: @escaping ([String]) -> Void) {
        self.monitoredDirectories = directories
        self.callback = callback
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // Start monitoring the specified directories
    private func startMonitoring() {
        guard eventStream == nil else { return }

        let pathsToWatch = monitoredDirectories.map { $0.path } as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callbackFunction: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            // Correctly convert eventPaths to a Swift array of Strings
            let eventPathsPointer = eventPaths.bindMemory(to: UnsafePointer<CChar>.self, capacity: numEvents)
            var paths: [String] = []
            for i in 0..<numEvents {
                let path = String(cString: eventPathsPointer[i])
                // filter out .git path
                if path.contains(".git") { continue }
                if path.contains(".zim-new~") { continue }
                paths.append(path)
            }

            // Getting the original DirectoryMonitor instance from the clientCallBackInfo
            let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
            // Call the directoryDidChange method with the paths of changed files
            monitor.directoryDidChange(paths)
        }

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callbackFunction,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            10.0, // Latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )

        if let eventStream = eventStream {
            FSEventStreamSetDispatchQueue(eventStream, queue)
            FSEventStreamStart(eventStream)
        }
    }

    // Stop monitoring the directories
    private func stopMonitoring() {
        if let eventStream = eventStream {
            FSEventStreamStop(eventStream)
            FSEventStreamInvalidate(eventStream)
            FSEventStreamRelease(eventStream)
            self.eventStream = nil
        }
    }

    // Called when a change is detected in the monitored directories
    private func directoryDidChange(_ paths: [String]) {
        callback?(paths)
    }
}
