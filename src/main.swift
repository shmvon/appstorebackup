import SwiftUI
import AppKit

// ----------------------------------------------------
// App Entry Point & Window Management
// ----------------------------------------------------
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        
        let contentView = ContentView()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "AppStore Backup Utility"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        
        // Ensure the app displays in the Dock and accepts window focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        let appName = "AppStoreBackup"
        
        let aboutItem = NSMenuItem(
            title: "About \(appName)",
            action: #selector(AppDelegate.showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        
        // Edit Menu (crucial for shortcuts like copy, paste, select all)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenu.addItem(undoItem)
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(cutItem)
        editMenu.addItem(copyItem)
        editMenu.addItem(pasteItem)
        editMenu.addItem(selectAllItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AppStore Backup"
        alert.informativeText = """
            Version 1.0
            © shmvon

            Backup your App Store apps before updating them.

            https://github.com/shmvon/appstorebackup
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open on GitHub")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/shmvon/appstorebackup") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// ----------------------------------------------------
// Main Coordinator View
// ----------------------------------------------------
enum ActiveScreen {
    case home
    case updateList
    case deleteList
    case progress(title: String)
}

struct ContentView: View {
    @StateObject private var manager = BackupManager()
    @State private var activeScreen: ActiveScreen = .home
    @State private var searchQuery: String = ""
    
    var body: some View {
        ZStack {
            // Premium Dark Gradient Background
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Window Drag/Header Bar (reserves space for traffic lights on all screens)
                HeaderBarView()
                
                // Screen Content Router
                ZStack {
                    switch activeScreen {
                    case .home:
                        HomeView(manager: manager, activeScreen: $activeScreen)
                        
                    case .updateList:
                        UpdateListView(manager: manager, activeScreen: $activeScreen, searchQuery: $searchQuery)
                        
                    case .deleteList:
                        DeleteListView(manager: manager, activeScreen: $activeScreen, searchQuery: $searchQuery)
                        
                    case .progress(let title):
                        ProgressScreen(manager: manager, activeScreen: $activeScreen, title: title)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 16)
            }
        }
        .frame(minWidth: 700, minHeight: 480)
    }
}

// ----------------------------------------------------
// Custom Window Header Bar
// ----------------------------------------------------
struct HeaderBarView: View {
    var body: some View {
        HStack {
            Spacer()
            Text("AppStore Backup Utility")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: 28)
        .background(Color.black.opacity(0.1))
    }
}

// ----------------------------------------------------
// Home View (Two main buttons)
// ----------------------------------------------------
struct HomeView: View {
    @ObservedObject var manager: BackupManager
    @Binding var activeScreen: ActiveScreen
    
    var body: some View {
        VStack(spacing: 0) {
            // Centred branding + buttons occupying all available space
            VStack(spacing: 32) {
                Spacer()
                
                // App Branding Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    Text("App Store Backup")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Backup your App Store applications before triggering updates.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if !manager.isMasInstalled {
                    // Dependency Warning State
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Missing Dependency")
                                    .font(.headline)
                                Text("The Mac App Store Command Line Interface ('mas') is required.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        
                        if manager.isInstallingMas {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Installing 'mas' via Homebrew...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if manager.isBrewInstalled {
                            Button(action: {
                                manager.installMas()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                    Text("Install 'mas' CLI via Homebrew")
                                }
                                .frame(width: 250)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            Text("Please install 'mas-cli' or Homebrew manually.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 40)
                } else {
                    // Main Button Options
                    HStack(spacing: 24) {
                        // Update Button
                        Button(action: {
                            activeScreen = .updateList
                            manager.scanOutdatedApps()
                        }) {
                            VStack(spacing: 16) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 4) {
                                    Text("Update Apps")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Scan outdated apps and backup before upgrade")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(width: 200, height: 120)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Delete Button
                        Button(action: {
                            activeScreen = .deleteList
                            manager.scanBackups()
                        }) {
                            VStack(spacing: 16) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 4) {
                                    Text("Delete Backups")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Scan and remove existing app backups")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(width: 200, height: 120)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color.purple, Color.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
            
            // Diagnostics Status — pinned to bottom, always fully visible
            HStack(spacing: 16) {
                StatusIndicator(title: "Brew Status", isActive: manager.isBrewInstalled)
                StatusIndicator(title: "Mas CLI Status", isActive: manager.isMasInstalled)
            }
            .font(.caption)
            .padding(.bottom, 8)
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundColor(.secondary)
        }
    }
}

// ----------------------------------------------------
// Update Apps List Screen
// ----------------------------------------------------
struct UpdateListView: View {
    @ObservedObject var manager: BackupManager
    @Binding var activeScreen: ActiveScreen
    @Binding var searchQuery: String
    
    var filteredApps: [BackupManager.OutdatedApp] {
        if searchQuery.isEmpty {
            return manager.outdatedApps
        } else {
            return manager.outdatedApps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var selectedCount: Int {
        manager.outdatedApps.filter { $0.isSelected }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Info
            HStack {
                Button(action: { activeScreen = .home }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Select Apps to Upgrade")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder alignment spacer
                Button(action: {}) {
                    Text("Back")
                }
                .buttonStyle(.borderless)
                .opacity(0)
            }
            
            // Search & Select All Actions
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search apps...", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .frame(maxWidth: 240)
                
                Spacer()
                
                Button("Select All") {
                    setAllSelection(true)
                }
                .buttonStyle(.borderless)
                
                Text("|")
                    .foregroundColor(.secondary)
                
                Button("Deselect All") {
                    setAllSelection(false)
                }
                .buttonStyle(.borderless)
            }
            
            // App List Box
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if manager.isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning outdated App Store apps...")
                            .foregroundColor(.secondary)
                    }
                } else if manager.outdatedApps.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("All App Store apps are up to date!")
                            .font(.title3)
                            .bold()
                        
                        Button("Refresh") {
                            manager.scanOutdatedApps()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List {
                        ForEach(filteredApps) { app in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { app.isSelected },
                                    set: { val in
                                        if let idx = manager.outdatedApps.firstIndex(where: { $0.id == app.id }) {
                                            manager.outdatedApps[idx].isSelected = val
                                        }
                                    }
                                ))
                                .toggleStyle(CheckboxToggleStyle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.name)
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Path: \(app.path ?? "Not found")")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Text(app.currentVersion)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text(app.newVersion)
                                        .foregroundColor(.green)
                                        .bold()
                                }
                                .font(.system(size: 12))
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom Action Confirm
            HStack {
                Text("\(selectedCount) of \(manager.outdatedApps.count) selected")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    activeScreen = .progress(title: "Backing Up & Updating Apps")
                    manager.updateSelectedApps()
                }) {
                    Text("Backup & Update")
                        .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedCount == 0 || manager.isScanning)
            }
        }
    }
    
    private func setAllSelection(_ select: Bool) {
        for i in 0..<manager.outdatedApps.count {
            manager.outdatedApps[i].isSelected = select
        }
    }
}

// ----------------------------------------------------
// Delete Backups List Screen
// ----------------------------------------------------
struct DeleteListView: View {
    @ObservedObject var manager: BackupManager
    @Binding var activeScreen: ActiveScreen
    @Binding var searchQuery: String
    
    var filteredBackups: [BackupManager.BackupApp] {
        if searchQuery.isEmpty {
            return manager.backupApps
        } else {
            return manager.backupApps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var selectedCount: Int {
        manager.backupApps.filter { $0.isSelected }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Info
            HStack {
                Button(action: { activeScreen = .home }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Select Backups to Delete")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder alignment spacer
                Button(action: {}) {
                    Text("Back")
                }
                .buttonStyle(.borderless)
                .opacity(0)
            }
            
            // Search & Select Actions
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search backups...", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .frame(maxWidth: 240)
                
                Spacer()
                
                Button("Select All") {
                    setAllSelection(true)
                }
                .buttonStyle(.borderless)
                
                Text("|")
                    .foregroundColor(.secondary)
                
                Button("Deselect All") {
                    setAllSelection(false)
                }
                .buttonStyle(.borderless)
            }
            
            // App List Box
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if manager.isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning backups in /Applications...")
                            .foregroundColor(.secondary)
                    }
                } else if manager.backupApps.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No backups found!")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        Button("Refresh") {
                            manager.scanBackups()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List {
                        ForEach(filteredBackups) { backup in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { backup.isSelected },
                                    set: { val in
                                        if let idx = manager.backupApps.firstIndex(where: { $0.id == backup.id }) {
                                            manager.backupApps[idx].isSelected = val
                                        }
                                    }
                                ))
                                .toggleStyle(CheckboxToggleStyle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.name + "-AppStoreBackup")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Path: \(backup.path)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(backup.size)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom Action Confirm
            HStack {
                Text("\(selectedCount) of \(manager.backupApps.count) selected")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    activeScreen = .progress(title: "Deleting App Backups")
                    manager.deleteSelectedBackups()
                }) {
                    Text("Delete Backups")
                        .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .foregroundColor(.white)
                .tint(.red)
                .disabled(selectedCount == 0 || manager.isScanning)
            }
        }
    }
    
    private func setAllSelection(_ select: Bool) {
        for i in 0..<manager.backupApps.count {
            manager.backupApps[i].isSelected = select
        }
    }
}

// ----------------------------------------------------
// Premium Progress & Real-Time Logs Screen
// ----------------------------------------------------
struct ProgressScreen: View {
    @ObservedObject var manager: BackupManager
    @Binding var activeScreen: ActiveScreen
    let title: String
    
    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2)
                .bold()
            
            // Custom Bouncing Gradient Progress Bar
            PremiumProgressBar(value: manager.progress)
                .padding(.horizontal, 20)
            
            HStack {
                Text(manager.currentStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(manager.progress * 100))%")
                    .font(.body)
                    .bold()
            }
            .padding(.horizontal, 20)
            
            // Log Viewer Box
            VStack(alignment: .leading, spacing: 8) {
                Text("Process Logs:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.07, green: 0.07, blue: 0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    ScrollView {
                        ScrollViewReader { scrollView in
                            Text(manager.logs.isEmpty ? "Initializing process..." : manager.logs)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.45))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .id("LogText")
                                .onChange(of: manager.logs) {
                                    withAnimation {
                                        scrollView.scrollTo("LogText", anchor: .bottom)
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom Done / Close
            Button(action: {
                activeScreen = .home
            }) {
                Text("Return to Home")
                    .frame(width: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manager.isPerformingAction)
        }
    }
}

// Custom Progress Bar Drawing
struct PremiumProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 10)
                
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0.0), 1.0)), height: 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
            }
        }
        .frame(height: 10)
    }
}

// Custom Checkbox Toggle Style for standard toggle boxes
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(configuration.isOn ? .blue : .secondary)
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ----------------------------------------------------
// App Delegate Main Initializer
// ----------------------------------------------------
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
