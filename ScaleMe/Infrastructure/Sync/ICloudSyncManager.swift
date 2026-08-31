import Foundation

enum ConfigurationSyncStrategy: String, CaseIterable, Identifiable {
    case push
    case pull

    var id: String { rawValue }
    var title: String { self == .push ? "推送" : "拉取" }
    var detail: String {
        switch self {
        case .push: "本地配置变更后自动写入 iCloud"
        case .pull: "以 iCloud 配置为准并替换本地配置"
        }
    }
}

enum CloudSyncState: Equatable {
    case idle
    case syncing
    case success(Date)
    case unavailable(String)
    case failed(String)

    var title: String {
        switch self {
        case .idle: "等待同步"
        case .syncing: "正在后台同步"
        case .success: "同步完成"
        case .unavailable: "iCloud 不可用"
        case .failed: "同步失败"
        }
    }

    var detail: String? {
        switch self {
        case .success(let date):
            date.formatted(date: .abbreviated, time: .shortened)
        case .unavailable(let message), .failed(let message):
            message
        case .idle, .syncing:
            nil
        }
    }
}

@MainActor
final class ICloudSyncManager: ObservableObject {
    @Published var isConfigurationSyncEnabled: Bool {
        didSet {
            defaults.set(isConfigurationSyncEnabled, forKey: Keys.configurationEnabled)
            scheduleSync()
        }
    }
    @Published var isDataSyncEnabled: Bool {
        didSet {
            defaults.set(isDataSyncEnabled, forKey: Keys.dataEnabled)
            scheduleSync()
        }
    }
    @Published var configurationStrategy: ConfigurationSyncStrategy {
        didSet {
            defaults.set(configurationStrategy.rawValue, forKey: Keys.configurationStrategy)
            scheduleSync()
        }
    }
    @Published private(set) var state: CloudSyncState = .idle

    private enum Keys {
        static let configurationEnabled = "icloud.configuration.enabled"
        static let dataEnabled = "icloud.data.enabled"
        static let configurationStrategy = "icloud.configuration.strategy"
    }

    private let defaults: UserDefaults
    private let cloudRepository = ICloudFileRepository()
    private weak var store: MeasurementStore?
    private var scheduledTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isConfigurationSyncEnabled = defaults.bool(forKey: Keys.configurationEnabled)
        isDataSyncEnabled = defaults.bool(forKey: Keys.dataEnabled)
        configurationStrategy = ConfigurationSyncStrategy(
            rawValue: defaults.string(forKey: Keys.configurationStrategy) ?? "push"
        ) ?? .push
    }

    var isEnabled: Bool { isConfigurationSyncEnabled || isDataSyncEnabled }

    func attach(to store: MeasurementStore) {
        self.store = store
        if isEnabled { syncNow() }
    }

    func configurationDidChange() {
        guard isConfigurationSyncEnabled, configurationStrategy == .push else { return }
        scheduleSync()
    }

    func measurementsDidChange() {
        guard isDataSyncEnabled else { return }
        scheduleSync()
    }

    func syncWhenAppBecomesActive() {
        guard isEnabled else { return }
        syncNow()
    }

    func syncNow() {
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            await self?.performSync()
        }
    }

    private func scheduleSync() {
        guard isEnabled else {
            scheduledTask?.cancel()
            state = .idle
            return
        }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.performSync()
        }
    }

    private func performSync() async {
        guard let store else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            state = .unavailable("请先在系统设置中登录 iCloud 并开启 iCloud Drive")
            return
        }

        let request = CloudSyncRequest(
            configurationAction: isConfigurationSyncEnabled ? configurationStrategy : nil,
            configuration: configurationStrategy == .push ? store.configuration : nil,
            shouldSyncData: isDataSyncEnabled,
            archive: isDataSyncEnabled ? store.archive : nil
        )

        state = .syncing
        let result = await cloudRepository.sync(request)
        guard !Task.isCancelled else { return }

        if let configuration = result.configuration {
            store.apply(configuration: configuration)
        }
        if let archive = result.archive {
            store.apply(archive: archive)
        }

        if result.errors.isEmpty {
            state = .success(.now)
        } else if result.didCompleteAnyOperation {
            state = .failed("部分内容未同步：\(result.errors.joined(separator: "；"))")
        } else {
            state = .failed(result.errors.joined(separator: "；"))
        }
    }
}

