import Foundation
import Combine
import AppKit

class BackupManager: ObservableObject {
    @Published var outdatedApps: [OutdatedApp] = []
    @Published var backupApps: [BackupApp] = []
    
    @Published var isScanning: Bool = false
    @Published var isPerformingAction: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentStatus: String = ""
    @Published var logs: String = ""
    
    @Published var isMasInstalled: Bool = true
    @Published var isBrewInstalled: Bool = true
    @Published var isInstallingMas: Bool = false
    
    private var resolvedMasPath: String = "mas"
    
    // Struct representing an app that has updates available
    struct OutdatedApp: Identifiable, Hashable {
        let id: String
        let name: String
        let currentVersion: String
        let newVersion: String
        var path: String?
        var isSelected: Bool = true
    }
    
    // Struct representing a backed-up app
    struct BackupApp: Identifiable, Hashable {
        let id: String // path acts as unique ID
        let name: String
        let path: String
        let size: String
        var isSelected: Bool = true
    }
    
    init() {
        // Run dependency checks asynchronously to avoid blocking the main thread
        // during SwiftUI graph initialization.
        DispatchQueue.global(qos: .userInitiated).async {
            self.checkDependencies()
        }
    }
    
    // Check if mas and brew are installed
    func checkDependencies() {
        let masCheck = runShell(command: "/usr/bin/which", arguments: ["mas"])
        var masFound = masCheck.status == 0
        var foundMasPath = "mas"
        
        if masFound {
            foundMasPath = masCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let alternativePaths = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
            for path in alternativePaths {
                if FileManager.default.fileExists(atPath: path) {
                    masFound = true
                    foundMasPath = path
                    break
                }
            }
        }
        
        let brewCheck = runShell(command: "/usr/bin/which", arguments: ["brew"])
        var brewFound = brewCheck.status == 0
        
        if !brewFound {
            let alternativeBrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            for path in alternativeBrewPaths {
                if FileManager.default.fileExists(atPath: path) {
                    brewFound = true
                    break
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isMasInstalled = masFound
            self.isBrewInstalled = brewFound
            self.resolvedMasPath = foundMasPath
        }
    }
    
    // Install mas using brew
    func installMas() {
        guard isBrewInstalled else {
            appendLog("Error: Homebrew is not installed. Please install Homebrew or 'mas' manually.\n")
            return
        }
        
        isInstallingMas = true
        progress = 0.0
        currentStatus = "Installing 'mas' CLI via Homebrew..."
        appendLog("Running: brew install mas\n")
        
        // Get absolute brew path
        var brewPath = "/opt/homebrew/bin/brew"
        if !FileManager.default.fileExists(atPath: brewPath) {
            brewPath = "/usr/local/bin/brew"
            if !FileManager.default.fileExists(atPath: brewPath) {
                brewPath = "brew" // fallback to path search
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runShell(command: brewPath, arguments: ["install", "mas"])
            
            DispatchQueue.main.async {
                self.isInstallingMas = false
                self.appendLog(result.output)
                if result.status == 0 {
                    self.isMasInstalled = true
                    self.currentStatus = "'mas' installed successfully!"
                    self.appendLog("'mas' CLI has been successfully installed.\n")
                } else {
                    self.currentStatus = "Failed to install 'mas'."
                    self.appendLog("Error installing 'mas'. Exit code: \(result.status)\n")
                }
            }
        }
    }
    
    // Scan for outdated apps
    func scanOutdatedApps(silent: Bool = false) {
        guard isMasInstalled else { return }
        
        if !silent {
            isScanning = true
            progress = 0.0
            currentStatus = "Scanning for outdated App Store apps..."
            outdatedApps = []
            logs = ""
        }
        
        let masPath = self.resolvedMasPath
        
        DispatchQueue.global(qos: .userInitiated).async {
            if !silent {
                self.appendLog("Running: mas outdated\n")
            }
            let result = self.runShell(command: masPath, arguments: ["outdated"])
            
            var apps: [OutdatedApp] = []
            let lines = result.output.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                // Parse lines like: "507589476 CotEditor (4.6.4 -> 4.7.2)"
                // Or: "409649525 Keynote (14.0 -> 14.1)"
                guard let openParenthesisIndex = trimmed.firstIndex(of: "("),
                      let closeParenthesisIndex = trimmed.firstIndex(of: ")"),
                      openParenthesisIndex < closeParenthesisIndex else {
                    continue
                }
                
                let idAndNamePart = trimmed[..<openParenthesisIndex].trimmingCharacters(in: .whitespaces)
                let versionPart = trimmed[trimmed.index(after: openParenthesisIndex)..<closeParenthesisIndex]
                
                // Split idAndNamePart by first space
                let parts = idAndNamePart.components(separatedBy: .whitespaces)
                guard parts.count >= 2 else { continue }
                let appId = parts[0]
                let appName = parts[1...].joined(separator: " ")
                
                // Parse version part like "4.6.4 -> 4.7.2"
                let versions = versionPart.components(separatedBy: "->")
                let currentVer = versions.first?.trimmingCharacters(in: .whitespaces) ?? "unknown"
                let newVer = versions.last?.trimmingCharacters(in: .whitespaces) ?? "unknown"
                
                // Find path via mdfind (excluding backup paths)
                let pathResult = self.runShell(command: "/usr/bin/mdfind", arguments: ["kMDItemAppStoreAdamID == \(appId)"])
                let paths = pathResult.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let nonBackupPath = paths.first { !$0.contains("-AppStoreBackup") && !$0.isEmpty }
                let finalPath = nonBackupPath ?? "/Applications/\(appName).app"
                
                let app = OutdatedApp(id: appId, name: appName, currentVersion: currentVer, newVersion: newVer, path: finalPath)
                apps.append(app)
                
                if !silent {
                    self.appendLog("Found Outdated App: \(appName) (ID: \(appId)) -> \(finalPath)\n")
                }
            }
            
            DispatchQueue.main.async {
                self.outdatedApps = apps
                if !silent {
                    self.isScanning = false
                    self.currentStatus = "Found \(apps.count) app\(apps.count == 1 ? "" : "s") to update."
                }
            }
        }
    }
    
    // Scan for existing backups
    func scanBackups(silent: Bool = false) {
        if !silent {
            isScanning = true
            progress = 0.0
            currentStatus = "Scanning /Applications for backups..."
            backupApps = []
            logs = ""
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let applicationsPath = "/Applications"
            let fileManager = FileManager.default
            var backups: [BackupApp] = []
            
            do {
                let items = try fileManager.contentsOfDirectory(atPath: applicationsPath)
                for item in items {
                    if item.hasSuffix("-AppStoreBackup.app") {
                        let fullPath = "\(applicationsPath)/\(item)"
                        let appName = item.replacingOccurrences(of: "-AppStoreBackup.app", with: "")
                        
                        // Get size using du -sh
                        let sizeResult = self.runShell(command: "/usr/bin/du", arguments: ["-sh", fullPath])
                        let sizeString = sizeResult.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first ?? "Unknown size"
                        
                        let backup = BackupApp(id: fullPath, name: appName, path: fullPath, size: sizeString)
                        backups.append(backup)
                        
                        if !silent {
                            self.appendLog("Found Backup: \(item) (\(sizeString))\n")
                        }
                    }
                }
            } catch {
                if !silent {
                    self.appendLog("Error scanning /Applications: \(error.localizedDescription)\n")
                }
            }
            
            DispatchQueue.main.async {
                self.backupApps = backups
                if !silent {
                    self.isScanning = false
                    self.currentStatus = "Found \(backups.count) backup\(backups.count == 1 ? "" : "s")."
                }
            }
        }
    }
    
    // Perform backup and updates
    func updateSelectedApps() {
        let appsToUpdate = outdatedApps.filter { $0.isSelected }
        guard !appsToUpdate.isEmpty else { return }
        
        isPerformingAction = true
        progress = 0.0
        currentStatus = "Starting updates..."
        logs = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            let totalSteps = Double(appsToUpdate.count + 1) // 1 step per backup, 1 step for consolidated upgrade
            var currentStep = 0.0
            
            for app in appsToUpdate {
                // Step 1: Backup App
                DispatchQueue.main.async {
                    self.currentStatus = "Backing up \(app.name)..."
                }
                
                let originalPath = app.path ?? "/Applications/\(app.name).app"
                let backupPath = originalPath.replacingOccurrences(of: ".app", with: "-AppStoreBackup.app")
                
                self.appendLog("----------------------------------------\n")
                self.appendLog("App: \(app.name)\n")
                self.appendLog("Original Path: \(originalPath)\n")
                self.appendLog("Backup Path: \(backupPath)\n")
                
                if FileManager.default.fileExists(atPath: originalPath) {
                    // Remove existing backup first to prevent directory nesting
                    _ = self.runShell(command: "/bin/rm", arguments: ["-rf", backupPath])
                    
                    self.appendLog("Backing up app...\n")
                    let cpResult = self.runShell(command: "/bin/cp", arguments: ["-R", originalPath, backupPath])
                    
                    if cpResult.status == 0 {
                        self.appendLog("✓ App backup successful.\n")
                    } else {
                        self.appendLog("✗ Backup failed with status \(cpResult.status): \(cpResult.output)\n")
                    }
                } else {
                    self.appendLog("✗ Original app bundle not found. Skipping backup.\n")
                }
                
                currentStep += 1.0
                DispatchQueue.main.async {
                    self.progress = currentStep / totalSteps
                }
            }
            
            // Step 2: Consolidated Upgrade App via mas
            DispatchQueue.main.async {
                self.currentStatus = "Upgrading selected apps (App Store)..."
            }
            
            let masPath = self.resolvedMasPath
            let ids = appsToUpdate.map { $0.id }.joined(separator: " ")
            
            self.appendLog("----------------------------------------\n")
            self.appendLog("Upgrading via App Store CLI (Consolidated IDs: \(ids))...\n")
            
            // Show native password dialog on the main thread.
            // NSAlert.runModal() runs a nested event loop so the app stays
            // responsive and DispatchQueue.main.sync does NOT deadlock.
            var password: String? = nil
            DispatchQueue.main.sync {
                let alert = NSAlert()
                alert.messageText = "Administrator Password Required"
                alert.informativeText = "Enter your password to update App Store apps."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                
                let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
                input.placeholderString = "Password"
                alert.accessoryView = input
                alert.window.initialFirstResponder = input
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    password = input.stringValue
                }
            }
            
            if let adminPassword = password, !adminPassword.isEmpty {
                self.appendLog("Running elevated mas upgrade...\n")
                
                // Use sudo -S which reads the password from stdin.
                // Real sudo automatically sets SUDO_UID/SUDO_GID/SUDO_USER
                // so mas-cli can identify the calling user's App Store session.
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                var args = ["-S", masPath, "upgrade"]
                args.append(contentsOf: appsToUpdate.map { $0.id })
                process.arguments = args
                
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                process.standardInput = inputPipe
                process.standardOutput = outputPipe
                process.standardError = outputPipe
                
                // Stream output to log in real-time
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let string = String(data: data, encoding: .utf8) {
                        self?.appendLog(string)
                    }
                }
                
                do {
                    try process.run()
                    
                    // Pipe password to sudo's stdin
                    if let passwordData = (adminPassword + "\n").data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(passwordData)
                    }
                    inputPipe.fileHandleForWriting.closeFile()
                    
                    process.waitUntilExit()
                    
                    // Clean up handler and read any remaining data
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    let remaining = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty, let str = String(data: remaining, encoding: .utf8) {
                        self.appendLog(str)
                    }
                    
                    if process.terminationStatus == 0 {
                        self.appendLog("✓ Upgrade completed successfully!\n")
                    } else {
                        self.appendLog("✗ Upgrade failed (Status: \(process.terminationStatus))\n")
                    }
                } catch {
                    self.appendLog("✗ Error running upgrade: \(error.localizedDescription)\n")
                }
            } else {
                self.appendLog("✗ Upgrade cancelled by user.\n")
            }
            
