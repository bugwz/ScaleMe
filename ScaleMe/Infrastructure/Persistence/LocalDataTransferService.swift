import Foundation

enum LocalDataTransferError: LocalizedError {
    case invalidConfiguration
    case invalidMeasurementArchive

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "配置文件格式无效"
        case .invalidMeasurementArchive:
            "测量数据文件格式无效或无法使用本机密钥解密"
        }
    }
}

struct LocalDataTransferService {
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let measurementCipher: MeasurementFileCipher?

    init(measurementCipher: MeasurementFileCipher? = nil) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.measurementCipher = measurementCipher
    }

    func exportConfiguration(_ configuration: AppConfiguration) throws -> Data {
        try encoder.encode(configuration)
    }

    func importConfiguration(from data: Data) throws -> AppConfiguration {
        do {
            let configuration = try decoder.decode(AppConfiguration.self, from: data)
            guard !configuration.profiles.isEmpty else {
                throw LocalDataTransferError.invalidConfiguration
            }
            return configuration
        } catch let error as LocalDataTransferError {
            throw error
        } catch {
            throw LocalDataTransferError.invalidConfiguration
        }
    }

    func exportMeasurements(_ archive: MeasurementArchive) throws -> Data {
        let plaintext = try encoder.encode(archive)
        return try resolvedMeasurementCipher().encrypt(plaintext)
    }

    func importMeasurements(from data: Data) throws -> MeasurementArchive {
        do {
            let plaintext = try resolvedMeasurementCipher().decrypt(data)
            return try decoder.decode(MeasurementArchive.self, from: plaintext)
        } catch {
            throw LocalDataTransferError.invalidMeasurementArchive
        }
    }

    private func resolvedMeasurementCipher() throws -> MeasurementFileCipher {
        if let measurementCipher { return measurementCipher }
        return try MeasurementFileCipher()
    }
}
