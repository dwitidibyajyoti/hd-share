import SwiftUI
import AppKit

public struct MenuBarView: View {
    @StateObject private var processor = VideoProcessor()
    @ObservedObject private var license = LicenseManager.shared
    @State private var selectedFileURL: URL?
    @State private var videoDuration: Double = 0.0
    @State private var splitMode: SplitMode = .whatsAppStatus30
    
    public var onOpenMainWindow: () -> Void
    
    public init(onOpenMainWindow: @escaping () -> Void) {
        self.onOpenMainWindow = onOpenMainWindow
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("HDShare")
                    .font(.headline)
                if license.isLicensed {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(3)
                } else {
                    Text("FREE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(3)
                }
                
                Spacer()
                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .help("Open Full App Window")
            }
            
            Divider()
            
            FileDropAreaView(selectedFileURL: $selectedFileURL, videoDuration: $videoDuration) { url in
                Task {
                    let meta = await VideoProcessor.inspectVideo(url: url)
                    await MainActor.run {
                        self.processor.metadata = meta
                    }
                }
            }
            
            if selectedFileURL != nil {
                if let meta = processor.metadata {
                    HStack {
                        Text("Bitrate: **\(meta.bitrateFormatted)**")
                        Spacer()
                        let maxDur: Double = {
                            switch splitMode {
                            case .whatsAppHD: return meta.maxDurationFor95MB
                            case .whatsAppStatus30: return 30.0
                            case .whatsAppStatus60: return 60.0
                            case .discordEmail: return meta.maxDurationFor25MB
                            case .telegram2GB: return meta.maxDurationFor2GB
                            default: return meta.maxDurationFor95MB
                            }
                        }()
                        Text("Slice: **\(String(format: "%.1f", maxDur))s**")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Picker("Target Preset", selection: $splitMode) {
                    Text("WhatsApp Status (30s)").tag(SplitMode.whatsAppStatus30)
                    Text("WhatsApp 95MB (PRO)").tag(SplitMode.whatsAppHD)
                    Text("Discord/Email 25MB (PRO)").tag(SplitMode.discordEmail)
                    Text("Telegram 2GB (PRO)").tag(SplitMode.telegram2GB)
                }
                .pickerStyle(.menu)
                
                let isProRequired = !license.isFeatureAvailable(mode: splitMode)
                
                Button(action: {
                    if isProRequired {
                        onOpenMainWindow()
                    } else {
                        guard let url = selectedFileURL else { return }
                        Task {
                            await processor.processVideo(inputURL: url, mode: splitMode)
                        }
                    }
                }) {
                    Label(
                        processor.isProcessing ? "Slicing..." : (isProRequired ? "Unlock Pro to Slice" : "Losslessly Slice Video"),
                        systemImage: isProRequired ? "crown.fill" : "scissors"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(processor.isProcessing)
            }
            
            if !processor.processedSegments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready (\(processor.processedSegments.count) parts)")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    HStack {
                        Button("Copy All (Cmd+V in WhatsApp)") {
                            let urls = processor.processedSegments.map { $0.url }
                            ShareManager.shared.copyFilesToClipboard(urls: urls)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Open Finder") {
                            ShareManager.shared.revealInFinder(urls: processor.processedSegments.map { $0.url })
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Open Full App") {
                    onOpenMainWindow()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
