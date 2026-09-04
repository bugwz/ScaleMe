import CryptoKit
import Foundation
import Security

enum AppStorageLayout {
    static let directoryName = "ScaleMe"
    static let configurationFileName = "configuration-v5.json"
    static let measurementsFileName = "measurements-v2.enc"
}

enum SecureStorageError: LocalizedError {
    case keychain(OSStatus)
    case invalidEncryptedData

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            "无法访问数据加密密钥（\(status)）"
        case .invalidEncryptedData:
            "加密数据文件格式无效"
        }
    }
}

struct MeasurementFileCipher: Sendable {
    private static let authenticatedContext = Data("ScaleMe.measurements.v2".utf8)
    private let keyData: Data

    init() throws {
        keyData = try EncryptionKeyStore().loadOrCreateKey()
    }

    init(keyData: Data) {
        self.keyData = keyData
    }

    func encrypt(_ plaintext: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: Self.authenticatedContext)
        guard let combined = box.combined else { throw SecureStorageError.invalidEncryptedData }
        return combined
    }

    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let box = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(box, using: key, authenticating: Self.authenticatedContext)
    }
}

private struct EncryptionKeyStore {
    private let service = "com.bugwz.scaleme.data-encryption"
    private let account = "local-measurement-file-key"

    func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() { return existing }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ] as CFDictionary, nil)

        if status == errSecDuplicateItem, let existing = try loadKey() { return existing }
        guard status == errSecSuccess else { throw SecureStorageError.keychain(status) }
        return data
    }

    func loadKey() throws -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecureStorageError.keychain(status) }
        return result as? Data
    }
}

struct LocalAppRepository {
    private let directoryURL: URL
    private let cipher: MeasurementFileCipher
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) throws {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        directoryURL = applicationSupport.appending(path: AppStorageLayout.directoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        cipher = try MeasurementFileCipher()
    }

    func loadConfiguration() throws -> AppConfiguration? {
        let url = directoryURL.appending(path: AppStorageLayout.configurationFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try ConfigurationFileCodec.decode(Data(contentsOf: url))
    }

    func saveConfiguration(_ configuration: AppConfiguration) throws {
        let data = try ConfigurationFileCodec.encode(configuration, prettyPrinted: false)
        try data.write(
            to: directoryURL.appending(path: AppStorageLayout.configurationFileName),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func loadArchive() throws -> MeasurementArchive? {
        let url = directoryURL.appending(path: AppStorageLayout.measurementsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let encryptedData = try Data(contentsOf: url)
        return try decoder.decode(MeasurementArchive.self, from: cipher.decrypt(encryptedData))
    }

    func saveArchive(_ archive: MeasurementArchive) throws {
        let plaintext = try encoder.encode(archive)
        let encryptedData = try cipher.encrypt(plaintext)
        try encryptedData.write(
            to: directoryURL.appending(path: AppStorageLayout.measurementsFileName),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

}

actor LocalPersistenceWriter {
    private let repository: LocalAppRepository
    private var latestConfigurationRevision = 0
    private var latestArchiveRevision = 0

    init(repository: LocalAppRepository) {
        self.repository = repository
    }

    func saveConfiguration(_ configuration: AppConfiguration, revision: Int) throws {
        guard revision > latestConfigurationRevision else { return }
        latestConfigurationRevision = revision
        try repository.saveConfiguration(configuration)
    }

    func saveArchive(_ archive: MeasurementArchive, revision: Int) throws {
        guard revision > latestArchiveRevision else { return }
        latestArchiveRevision = revision
        try repository.saveArchive(archive)
    }

}
