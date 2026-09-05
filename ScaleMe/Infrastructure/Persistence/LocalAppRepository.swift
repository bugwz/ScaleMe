import Foundation

enum AppStorageLayout {
    static let directoryName = "ScaleMe"
    static let configurationFileName = "configuration.json"
    static let dataFileName = "data.json"
}

struct LocalAppRepository {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        directoryURL = applicationSupport.appending(path: AppStorageLayout.directoryName, directoryHint: .isDirectory)
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    init(directoryURL: URL, fileManager: FileManager = .default) throws {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadConfiguration() throws -> AppConfiguration? {
        let url = directoryURL.appending(path: AppStorageLayout.configurationFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try ConfigurationFileCodec.decode(Data(contentsOf: url))
    }

    func saveConfiguration(_ configuration: AppConfiguration) throws {
        let data = try ConfigurationFileCodec.encode(configuration, prettyPrinted: false)
        try data.write(
            to: directoryURL.appending(path: AppStorageLayout.configurationFileName),
            options: [.atomic, .completeFileProtection]
        )
    }

    func loadArchive() throws -> MeasurementArchive? {
        let url = directoryURL.appending(path: AppStorageLayout.dataFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try RecordFileCodec.decode(Data(contentsOf: url))
    }

    func saveArchive(_ archive: MeasurementArchive) throws {
        let data = try RecordFileCodec.encode(archive, prettyPrinted: false)
        try data.write(
            to: directoryURL.appending(path: AppStorageLayout.dataFileName),
            options: [.atomic, .completeFileProtection]
        )
    }
}

final class LocalPersistenceWriter {
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
