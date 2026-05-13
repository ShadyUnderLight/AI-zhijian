import Foundation
import Security

struct SavedLoginCredentials: Codable, Equatable {
    let username: String
    let password: String
}

enum CredentialStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.yourcompany.aizhijian"
    private static let account = "saved-login"

    static func load() -> SavedLoginCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(SavedLoginCredentials.self, from: data)
    }

    static func save(_ credentials: SavedLoginCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        delete()

        var item = baseQuery()
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
