import SwiftUI
import AppKit

public struct MainContentView: View {
    @StateObject private var processor = VideoProcessor()
    @ObservedObject private var license = LicenseManager.shared
    @State private var selectedFileURL: URL?
    @State private var videoDuration: Double = 0.0
    @State private var splitMode: SplitMode = .whatsAppStatus30
    @State private var customMB: Double = 95.0
    @State private var customSeconds: Double = 30.0
    @State private var customOutputDir: URL?
    @State private var showLogs: Bool = false
    @State private var allCopied: Bool = false
    @State private var showUpgradeSheet: Bool = false
    
    public init(initialFileURL: URL? = nil) {
        self._selectedFileURL = State(initialValue: initialFileURL)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Free Tier Banner
                    if !license.isLicensed {
                        freeTierBanner
                    }
                    
                    // Drop area
                    FileDropAreaView(
                        selectedFileURL: $selectedFileURL,
                        videoDuration: $videoDuration,
                        onFileSelected: { url in
                            processor.processedSegments.removeAll()
                            processor.statusMessage = "Ready to slice"
                            loadVideoDetails(url: url)
                        }
                    )
                    
                    // Metadata & Calculation Card
                    if let meta = processor.metadata, selectedFileURL != nil {
                        bitrateAnalysisCard(meta: meta)
                    }
                    
                    // Options Card
                    if selectedFileURL != nil {
                        optionsCard
                    }
                    
                    // Processing / Results Section
                    if processor.isProcessing || !processor.processedSegments.isEmpty {
                        resultsSection
                    }
                    
                    if showLogs {
                        logSection
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(minWidth: 680, minHeight: 640)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeToProSheet(isPresented: $showUpgradeSheet)
        }
        .onReceive(NotificationCenter.default.publisher(for: .hdShareOpenFile)) { notification in
            if let url = notification.object as? URL {
                self.selectedFileURL = url
                self.processor.processedSegments.removeAll()
                self.processor.statusMessage = "Ready to slice \(url.lastPathComponent)"
                loadVideoDetails(url: url)
            }
        }
    }
    
