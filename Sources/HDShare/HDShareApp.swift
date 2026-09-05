import SwiftUI
import AppKit

@main
struct HDShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainContentView()
                .navigationTitle("HDShare for WhatsApp")
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        MenuBarExtra("HDShare", systemImage: "video.badge.waveform") {
            MenuBarView {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupAppDockIcon()
        
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = args[1]
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .hdShareOpenFile, object: url)
                }
            }
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened via "Open With" or Dragged to App Icon
        if let videoURL = urls.first {
            NotificationCenter.default.post(name: .hdShareOpenFile, object: videoURL)
        }
    }
    
    private func setupAppDockIcon() {
        let size: CGFloat = 512
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = size * 0.223
        let roundedRect = rect.insetBy(dx: size * 0.05, dy: size * 0.05)
        let path = NSBezierPath(roundedRect: roundedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Deep Indigo to Vibrant Blue Gradient
        if let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.32, alpha: 1.0),
            NSColor(calibratedRed: 0.05, green: 0.50, blue: 0.90, alpha: 1.0)
        ]) {
            gradient.draw(in: path, angle: -45)
        }
        
        // Subtle highlight border
        NSColor(white: 1.0, alpha: 0.25).setStroke()
        path.lineWidth = size * 0.015
        path.stroke()
        
        // SF Symbol: video.badge.waveform
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.44, weight: .bold)
        if let symbol = NSImage(systemSymbolName: "video.badge.waveform", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolRect = NSRect(
                x: (size - symbol.size.width) / 2.0,
                y: (size - symbol.size.height) / 2.0,
                width: symbol.size.width,
                height: symbol.size.height
            )
            symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        
        img.unlockFocus()
        NSApp.applicationIconImage = img
    }
}

extension Notification.Name {
    static let hdShareOpenFile = Notification.Name("hdShareOpenFile")
}
