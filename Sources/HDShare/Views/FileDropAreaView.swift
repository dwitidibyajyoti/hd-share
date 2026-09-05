import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

public struct FileDropAreaView: View {
    @Binding public var selectedFileURL: URL?
    @Binding public var videoDuration: Double
    @State private var isTargeted: Bool = false
    @State private var thumbnail: NSImage?
    
    public var onFileSelected: ((URL) -> Void)?
    
    public init(
        selectedFileURL: Binding<URL?>,
        videoDuration: Binding<Double>,
        onFileSelected: ((URL) -> Void)? = nil
    ) {
        self._selectedFileURL = selectedFileURL
        self._videoDuration = videoDuration
        self.onFileSelected = onFileSelected
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 2, dash: selectedFileURL == nil ? [6, 4] : [])
                        )
                )
            
            if let fileURL = selectedFileURL {
                HStack(spacing: 16) {
                    if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 2)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "video.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(fileURL.lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                        
                        HStack(spacing: 12) {
                            Label(formatDuration(videoDuration), systemImage: "clock")
                            if let size = getFileSize(url: fileURL) {
                                Label(size, systemImage: "internaldrive")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Button("Choose Different Video") {
                            pickFile()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        selectedFileURL = nil
                        thumbnail = nil
                        videoDuration = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 38))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)
                    
                    VStack(spacing: 4) {
                        Text("Drag & Drop your large video here")
                            .font(.headline)
                        Text("Supports MP4, MOV, MKV, AVI, etc. for Lossless WhatsApp HD Sharing")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { pickFile() }) {
                        Label("Browse File...", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(24)
            }
        }
        .frame(minHeight: 140)
        .onDrop(of: [.movie, .video, .fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        handleSelectedURL(url)
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        handleSelectedURL(url)
                    }
                }
            }
            return true
        }
        .onChange(of: selectedFileURL) { newURL in
            if let newURL = newURL {
                loadMetadata(url: newURL)
            }
        }
    }
    
    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        
        if panel.runModal() == .OK, let url = panel.url {
            handleSelectedURL(url)
        }
    }
    
    private func handleSelectedURL(_ url: URL) {
        self.selectedFileURL = url
        self.onFileSelected?(url)
        loadMetadata(url: url)
    }
    
    private func loadMetadata(url: URL) {
        Task {
            let dur = await VideoProcessor.getVideoDuration(url: url) ?? 0.0
            let thumb = await generateThumbnail(for: url)
            await MainActor.run {
                self.videoDuration = dur
                self.thumbnail = thumb
            }
        }
    }
    
    private func generateThumbnail(for url: URL) async -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1.0, preferredTimescale: 600), actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: 80, height: 80))
        } catch {
            return nil
        }
    }
    
    private func getFileSize(url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d min %02d sec", mins, secs)
    }
}