    // MARK: - Free Tier Banner
    private var freeTierBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Free Plan: WhatsApp 30s Status Slicing Included")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Unlock WhatsApp 95MB HD Chat, 2GB Telegram, 25MB Discord/Email & Custom limits with Pro.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showUpgradeSheet = true }) {
                Label("Unlock Pro ($4.99)", systemImage: "crown.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "video.badge.waveform")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("HDShare")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Lossless Slicing • Zero Compression • 100% Original HD Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // License Badge
            if license.isLicensed {
                Label("PRO Active", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(6)
            } else {
                Button(action: { showUpgradeSheet = true }) {
                    Label("Upgrade to Pro", systemImage: "crown.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // FFmpeg Status Badge
            if let path = VideoProcessor.findFFmpegPath() {
                let isBundled = path.contains("HDShare.app")
                Label(isBundled ? "FFmpeg (Bundled)" : "FFmpeg (System)", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
            } else {
                Label("FFmpeg Missing", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Bitrate Analysis Card
    private func bitrateAnalysisCard(meta: VideoMetadata) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dynamic Bitrate Analysis", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)
                Spacer()
                Text(splitMode.rawValue)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Bitrate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(meta.bitrateFormatted)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Max Duration / Slice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let maxDur: Double = {
                        switch splitMode {
                        case .whatsAppHD: return meta.maxDurationFor95MB
                        case .whatsAppStatus30: return 30.0
                        case .whatsAppStatus60: return 60.0
                        case .discordEmail: return meta.maxDurationFor25MB
                        case .telegram2GB: return meta.maxDurationFor2GB
                        case .customMB: return meta.maxDuration(forTargetMB: customMB)
                        case .customDuration: return customSeconds
                        }
                    }()
                    Text("\(String(format: "%.1f", maxDur))s per slice")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let maxDur: Double = {
                        switch splitMode {
                        case .whatsAppHD: return meta.maxDurationFor95MB
                        case .whatsAppStatus30: return 30.0
                        case .whatsAppStatus60: return 60.0
                        case .discordEmail: return meta.maxDurationFor25MB
                        case .telegram2GB: return meta.maxDurationFor2GB
                        case .customMB: return meta.maxDuration(forTargetMB: customMB)
                        case .customDuration: return customSeconds
                        }
                    }()
                    let count = max(1, Int(ceil(meta.duration / maxDur)))
                    Text("\(count) \(count == 1 ? "part" : "parts")")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }
            }
            
            Text("Formula: `(Target MB × 8,000,000 bits) / \(meta.bitrateFormatted)` = lossless slice duration with zero compression.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    // MARK: - Options Card
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Target Platform & File Limit")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(SplitMode.allCases) { mode in
                    let isAvailable = license.isFeatureAvailable(mode: mode)
                    HStack(alignment: .top, spacing: 10) {
                        Button(action: {
                            splitMode = mode
                            if !isAvailable {
                                showUpgradeSheet = true
                            }
                        }) {
                            Image(systemName: splitMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(splitMode == mode ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(mode.rawValue)
                                    .font(.body)
                                    .fontWeight(splitMode == mode ? .semibold : .regular)
                                
                                if isAvailable {
                                    if mode == .whatsAppStatus30 && !license.isLicensed {
                                        Text("FREE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.12))
                                            .cornerRadius(4)
                                    }
                                } else {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9))
                                        Text("PRO")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(4)
                                }
                            }
                            
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(splitMode == mode ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        splitMode = mode
                        if !isAvailable {
                            showUpgradeSheet = true
                        }
                    }
                }
            }
            
            if splitMode == .customMB && license.isLicensed {
                HStack {
                    Text("Target Size:")
                    Slider(value: $customMB, in: 5...4000, step: 5) {
                        Text("Target MB")
                    }
                    Text("\(Int(customMB)) MB")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.top, 4)
            }
            
            if splitMode == .customDuration && license.isLicensed {
                HStack {
                    Text("Chunk Duration:")
                    Slider(value: $customSeconds, in: 5...300, step: 5) {
                        Text("Duration")
                    }
                    Text("\(Int(customSeconds)) sec")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            HStack {
                let isProRequired = !license.isFeatureAvailable(mode: splitMode)
                
                Button(action: {
                    if isProRequired {
                        showUpgradeSheet = true
                    } else {
                        startProcessing()
                    }
                }) {
                    Label(
                        processor.isProcessing ? "Slicing..." : (isProRequired ? "Unlock Pro to Slice (\(splitMode.rawValue))" : "Losslessly Slice Video"),
                        systemImage: isProRequired ? "crown.fill" : "scissors"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(processor.isProcessing || selectedFileURL == nil)
                
                if processor.isProcessing {
                    Button("Cancel", role: .cancel) {
                        processor.cancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
                
                if let meta = processor.metadata {
                    let maxDur: Double = {
                        switch splitMode {
                        case .whatsAppHD: return meta.maxDurationFor95MB
                        case .whatsAppStatus30: return 30.0
                        case .whatsAppStatus60: return 60.0
                        case .discordEmail: return meta.maxDurationFor25MB
                        case .telegram2GB: return meta.maxDurationFor2GB
                        case .customMB: return meta.maxDuration(forTargetMB: customMB)
                        case .customDuration: return customSeconds
                        }
                    }()
                    let count = max(1, Int(ceil(meta.duration / maxDur)))
                    Text("Will slice into **\(count) HD \(count == 1 ? "part" : "parts")**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(12)
    }
    
    // MARK: - Results
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Lossless Slices (100% Original Quality)")
                    .font(.headline)
                
                Spacer()
                
                if !processor.processedSegments.isEmpty {
                    Button(action: copyAllFiles) {
                        Label(allCopied ? "All Copied!" : "Copy All", systemImage: allCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        let urls = processor.processedSegments.map { $0.url }
                        ShareManager.shared.revealInFinder(urls: urls)
                    }) {
                        Label("Show in Finder", systemImage: "folder.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        ShareManager.shared.openWhatsApp()
                    }) {
                        Label("Open WhatsApp", systemImage: "arrow.up.forward.app.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if processor.isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: processor.progress)
                    Text(processor.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            ForEach(processor.processedSegments) { seg in
                SegmentRowView(segment: seg, totalCount: processor.processedSegments.count)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(12)
    }
    
    // MARK: - Log
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Console Logs")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(processor.logOutput.isEmpty ? "No logs" : processor.logOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 100)
            .background(Color(nsColor: .black).opacity(0.2))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Button(action: { showLogs.toggle() }) {
                Label(showLogs ? "Hide Logs" : "Show Logs", systemImage: "terminal")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Text("⚡ Instant lossless slicing (-c copy). Zero CPU strain, zero quality loss.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func loadVideoDetails(url: URL) {
        Task {
            let meta = await VideoProcessor.inspectVideo(url: url)
            await MainActor.run {
                self.videoDuration = meta?.duration ?? 0.0
                self.processor.metadata = meta
            }
        }
    }
    
    private func startProcessing() {
        guard let url = selectedFileURL else { return }
        
        // Freemium check: free users can only use WhatsApp Status (30s)
        if !license.isFeatureAvailable(mode: splitMode) {
            showUpgradeSheet = true
            return
        }
        
        Task {
            await processor.processVideo(
                inputURL: url,
                mode: splitMode,
                customTargetMB: customMB,
                customChunkSeconds: customSeconds,
                outputDirectory: customOutputDir
            )
        }
    }
    
    private func copyAllFiles() {
        let urls = processor.processedSegments.map { $0.url }
        ShareManager.shared.copyFilesToClipboard(urls: urls)
        allCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            allCopied = false
        }
    }
}
