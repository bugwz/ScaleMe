import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case russian = "ru"
    case korean = "ko"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .russian: "Русский"
        case .korean: "한국어"
        }
    }

    static var systemDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let normalized = identifier.lowercased()
            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
                return .traditionalChinese
            }
            if normalized.hasPrefix("zh") { return .simplifiedChinese }
            if let language = allCases.first(where: { normalized.hasPrefix($0.rawValue.lowercased()) }) {
                return language
            }
        }
        return .simplifiedChinese
    }

    func text(_ key: AppText) -> String {
        key.value(for: self)
    }
}

enum AppText {
    case productName
    case tagline
    case home
    case measure
    case trends
    case devices
    case settings
    case currentPage
    case language
    case languageDetail
    case languageSettings
    case languageHint
    case selected
    case userInformation
    case appSettings
    case displaySettings
    case displaySettingsDetail
    case dataSync
    case dataSyncDetail
    case communicationProtocol
    case communicationProtocolDetail
    case developerDiagnostics
    case developerDiagnosticsDetail
    case about
    case aboutDetail

    fileprivate func value(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            switch self {
            case .productName: "观我"
            case .tagline: "从细微变化里，看见身体长期的方向"
            case .home: "首页"
            case .measure: "测量"
            case .trends: "趋势"
            case .devices: "设备"
            case .settings: "设置"
            case .currentPage: "当前页面"
            case .language: "语言"
            case .languageDetail: "选择应用界面与启动页语言"
            case .languageSettings: "语言设置"
            case .languageHint: "更改后立即应用到界面，无需重新启动。"
            case .selected: "已选择"
            case .userInformation: "用户信息"
            case .appSettings: "应用设置"
            case .displaySettings: "显示设置"
            case .displaySettingsDetail: "体重单位、连续称重与模拟数据"
            case .dataSync: "数据同步"
            case .dataSyncDetail: "iCloud 配置与测量数据"
            case .communicationProtocol: "通信协议"
            case .communicationProtocolDetail: "设备识别与数据解析"
            case .developerDiagnostics: "开发诊断"
            case .developerDiagnosticsDetail: "输入响应计时与日志导出"
            case .about: "关于观我"
            case .aboutDetail: "产品原则与版本信息"
            }
        case .traditionalChinese:
            switch self {
            case .productName: "見微"
            case .tagline: "從細微變化裡，看見身體長期的方向"
            case .home: "首頁"
            case .measure: "測量"
            case .trends: "趨勢"
            case .devices: "裝置"
            case .settings: "設定"
            case .currentPage: "目前頁面"
            case .language: "語言"
            case .languageDetail: "選擇 App 介面與啟動畫面語言"
            case .languageSettings: "語言設定"
            case .languageHint: "變更後會立即套用，無需重新啟動。"
            case .selected: "已選擇"
            case .userInformation: "使用者資訊"
            case .appSettings: "App 設定"
            case .displaySettings: "顯示設定"
            case .displaySettingsDetail: "體重單位、連續測量與模擬資料"
            case .dataSync: "資料同步"
            case .dataSyncDetail: "iCloud 設定與測量資料"
            case .communicationProtocol: "通訊協定"
            case .communicationProtocolDetail: "裝置識別與資料解析"
            case .developerDiagnostics: "開發診斷"
            case .developerDiagnosticsDetail: "輸入回應計時與記錄匯出"
            case .about: "關於見微"
            case .aboutDetail: "產品原則與版本資訊"
            }
        case .english:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "See the long-term direction in every subtle change"
            case .home: "Home"
            case .measure: "Measure"
            case .trends: "Trends"
            case .devices: "Devices"
            case .settings: "Settings"
            case .currentPage: "Current page"
            case .language: "Language"
            case .languageDetail: "Choose the app and launch screen language"
            case .languageSettings: "Language"
            case .languageHint: "Changes apply immediately without restarting."
            case .selected: "Selected"
            case .userInformation: "User information"
            case .appSettings: "App settings"
            case .displaySettings: "Display"
            case .displaySettingsDetail: "Weight unit, repeated measurements, and demo data"
            case .dataSync: "Data sync"
            case .dataSyncDetail: "iCloud settings and measurement data"
            case .communicationProtocol: "Communication protocols"
            case .communicationProtocolDetail: "Device identification and data parsing"
            case .developerDiagnostics: "Developer diagnostics"
            case .developerDiagnosticsDetail: "Input timing and log export"
            case .about: "About ScaleMe"
            case .aboutDetail: "Product principles and version information"
            }
        case .japanese:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "小さな変化から、身体の長期的な方向を見つける"
            case .home: "ホーム"
            case .measure: "測定"
            case .trends: "推移"
            case .devices: "デバイス"
            case .settings: "設定"
            case .currentPage: "現在のページ"
            case .language: "言語"
            case .languageDetail: "アプリと起動画面の言語を選択"
            case .languageSettings: "言語設定"
            case .languageHint: "変更は再起動せずにすぐ反映されます。"
            case .selected: "選択済み"
            case .userInformation: "ユーザー情報"
            case .appSettings: "アプリ設定"
            case .displaySettings: "表示設定"
            case .displaySettingsDetail: "体重単位、連続測定、デモデータ"
            case .dataSync: "データ同期"
            case .dataSyncDetail: "iCloud 設定と測定データ"
            case .communicationProtocol: "通信プロトコル"
            case .communicationProtocolDetail: "デバイス識別とデータ解析"
            case .developerDiagnostics: "開発者診断"
            case .developerDiagnosticsDetail: "入力応答時間とログの書き出し"
            case .about: "ScaleMe について"
            case .aboutDetail: "製品方針とバージョン情報"
            }
        case .french:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "Percevez la tendance à long terme dans chaque variation"
            case .home: "Accueil"
            case .measure: "Mesurer"
            case .trends: "Tendances"
            case .devices: "Appareils"
            case .settings: "Réglages"
            case .currentPage: "Page actuelle"
            case .language: "Langue"
            case .languageDetail: "Choisir la langue de l’app et de l’écran de lancement"
            case .languageSettings: "Langue"
            case .languageHint: "Les modifications s’appliquent immédiatement."
            case .selected: "Sélectionné"
            case .userInformation: "Informations utilisateur"
            case .appSettings: "Réglages de l’app"
            case .displaySettings: "Affichage"
            case .displaySettingsDetail: "Unité de poids, mesures répétées et données de démo"
            case .dataSync: "Synchronisation"
            case .dataSyncDetail: "Configuration iCloud et données de mesure"
            case .communicationProtocol: "Protocoles de communication"
            case .communicationProtocolDetail: "Identification des appareils et analyse des données"
            case .developerDiagnostics: "Diagnostic développeur"
            case .developerDiagnosticsDetail: "Temps de réponse et exportation des journaux"
            case .about: "À propos de ScaleMe"
            case .aboutDetail: "Principes du produit et version"
            }
        case .german:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "Erkenne die langfristige Richtung in kleinen Veränderungen"
            case .home: "Start"
            case .measure: "Messen"
            case .trends: "Trends"
            case .devices: "Geräte"
            case .settings: "Einstellungen"
            case .currentPage: "Aktuelle Seite"
            case .language: "Sprache"
            case .languageDetail: "Sprache der App und des Startbildschirms wählen"
            case .languageSettings: "Sprache"
            case .languageHint: "Änderungen werden sofort ohne Neustart übernommen."
            case .selected: "Ausgewählt"
            case .userInformation: "Benutzerinformationen"
            case .appSettings: "App-Einstellungen"
            case .displaySettings: "Anzeige"
            case .displaySettingsDetail: "Gewichtseinheit, Folgemessungen und Demodaten"
            case .dataSync: "Datensynchronisierung"
            case .dataSyncDetail: "iCloud-Konfiguration und Messdaten"
            case .communicationProtocol: "Kommunikationsprotokolle"
            case .communicationProtocolDetail: "Geräteerkennung und Datenanalyse"
            case .developerDiagnostics: "Entwicklerdiagnose"
            case .developerDiagnosticsDetail: "Eingabezeiten und Protokollexport"
            case .about: "Über ScaleMe"
            case .aboutDetail: "Produktprinzipien und Versionsinformationen"
            }
        case .spanish:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "Descubre la dirección a largo plazo en cada pequeño cambio"
            case .home: "Inicio"
            case .measure: "Medir"
            case .trends: "Tendencias"
            case .devices: "Dispositivos"
            case .settings: "Ajustes"
            case .currentPage: "Página actual"
            case .language: "Idioma"
            case .languageDetail: "Elige el idioma de la app y de la pantalla de inicio"
            case .languageSettings: "Idioma"
            case .languageHint: "Los cambios se aplican al instante, sin reiniciar."
            case .selected: "Seleccionado"
            case .userInformation: "Información del usuario"
            case .appSettings: "Ajustes de la app"
            case .displaySettings: "Pantalla"
            case .displaySettingsDetail: "Unidad de peso, mediciones seguidas y datos de demostración"
            case .dataSync: "Sincronización de datos"
            case .dataSyncDetail: "Configuración de iCloud y datos de medición"
            case .communicationProtocol: "Protocolos de comunicación"
            case .communicationProtocolDetail: "Identificación de dispositivos y análisis de datos"
            case .developerDiagnostics: "Diagnóstico de desarrollo"
            case .developerDiagnosticsDetail: "Tiempos de entrada y exportación de registros"
            case .about: "Acerca de ScaleMe"
            case .aboutDetail: "Principios del producto e información de versión"
            }
        case .portuguese:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "Veja a direção a longo prazo em cada pequena mudança"
            case .home: "Início"
            case .measure: "Medir"
            case .trends: "Tendências"
            case .devices: "Dispositivos"
            case .settings: "Definições"
            case .currentPage: "Página atual"
            case .language: "Idioma"
            case .languageDetail: "Escolha o idioma da app e do ecrã inicial"
            case .languageSettings: "Idioma"
            case .languageHint: "As alterações são aplicadas de imediato, sem reiniciar."
            case .selected: "Selecionado"
            case .userInformation: "Informações do utilizador"
            case .appSettings: "Definições da app"
            case .displaySettings: "Apresentação"
            case .displaySettingsDetail: "Unidade de peso, medições seguidas e dados de demonstração"
            case .dataSync: "Sincronização de dados"
            case .dataSyncDetail: "Configuração do iCloud e dados de medição"
            case .communicationProtocol: "Protocolos de comunicação"
            case .communicationProtocolDetail: "Identificação de dispositivos e análise de dados"
            case .developerDiagnostics: "Diagnóstico de desenvolvimento"
            case .developerDiagnosticsDetail: "Tempos de entrada e exportação de registos"
            case .about: "Acerca do ScaleMe"
            case .aboutDetail: "Princípios do produto e informações da versão"
            }
        case .russian:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "Замечайте долгосрочное направление в каждом небольшом изменении"
            case .home: "Главная"
            case .measure: "Измерить"
            case .trends: "Тенденции"
            case .devices: "Устройства"
            case .settings: "Настройки"
            case .currentPage: "Текущая страница"
            case .language: "Язык"
            case .languageDetail: "Выберите язык приложения и экрана запуска"
            case .languageSettings: "Язык"
            case .languageHint: "Изменения применяются сразу без перезапуска."
            case .selected: "Выбрано"
            case .userInformation: "Данные пользователя"
            case .appSettings: "Настройки приложения"
            case .displaySettings: "Отображение"
            case .displaySettingsDetail: "Единицы веса, повторные измерения и демоданные"
            case .dataSync: "Синхронизация данных"
            case .dataSyncDetail: "Настройки iCloud и данные измерений"
            case .communicationProtocol: "Протоколы связи"
            case .communicationProtocolDetail: "Определение устройств и разбор данных"
            case .developerDiagnostics: "Диагностика разработчика"
            case .developerDiagnosticsDetail: "Время отклика и экспорт журнала"
            case .about: "О ScaleMe"
            case .aboutDetail: "Принципы продукта и версия"
            }
        case .korean:
            switch self {
            case .productName: "ScaleMe"
            case .tagline: "작은 변화에서 몸의 장기적인 방향을 발견하세요"
            case .home: "홈"
            case .measure: "측정"
            case .trends: "추세"
            case .devices: "기기"
            case .settings: "설정"
            case .currentPage: "현재 페이지"
            case .language: "언어"
            case .languageDetail: "앱과 시작 화면의 언어 선택"
            case .languageSettings: "언어 설정"
            case .languageHint: "다시 시작하지 않아도 즉시 적용됩니다."
            case .selected: "선택됨"
            case .userInformation: "사용자 정보"
            case .appSettings: "앱 설정"
            case .displaySettings: "화면 설정"
            case .displaySettingsDetail: "체중 단위, 연속 측정 및 데모 데이터"
            case .dataSync: "데이터 동기화"
            case .dataSyncDetail: "iCloud 설정 및 측정 데이터"
            case .communicationProtocol: "통신 프로토콜"
            case .communicationProtocolDetail: "기기 식별 및 데이터 분석"
            case .developerDiagnostics: "개발자 진단"
            case .developerDiagnosticsDetail: "입력 응답 시간 및 로그 내보내기"
            case .about: "ScaleMe 정보"
            case .aboutDetail: "제품 원칙 및 버전 정보"
            }
        }
    }
}
