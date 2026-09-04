import Foundation

enum LocalDataTransferError: LocalizedError {
    case invalidConfiguration
    case invalidRecordFile

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "配置文件格式无效"
        case .invalidRecordFile:
            "记录文件格式无效"
        }
    }
}

struct LocalDataTransferService {
    func exportConfiguration(_ configuration: AppConfiguration) throws -> Data {
        try ConfigurationFileCodec.encode(configuration, prettyPrinted: true)
    }

    func importConfiguration(from data: Data) throws -> AppConfiguration {
        do {
            let configuration = try ConfigurationFileCodec.decode(data)
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

    func exportRecords(_ archive: MeasurementArchive) throws -> Data {
        try RecordFileCodec.encode(archive, prettyPrinted: true)
    }

    func importRecords(from data: Data) throws -> MeasurementArchive {
        do {
            return try RecordFileCodec.decode(data)
        } catch {
            throw LocalDataTransferError.invalidRecordFile
        }
    }
}
