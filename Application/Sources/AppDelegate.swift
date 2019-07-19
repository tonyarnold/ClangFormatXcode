import AppKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, NSPathControlDelegate {
    @IBOutlet var formatPopUpButton: NSPopUpButton!
    @IBOutlet var pathControl: NSPathControl!
    @IBOutlet var window: NSWindow!

    override init() {
        super.init()

        // Register value transformers
        ValueTransformer.setValueTransformer(LowercaseValueTransformer(), forName: LowercaseValueTransformer.transformerName)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.applicationGroupDefaults.register(defaults: [
            "style": "llvm"
        ])

        let itemTitleToSelect = formatPopUpButton.itemTitles.first { $0.lowercased() == UserDefaults.applicationGroupDefaults.string(forKey: "style") }!
        formatPopUpButton.selectItem(withTitle: itemTitleToSelect)
        pathControl.isEnabled = itemTitleToSelect.lowercased() == "custom"
        pathControl.isHidden = itemTitleToSelect.lowercased() != "custom"

        var isStale = false

        guard
            let bookmark = UserDefaults.applicationGroupDefaults.data(forKey: "securityBookmark"),
            let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale),
            url.startAccessingSecurityScopedResource()
        else {
            // Remove the bookmark value from the storage
            UserDefaults.applicationGroupDefaults.removeObject(forKey: "regularBookmark")
            return
        }

        // Regenerate the bookmark, so that the extension can read a valid bookmark after a system restart.\
        let regularBookmark = try? url.bookmarkData()
        url.stopAccessingSecurityScopedResource()
        UserDefaults.applicationGroupDefaults.set(regularBookmark, forKey: "regularBookmark")
        pathControl.url = url
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        return selectURL(url)
    }

    @IBAction func selectFormatStyle(_ sender: NSPopUpButton) {
        let title = sender.selectedItem?.title.lowercased()
        UserDefaults.applicationGroupDefaults.set(title, forKey: "style")
        pathControl.isEnabled = (title == "custom")
        pathControl.isHidden = (title != "custom")
    }

    @IBAction func selectConfiguration(_ sender: NSPathControl) {
        guard
            let url = sender.url,
            let configurationFileURL = findClangFormatFile(from: url)
        else {
            return
        }

        selectURL(configurationFileURL)
    }

    func pathControl(_ pathControl: NSPathControl, willDisplay openPanel: NSOpenPanel) {
        openPanel.title = NSLocalizedString("Choose a custom .clang-format file", comment: "Title for open panel when selecting a custom configuration file")
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.showsHiddenFiles = true
        openPanel.treatsFilePackagesAsDirectories = true
        openPanel.allowsMultipleSelection = false
    }

    func pathControl(_ pathControl: NSPathControl, validateDrop info: NSDraggingInfo) -> NSDragOperation {
        guard
            let url = NSURL(from: info.draggingPasteboard),
            let configurationFileURL = findClangFormatFile(from: url as URL),
            let _ = try? createBookmark(from: configurationFileURL)
        else {
            return []
        }

        return .copy
    }

    // MARK: - Private Implementation -

    private func createBookmark(from url: URL) throws -> Data {
        // Create a bookmark and store into defaults.
        return try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    @discardableResult
    private func selectURL(_ url: URL) -> Bool {
        guard let bookmark = try? createBookmark(from: url) else {
            return false
        }

        pathControl.url = url
        UserDefaults.applicationGroupDefaults.set("custom", forKey: "style")
        UserDefaults.applicationGroupDefaults.set(bookmark, forKey: "securityBookmark")
        UserDefaults.applicationGroupDefaults.set(try? url.bookmarkData(), forKey: "regularBookmark")

        return true
    }

    private func findClangFormatFile(from url: URL) -> URL? {
        guard
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
            resourceValues.isDirectory ?? false
        else {
            return url
        }

        return url.appendingPathComponent(".clang-format")
    }
}
