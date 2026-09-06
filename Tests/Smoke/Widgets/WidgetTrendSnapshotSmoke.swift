import Foundation

@main
enum WidgetTrendSnapshotSmoke {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let endDate = date(2026, 9, 2, calendar: calendar)
        let profileA = WidgetTrendProfile(
            id: "profile-a",
            name: "甲",
            relation: "本人"
        )
        let profileB = WidgetTrendProfile(
            id: "profile-b",
            name: "乙",
            relation: "家人"
        )
        let deviceA = WidgetTrendDevice(
            id: "device-a",
            name: "秤 A",
            modelName: "A1"
        )
        let metric = WidgetTrendMetricMetadata(
            metricID: "weight",
            title: "体重",
            systemImage: "scalemass.fill",
            unit: "kg",
            fractionDigits: 2,
            isEstimated: false
        )
        let snapshot = WidgetTrendSnapshot(
            generatedAt: endDate,
            localeIdentifier: "en",
            defaultProfileID: profileA.id,
            rangeTitles: ["week": "近 7 天", "month": "近 30 天"],
            allDevicesTitle: "全部设备",
            metrics: [metric],
            profiles: [profileA, profileB],
            devices: [deviceA],
            measurements: [
                measurement("a-old", profileA.id, deviceA.id, 2026, 7, 1, 70, calendar),
                measurement("a-1", profileA.id, deviceA.id, 2026, 9, 1, 60, calendar),
                measurement("a-2", profileA.id, deviceA.id, 2026, 9, 1, 62, calendar, hour: 12),
                measurement("a-manual", profileA.id, nil, 2026, 9, 2, 61, calendar),
                measurement("b-1", profileB.id, deviceA.id, 2026, 9, 2, 80, calendar)
            ]
        )

        let aggregate = snapshot.series(
            metricID: "weight",
            profileID: profileA.id,
            deviceID: deviceA.id,
            rangeID: "week",
            displayStyleID: "periodFocused",
            endingAt: endDate,
            calendar: calendar
        )
        precondition(aggregate?.points.count == 1)
        precondition(metric.formattedValue(61, locale: Locale(identifier: "en_US_POSIX")) == "61.00")
        precondition(metric.formattedValue(61.2, locale: Locale(identifier: "en_US_POSIX")) == "61.20")
        precondition(metric.formattedSignedValue(-0.5, locale: Locale(identifier: "en_US_POSIX")) == "-0.50")
        precondition(snapshot.localeIdentifier == "en")
        precondition(aggregate?.points.first?.value == 61)
        precondition(aggregate?.measurementCount == 2)
        precondition(aggregate?.profileName == "甲")
        precondition(aggregate?.deviceName == "秤 A")

        let actual = snapshot.series(
            metricID: "weight",
            profileID: profileA.id,
            deviceID: "all",
            rangeID: "week",
            displayStyleID: "actualFullRange",
            endingAt: endDate,
            calendar: calendar
        )
        precondition(actual?.points.map(\.value) == [60, 62, 61])
        precondition(actual?.measurementCount == 3)
        precondition(actual?.deviceName == "全部设备")

        let fullRange = snapshot.dateDomain(
            rangeID: "week",
            displayStyleID: "periodFullRange",
            endingAt: endDate,
            calendar: calendar
        )
        precondition(fullRange?.upperBound == endDate)
        precondition(fullRange?.lowerBound == calendar.date(byAdding: .day, value: -7, to: endDate))
        precondition(snapshot.dateDomain(
            rangeID: "week",
            displayStyleID: "periodFocused",
            endingAt: endDate,
            calendar: calendar
        ) == nil)

        let decodedSnapshot = try JSONDecoder().decode(
            WidgetTrendSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        precondition(decodedSnapshot.localeIdentifier == "en")
        precondition(decodedSnapshot.profiles.first?.name == "甲")
        precondition(decodedSnapshot.devices.first?.name == "秤 A")

        print("Widget trend snapshot smoke passed")
    }

    private static func measurement(
        _ id: String,
        _ profileID: String,
        _ deviceID: String?,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ value: Double,
        _ calendar: Calendar,
        hour: Int = 8
    ) -> WidgetTrendMeasurement {
        WidgetTrendMeasurement(
            id: id,
            profileID: profileID,
            deviceID: deviceID,
            date: date(year, month, day, hour: hour, calendar: calendar),
            values: ["weight": value]
        )
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 23,
        calendar: Calendar
    ) -> Date {
        guard let value = calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        ) else {
            preconditionFailure("invalid deterministic test date")
        }
        return value
    }
}
