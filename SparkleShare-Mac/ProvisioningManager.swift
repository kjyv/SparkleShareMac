//
//  ProvisioningManager.swift
//  SparkleShare-Mac
//

import Foundation
import UserNotifications

class ProvisioningManager: ObservableObject {
    enum ProvisioningStatus {
        case unchecked
        case checking
        case valid(expiryDate: Date)
        case needsDeploy(expiryDate: Date)
    }

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.mobileDeploymentEnabled)
            if isEnabled {
                startTimer()
                checkAndDeployIfNeeded()
            } else {
                stopTimer()
                status = .unchecked
            }
        }
    }

    @Published var checkScriptPath: String {
        didSet {
            UserDefaults.standard.set(checkScriptPath, forKey: Keys.checkProvisionExpiryScriptPath)
            if !checkScriptPath.isEmpty && isEnabled {
                runExpiryCheck(completion: nil)
            }
        }
    }

    @Published var deployScriptPath: String {
        didSet { UserDefaults.standard.set(deployScriptPath, forKey: Keys.deployToDeviceScriptPath) }
    }

    @Published var nextDeployDate: Date? {
        didSet {
            if let date = nextDeployDate {
                UserDefaults.standard.set(date, forKey: Keys.nextDeployDate)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.nextDeployDate)
            }
        }
    }

    @Published var expiryDate: Date? {
        didSet {
            if let date = expiryDate {
                UserDefaults.standard.set(date, forKey: Keys.expiryDate)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.expiryDate)
            }
        }
    }

    @Published var status: ProvisioningStatus = .unchecked

    private var lastExpiryCheckDate: Date? {
        didSet {
            if let date = lastExpiryCheckDate {
                UserDefaults.standard.set(date, forKey: Keys.lastExpiryCheckDate)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastExpiryCheckDate)
            }
        }
    }

    @Published var isDeploying = false
    @Published var deployOutput: String = ""

    weak var errorStore: ErrorStore?
    private var timer: Timer?
    private var deployProcess: Process?

    private enum Keys {
        static let mobileDeploymentEnabled = "mobileDeploymentEnabled"
        static let checkProvisionExpiryScriptPath = "checkProvisionExpiryScriptPath"
        static let deployToDeviceScriptPath = "deployToDeviceScriptPath"
        static let nextDeployDate = "nextDeployDate"
        static let expiryDate = "expiryDate"
        static let lastExpiryCheckDate = "lastExpiryCheckDate"
    }

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.mobileDeploymentEnabled)
        self.checkScriptPath = UserDefaults.standard.string(forKey: Keys.checkProvisionExpiryScriptPath) ?? ""
        self.deployScriptPath = UserDefaults.standard.string(forKey: Keys.deployToDeviceScriptPath) ?? ""
        self.nextDeployDate = UserDefaults.standard.object(forKey: Keys.nextDeployDate) as? Date
        self.expiryDate = UserDefaults.standard.object(forKey: Keys.expiryDate) as? Date
        self.lastExpiryCheckDate = UserDefaults.standard.object(forKey: Keys.lastExpiryCheckDate) as? Date
        updateStatusFromStoredDates()
    }

    func startIfEnabled() {
        guard isEnabled else { return }
        requestNotificationPermission()
        updateStatusFromStoredDates()
        startTimer()
        checkAndDeployIfNeeded()
    }

    private func updateStatusFromStoredDates() {
        guard isEnabled, let expiry = expiryDate else { return }
        if let deployDate = nextDeployDate, deployDate <= Date() {
            status = .needsDeploy(expiryDate: expiry)
        } else {
            status = .valid(expiryDate: expiry)
        }
    }

    func handleWakeFromSleep() {
        guard isEnabled else { return }
        checkAndDeployIfNeeded()
    }

    func deployNow(onFailure: (() -> Void)? = nil) {
        runDeploy { [weak self] success in
            if success {
                self?.runExpiryCheck(completion: nil)
            } else {
                onFailure?()
            }
        }
    }

    func cancelDeploy() {
        deployProcess?.terminate()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.checkAndDeployIfNeeded()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Check & Deploy Logic

    private func checkAndDeployIfNeeded() {
        guard isEnabled else { return }

        // Re-run check script if > 24h since last check (or never checked)
        if shouldRunExpiryCheck() {
            runExpiryCheck { [weak self] in
                self?.evaluateAndDeploy()
            }
        } else {
            evaluateAndDeploy()
        }
    }

    private func shouldRunExpiryCheck() -> Bool {
        guard let lastCheck = lastExpiryCheckDate else { return true }
        return Date().timeIntervalSince(lastCheck) > 24 * 60 * 60
    }

    private func evaluateAndDeploy() {
        guard let deployDate = nextDeployDate else { return }

        if deployDate <= Date() {
            runDeploy { [weak self] success in
                if success {
                    // After successful deploy, re-check to get new expiry
                    self?.runExpiryCheck(completion: nil)
                } else {
                    // Deploy failed (device not connected) - check if we need notification
                    self?.checkIfNotificationNeeded()
                }
            }
        }
    }

    private func checkIfNotificationNeeded() {
        guard let expiry = expiryDate else { return }
        let hoursUntilExpiry = expiry.timeIntervalSinceNow / 3600

        if hoursUntilExpiry < 24 {
            sendNotification(expiryDate: expiry)
        }
    }

    // MARK: - Run Check Script

    private func runExpiryCheck(completion: (() -> Void)?) {
        guard !checkScriptPath.isEmpty else { return }

        status = .checking

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-l", self.checkScriptPath]
            process.currentDirectoryURL = URL(fileURLWithPath: self.checkScriptPath).deletingLastPathComponent()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.status = .unchecked
                    self.errorStore?.addError(
                        repositoryPath: self.checkScriptPath,
                        operationType: .provisioning,
                        errorMessage: "Failed to run check script: \(error.localizedDescription)"
                    )
                }
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                DispatchQueue.main.async {
                    self.status = .unchecked
                    self.errorStore?.addError(
                        repositoryPath: self.checkScriptPath,
                        operationType: .provisioning,
                        errorMessage: "Check script failed (exit \(process.terminationStatus)): \(output)"
                    )
                }
                return
            }

            // Parse SECONDS_LEFT=<number> from output
            if let secondsLeft = self.parseSecondsLeft(from: output) {
                let expiry = Date().addingTimeInterval(secondsLeft)
                let deployDate = Date().addingTimeInterval(secondsLeft - 24 * 60 * 60) // Deploy 1 day early
                DispatchQueue.main.async {
                    self.lastExpiryCheckDate = Date()
                    self.expiryDate = expiry
                    self.nextDeployDate = deployDate
                    if deployDate <= Date() {
                        self.status = .needsDeploy(expiryDate: expiry)
                        self.checkIfNotificationNeeded()
                    } else {
                        self.status = .valid(expiryDate: expiry)
                    }
                    completion?()
                }
            } else {
                DispatchQueue.main.async {
                    self.status = .unchecked
                    self.errorStore?.addError(
                        repositoryPath: self.checkScriptPath,
                        operationType: .provisioning,
                        errorMessage: "Could not parse SECONDS_LEFT from check script output: \(output)"
                    )
                }
            }
        }
    }

    private func parseSecondsLeft(from output: String) -> TimeInterval? {
        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("SECONDS_LEFT=") {
                let value = line.replacingOccurrences(of: "SECONDS_LEFT=", with: "")
                if let seconds = Double(value.trimmingCharacters(in: .whitespaces)) {
                    return seconds
                }
            }
        }
        return nil
    }

    // MARK: - Run Deploy Script

    private func runDeploy(completion: @escaping (Bool) -> Void) {
        guard !deployScriptPath.isEmpty, !isDeploying else {
            completion(false)
            return
        }

        isDeploying = true
        deployOutput = ""

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-l", self.deployScriptPath]
            process.currentDirectoryURL = URL(fileURLWithPath: self.deployScriptPath).deletingLastPathComponent()
            process.standardOutput = pipe
            process.standardError = pipe

            DispatchQueue.main.async {
                self.deployProcess = process
            }

            // Read output line-by-line as it arrives
            var fullOutput = ""
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                fullOutput += line
                let lastLine = line.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .last ?? ""
                DispatchQueue.main.async {
                    self.deployOutput = lastLine
                }
            }

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    self.deployProcess = nil
                    self.isDeploying = false
                    self.deployOutput = ""
                    self.errorStore?.addError(
                        repositoryPath: self.deployScriptPath,
                        operationType: .provisioning,
                        errorMessage: "Failed to run deploy script: \(error.localizedDescription)"
                    )
                    completion(false)
                }
                return
            }

            pipe.fileHandleForReading.readabilityHandler = nil
            let success = process.terminationStatus == 0

            DispatchQueue.main.async {
                self.deployProcess = nil
                self.isDeploying = false
                self.deployOutput = ""
                if !success {
                    self.errorStore?.addError(
                        repositoryPath: self.deployScriptPath,
                        operationType: .provisioning,
                        errorMessage: "Deploy script failed (exit \(process.terminationStatus)): \(fullOutput)"
                    )
                }
                completion(success)
            }
        }
    }

    // MARK: - Notification

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(expiryDate: Date) {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: expiryDate, relativeTo: Date())

        let content = UNMutableNotificationContent()
        content.title = "SparkleShare"
        content.subtitle = "Provisioning profile expiring soon"
        content.body = "Mobile app profile expires \(relative). Make sure your iOS device is connected to re-deploy."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "provisioningExpiry", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