private struct CloudSyncRequest {
    let configurationAction: ConfigurationSyncStrategy?
    let configuration: AppConfiguration?
    let shouldSyncData: Bool
    let archive: MeasurementArchive?
}

private struct CloudSyncResult {
    var configuration: AppConfiguration?
    var archive: MeasurementArchive?
    var errors: [String] = []
    var didCompleteAnyOperation = false
}

private struct CloudConfigurationDocument: Codable {
    let schemaVersion: Int
    let updatedAt: Date
    let configuration: AppConfiguration
}

private enum ICloudSyncError: LocalizedError {
    case unavailable
    case missingConfiguration
    case missingArchive

    var errorDescription: String? {
        switch self {
        case .unavailable: "无法访问观我的 iCloud 目录"
        case .missingConfiguration: "iCloud 中还没有配置文件"
        case .missingArchive: "没有可同步的数据文件"
        }
    }
}

private actor ICloudFileRepository {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func sync(_ request: CloudSyncRequest) -> CloudSyncResult {
        var result = CloudSyncResult()

        do {
            let directory = try cloudDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            if let action = request.configurationAction {
                do {
                    switch action {
                    case .push:
                        guard let configuration = request.configuration else {
                            throw ICloudSyncError.missingConfiguration
                        }
                        let document = CloudConfigurationDocument(
                            schemaVersion: 1,
                            updatedAt: .now,
                            configuration: configuration
                        )
                        try coordinatedWrite(
                            encoder.encode(document),
                            to: directory.appending(path: AppStorageLayout.configurationFileName)
                        )
                    case .pull:
                        let url = directory.appending(path: AppStorageLayout.configurationFileName)
                        guard fileManager.fileExists(atPath: url.path) else {
                            throw ICloudSyncError.missingConfiguration
                        }
                        let document = try decoder.decode(
                            CloudConfigurationDocument.self,
                            from: coordinatedRead(from: url)
                        )
                        result.configuration = document.configuration
                    }
                    result.didCompleteAnyOperation = true
                } catch {
                    result.errors.append("配置：\(error.localizedDescription)")
                }
            }

            if request.shouldSyncData {
                do {
                    guard let localArchive = request.archive else { throw ICloudSyncError.missingArchive }
                    let url = directory.appending(path: AppStorageLayout.measurementsFileName)
                    let cloudFileExists = fileManager.fileExists(atPath: url.path)
                    let cipher = try MeasurementFileCipher(
                        scope: .cloud,
                        createIfMissing: !cloudFileExists
                    )
                    let mergedArchive: MeasurementArchive

                    if cloudFileExists {
                        let encryptedData = try coordinatedRead(from: url)
                        let cloudArchive = try decoder.decode(
                            MeasurementArchive.self,
                            from: cipher.decrypt(encryptedData)
                        )
                        mergedArchive = localArchive.merging(cloudArchive)
                    } else {
                        mergedArchive = localArchive
                    }

                    let plaintext = try encoder.encode(mergedArchive)
                    try coordinatedWrite(try cipher.encrypt(plaintext), to: url)
                    result.archive = mergedArchive
                    result.didCompleteAnyOperation = true
                } catch {
                    result.errors.append("数据：\(error.localizedDescription)")
                }
            }
        } catch {
            result.errors.append(error.localizedDescription)
        }

        return result
    }

    private func cloudDirectory() throws -> URL {
        guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw ICloudSyncError.unavailable
        }
        return container
            .appending(path: "Documents", directoryHint: .isDirectory)
            .appending(path: AppStorageLayout.directoryName, directoryHint: .isDirectory)
    }

    private func coordinatedRead(from url: URL) throws -> Data {
        try? fileManager.startDownloadingUbiquitousItem(at: url)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            operationResult = Result { try Data(contentsOf: coordinatedURL) }
        }

        if let coordinationError { throw coordinationError }
        guard let operationResult else { throw ICloudSyncError.unavailable }
        return try operationResult.get()
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        let options: NSFileCoordinator.WritingOptions = fileManager.fileExists(atPath: url.path) ? .forReplacing : []

        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch {
                operationError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }
}
