import SwiftUI
import AppKit

public struct SegmentRowView: View {
    public let segment: ProcessedSegment
    public let totalCount: Int
    @State private var copied: Bool = false
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(segment.index)")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 10) {
                    Text("⏱ \(segment.timeRangeFormatted)")
                    Text("📦 \(segment.fileSizeFormatted)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Copy File to Clipboard button (for direct pasting into WhatsApp)
            Button(action: {
                ShareManager.shared.copyFilesToClipboard(urls: [segment.url])
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }) {
                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy video to clipboard — paste directly (Cmd+V) into WhatsApp")
            
            // Reveal in Finder
            Button(action: {
                ShareManager.shared.revealInFinder(urls: [segment.url])
            }) {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reveal in Finder")
            
            // Share Sheet
            ShareLink(item: segment.url) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Share via macOS Share Sheet")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }
}
