import Foundation
import AVFoundation

public enum SplitMode: String, CaseIterable, Identifiable {
    case whatsAppHD = "WhatsApp HD Chat (95 MB Limit)"
    case whatsAppStatus30 = "WhatsApp Status (30s Slices)"
    case whatsAppStatus60 = "WhatsApp Status (60s Slices)"
    case discordEmail = "Discord Free & Email (25 MB Limit)"
    case telegram2GB = "Telegram Large Video (2 GB Limit)"
    case customMB = "Custom Target File Size (MB)"
    case customDuration = "Custom Duration (Seconds)"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .whatsAppHD:
            return "Auto-calculated duration to stay under WhatsApp's 100MB HD limit"
        case .whatsAppStatus30:
            return "Exact 30-second slices for WhatsApp Status/Stories"
        case .whatsAppStatus60:
            return "Exact 60-second slices for WhatsApp Status updates"
        case .discordEmail:
            return "Strict 25MB chunks for Discord Free tier & standard Email attachments (Gmail, Outlook, Apple Mail)"
        case .telegram2GB:
            return "Slices large 4K movies/recordings to stay safely under Telegram's 2GB free document limit"
        case .customMB:
            return "Calculate slice length based on your chosen target MB size"
        case .customDuration:
            return "Slice video into exact custom time intervals"
        }
    }
}

public struct VideoMetadata: Sendable {
    public let duration: Double
    public let fileSizeBytes: Int64
    public let totalBitrateBps: Double
    
    public func maxDuration(forTargetMB targetMB: Double) -> Double {
        guard totalBitrateBps > 0 else { return 30.0 }
        return (targetMB * 8_000_000.0) / totalBitrateBps
    }
    
    public var maxDurationFor95MB: Double {
        maxDuration(forTargetMB: 95.0)
    }
    
    public var maxDurationFor25MB: Double {
        maxDuration(forTargetMB: 25.0)
    }
    
    public var maxDurationFor2GB: Double {
        maxDuration(forTargetMB: 1950.0) // Safe 1.95 GB margin for Telegram
    }
    
    public var bitrateFormatted: String {
        let kbps = totalBitrateBps / 1_000
        if kbps >= 1_000 {
            return String(format: "%.2f Mbps", kbps / 1_000)
        } else {
            return String(format: "%.0f kbps", kbps)
        }
    }
}

public struct ProcessedSegment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let index: Int
    public let url: URL
    public let duration: Double
    public let fileSizeFormatted: String
    public let timeRangeFormatted: String
    
    public init(id: UUID = UUID(), index: Int, url: URL, duration: Double, fileSizeFormatted: String, timeRangeFormatted: String) {
        self.id = id
        self.index = index
        self.url = url
        self.duration = duration
        self.fileSizeFormatted = fileSizeFormatted
        self.timeRangeFormatted = timeRangeFormatted
    }
}

public final class VideoProcessor: ObservableObject {
    @Published public var isProcessing: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var processedSegments: [ProcessedSegment] = []
    @Published public var logOutput: String = ""
    @Published public var metadata: VideoMetadata?
    
    private var currentProcess: Process?
    
    public static func findFFmpegPath() -> String? {
        // 1. Check inside App Bundle Resources first
        if let bundlePath = Bundle.main.path(forResource: "ffmpeg", ofType: nil),
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            return bundlePath
        }
        
