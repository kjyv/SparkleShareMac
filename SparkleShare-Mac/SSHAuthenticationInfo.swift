//
//  SSHAuthenticationInfo.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//


import Foundation

class SSHAuthenticationInfo {
    static var defaultAuthenticationInfo: SSHAuthenticationInfo?

    let privateKeyFilePath: String
    let privateKey: String
    let publicKeyFilePath: String
    let publicKey: String
    let knownHostsFilePath: String

    private let path: String

    init() {
        let configurationPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("SparkleShareMac/ssh")
        self.path = configurationPath.path

        self.knownHostsFilePath = configurationPath.appendingPathComponent("known_hosts").path
        SSHAuthenticationInfo.createDirectoryIfNeeded(at: configurationPath)

        func assignKeys(_ keys: (privateKeyFilePath: String, privateKey: String, publicKeyFilePath: String, publicKey: String)) {
        }

        let keys: (privateKeyFilePath: String, privateKey: String, publicKeyFilePath: String, publicKey: String)
        if let localKeys = SSHAuthenticationInfo.importKeys(from: self.path) {
            keys = localKeys
        } else {
            // Before creating new files, also check the location of C# SparkleShare for files
            let legacyConfigurationPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/org.sparkleshare.SparkleShare/ssh").path
            if let legacyKeys = SSHAuthenticationInfo.importKeys(from: legacyConfigurationPath) {
                print("Using legacy ssh keys from \(legacyConfigurationPath).")
                keys = legacyKeys
                //TODO: copy legacy keys to new location
                SSHAuthenticationInfo.copyLegacyKeys(to: self.path)
            } else {
                print("No ssh keys found, creating some...")
                keys = SSHAuthenticationInfo.createKeyPair(at: self.path)
            }
        }
        
        self.privateKeyFilePath = keys.privateKeyFilePath
        self.privateKey = keys.privateKey
        self.publicKeyFilePath = keys.publicKeyFilePath
        self.publicKey = keys.publicKey
    }

    private static func createDirectoryIfNeeded(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }

    private static func importKeys(from path: String) -> (privateKeyFilePath: String, privateKey: String, publicKeyFilePath: String, publicKey: String)? {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: path)
            if let privateKeyFile = files.first(where: { $0.hasSuffix(".key") }) {
                let privateKeyFilePath = path + "/" + privateKeyFile
                let publicKeyFilePath = privateKeyFilePath + ".pub"

                let privateKey = try String(contentsOfFile: privateKeyFilePath, encoding: .utf8)
                let publicKey = try String(contentsOfFile: publicKeyFilePath, encoding: .utf8)

                return (privateKeyFilePath, privateKey, publicKeyFilePath, publicKey)
            }
        } catch {
            print("Error importing keys: \(error)")
        }
        return nil
    }
    
    private static func copyLegacyKeys(to path: String) {
        let fileManager = FileManager.default
        let legacyConfigurationPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".config/org.sparkleshare.SparkleShare/ssh").path
        
        do {
            let legacyFiles = try fileManager.contentsOfDirectory(atPath: legacyConfigurationPath)
            // Iterate through each file in the legacy directory
            for file in legacyFiles {
                let legacyFilePath = (legacyConfigurationPath as NSString).appendingPathComponent(file)
                let newFilePath = (path as NSString).appendingPathComponent(file)
                
                if !fileManager.fileExists(atPath: newFilePath) {
                    try fileManager.copyItem(atPath: legacyFilePath, toPath: newFilePath)
                    print("Copied \(file) to new location")
                } else {
                    print("\(file) already exists at the new location")
                }
            }
        } catch {
            print("Error copying legacy keys: \(error.localizedDescription)")
        }
    }

    private static func createKeyPair(at path: String) -> (privateKeyFilePath: String, privateKey: String, publicKeyFilePath: String, publicKey: String) {
        let privateKeyFilePath = path + "/id_rsa.key"
        let publicKeyFilePath = privateKeyFilePath + ".pub"

        // Generate key pair using shell command (simplified example)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = ["-t", "rsa", "-b", "2048", "-f", privateKeyFilePath, "-N", ""]
        try? process.run()
        process.waitUntilExit()

        let privateKey = (try? String(contentsOfFile: privateKeyFilePath, encoding: .utf8)) ?? ""
        let publicKey = (try? String(contentsOfFile: publicKeyFilePath, encoding: .utf8)) ?? ""

        return (privateKeyFilePath, privateKey, publicKeyFilePath, publicKey)
    }
}
