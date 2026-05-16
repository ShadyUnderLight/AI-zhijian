import Foundation
import OSLog
import Security

struct SavedLoginCredentials: Codable, Equatable {
    let username: String
    let password: String
}

enum AppRuntime {
#if DEBUG
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCTestSessionIdentifier"] != nil
    }

    static var shouldSkipLoginForUITests: Bool {
        ProcessInfo.processInfo.environment["UITEST_SKIP_LOGIN"] == "YES"
    }

    static var disablesCredentialStore: Bool {
        ProcessInfo.processInfo.environment["AI_ZHIJIAN_DISABLE_KEYCHAIN"] == "YES" ||
            isRunningTests ||
            shouldSkipLoginForUITests
    }
#else
    static var isRunningTests: Bool { false }
    static var shouldSkipLoginForUITests: Bool { false }
    static var disablesCredentialStore: Bool { false }
#endif
}

enum CredentialStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.yourcompany.aizhijian"
    private static let account = "saved-login"
    private static let logger = Logger(subsystem: service, category: "CredentialStore")

    static func load() -> SavedLoginCredentials? {
        guard !AppRuntime.disablesCredentialStore else { return nil }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status != errSecSuccess && status != errSecItemNotFound {
            logFailure("load saved login credentials", status: status)
        }
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SavedLoginCredentials.self, from: data)
        } catch {
            logger.error("Failed to decode saved login credentials: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    static func save(_ credentials: SavedLoginCredentials) -> Bool {
        guard !AppRuntime.disablesCredentialStore else { return false }

        guard let data = try? JSONEncoder().encode(credentials) else {
            logger.error("Failed to encode saved login credentials")
            return false
        }

        let attributes = itemAttributes(data: data)
        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus != errSecItemNotFound {
            logFailure("update saved login credentials", status: updateStatus)
            return false
        }

        var item = baseQuery()
        item.merge(attributes) { _, newValue in newValue }

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
            if retryStatus == errSecSuccess {
                return true
            }
            logFailure("retry saved login credentials update", status: retryStatus)
            return false
        }

        logFailure("add saved login credentials", status: addStatus)
        return false
    }

    @discardableResult
    static func delete() -> Bool {
        guard !AppRuntime.disablesCredentialStore else { return true }

        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        }

        logFailure("delete saved login credentials", status: status)
        return false
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func itemAttributes(data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    private static func logFailure(_ operation: String, status: OSStatus) {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        logger.error("Failed to \(operation, privacy: .public): \(message, privacy: .public)")
    }
}
