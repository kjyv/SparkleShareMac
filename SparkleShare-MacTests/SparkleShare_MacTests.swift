//
//  SparkleShare_MacTests.swift
//  SparkleShare-MacTests
//
//  Created by Stefan Bethge on 22.09.24.
//

import Testing
import Foundation
@testable import SparkleShare_Mac

struct SparkleShare_MacTests {
    
    @Test func testCloneRepository() async throws {
        let syncHandler = SyncHandler()
        let remoteURL = URL.init(string: "https://github.com/kjyv/SparkleShareMac")!
        var localPathURL = URL(fileURLWithPath: #file).deletingLastPathComponent()
        localPathURL.append(path: "test")
        try FileManager.default.createDirectory(atPath: localPathURL.path(), withIntermediateDirectories: false)
        var outputMessage = ""
        let result = syncHandler.cloneRepository(from: remoteURL, to: localPathURL, progressHandler: {output in
//            print(output)
            outputMessage += output
        })
        #expect(!outputMessage.isEmpty, "Progress output should not be empty")
        #expect(outputMessage.contains("Receiving objects: 100%"))
        #expect(result != nil)
        
        try FileManager.default.removeItem(atPath: localPathURL.path())
    }
}
