import Foundation

enum LocalDataTransferError: LocalizedError {
    case invalidConfiguration
    case invalidRecordFile
    case invalidCombinedFile

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "配置文件格式无效"
        case .invalidRecordFile:
            "数据文件格式无效"
        case .invalidCombinedFile:
            "配置和数据文件格式无效"
        }
    }
}

struct LocalDataTransferBundle {
    let configuration: AppConfiguration
    let archive: MeasurementArchive
}

struct LocalDataTransferService {
    func exportConfiguration(_ configuration: AppConfiguration) throws -> Data {
        try ConfigurationFileCodec.encode(configuration, prettyPrinted: true)
    }

    func importConfiguration(from data: Data) throws -> AppConfiguration {
        do {
            return try ConfigurationFileCodec.decode(data)
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

    func exportCombined(
        configuration: AppConfiguration,
        archive: MeasurementArchive
    ) throws -> Data {
        let configurationJSON = String(
            decoding: try exportConfiguration(configuration),
            as: UTF8.self
        )
        let recordJSON = String(
            decoding: try exportRecords(archive),
            as: UTF8.self
        )
        let document = """
        {
          "config": \(indented(configurationJSON)),
          "data": \(indented(recordJSON))
        }
        """
        return Data(document.utf8)
    }

    func importCombined(from data: Data) throws -> LocalDataTransferBundle {
        do {
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                Set(root.keys) == ["config", "data"],
                let configurationObject = root["config"] as? [String: Any],
                let recordObject = root["data"] as? [String: Any]
            else {
                throw LocalDataTransferError.invalidCombinedFile
            }
            let configurationData = try JSONSerialization.data(withJSONObject: configurationObject)
            let recordData = try JSONSerialization.data(withJSONObject: recordObject)
            return LocalDataTransferBundle(
                configuration: try ConfigurationFileCodec.decode(configurationData),
                archive: try RecordFileCodec.decode(recordData)
            )
        } catch {
            throw LocalDataTransferError.invalidCombinedFile
        }
    }

    private func indented(_ json: String) -> String {
        json.split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: "\n  ")
    }
}
