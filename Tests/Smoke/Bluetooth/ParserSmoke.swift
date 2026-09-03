import Foundation

// All device samples below use synthetic credentials, addresses, measurements and dates.
// Packet layouts reproduce protocol behavior; these bytes are not raw personal captures.

@main
enum ParserSmoke {
    static func main() throws {
        let huaweiProbe = HuaweiHagridProtocol.makeAuthenticationProbe()
        precondition(huaweiProbe == hexData("DB0300C140"))
        let huaweiChallenge = hexData("BD1300000102030405060708090A0B0C0D0E0F92C5")
        let huaweiFrame = try HuaweiHagridProtocol.parseNotificationFrame(huaweiChallenge)
        precondition(!huaweiFrame.isEncrypted)
        precondition(huaweiFrame.totalFrames == 1 && huaweiFrame.frameIndex == 0)
        precondition(huaweiFrame.payload == Data((0...15).map(UInt8.init)))
        let huaweiMeasuring = try HuaweiHagridProtocol.parseNotificationFrame(hexData("BD040001A449"))
        let huaweiMeasuringStatus = try HuaweiHagridProtocol.parseMeasurementStatus(huaweiMeasuring)
        precondition(huaweiMeasuringStatus == .measuring)
        let huaweiReady = try HuaweiHagridProtocol.parseNotificationFrame(hexData("BD0400006589"))
        let huaweiReadyStatus = try HuaweiHagridProtocol.parseMeasurementStatus(huaweiReady)
        precondition(huaweiReadyStatus == .ready)
        let huaweiChallengePart1 = try HuaweiHagridProtocol.parseNotificationFrame(
            hexData("BD1210A0A1A2A3A4A5A6A7A8A9AAABACADAEC9A1")
        )
        let huaweiChallengePart2 = try HuaweiHagridProtocol.parseNotificationFrame(
            hexData("BD0511AF006522")
        )
        var huaweiAccumulator = HuaweiHagridProtocol.NotificationAccumulator()
        precondition(huaweiAccumulator.ingest(huaweiChallengePart1) == nil)
        let completedHuaweiChallenge = huaweiAccumulator.ingest(huaweiChallengePart2)
        precondition(completedHuaweiChallenge?.payload.count == 17)
        let huaweiRandom = try HuaweiHagridProtocol.parseAuthenticationChallenge(
            completedHuaweiChallenge?.payload ?? Data()
        )
        precondition(huaweiRandom == hexData("A0A1A2A3A4A5A6A7A8A9AAABACADAEAF"))
        let huaweiCredentials = try HuaweiHagridProtocol.Credentials(
            bluetoothAddress: "02:00:00:00:00:01",
            cakHex: "00112233445566778899AABBCCDDEEFF",
            c1Hex: "FFEEDDCCBBAA99887766554433221100",
            c2Hex: "0123456789ABCDEFFEDCBA9876543210"
        )
        precondition(huaweiCredentials.encoded.count == 55)
        precondition(huaweiCredentials.bluetoothAddressText == "02:00:00:00:00:01")
        let decodedHuaweiCredentials = try HuaweiHagridProtocol.Credentials(encoded: huaweiCredentials.encoded)
        precondition(decodedHuaweiCredentials == huaweiCredentials)
        do {
            _ = try HuaweiHagridProtocol.Credentials(
                bluetoothAddress: "02:00:00:00:00:01",
                cakHex: "GG112233445566778899AABBCCDDEEFF",
                c1Hex: "FFEEDDCCBBAA99887766554433221100",
                c2Hex: "0123456789ABCDEFFEDCBA9876543210"
            )
            preconditionFailure("Huawei WSP 认证材料必须拒绝非十六进制字符")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        // Synthetic Huawei known-answer vectors; no captured device credentials.
        // C1=10...1F, C2=20...2F, work key=30...3F, IVs=40...4F / 50...5F.
        // AES-CTR expected ciphertext was generated independently with OpenSSL.
        let huaweiCryptoCredentials = try HuaweiHagridProtocol.Credentials(
            bluetoothAddress: "02:00:00:00:00:02",
            cakHex: "00000000000000000000000000000000",
            c1Hex: "101112131415161718191A1B1C1D1E1F",
            c2Hex: "202122232425262728292A2B2C2D2E2F"
        )
        let huaweiRootKey = HuaweiHagridProtocol.deriveRootKey(credentials: huaweiCryptoCredentials)
        precondition(huaweiRootKey == hexData("92F26455D32B0FB1EC56C7BB47878974"))
        let huaweiEncryptedWorkKey = hexData(
            "404142434445464748494A4B4C4D4E4F47E6319BDECD7508420B0DFD2F9AE88E"
        )
        let huaweiWorkKey = try HuaweiHagridProtocol.decryptPayloadWithIV(
            huaweiEncryptedWorkKey,
            key: huaweiRootKey
        )
        precondition(huaweiWorkKey == hexData("303132333435363738393A3B3C3D3E3F"))
        let huaweiEncryptedMeasurement = hexData(
            "505152535455565758595A5B5C5D5E5F8A5110208D5F2422A8AA93EEBB8165F327ABE7063BEB41ADD3EA"
        )
        let huaweiMeasurementPayload = try HuaweiHagridProtocol.decryptPayloadWithIV(
            huaweiEncryptedMeasurement,
            key: huaweiWorkKey
        )
        let huaweiMeasurement = try HuaweiHagridProtocol.parseRealtimeMeasurement(huaweiMeasurementPayload)
        precondition(abs(huaweiMeasurement.weightKG - 60.0) < 0.001)
        precondition(abs(huaweiMeasurement.deviceFatPercent - 20.0) < 0.001)
        precondition(huaweiMeasurement.heartRateBPM == 60)
        precondition(abs((huaweiMeasurement.representativeLowImpedanceOhm ?? 0) - 500.0) < 0.001)
        do {
            var invalidHuaweiChallenge = huaweiChallenge
            invalidHuaweiChallenge[invalidHuaweiChallenge.index(before: invalidHuaweiChallenge.endIndex)] ^= 0x01
            _ = try HuaweiHagridProtocol.parseNotificationFrame(invalidHuaweiChallenge)
            preconditionFailure("Huawei WSP 校验错误必须被拒绝")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        let xiaomi = Data([
            0x00, 0x22,             // kg, stabilized, impedance stabilized
            0xE4, 0x07, 1, 2, 3, 4, 5,
            0xF4, 0x01,             // 500 ohm
            0xE0, 0x2E              // 12000 / 200 = 60 kg
        ])
        let xiaomiValue = try XiaomiScaleParser.parse(xiaomi)
        precondition(abs(xiaomiValue.weightKG - 60) < 0.001)
        precondition(xiaomiValue.impedanceOhm == 500)
        precondition(xiaomiValue.isStable)

        let removed = Data([
            0x00, 0x80,
            0xE4, 0x07, 1, 2, 3, 4, 6,
            0x00, 0x00,
            0x00, 0x00
        ])
        if case .measurement = try XiaomiScaleParser.parsePacket(removed) {
            preconditionFailure("离秤包不得解析为测量值")
        }

        let standardWeight = Data([0x00, 0xE0, 0x2E]) // 12000 * 0.005 kg
        let weightValue = try StandardWeightScaleParser.parse(standardWeight)
        precondition(abs(weightValue.weightKG - 60) < 0.001)
        precondition(!weightValue.isStable)

        let xiaomiGATTLive = Data([0x12, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        let xiaomiGATTStable = Data([0x32, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        let xiaomiGATTRemoved = Data([0xB2, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        guard case .measurement(let liveValue) = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTLive),
              case .measurement(let stableValue) = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTStable),
              case .weightRemoved = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTRemoved) else {
            preconditionFailure("小米 GATT 状态包解析失败")
        }
        precondition(abs(liveValue.weightKG - 60.0) < 0.001)
        precondition(!liveValue.isStable)
        precondition(abs(stableValue.weightKG - 60.0) < 0.001)
        precondition(stableValue.isStable)

        let historyRecord = Data([0x20, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        let historyValue = try XiaomiScaleHistoryProtocol.parseRecord(historyRecord)
        precondition(abs(historyValue.weightKG - 60) < 0.001)
        var historySession = XiaomiScaleHistorySession()
        guard case .progress(received: 0, announced: 1) = try historySession.consume(
            Data([0x01, 0x01, 0xFF, 0xFF, 0xFF, 0xFF])
        ) else {
            preconditionFailure("小米历史计数响应解析失败")
        }
        _ = try historySession.consume(historyRecord.prefix(4))
        guard case .progress(received: 1, announced: 1) = try historySession.consume(historyRecord.dropFirst(4)),
              case .completed(let importedHistory) = try historySession.consume(Data([0x03])) else {
            preconditionFailure("小米历史分片重组失败")
        }
        precondition(importedHistory.count == 1)

        let bodyHistoryRecord = Data([
            0x00, 0x22, 0xEA, 0x07, 8, 29, 10, 13, 0,
            0xF4, 0x01, 0xE0, 0x2E
        ])
        let bodyHistoryValue = try XiaomiScaleHistoryProtocol.parseBodyCompositionRecord(bodyHistoryRecord)
        precondition(abs(bodyHistoryValue.weightKG - 60) < 0.001)
        precondition(bodyHistoryValue.impedanceOhm == 500)
        do {
            var incompleteHistory = XiaomiScaleHistorySession()
            _ = try incompleteHistory.consume(historyRecord.prefix(4))
            _ = try incompleteHistory.consume(Data([0x03]))
            preconditionFailure("不完整的小米历史记录不得被静默丢弃")
        } catch ScalePayloadError.tooShort {
            // Expected.
        }

        let standardBody = Data([
            0x00, 0x04,             // weight present
            0xFA, 0x00,             // 25.0% body fat
            0xE0, 0x2E              // 60 kg
        ])
        let bodyValue = try StandardBodyCompositionParser.parse(standardBody)
        precondition(abs(bodyValue.weightKG - 60) < 0.001)
        precondition(abs((bodyValue.bodyFatPercent ?? 0) - 25) < 0.001)

        do {
            _ = try StandardBodyCompositionParser.parse(Data([0x08, 0x00, 0xFA, 0x00, 0x01]))
            preconditionFailure("截断的可选字段必须被拒绝")
        } catch ScalePayloadError.tooShort {
            // Expected.
        }

        let wolaiLive = try WolaiAFUScaleParser.parse(hexData(
            "AC2900684E20020005400064000000000029D51F"
        ))
        precondition(wolaiLive.phase == .live)
        precondition(abs(wolaiLive.measurement.weightKG - 20.0) < 0.000_01)
        precondition(!wolaiLive.measurement.isStable)

        let wolaiStable = try WolaiAFUScaleParser.parse(hexData(
            "AC298068EA60020005400064000000000029D51B"
        ))
        precondition(wolaiStable.phase == .stable)
        precondition(abs(wolaiStable.measurement.weightKG - 60.0) < 0.000_01)
        precondition(wolaiStable.measurement.isStable)

        let finalFixtures = [
            ("AC29020001F40258018068EA600000000029D603", 500.0, 600.0),
            ("AC29020001FE0262018068EA600000000029D617", 510.0, 610.0),
            ("AC2902000208026C018068EA600000000029D60C", 520.0, 620.0)
        ]
        for (fixture, primaryImpedance, secondaryImpedance) in finalFixtures {
            let packet = try WolaiAFUScaleParser.parse(hexData(fixture))
            precondition(packet.phase == .final)
            precondition(abs(packet.measurement.weightKG - 60.0) < 0.000_01)
            precondition(packet.measurement.impedanceOhm == primaryImpedance)
            precondition(packet.measurement.secondaryImpedanceOhm == secondaryImpedance)
            precondition(packet.measurement.source == .wolaiAFU)
            precondition(packet.measurement.isStable)
        }

        let latestCapture = try WolaiAFUScaleParser.parse(hexData(
            "AC2902000226028A018068FDE80000000029D603"
        ))
        precondition(abs(latestCapture.measurement.weightKG - 65.0) < 0.000_01)
        precondition(latestCapture.measurement.impedanceOhm == 550)
        precondition(latestCapture.measurement.secondaryImpedanceOhm == 650)

        let enriched = BodyCompositionEstimator.enriching(
            latestCapture.measurement,
            profile: UserProfile(
                heightCM: 174,
                birthDate: Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
                biologicalSex: .male
            )
        )
        guard let bodyFatPercent = enriched.bodyFatPercent,
              let waterPercent = enriched.waterPercent,
              let proteinMassKG = enriched.proteinMassKG else {
            preconditionFailure("阻抗测量应生成完整的派生体成分")
        }
        precondition(abs(waterPercent - (100 - bodyFatPercent) * 0.732) < 0.000_01)
        precondition(proteinMassKG > 0)

        do {
            var invalidChecksum = hexData(finalFixtures[0].0)
            invalidChecksum[invalidChecksum.index(before: invalidChecksum.endIndex)] ^= 0x01
            _ = try WolaiAFUScaleParser.parse(invalidChecksum)
            preconditionFailure("Wolai 校验错误必须被拒绝")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        do {
            _ = try WolaiAFUScaleParser.parse(hexData("AC29020001F40258018068EA600000000029D6"))
            preconditionFailure("截断的 Wolai 帧必须被拒绝")
        } catch ScalePayloadError.tooShort {
            // Expected.
        }

        let qnPayload = Data([
            0xAA, 0xBB, 1, 2, 3, 4, 5, 6,
            0, 0, 0, 0, 0, 0, 0, 0x20, 0,
            0x43, 0x1C // 7235 / 100 = 72.35 kg
        ])
        let qn = try QNAABBScaleParser.parse(.init(companyID: 0xFFFF, payload: qnPayload))
        precondition(abs(qn.weightKG - 72.35) < 0.001)
        precondition(qn.isStable)
        precondition(qn.source == .communityProtocol)

        let aaaPayload = Data([
            1, 2, 3, 4, 5, 6,
            0x92, 0x13, 0x18, 0x88, 0xBF, 0x00
        ])
        let aaa = try AAASeriesScaleParser.parse(
            .init(companyID: 0x1234, payload: aaaPayload),
            advertisedName: "AAA007"
        )
        precondition(abs(aaa.weightKG - 68.25) < 0.001)
        precondition(aaa.isStable)

        let sinocare = try SinocareScaleParser.parse(.init(
            companyID: 0xFF64,
            payload: Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0x43, 0x1C, 0, 0, 0, 0, 0, 0x5F])
        ))
        precondition(abs(sinocare.weightKG - 72.35) < 0.001)
        precondition(!sinocare.isStable)

        let scaleup = try ScaleupScaleParser.parse(.init(
            companyID: 0x1CE0,
            payload: Data([0x43, 0x01, 0xF4, 0, 0, 0, 0, 0, 0])
        ))
        precondition(abs(scaleup.weightKG - 72.35) < 0.001)
        precondition(scaleup.isStable)

        let okokV20 = try OKOKScaleParser.parse(
            .init(
                companyID: 0x20CA,
                payload: Data([0, 0, 0, 0, 0, 0, 0x05, 0, 0x1C, 0x43, 0x13, 0x88, 0xE1, 0, 0, 0, 0, 0, 0])
            ),
            advertisedName: "Chipsea-BLE"
        )
        precondition(abs(okokV20.weightKG - 72.35) < 0.001)
        precondition(okokV20.impedanceOhm == 500)
        precondition(okokV20.isStable)

        do {
            _ = try OKOKScaleParser.parse(
                .init(
                    companyID: 0x20CA,
                    payload: Data([0, 0, 0, 0, 0, 0, 0x05, 0, 0x1C, 0x43, 0x13, 0x88, 0xE1, 0, 0, 0, 0, 0, 0])
                ),
                advertisedName: "unrelated-device"
            )
            preconditionFailure("OKOK 特定 Company ID 仍必须结合已知设备名")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        let etekcityPayload = Data([
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0x9E, 0x1A, 0x01, 0xF4, 0x01, 1, 0, 0, 0, 0
        ])
        let etekcity = try EtekcityFit8SScaleParser.parse(
            .init(companyID: 0x06D0, payload: etekcityPayload),
            advertisedServiceUUIDs: ["FFD0"]
        )
        precondition(abs(etekcity.weightKG - 72.35) < 0.001)
        precondition(etekcity.impedanceOhm == 500)
        precondition(etekcity.isStable)

        let etekcityCatalogMatch = ScaleBroadcastProtocolCatalog.parse(
            name: "Etekcity Fit 8S",
            manufacturerData: Data([0xD0, 0x06]) + etekcityPayload,
            advertisedServiceUUIDs: ["FFD0"]
        )
        precondition(etekcityCatalogMatch?.family == .etekcityFit8S)

        let eufyPayload = Data([
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0x41, 0, 0x43, 0x1C, 0, 0, 0, 0x88, 0x13
        ])
        let eufy = try EufyC20ScaleParser.parse(.init(companyID: 48_228, payload: eufyPayload))
        precondition(abs(eufy.weightKG - 72.35) < 0.001)
        precondition(eufy.impedanceOhm == 500)
        precondition(eufy.isStable)

        let yunmaiXPayload = Data([
            0, 0, 0, 0, 0x0B, 0x74, 0x17,
            0x04, 0x03, 0x1C, 0x43, 0x01, 0xF4, 0xAD
        ])
        let yunmaiX = try YunmaiXScaleParser.parse(
            .init(companyID: 0x1234, payload: yunmaiXPayload),
            advertisedServiceUUIDs: ["00001320-0000-1000-8000-00805F9B34FB"]
        )
        precondition(abs(yunmaiX.weightKG - 72.35) < 0.001)
        precondition(yunmaiX.impedanceOhm == 500)
        precondition(yunmaiX.isStable)

        let xiaomiMiScale2Payload = hexData("23B036E4070102030405")
        guard case .measurement(let xiaomiMiScale2) = try XiaomiMiScale2BroadcastParser.parsePacket(
            xiaomiMiScale2Payload
        ) else {
            preconditionFailure("小米 XMTZC04HM 广播解析失败")
        }
        precondition(abs(xiaomiMiScale2.weightKG - 63.502_931_8) < 0.000_001)
        precondition(xiaomiMiScale2.isStable)
        guard case .measurement(let xiaomiMiScale2KG) = try XiaomiMiScale2BroadcastParser.parsePacket(
            hexData("22E02EE4070102030405")
        ),
        case .measurement(let xiaomiMiScale2Jin) = try XiaomiMiScale2BroadcastParser.parsePacket(
            hexData("32B036E4070102030405")
        ),
        case .weightRemoved = try XiaomiMiScale2BroadcastParser.parsePacket(
            hexData("A3B036E4070102030405")
        ) else {
            preconditionFailure("小米 XMTZC04HM 单位或离秤状态解析失败")
        }
        precondition(abs(xiaomiMiScale2KG.weightKG - 60.0) < 0.001)
        precondition(abs(xiaomiMiScale2Jin.weightKG - 70.0) < 0.001)
        let xiaomiMiScale2Match = ScaleServiceDataProtocolCatalog.parse(
            name: "MI SCALE2",
            serviceUUID: "181D",
            payload: xiaomiMiScale2Payload,
            manufacturerData: nil
        )
        precondition(xiaomiMiScale2Match?.family == .xiaomiMiScale2)
        precondition(ScaleServiceDataProtocolCatalog.parse(
            name: "Generic Scale",
            serviceUUID: "181D",
            payload: xiaomiMiScale2Payload,
            manufacturerData: Data([0x34, 0x12])
        ) == nil)

        let silvergearPayload = hexData("030000000002202C4AC00DA3")
        let silvergear = try Silvergear108ScaleParser.parse(.init(
            companyID: 0xA0AC,
            payload: silvergearPayload
        ))
        precondition(abs(silvergear.weightKG - 60.0) < 0.001)
        precondition(silvergear.isStable)
        let silvergearCatalogMatch = ScaleBroadcastProtocolCatalog.parse(
            name: "108",
            manufacturerData: Data([0xAC, 0xA0]) + silvergearPayload,
            advertisedServiceUUIDs: ["FFB0"]
        )
        precondition(silvergearCatalogMatch?.family == .silvergear108)
        let silvergearSettling = try Silvergear108ScaleParser.parse(.init(
            companyID: 0xA0AC,
            payload: hexData("030000000002A02C4AC00DA3")
        ))
        precondition(abs(silvergearSettling.weightKG - 60.0) < 0.001)
        precondition(!silvergearSettling.isStable)
        do {
            _ = try Silvergear108ScaleParser.parse(.init(
                companyID: 0xA0AC,
                payload: hexData("030000000002202C4AC00D02")
            ))
            preconditionFailure("Silvergear 校验错误必须被拒绝")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }
        do {
            _ = try Silvergear108ScaleParser.parse(.init(
                companyID: 0xA0AC,
                payload: hexData("030000000002A201020306AE")
            ))
            preconditionFailure("Silvergear 未确认的身体数据帧不得被解析为测量值")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        let appleManufacturerData = Data([0xFF, 0xFF]) + qnPayload
        let catalogMatch = ScaleBroadcastProtocolCatalog.parse(
            name: "QN-Scale",
            manufacturerData: appleManufacturerData
        )
        precondition(catalogMatch?.family == .qnAABB)
        precondition(abs((catalogMatch?.measurement.weightKG ?? 0) - 72.35) < 0.001)

        do {
            var invalidAAA = aaaPayload
            invalidAAA[invalidAAA.index(before: invalidAAA.endIndex)] = 0x01
            _ = try AAASeriesScaleParser.parse(
                .init(companyID: 0x1234, payload: invalidAAA),
                advertisedName: "AAA007"
            )
            preconditionFailure("AAA 校验错误必须被拒绝")
        } catch ScalePayloadError.unsupported {
            // Expected.
        }

        print("Parser smoke tests passed")
    }

    private static func hexData(_ value: String) -> Data {
        var result = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else {
                preconditionFailure("无效的十六进制测试数据")
            }
            result.append(byte)
            index = next
        }
        return result
    }
}
