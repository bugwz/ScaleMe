import Foundation
import Security

struct HuaweiHagridCredentialStore {
    private let service = "com.scaleme.app.bluetooth.huawei-hagrid"

    func load(for scaleID: UUID) throws -> HuaweiHagridProtocol.Credentials? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(for: scaleID).merging([
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new } as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw SecureStorageError.keychain(status)
        }
        return try HuaweiHagridProtocol.Credentials(encoded: data)
    }

    func save(_ credentials: HuaweiHagridProtocol.Credentials, for scaleID: UUID) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: credentials.encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status: OSStatus
        if try load(for: scaleID) == nil {
            status = SecItemAdd(
                query(for: scaleID).merging(attributes) { _, new in new } as CFDictionary,
                nil
            )
        } else {
            status = SecItemUpdate(query(for: scaleID) as CFDictionary, attributes as CFDictionary)
        }
        guard status == errSecSuccess else { throw SecureStorageError.keychain(status) }
    }

    func delete(for scaleID: UUID) throws {
        let status = SecItemDelete(query(for: scaleID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychain(status)
        }
    }

    private func query(for scaleID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: scaleID.uuidString.lowercased()
        ]
    }
}
