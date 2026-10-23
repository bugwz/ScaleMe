<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![On-device storage](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

A native iOS app for weight and body composition trends

**Observe changes in your body and follow your health journey.**

[简体中文](../../README.md) | [繁體中文](README-zh-Hant.md) | [**English**](README-en.md) | [日本語](README-ja.md) | [Français](README-fr.md) | [Deutsch](README-de.md) | [Español](README-es.md) | [Português](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

ScaleMe (观我) is a native iOS app for individuals and families to record weight and body composition. Connect compatible scales via Bluetooth or enter measurements manually, then browse history and trends by profile, device, and time.

No account registration is required. Profiles, device settings, and measurements are stored on the device, are not uploaded to developer servers, and have no app-managed cloud sync. Users choose whether to enable Apple Health access or import and export files.

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreBanner.png" width="100%" alt="ScaleMe product overview and App Store download">
</a>

</div>

## Main features

### Measurements and records

- Discover and pair compatible Bluetooth scales, display measurement progress and available device data, and save stable measurements.
- Enter weight manually, choose the measurement date and time, and optionally add body composition values shown by the device, including past measurements.
- View measurement details, reassign records to a profile, or delete them. Supported protocols can retrieve scale history, match profiles, and remove duplicates.
- Live measurements are saved to a local file before becoming permanent records and triggering enabled Health sharing. Failed saves show an unsaved status and a retry option.

### Family profiles and trends

- Create multiple profiles, manage multiple devices, and view each person's records separately.
- Choose and arrange health metrics on the home screen, with their latest values, explanations, and applicable reference ranges.
- Filter trends by profile, device, date range, and metric; explore changes through charts and history.
- Small, medium, and large Home Screen trend widgets each offer independent metric, date range, device, profile, and display settings.

### Data management and Apple Health

- Import and export settings and measurements separately or together as JSON files, and delete local data.
- Optionally read weight and body fat percentage from Apple Health into your own profile, and write eligible new measurements to Apple Health.
- App sync switches and system permissions are managed separately. Bluetooth measurements, manual entries, and trends remain available with sync off.

### Interface and accessibility

- Supports Simplified Chinese, Traditional Chinese, English, Japanese, French, German, Spanish, Portuguese, Russian, and Korean, following the system language or an in-app selection.
- Default and color-vision-friendly themes support light, dark, and system appearance.
- VoiceOver support covers measurement status, charts, menus, and forms, with adaptations for Dynamic Type and Reduce Motion. See [accessibility validation](../Accessibility.md) for the actual acceptance scope.
- Simulated family data lets you explore the interface without a scale. Record changes in simulation mode are not written to real measurement data; preset data returns on the next launch.

## Device compatibility

The project implements Bluetooth SIG standard weight and body composition characteristic parsing, plus advertisement parsing or GATT measurement sessions for several vendor protocols. Features and validation levels differ by protocol; a brand name does not establish support for every model.

- Discovering a device, matching its name, or registering a protocol does not establish measurement support.
- Sample-data tests validate parsing behavior, not end-to-end operation with an iPhone and a real scale.
- Live measurements, body composition, scale history retrieval, and authentication settings depend on the protocol. Unconfirmed fields are not saved as known metrics.
- Valid declarative communication rules can be imported from local JSON files. The app does not download protocols from remote URLs.

See the [scale protocol support matrix](../BluetoothProtocolSupport.md) for protocols, current capabilities, validation levels, and research sources, and [external communication rules](../ExternalCommunicationRules.md) for the extension format.

## Metrics and estimates

The app distinguishes raw device values from app-calculated values. Weight, device-reported body composition, BMI calculated from profile information, and conditionally estimated body composition have different sources and applicability.

For recognized body composition scales, device or protocol values take precedence. Experimental estimates fill missing body composition values only when valid primary impedance, profile information, and model conditions are available. Ordinary weight scales, manual records, and Apple Health imports do not trigger these default estimates. Without primary impedance, BMI is not substituted for impedance to estimate missing body composition.

Calculated results are saved with each measurement, separately from raw device values. Editing a profile does not automatically recalculate history; reassigning a record to another profile does. App estimates are not written to Apple Health. Model age ranges, device adaptation assumptions, and empirical rules have limitations; app estimates are not official vendor algorithms or clinical measurements.

The in-app Data Information section and individual metric calculation pages provide formulas, sources, and applicability. Technical details are in [data, sync, and privacy](../DataAndPrivacy.md). Body composition results are for observing trends, not diagnosis, treatment, or medical decisions.

<a id="data-storage-and-privacy"></a>

## Data storage and privacy

### On-device storage

Profiles, device settings, and measurements are stored as versioned JSON files in the app sandbox. Settings and records are separate and use iOS Complete File Protection. Device binding and authentication secrets are stored in the system Keychain.

Home Screen widgets read a compact trend snapshot through an on-device App Group. The snapshot uses AES-GCM encryption, with keys managed through a shared Keychain. This shares data between the app and its extension on the same device.

The app has no account system, advertising, or analytics reporting service. It does not upload profiles or health measurements to developer servers or use iCloud to sync these data in real time.

### User-controlled data transfers

- **System backups**: Settings and measurement files may be included in system device backups enabled by the user. The system handles backup and restoration.
- **Apple Health**: Reading and writing are off by default and require setup and authorization. Reads go only into your own profile; writes include only your own new stable measurements from selected real devices. Historical imports, manual records, simulated data, and app estimates are not written to Apple Health. Turning sync off does not delete previously written or imported data.
- **File import and export**: Initiated by the user. Exported JSON is unencrypted plain text and may contain profile details, device information, and measurements. Users choose where to save it and whom to share it with.
- **Diagnostic exports**: Collected and exported by the user, these may contain device identifiers and measurement payloads. Original files should not be shared publicly.

See the [privacy policy](../PrivacyPolicy.md) for full details and the [HealthKit validation guide](../AppReviewHealthKit.md) for authorization and validation procedures.

## Technology and project structure

Requires iOS 17 or later and uses Swift, SwiftUI, Charts, CoreBluetooth, HealthKit, WidgetKit, and CryptoKit. The interface, domain calculations, protocol parsing, and system services are separated by responsibility.

```text
ScaleMe/
├── App/              # Entry point, navigation, launch flow, and global state
├── Core/             # Cross-feature foundations such as localization
├── Domain/           # Domain models, calculations, and trend analysis
├── Infrastructure/   # Bluetooth, persistence, health data, diagnostics, widget export
├── Features/         # Home, measurement, trends, devices, and settings
├── Shared/           # Design system and shared components
└── Resources/        # Assets, String Catalogs, and configuration resources
ScaleMeWidget/        # Home Screen trend widgets
ScaleMeWidgetShared/  # Shared app/widget data contracts and storage
Docs/                # Implementation and validation documentation
└── readme/           # Full README translations
Tests/Smoke/         # Deterministic protocol, calculation, and localization checks
Tools/               # Development and asset generation tools
```

See [architecture and implementation](../Architecture.md) for layering, state transitions, and the Bluetooth pipeline.

## Running the project

1. Open `ScaleMe.xcodeproj` in Xcode 26 or later and select the `ScaleMe` scheme.
2. Run in the simulator and enable simulated data under Settings → Data Management to explore profiles, devices, records, and charts.
3. To test real Bluetooth measurements, configure a development team, install on an iPhone, and grant Bluetooth permission when searching for devices.
4. To test widgets, configure matching App Groups and Keychain Sharing capabilities for the app and the `ScaleMeWidget` extension.

Simulator and automated tests do not replace physical-device validation of Bluetooth, HealthKit, or individual scale models. See [development and validation](../Development.md) for requirements, build commands, and test entry points.

## Documentation and contributing

- [Documentation index](../README.md)
- [Architecture and implementation](../Architecture.md)
- [Scale protocol support matrix](../BluetoothProtocolSupport.md)
- [Data, sync, and privacy](../DataAndPrivacy.md)
- [Development and validation](../Development.md)
- [Agent development conventions](../../AGENTS.md)

The Chinese product name is “观我”; the English name and Xcode project name are “ScaleMe.” The canonical logo is [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg). Third-party brand names in the documentation describe device compatibility or technical sources and do not imply endorsement.

## License

The project's source distribution as a whole uses **[GNU GPL v3 or later](../../LICENSE)** (`GPL-3.0-or-later`). Original contributions are Copyright (C) 2026 bugwz; third-party portions retain their original copyrights and licenses. See the [project notice](../../NOTICE) and [licenses and third-party notices](../../LICENSES/README.md).