            currentStep += 1.0
            DispatchQueue.main.async {
                self.progress = currentStep / totalSteps
            }
            
            DispatchQueue.main.async {
                self.isPerformingAction = false
                self.currentStatus = "Update process completed."
                self.progress = 1.0
                // Rescan outdated apps to update list silently
                self.scanOutdatedApps(silent: true)
            }
        }
    }
    
    // Perform deletion of selected backups
    func deleteSelectedBackups() {
        let backupsToDelete = backupApps.filter { $0.isSelected }
        guard !backupsToDelete.isEmpty else { return }
        
        isPerformingAction = true
        progress = 0.0
        currentStatus = "Deleting backups..."
        logs = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            let totalSteps = Double(backupsToDelete.count)
            var currentStep = 0.0
            
            for backup in backupsToDelete {
                DispatchQueue.main.async {
                    self.currentStatus = "Deleting \(backup.name) backup..."
                }
                
                self.appendLog("Deleting: \(backup.path)\n")
                let rmResult = self.runShell(command: "/bin/rm", arguments: ["-rf", backup.path])
                
                if rmResult.status == 0 {
                    self.appendLog("✓ Deleted \(backup.name) backup.\n")
                } else {
                    self.appendLog("✗ Failed to delete \(backup.name) backup (Status: \(rmResult.status)): \(rmResult.output)\n")
                }
                
                currentStep += 1.0
                DispatchQueue.main.async {
                    self.progress = currentStep / totalSteps
                }
            }
            
            DispatchQueue.main.async {
                self.isPerformingAction = false
                self.currentStatus = "Deletion completed."
                self.progress = 1.0
                // Rescan backups silently
                self.scanBackups(silent: true)
            }
        }
    }
    
    // Helper to log text safely on main thread
    private func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.logs += text
        }
    }
    
    // Runs shell command and streams stdout/stderr in real-time if verbose is true, otherwise returns accumulated output.
    private func runShell(command: String, arguments: [String], verbose: Bool = false) -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        var outputData = Data()
        let outputLock = NSLock()
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            outputLock.lock()
            outputData.append(data)
            outputLock.unlock()
            
            if verbose, let string = String(data: data, encoding: .utf8) {
                self?.appendLog(string)
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Disable readability handler
            pipe.fileHandleForReading.readabilityHandler = nil
            
            // Read any leftover data in the pipe buffer
            let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
            outputLock.lock()
            outputData.append(remaining)
            let finalOutput = String(data: outputData, encoding: .utf8) ?? ""
            outputLock.unlock()
            
            return (finalOutput, process.terminationStatus)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return ("Error running command: \(error.localizedDescription)", -1)
        }
    }
}
