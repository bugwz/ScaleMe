<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Speicherung auf dem Gerät](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

Eine native iOS-App für Gewichts- und Körperzusammensetzungstrends

**Beobachte Veränderungen deines Körpers und verfolge deinen Gesundheitsverlauf.**

[简体中文](../../README.md) | [繁體中文](README-zh-Hant.md) | [English](README-en.md) | [日本語](README-ja.md) | [Français](README-fr.md) | [**Deutsch**](README-de.md) | [Español](README-es.md) | [Português](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

观我 (ScaleMe) ist eine native iOS-App für Einzelpersonen und Familien zur Aufzeichnung von Gewicht und Körperzusammensetzung. Verbinde kompatible Waagen per Bluetooth oder erfasse Messungen manuell und betrachte Verlauf und Trends nach Profil, Gerät und Zeitraum.

Eine Registrierung ist nicht nötig. Profile, Geräteeinstellungen und Messungen werden auf dem Gerät gespeichert und nicht an Entwicklerserver übertragen. Die App bietet keine eigene Cloud-Synchronisierung. Apple-Health-Zugriff sowie Dateiimporte und -exporte werden vom Nutzer aktiviert beziehungsweise ausgeführt.

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreBanner.png" width="100%" alt="ScaleMe-Produktübersicht und Download im App Store">
</a>

</div>

## Hauptfunktionen

### Messungen und Aufzeichnungen

- Kompatible Bluetooth-Waagen finden und zuordnen, Messfortschritt und verfügbare Gerätedaten anzeigen und stabile Ergebnisse speichern.
- Gewicht manuell eingeben, Datum und Uhrzeit wählen und bei Bedarf angezeigte Körperzusammensetzungswerte ergänzen; auch vergangene Messungen lassen sich nachtragen.
- Details anzeigen, Messungen einem anderen Profil zuordnen oder löschen. Unterstützte Protokolle können den Waagenverlauf abrufen, Profile zuordnen und Duplikate entfernen.
- Live-Messungen werden zuerst lokal gespeichert, bevor sie als endgültige Datensätze erscheinen und die aktivierte Health-Freigabe auslösen. Bei einem Speicherfehler werden der ungespeicherte Zustand und eine Wiederholungsoption angezeigt.

### Familienprofile und Trends

- Mehrere Profile und Geräte verwalten und die Messungen jeder Person getrennt ansehen.
- Gesundheitsindikatoren auf der Startseite auswählen und anordnen sowie aktuelle Werte, Bedeutung und anwendbare Referenzbereiche anzeigen.
- Trends nach Profil, Gerät, Zeitraum und Messgröße filtern und Veränderungen anhand von Diagrammen und Verlauf betrachten.
- Kleine, mittlere und große Trend-Widgets für den Home-Bildschirm, jeweils mit eigener Auswahl von Messgröße, Zeitraum, Gerät, Profil und Darstellung.

### Datenverwaltung und Apple Health

- Einstellungen und Messungen getrennt oder gemeinsam als JSON importieren und exportieren sowie lokale Daten löschen.
- Optional Gewicht und Körperfettanteil aus Apple Health in das eigene Profil einlesen und geeignete neue Messungen in Apple Health schreiben.
- Synchronisierungsschalter und Systemberechtigungen werden getrennt verwaltet. Bluetooth-Messungen, manuelle Einträge und Trends funktionieren auch ohne Synchronisierung.

### Oberfläche und Bedienungshilfen

- Vereinfachtes und traditionelles Chinesisch, Englisch, Japanisch, Französisch, Deutsch, Spanisch, Portugiesisch, Russisch und Koreanisch; entsprechend dem System oder per Auswahl in der App.
- Standarddesign und ein Design für Menschen mit Farbsehschwäche, jeweils mit heller, dunkler oder systemabhängiger Darstellung.
- VoiceOver für Messstatus, Diagramme, Menüs und Formulare sowie Anpassungen an Dynamic Type und „Bewegung reduzieren“. Der tatsächliche Abnahmeumfang steht in der [Prüfung der Bedienungshilfen](../Accessibility.md).
- Simulierte Familiendaten ermöglichen das Ausprobieren ohne Waage. Änderungen an simulierten Messungen werden nicht in die echten Messdaten geschrieben; beim nächsten Start kehren die voreingestellten Daten zurück.

## Gerätekompatibilität

Implementiert sind die Auswertung standardisierter Bluetooth-SIG-Merkmale für Gewicht und Körperzusammensetzung sowie Advertisement-Parser oder GATT-Messsitzungen für mehrere Herstellerprotokolle. Funktionen und Prüfstand unterscheiden sich je Protokoll; ein Markenname belegt nicht die Unterstützung aller Modelle.

- Geräteerkennung, Namensübereinstimmung oder Registrierung eines Protokolls bedeuten noch keine Messunterstützung.
- Tests mit Beispieldaten prüfen die Auswertung, nicht den vollständigen Betrieb zwischen iPhone und echter Waage.
- Live-Messung, Körperzusammensetzung, Verlaufsabruf und Authentifizierung hängen vom Protokoll ab. Unbestätigte Datenfelder werden nicht als bekannte Messgrößen gespeichert.
- Formatkonforme deklarative Kommunikationsregeln können aus lokalen JSON-Dateien importiert werden. Die App lädt keine Protokolle von entfernten URLs herunter.

Protokolle, Funktionen, Prüfstand und Forschungsquellen stehen in der [Protokoll-Unterstützungsmatrix](../BluetoothProtocolSupport.md), das Erweiterungsformat unter [externe Kommunikationsregeln](../ExternalCommunicationRules.md).

## Messgrößen und Schätzungen

Die App unterscheidet Geräte-Rohwerte von eigenen Berechnungen. Gewicht, geräteseitige Körperzusammensetzung, aus Profildaten berechneter BMI und bedingt ergänzte Körperzusammensetzungswerte haben unterschiedliche Quellen und Geltungsbereiche.

Bei erkannten Körperanalysewaagen haben Geräte- oder Protokollwerte Vorrang. Fehlende Körperzusammensetzungswerte werden nur experimentell geschätzt, wenn eine gültige Hauptimpedanz, Profildaten und passende Modellbedingungen vorliegen. Reine Gewichtswaagen, manuelle Einträge und Apple-Health-Importe lösen diese Standardergänzungen nicht aus. Fehlt die Hauptimpedanz, wird sie nicht durch den BMI ersetzt, um fehlende Körperzusammensetzungswerte zu schätzen.

Berechnungen werden mit der Messung gespeichert; Rohwerte und App-Schätzungen bleiben getrennt. Profiländerungen berechnen alte Messungen nicht automatisch neu, die Zuordnung einer Messung zu einem anderen Profil dagegen schon. Schätzwerte werden nicht in Apple Health geschrieben. Altersbereiche, Annahmen zur Geräteanpassung und empirische Regeln sind begrenzt; App-Schätzungen sind keine offiziellen Herstelleralgorithmen oder klinischen Messungen.

Die Dateninformationen in der App und die Berechnungsseiten der Messgrößen nennen Formeln, Quellen und Anwendungsbereiche. Technische Details stehen unter [Daten, Synchronisierung und Datenschutz](../DataAndPrivacy.md). Körperzusammensetzungswerte dienen der Trendbeobachtung, nicht der Diagnose, Behandlung oder medizinischen Entscheidung.

<a id="data-storage-and-privacy"></a>

## Datenspeicherung und Datenschutz

### Speicherung auf dem Gerät

Profile, Geräteeinstellungen und Messungen liegen als versionierte JSON-Dateien in der App-Sandbox. Einstellungen und Messungen sind getrennt und verwenden iOS Complete File Protection. Geheimnisse zur Gerätebindung und Authentifizierung liegen in der System-Keychain.

Widgets lesen einen kompakten Trend-Schnappschuss über eine lokale App Group. Dieser ist mit AES-GCM verschlüsselt; Schlüssel werden über eine gemeinsame Keychain verwaltet. Dabei teilen App und Erweiterung Daten auf demselben Gerät.

Die App enthält weder Kontosystem noch Werbung oder Analysedaten-Übermittlung. Profile und Gesundheitsmessungen werden nicht an Entwicklerserver übertragen oder per iCloud in Echtzeit synchronisiert.

### Vom Nutzer gesteuerte Datenübertragung

- **Systemsicherungen**: Einstellungs- und Messdateien können in vom Nutzer aktivierten Gerätesicherungen enthalten sein. Sicherung und Wiederherstellung übernimmt das System.
- **Apple Health**: Lesen und Schreiben sind zunächst aus und erfordern Einrichtung und Berechtigung. Gelesene Daten gelangen nur ins eigene Profil; geschrieben werden nur eigene neue stabile Messungen ausgewählter realer Geräte. Importierter Verlauf, manuelle Einträge, Simulationsdaten und App-Schätzwerte werden nicht geschrieben. Das Abschalten der Synchronisierung löscht keine bereits geschriebenen oder importierten Daten.
- **Dateiimport und -export**: Werden vom Nutzer ausgelöst. Exportiertes JSON ist unverschlüsselter Klartext und kann Profile, Geräteinformationen und Messungen enthalten. Speicherort und Empfänger bestimmt der Nutzer.
- **Diagnoseexport**: Wird vom Nutzer aufgezeichnet und exportiert und kann Gerätekennungen und Messnutzdaten enthalten. Originaldateien sollten nicht öffentlich geteilt werden.

Einzelheiten stehen in der [Datenschutzerklärung](../PrivacyPolicy.md), Berechtigungs- und Prüfabläufe im [HealthKit-Prüfleitfaden](../AppReviewHealthKit.md).

## Technik und Projektstruktur

Mindestens iOS 17, mit Swift, SwiftUI, Charts, CoreBluetooth, HealthKit, WidgetKit und CryptoKit. Oberfläche, fachliche Berechnungen, Protokollauswertung und Systemdienste sind nach Verantwortung getrennt.

```text
ScaleMe/
├── App/              # Einstieg, Navigation, Startablauf und globaler Zustand
├── Core/             # Funktionsübergreifende Grundlagen wie Lokalisierung
├── Domain/           # Fachmodelle, Berechnungen und Trendanalyse
├── Infrastructure/   # Bluetooth, Speicherung, Gesundheitsdaten, Diagnose, Widget-Export
├── Features/         # Startseite, Messung, Trends, Geräte und Einstellungen
├── Shared/           # Designsystem und gemeinsame Komponenten
└── Resources/        # Assets, String Catalogs und Konfigurationsressourcen
ScaleMeWidget/        # Trend-Widgets für den Home-Bildschirm
ScaleMeWidgetShared/  # Gemeinsame Datenverträge und Speicherung für App und Widgets
Docs/                # Implementierungs- und Prüfdokumentation
└── readme/           # Vollständige README-Übersetzungen
Tests/Smoke/         # Deterministische Prüfungen für Protokolle, Berechnungen und Sprachen
Tools/               # Entwicklungs- und Ressourcengenerierungswerkzeuge
```

Schichten, Zustandsübergänge und Bluetooth-Pipeline beschreibt [Architektur und Implementierung](../Architecture.md).

## Projekt ausführen

1. `ScaleMe.xcodeproj` mit Xcode 26 oder neuer öffnen und das Scheme `ScaleMe` auswählen.
2. Im Simulator starten und unter Einstellungen → Datenverwaltung Simulationsdaten aktivieren, um Profile, Geräte, Messungen und Diagramme auszuprobieren.
3. Für echte Bluetooth-Messungen ein Entwicklungsteam konfigurieren, auf einem iPhone installieren und bei der Gerätesuche Bluetooth erlauben.
4. Für Widgets passende App-Groups- und Keychain-Sharing-Berechtigungen für die App und die Erweiterung `ScaleMeWidget` konfigurieren.

Simulator und automatisierte Tests ersetzen keine Prüfung von Bluetooth, HealthKit oder einzelnen Waagenmodellen am echten Gerät. Anforderungen, Build-Befehle und Testeinstiege stehen unter [Entwicklung und Prüfung](../Development.md).

## Dokumentation und Beiträge

- [Dokumentationsübersicht](../README.md)
- [Architektur und Implementierung](../Architecture.md)
- [Protokoll-Unterstützungsmatrix](../BluetoothProtocolSupport.md)
- [Daten, Synchronisierung und Datenschutz](../DataAndPrivacy.md)
- [Entwicklung und Prüfung](../Development.md)
- [Entwicklungsregeln für Agents](../../AGENTS.md)

Der chinesische Produktname ist „观我“, der englische Name und Xcode-Projektname „ScaleMe“. Das verbindliche Logo liegt unter [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg). Fremde Markennamen beschreiben Gerätekompatibilität oder technische Quellen und bedeuten keine Unterstützung durch die Hersteller.

## Lizenz

Die Quellcodeverteilung des Gesamtprojekts erfolgt unter **[GNU GPL v3 oder neuer](../../LICENSE)** (`GPL-3.0-or-later`). Eigene Beiträge: Copyright (C) 2026 bugwz. Drittanbieteranteile behalten ihre ursprünglichen Urheberrechte und Lizenzen; siehe [Projekthinweise](../../NOTICE) und [Lizenzen und Drittanbieterhinweise](../../LICENSES/README.md).
