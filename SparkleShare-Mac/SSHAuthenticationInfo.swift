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

        if let keys = SSHAuthenticationInfo.importKeys(from: self.path) {
            self.privateKeyFilePath = keys.privateKeyFilePath
            self.privateKey = keys.privateKey
            self.publicKeyFilePath = keys.publicKeyFilePath
            self.publicKey = keys.publicKey
        } else {
            let keys = SSHAuthenticationInfo.createKeyPair(at: self.path)
            self.privateKeyFilePath = keys.privateKeyFilePath
            self.privateKey = keys.privateKey
            self.publicKeyFilePath = keys.publicKeyFilePath
            self.publicKey = keys.publicKey
        }
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
