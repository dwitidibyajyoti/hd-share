import AppKit
import Foundation

public final class ShareManager {
    public static let shared = ShareManager()
    
    private init() {}
    
    /// Reveal URLs in Finder
    public func revealInFinder(urls: [URL]) {
        guard let first = urls.first else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls.isEmpty ? [first] : urls)
    }
    
    /// Present macOS Share Sheet
    public func showShareSheet(items: [Any], from view: NSView) {
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
    
    /// Attempt to launch WhatsApp app or WhatsApp Web
    public func openWhatsApp() {
        if let whatsappAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.whatsapp.WhatsApp") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: whatsappAppURL, configuration: configuration, completionHandler: nil)
        } else if let webURL = URL(string: "https://web.whatsapp.com") {
            NSWorkspace.shared.open(webURL)
        }
    }
    
    /// Copy files to pasteboard so user can simply Cmd+V directly in WhatsApp chat
    public func copyFilesToClipboard(urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSPasteboardWriting])
    }
}
