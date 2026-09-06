import Foundation
import Security

public final class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()

    // Lemon Squeezy public license activation/validation endpoints
    private let activateURL = "https://api.lemonsqueezy.com/v1/licenses/activate"
    private let validateURL = "https://api.lemonsqueezy.com/v1/licenses/validate"
    private let deactivateURL = "https://api.lemonsqueezy.com/v1/licenses/deactivate"

    // Keychain keys
    private let keychainService = "com.hdshare.license"
    private let keychainKeyAccount = "license_key"
    private let keychainInstanceAccount = "instance_id"

    @Published public var isLicensed: Bool = false
    @Published public var licenseKey: String = ""
    @Published public var isValidating: Bool = false
    @Published public var errorMessage: String?

    private init() {
        loadState()
    }

    private func loadState() {
        if let storedKey = readKeychain(account: keychainKeyAccount), !storedKey.isEmpty {
            self.licenseKey = storedKey
            self.isLicensed = true
        } else {
            self.isLicensed = false
        }
    }

    // Free users can use WhatsApp Status (30s & 60s). All other presets require Pro license.
    public func isFeatureAvailable(mode: SplitMode) -> Bool {
        if isLicensed { return true }
        return mode == .whatsAppStatus30 || mode == .whatsAppStatus60
    }

    // MARK: - Machine ID

    private func getMachineID() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-d2", "-c", "IOPlatformExpertDevice"]
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    if line.contains("IOPlatformUUID") {
                        let parts = line.components(separatedBy: "\"")
                        if parts.count >= 4 { return parts[3] }
                    }
                }
            }
        } catch {}
        let fallbackKey = "hdshare_machine_uuid"
        if let existing = UserDefaults.standard.string(forKey: fallbackKey) { return existing }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: fallbackKey)
        return newUUID
    }

    // MARK: - Activate License

    public func activateLicense(key: String) async -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            await MainActor.run { self.errorMessage = "Please enter a license key." }
            return false
        }
        await MainActor.run { self.isValidating = true; self.errorMessage = nil }

        let machineID = getMachineID()
        let machineName = Host.current().localizedName ?? "Mac"
        let body: [String: Any] = [
            "license_key": trimmedKey,
            "instance_name": "\(machineName) (\(machineID))"
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            await MainActor.run { self.isValidating = false; self.errorMessage = "Internal request error." }
            return false
        }

        var request = URLRequest(url: URL(string: activateURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await MainActor.run { self.isValidating = false; self.errorMessage = "Invalid server response." }
                return false
            }
            let activated = json["activated"] as? Bool ?? false
            if activated {
                if let meta = json["meta"] as? [String: Any],
                   let instanceID = meta["instance_id"] as? String {
                    saveKeychain(value: instanceID, account: keychainInstanceAccount)
                }
                saveKeychain(value: trimmedKey, account: keychainKeyAccount)
                await MainActor.run {
                    self.licenseKey = trimmedKey
                    self.isLicensed = true
                    self.isValidating = false
                    self.errorMessage = nil
                }
                return true
            } else {
                let code = httpResponse?.statusCode ?? 0
                let msg = (json["error"] as? String)
                    ?? (code == 422 ? "Activation limit reached. Please deactivate another Mac first." : "Invalid license key (HTTP \(code)).")
                await MainActor.run { self.isValidating = false; self.errorMessage = msg }
                return false
            }
        } catch {
            await MainActor.run {
                self.isValidating = false
                self.errorMessage = "Network error. Please check your internet connection."
            }
            return false
        }
    }

    // MARK: - Deactivate

    public func deactivateLicense() async {
        guard let storedKey = readKeychain(account: keychainKeyAccount),
              let instanceID = readKeychain(account: keychainInstanceAccount) else {
            await MainActor.run { self.isLicensed = false; self.licenseKey = "" }
            deleteKeychain(account: keychainKeyAccount)
            deleteKeychain(account: keychainInstanceAccount)
            return
        }
        let body: [String: Any] = ["license_key": storedKey, "instance_id": instanceID]
        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            var request = URLRequest(url: URL(string: deactivateURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = jsonData
            _ = try? await URLSession.shared.data(for: request)
        }
        deleteKeychain(account: keychainKeyAccount)
        deleteKeychain(account: keychainInstanceAccount)
        await MainActor.run { self.isLicensed = false; self.licenseKey = "" }
    }

    // MARK: - Keychain Helpers

    private func saveKeychain(value: String, account: String) {
        let data = value.data(using: .utf8)!
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
