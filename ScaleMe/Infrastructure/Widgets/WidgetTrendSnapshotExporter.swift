import Foundation
import WidgetKit

actor WidgetTrendSnapshotExporter {
    static let shared = WidgetTrendSnapshotExporter()

    func export(_ snapshot: WidgetTrendSnapshot) {
        do {
            try WidgetTrendRepository().save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetTrendRepository.widgetKind)
        } catch {
            // Widget export is best-effort and must never block local measurement or persistence.
        }
    }
}

@MainActor
extension MeasurementStore {
    func makeWidgetTrendSnapshot(now: Date = .now) -> WidgetTrendSnapshot {
        let metrics = TrendMetric.allCases.map { metric in
            WidgetTrendMetricMetadata(
                metricID: metric.rawValue,
                title: appLanguage.text(metric.title),
                systemImage: metric.systemImage,
                unit: metric.unitLabel(weightUnit: unit),
                isEstimated: metric.isEstimatedComposition
            )
        }
        let profiles = displayProfiles.map {
            WidgetTrendProfile(
                id: $0.id.uuidString,
                name: $0.name,
                relation: appLanguage.text($0.role)
            )
        }
        let devices = displayPairedScales.map {
            WidgetTrendDevice(
                id: $0.id.uuidString,
                name: $0.name,
                modelName: $0.modelName
            )
        }
        let measurements = displayProfiles.flatMap { profile in
            displayMeasurements(for: profile.id).map { measurement in
                let values = Dictionary(uniqueKeysWithValues: TrendMetric.allCases.compactMap { metric in
                    metric.value(for: measurement, profile: profile).map {
                        (metric.rawValue, metric.displayValue($0, unit: unit))
                    }
                })
                return WidgetTrendMeasurement(
                    id: measurement.id.uuidString,
                    profileID: profile.id.uuidString,
                    deviceID: measurement.deviceID?.uuidString,
                    date: measurement.date,
                    values: values
                )
            }
        }

        return WidgetTrendSnapshot(
            generatedAt: now,
            localeIdentifier: appLanguage.rawValue,
            defaultProfileID: displaySelectedProfileID.uuidString,
            rangeTitles: Dictionary(uniqueKeysWithValues: WidgetTrendTimeRange.allCases.map {
                ($0.rawValue, appLanguage.text($0.title))
            }),
            allDevicesTitle: appLanguage.text("全部设备"),
            metrics: metrics,
            profiles: profiles,
            devices: devices,
            measurements: measurements
        )
    }
}