        let directBundlePath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/ffmpeg").path
        if FileManager.default.isExecutableFile(atPath: directBundlePath) {
            return directBundlePath
        }
        
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/bin/ffmpeg"
        ]
        
        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try `which ffmpeg`
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) {
                return output
            }
        }
        
        return nil
    }
    
    public static func getVideoDuration(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let durationTime = try? await asset.load(.duration) else { return nil }
        return CMTimeGetSeconds(durationTime)
    }
    
    public static func inspectVideo(url: URL) async -> VideoMetadata? {
        let asset = AVURLAsset(url: url)
        guard let durationTime = try? await asset.load(.duration) else { return nil }
        let duration = CMTimeGetSeconds(durationTime)
        guard duration > 0 else { return nil }
        
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let sizeBytes = (attrs[.size] as? Int64) ?? 0
        guard sizeBytes > 0 else { return nil }
        
        // Total Bitrate (bps) = (Total File Size in Bytes * 8) / Duration in Seconds
        let totalBitrate = (Double(sizeBytes) * 8.0) / duration
        
        return VideoMetadata(
            duration: duration,
            fileSizeBytes: sizeBytes,
            totalBitrateBps: totalBitrate
        )
    }
    
    public func cancel() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
            currentProcess = nil
        }
        DispatchQueue.main.async {
            self.isProcessing = false
            self.statusMessage = "Slicing cancelled."
        }
    }
    
    public func processVideo(
        inputURL: URL,
        mode: SplitMode,
        customTargetMB: Double = 95.0,
        customChunkSeconds: Double = 30.0,
        outputDirectory: URL? = nil
    ) async {
        guard let ffmpegPath = Self.findFFmpegPath() else {
            await updateState(
                isProcessing: false,
                progress: 0,
                message: "FFmpeg not found! Please bundle ffmpeg or install via 'brew install ffmpeg'",
                log: "Error: FFmpeg binary not located in bundle or system paths."
            )
            return
        }
        
        guard let meta = await Self.inspectVideo(url: inputURL) else {
            await updateState(
                isProcessing: false,
                progress: 0,
                message: "Failed to read video bitrate and duration.",
                log: "Error inspecting media asset: \(inputURL.path)\n"
            )
            return
        }
        
        await MainActor.run {
            self.metadata = meta
        }
        
        let targetChunkDuration: Double
        let targetSizeLabel: String
        switch mode {
        case .whatsAppHD:
            targetChunkDuration = min(meta.duration, meta.maxDurationFor95MB)
            targetSizeLabel = "95 MB (WhatsApp HD)"
        case .whatsAppStatus30:
            targetChunkDuration = 30.0
            targetSizeLabel = "30s Status"
        case .whatsAppStatus60:
            targetChunkDuration = 60.0
            targetSizeLabel = "60s Status"
        case .discordEmail:
            targetChunkDuration = min(meta.duration, meta.maxDurationFor25MB)
            targetSizeLabel = "25 MB (Discord / Email)"
        case .telegram2GB:
            targetChunkDuration = min(meta.duration, meta.maxDurationFor2GB)
            targetSizeLabel = "2 GB (Telegram)"
        case .customMB:
            let calculated = meta.maxDuration(forTargetMB: customTargetMB)
            targetChunkDuration = min(meta.duration, calculated)
            targetSizeLabel = "\(Int(customTargetMB)) MB (Custom)"
        case .customDuration:
            targetChunkDuration = customChunkSeconds
            targetSizeLabel = "\(Int(customChunkSeconds))s (Custom Duration)"
        }
        
        let chunkCount = max(1, Int(ceil(meta.duration / targetChunkDuration)))
        
        await updateState(
            isProcessing: true,
            progress: 0.05,
            message: "Slicing losslessly (Total Bitrate: \(meta.bitrateFormatted), Target: \(targetSizeLabel))...",
            log: """
            --- Lossless Video Slicing Task ---
            Input: \(inputURL.lastPathComponent)
            Duration: \(String(format: "%.2f", meta.duration))s
            Total Bitrate: \(meta.bitrateFormatted)
            Target Preset: \(mode.rawValue) (\(targetSizeLabel))
            Calculated Slicing Duration: \(String(format: "%.2f", targetChunkDuration))s (\(chunkCount) parts)
            FFmpeg Path: \(ffmpegPath)
            Mode: Pure Lossless Stream Copy (-c copy) - NO Compression
            
            """
        )
        
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension.isEmpty ? "mp4" : inputURL.pathExtension
        
        let outDir: URL
        if let customDir = outputDirectory {
            outDir = customDir
        } else {
            let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("HDShare_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
            outDir = tempBase
        }
        
        var segments: [ProcessedSegment] = []
        
        for i in 0..<chunkCount {
            let start = Double(i) * targetChunkDuration
            let duration = min(targetChunkDuration, meta.duration - start)
            if duration <= 0.5 && i > 0 { continue } // Skip negligible trailing fragments
            
            let partNumber = String(format: "%02d", i + 1)
            let outFileName = "\(baseName)_Part\(partNumber).\(ext)"
            let outURL = outDir.appendingPathComponent(outFileName)
            
            await updateState(
                isProcessing: true,
                progress: Double(i) / Double(chunkCount),
                message: "Losslessly slicing Part \(i + 1) of \(chunkCount)...",
                log: "Slicing part \(i + 1)/\(chunkCount) (start: \(String(format: "%.1f", start))s, duration: \(String(format: "%.1f", duration))s)\n"
            )
            
            // Pure lossless slicing using stream copy (-c copy) - NO compression or re-encoding
            let args = [
                "-y",
                "-ss", String(format: "%.3f", start),
                "-i", inputURL.path,
                "-t", String(format: "%.3f", duration),
                "-c", "copy",
                "-avoid_negative_ts", "make_zero",
                "-movflags", "+faststart",
                outURL.path
            ]
            
            let success = await runProcess(executable: ffmpegPath, arguments: args)
            if success && FileManager.default.fileExists(atPath: outURL.path) {
                let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int64) ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
                let timeRange = "\(formatTime(start)) - \(formatTime(start + duration))"
                
                let segment = ProcessedSegment(
                    index: i + 1,
                    url: outURL,
                    duration: duration,
                    fileSizeFormatted: sizeStr,
                    timeRangeFormatted: timeRange
                )
                segments.append(segment)
            } else {
                await updateState(
                    isProcessing: false,
                    progress: 0,
                    message: "Failed to slice part \(i + 1)",
                    log: "Error executing FFmpeg stream copy for part \(i + 1)\n"
                )
                return
            }
        }
        
        let finalSegments = segments
        await MainActor.run {
            self.processedSegments = finalSegments
            self.isProcessing = false
            self.progress = 1.0
            self.statusMessage = "Successfully sliced into \(finalSegments.count) lossless HD parts!"
            self.logOutput += "Completed. \(finalSegments.count) parts ready with 100% original quality.\n"
        }
    }
    
    private func runProcess(executable: String, arguments: [String]) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            self.currentProcess = process
            
            process.terminationHandler = { proc in
                let success = proc.terminationStatus == 0
                continuation.resume(returning: success)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func updateState(isProcessing: Bool, progress: Double, message: String, log: String) async {
        await MainActor.run {
            self.isProcessing = isProcessing
            self.progress = progress
            self.statusMessage = message
            self.logOutput += log
        }
    }
}
