import SwiftUI
import AppKit

public struct UpgradeToProSheet: View {
    @ObservedObject var license = LicenseManager.shared
    @Binding var isPresented: Bool
    @State private var inputKey: String = ""
    @State private var activationSuccess: Bool = false
    
    // Lemon Squeezy checkout link
    public var buyURL: String = "https://dwitiapps.lemonsqueezy.com/checkout/buy/14f97665-6146-4cf5-9952-027b89919c55"

    public init(isPresented: Binding<Bool>, buyURL: String = "https://dwitiapps.lemonsqueezy.com/checkout/buy/14f97665-6146-4cf5-9952-027b89919c55") {
        self._isPresented = isPresented
        self.buyURL = buyURL
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to HDShare Pro")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unlock all platforms & custom file size limits forever")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Comparison / Features List
            VStack(alignment: .leading, spacing: 12) {
                proFeatureRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "Free Tier (Included)",
                    desc: "WhatsApp Status 30-Second & 60-Second Lossless Slicing"
                )
                
                proFeatureRow(
                    icon: "sparkles",
                    color: .yellow,
                    title: "WhatsApp HD Chat (95 MB Slices)",
                    desc: "Send full HD/4K videos under WhatsApp's 100MB HD limit"
                )

                proFeatureRow(
                    icon: "sparkles",
                    color: .yellow,
                    title: "Discord Free & Email Attachments (25 MB)",
                    desc: "Auto-slice videos to fit Gmail, Apple Mail, Outlook & Discord"
                )

                proFeatureRow(
                    icon: "sparkles",
                    color: .yellow,
                    title: "Telegram Large Video (2 GB Slices)",
                    desc: "Split full 4K movies & screen recordings with zero quality loss"
                )

                proFeatureRow(
                    icon: "sparkles",
                    color: .yellow,
                    title: "Custom File Size (MB) & Custom Duration",
                    desc: "Set exact target MB limits or custom chunk intervals"
                )
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .cornerRadius(10)

            // License Activation Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Already have a license key?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("Enter your License Key (e.g. 8A3B2C...)", text: $inputKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(license.isValidating)

                    Button(action: {
                        Task {
                            let success = await license.activateLicense(key: inputKey)
                            if success {
                                activationSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    isPresented = false
                                }
                            }
                        }
                    }) {
                        if license.isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 70)
                        } else {
                            Text(activationSuccess ? "Activated!" : "Activate")
                                .frame(width: 70)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty || license.isValidating)
                }

                if let err = license.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Buy License Button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("One-Time Purchase — Lifetime Access")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("No subscriptions • Free updates forever")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    if let url = URL(string: buyURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Get Pro — $4.99", systemImage: "cart.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    private func proFeatureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
