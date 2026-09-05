import Foundation
import Security

enum HuaweiHagridCredentialStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            "无法访问设备认证材料（\(status)）"
        }
    }
}

struct HuaweiHagridCredentialStore {
    private let service = "com.bugwz.scaleme.bluetooth.huawei-hagrid"

    func load(for scaleID: UUID) throws -> HuaweiHagridProtocol.Credentials? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(for: scaleID).merging([
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new } as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw HuaweiHagridCredentialStoreError.keychain(status)
        }
        do {
            return try HuaweiHagridProtocol.Credentials(encoded: data)
        } catch ScalePayloadError.unsupported {
            // Development builds previously stored CAK/C1/C2 without the address
            // needed for C3. Discard that incomplete record instead of blocking a
            // replacement with the current credential shape.
            try delete(for: scaleID)
            return nil
        }
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
        guard status == errSecSuccess else { throw HuaweiHagridCredentialStoreError.keychain(status) }
    }

    func delete(for scaleID: UUID) throws {
        let status = SecItemDelete(query(for: scaleID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HuaweiHagridCredentialStoreError.keychain(status)
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
