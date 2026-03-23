import Cocoa
import Foundation
import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var fileListWindow: NSWindow?
    var fileListData: [(path: String, version: String)] = []
    var tableView: NSTableView?

    // Debounce: macOS may split a single drag-drop into multiple openFiles calls,
    // buffer all files and process together after 0.3s of inactivity
    private var pendingFiles: [String] = []
    private var debounceTimer: Timer?
    private static let debounceInterval: TimeInterval = 0.3

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, openFiles files: [String]) {
        pendingFiles.append(contentsOf: files)
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: Self.debounceInterval, repeats: false) { [weak self] _ in
            self?.processAllFiles()
        }
        NSApp.reply(toOpenOrPrint: .success)
    }

    private static let validExtensions: Set<String> = ["indd", "indt", "indb", "indl"]

    private func processAllFiles() {
        let files = pendingFiles
        pendingFiles = []

        // Separate directories and files, recursively scan directories for InDesign files
        var indesignFiles: [String] = []
        var hasDirectory = false
        let fm = FileManager.default

        for path in files {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                hasDirectory = true
                collectInDesignFiles(in: path, into: &indesignFiles)
            } else {
                let ext = (path as NSString).pathExtension.lowercased()
                if Self.validExtensions.contains(ext) {
                    indesignFiles.append(path)
                }
            }
        }

        // If any directory was dropped, force show file list window (same as Option mode)
        let optionKeyHeld = NSEvent.modifierFlags.contains(.option)
        let showListMode = optionKeyHeld || hasDirectory

        let myInDesignFile = InDesignFile()

        if showListMode {
            // Show file list window, don't open files
            fileListData = []
            for filePath in indesignFiles {
                if let (_, appName) = myInDesignFile.getVersion(file: filePath) {
                    fileListData.append((path: filePath, version: appName))
                } else {
                    fileListData.append((path: filePath, version: "Unknown"))
                }
            }
            if !fileListData.isEmpty {
                showFileListWindow()
            } else {
                NSApp.terminate(nil)
            }
        } else {
            // Normal mode: open files with corresponding InDesign version
            // Files without an installed version are collected and shown in the list window
            var filesToOpen: [(fileURL: URL, appURL: URL)] = []
            var notInstalledFiles: [(path: String, version: String)] = []

            for filePath in indesignFiles {
                if let (_, appName) = myInDesignFile.getVersion(file: filePath) {
                    let applicationPath = "/Applications/\(appName)/\(appName).app"
                    if fm.fileExists(atPath: applicationPath) {
                        filesToOpen.append((
                            fileURL: URL(fileURLWithPath: filePath),
                            appURL: URL(fileURLWithPath: applicationPath)
                        ))
                    } else {
                        notInstalledFiles.append((path: filePath, version: appName))
                    }
                }
                // Files with unrecognized format: skip silently
            }

            if notInstalledFiles.isEmpty && filesToOpen.isEmpty {
                NSApp.terminate(nil)
                return
            }

            // Show a single list window for all files without a matching installed version
            if !notInstalledFiles.isEmpty {
                fileListData = notInstalledFiles
                showFileListWindow()
            }

            let group = DispatchGroup()
            for item in filesToOpen {
                group.enter()
                NSWorkspace.shared.open([item.fileURL], withApplicationAt: item.appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                    group.leave()
                }
            }

            // Only auto-terminate when there is no list window keeping the app alive
            if notInstalledFiles.isEmpty {
                group.notify(queue: .main) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    /// Recursively collect InDesign files from a directory
    private func collectInDesignFiles(in directory: String, into results: inout [String]) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: directory) else { return }
        while let relativePath = enumerator.nextObject() as? String {
            let ext = (relativePath as NSString).pathExtension.lowercased()
            if Self.validExtensions.contains(ext) {
                results.append((directory as NSString).appendingPathComponent(relativePath))
            }
        }
    }

    // MARK: - File List Window

    private func showFileListWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InDesign Files"
        window.center()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        window.contentView?.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])

        let table = NSTableView()
        table.delegate = self
        table.dataSource = self
        table.doubleAction = #selector(tableViewDoubleClick(_:))
        table.target = self
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let versionColumnWidth: CGFloat = 200
        let contentWidth = window.contentView!.bounds.width

        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("filePath"))
        fileColumn.title = "File Path"
        fileColumn.width = contentWidth - versionColumnWidth
        fileColumn.minWidth = 200
        fileColumn.resizingMask = .autoresizingMask
        fileColumn.sortDescriptorPrototype = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        table.addTableColumn(fileColumn)

        let versionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        versionColumn.title = "InDesign Version"
        versionColumn.width = versionColumnWidth
        versionColumn.minWidth = versionColumnWidth
        versionColumn.maxWidth = versionColumnWidth
        versionColumn.resizingMask = []
        versionColumn.sortDescriptorPrototype = NSSortDescriptor(key: "version", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        table.addTableColumn(versionColumn)

        scrollView.documentView = table

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.fileListWindow = window
        self.tableView = table
    }

    @objc func tableViewDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < fileListData.count else { return }

        let item = fileListData[row]
        let myInDesignFile = InDesignFile()
        if let (_, appName) = myInDesignFile.getVersion(file: item.path) {
            let fileURL = URL(fileURLWithPath: item.path)
            let applicationPath = "/Applications/\(appName)/\(appName).app"
            if FileManager.default.fileExists(atPath: applicationPath) {
                NSWorkspace.shared.open([fileURL], withApplicationAt: URL(fileURLWithPath: applicationPath), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            } else {
                let alert = NSAlert()
                alert.messageText = "InDesign Not Installed"
                alert.informativeText = "\(appName) is not installed on this computer."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension AppDelegate: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return fileListData.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        for descriptor in tableView.sortDescriptors.reversed() {
            let ascending = descriptor.ascending
            switch descriptor.key {
            case "path":
                fileListData.sort { ascending ? $0.path.localizedStandardCompare($1.path) == .orderedAscending : $0.path.localizedStandardCompare($1.path) == .orderedDescending }
            case "version":
                fileListData.sort { ascending ? $0.version.localizedStandardCompare($1.version) == .orderedAscending : $0.version.localizedStandardCompare($1.version) == .orderedDescending }
            default:
                break
            }
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = fileListData[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        let cellView = NSTableCellView()
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingHead
        cellView.addSubview(textField)
        cellView.textField = textField
        cellView.toolTip = item.path

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        if identifier.rawValue == "filePath" {
            textField.stringValue = item.path
        } else if identifier.rawValue == "version" {
            textField.stringValue = item.version
        }

        return cellView
    }
}

// MARK: - InDesign Version Detection

struct InDesignVersion: Hashable {
    let major: Int
    let minor: Int
}

class InDesignFile {

    let fGUID: String
    let database: [String]
    var names: [InDesignVersion: String]

    init() {
        self.fGUID = "0606edf5d81d46e5bd31efe7fe74b71d"

        self.database = [
            "444f43554d454e54",// DOCUMENT: .indd/.indt
            "424f4f4b424f4f4b",// BOOKBOOK: .indb
            "4c49425241525934",// LIBRARY4: .indl
            "4c49425241525932" // LIBRARY2: old version: InDesign 2.0 / CS
        ]

        self.names = [
            InDesignVersion(major: 1, minor: 0): "1.0",
            InDesignVersion(major: 1, minor: 5): "1.5",
            InDesignVersion(major: 2, minor: 0): "2.0",
            InDesignVersion(major: 3, minor: 0): "CS",
            InDesignVersion(major: 4, minor: 0): "CS2",
            InDesignVersion(major: 5, minor: 0): "CS3",
            InDesignVersion(major: 6, minor: 0): "CS4",
            InDesignVersion(major: 7, minor: 0): "CS5",
            InDesignVersion(major: 7, minor: 5): "CS5.5",
            InDesignVersion(major: 8, minor: 0): "CS6",
            InDesignVersion(major: 9, minor: 0): "CC",
            InDesignVersion(major: 10, minor: 0): "CC 2014",
            InDesignVersion(major: 11, minor: 0): "CC 2015",
            InDesignVersion(major: 12, minor: 0): "CC 2017",
            InDesignVersion(major: 13, minor: 0): "CC 2018",
            InDesignVersion(major: 14, minor: 0): "CC 2019",
        ]
    }

    func getVersion(file: String, checkFGUID: Bool = true) -> (InDesignVersion, String)? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            var pos = 16
            let fGUID = data.prefix(pos).map { String(format: "%02hhx", $0) }.joined()
            if fGUID != self.fGUID {
                if checkFGUID {
                    return nil
                } else {
                    pos = 92
                }
            }

            guard data.count >= pos + 24 else { return nil }

            let subData = data.subdata(in: pos..<pos + 24)
            let fMagicBytes = subData[0..<8].map { String(format: "%02hhx", $0) }.joined()
            if !self.database.contains(fMagicBytes) {
                return nil
            }

            let fObjectStreamEndian = subData[8]
            let majorVersion: Int
            let minorVersion: Int

            switch fObjectStreamEndian {
            case 1:
                majorVersion = Int(subData[13])
                minorVersion = Int(subData[17])
            case 2:
                majorVersion = Int(subData[16])
                minorVersion = Int(subData[20])
            default:
                return nil
            }

            let appName = self.getAppName(majorVersion: majorVersion, minorVersion: minorVersion)
            return (InDesignVersion(major: majorVersion, minor: minorVersion), appName)
        } catch {
            return nil
        }
    }

    private func getAppName(majorVersion: Int, minorVersion: Int) -> String {
        let v: Int
        if (majorVersion == 1 || majorVersion == 7) && minorVersion == 5 {
            v = 5
        } else {
            v = 0
        }
        return "Adobe InDesign \(self.names[InDesignVersion(major: majorVersion, minor: v), default: String(2005 + majorVersion)])"
    }
}
