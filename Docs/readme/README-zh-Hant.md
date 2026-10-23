<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 觀我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![本機儲存](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

原生 iOS 體重與身體組成趨勢應用

**觀察身體變化，看見自己的健康軌跡。**

[简体中文](../../README.md) | [**繁體中文**](README-zh-Hant.md) | [English](README-en.md) | [日本語](README-ja.md) | [Français](README-fr.md) | [Deutsch](README-de.md) | [Español](README-es.md) | [Português](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

觀我（ScaleMe）是一款面向個人與家庭的原生 iOS 體重與身體組成記錄應用。透過藍牙連接相容的體重秤，也可手動輸入測量，按成員、設備和時間查看歷史記錄與變化趨勢。

應用無需註冊帳號，成員資料、設備設定和測量記錄保存在裝置上，不上傳至開發者伺服器，也不提供應用自身的雲端同步。Apple 健康讀寫和檔案匯入匯出由使用者自行啟用或操作。

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreQRCode.png" width="100%" alt="掃描 QR Code，在 App Store 下載觀我 ScaleMe">
</a>

</div>

## 主要功能

### 測量與記錄

- 發現並關聯相容的藍牙體重秤，顯示測量過程及設備提供的可用資料，保存穩定測量結果。
- 手動記錄體重，選擇測量日期與時間，按需補充設備顯示的身體組成數值，支援補登歷史記錄。
- 查看測量詳情、修改記錄的成員歸屬或刪除記錄；支援的設備協定可讀取秤內歷史，並進行成員匹配和去重。
- 即時測量先保存到本機檔案，再成為正式記錄並觸發已啟用的健康共享；保存失敗時顯示未保存狀態並提供重試入口。

### 家庭成員與趨勢

- 建立多個成員檔案，管理多台設備，分別查看各成員的記錄。
- 在首頁選擇和排列健康指標，查看最新值、指標含義和適用的參考範圍。
- 按成員、設備、時間範圍和指標篩選趨勢，結合圖表與歷史記錄觀察變化。
- 提供小、中、大三種尺寸的主畫面趨勢小工具；每個小工具可獨立選擇指標、時間範圍、設備、成員及顯示方式。

### 資料管理與 Apple 健康

- 透過 JSON 檔案分別或同時匯入匯出設定與測量記錄，提供本機資料刪除功能。
- 可選擇讀取 Apple 健康中的體重、體脂率並匯入「本人」檔案，也可將符合條件的新測量寫入 Apple 健康。
- 健康同步開關與系統授權分別管理；關閉同步後仍可使用藍牙測量、手動記錄與趨勢查看。

### 介面與輔助使用

- 支援簡體中文、繁體中文、英語、日語、法語、德語、西班牙語、葡萄牙語、俄語和韓語，可跟隨系統或在應用內選擇。
- 提供預設與色覺友好主題，支援淺色、深色及跟隨系統外觀。
- 為測量狀態、圖表、選單與表單提供 VoiceOver 支援，並適配動態字體和減少動態效果設定。實際驗收範圍見[輔助使用驗證](../Accessibility.md)。
- 提供家庭模擬資料，方便在沒有體重秤時體驗介面；模擬模式內的記錄修改不寫入正式測量資料，下次啟動恢復預設資料。

## 設備相容性

專案已實作 Bluetooth SIG 標準體重與身體組成特徵解析，以及多個廠商協定的廣播解析或 GATT 測量工作階段。不同協定的功能與驗證程度不同，不能按品牌名稱推斷所有型號均可使用。

- 掃描到設備、匹配名稱或登記協定，不等於已經支援測量。
- 資料樣本測試驗證解析行為，不等於完成 iPhone 與真實體重秤的端到端驗證。
- 即時測量、身體組成、設備歷史讀取和認證設定均取決於具體協定；未確認的資料欄位不會作為已知指標保存。
- 可從本機 JSON 檔案匯入符合格式的宣告式通訊規則；應用不從遠端位址下載協定。

具體協定、目前能力、驗證層級與研究來源見[體重秤協定支援矩陣](../BluetoothProtocolSupport.md)，擴充格式見[外部通訊規則](../ExternalCommunicationRules.md)。

## 指標與估算說明

應用區分設備原始值與應用計算值。體重、設備提供的身體組成、根據成員資料計算的 BMI，以及滿足條件時補算的身體組成，各有不同的資料來源和適用範圍。

對於已識別的體脂設備，優先使用設備或協定提供的指標；僅在具備有效主阻抗、成員資料且符合模型條件時，對缺失的身體組成進行實驗性估算。普通體重秤、手動記錄及 Apple 健康匯入不觸發這類預設補算。缺少主阻抗時，不以 BMI 替代阻抗來估算缺失的身體組成。

計算結果隨測量記錄保存，設備原始值與應用估算分開儲存；修改成員資料不會自動重算歷史記錄，重新分配記錄成員時會重新計算。應用估算不寫入 Apple 健康。模型的年齡範圍、設備適配假設和經驗規則存在限制，不能將應用估算視為廠商官方演算法或臨床測量。

應用內「資料說明」和各指標計算頁提供公式、來源與適用範圍，技術細節見[資料、同步與隱私](../DataAndPrivacy.md)。身體組成結果僅供觀察趨勢，不用於診斷、治療或醫療決策。

<a id="data-storage-and-privacy"></a>

## 資料儲存與隱私

### 本機儲存

成員資料、設備設定與測量記錄以版本化 JSON 檔案保存在應用沙盒中，設定和記錄分開儲存，使用 iOS Complete File Protection。設備綁定與認證秘密保存在系統 Keychain 中。

主畫面小工具透過本機 App Group 讀取精簡的趨勢快照；快照使用 AES-GCM 加密，金鑰透過共享 Keychain 管理。這是同一裝置上應用與擴充功能之間的資料共享。

應用不包含帳號系統、廣告或分析回報服務，不將成員資料和健康測量上傳至開發者伺服器，也不使用 iCloud 即時同步這些資料。

### 使用者控制的資料流轉

- **系統備份**：設定與測量檔案可包含在使用者啟用的系統裝置備份中，由系統負責備份和還原。
- **Apple 健康**：讀寫預設關閉，需要使用者設定並授權。讀取資料僅匯入「本人」；寫入僅針對「本人」由所選真實設備產生的新穩定測量。歷史匯入、手動記錄、模擬資料和應用估算不寫入 Apple 健康。關閉同步不會刪除已寫入或已匯入的資料。
- **檔案匯入匯出**：由使用者主動操作。匯出的 JSON 是未加密明文，可能包含成員資料、設備資訊和測量記錄，保存位置與分享對象由使用者選擇。
- **診斷匯出**：由使用者主動蒐集和匯出，可能包含設備識別碼及測量酬載，不應公開分享原始檔案。

完整說明見[隱私政策](../PrivacyPolicy.md)，健康授權與驗證流程見[HealthKit 驗證指南](../AppReviewHealthKit.md)。

## 技術與專案結構

最低支援 iOS 17，使用 Swift、SwiftUI、Charts、CoreBluetooth、HealthKit、WidgetKit 與 CryptoKit。介面、領域計算、協定解析和系統服務按職責分層。

```text
ScaleMe/
├── App/              # 應用入口、導覽、啟動流程與全域狀態
├── Core/             # 本地化等跨功能基礎能力
├── Domain/           # 領域模型、計算與趨勢分析
├── Infrastructure/   # 藍牙、持久化、健康資料、診斷與小工具匯出
├── Features/         # 首頁、測量、趨勢、設備和設定
├── Shared/           # 設計系統與共享元件
└── Resources/        # Assets、String Catalog 與設定資源
ScaleMeWidget/        # 主畫面趨勢小工具
ScaleMeWidgetShared/  # 主應用與小工具共享的資料契約和儲存
Docs/                # 實作與驗證文件
└── readme/           # 其他語言的完整 README 翻譯
Tests/Smoke/         # 協定、領域計算及本地化等確定性檢查
Tools/               # 開發與資源產生工具
```

具體分層、狀態流轉和藍牙管線見[架構與實作](../Architecture.md)。

## 執行專案

1. 使用 Xcode 26 或更新版本開啟 `ScaleMe.xcodeproj`，選擇 `ScaleMe` scheme。
2. 在模擬器中執行，從「設定 → 資料管理」啟用模擬資料，體驗成員、設備、記錄與圖表。
3. 測試真實藍牙測量時，設定開發團隊並安裝到 iPhone，在使用設備搜尋時授予藍牙權限。
4. 測試小工具時，為主應用與 `ScaleMeWidget` 擴充功能設定相符的 App Groups 和 Keychain Sharing 能力。

模擬器和自動化測試不能替代藍牙、HealthKit 與具體秤型的實機驗證。環境要求、建置命令與測試入口見[開發與驗證](../Development.md)。

## 文件與貢獻

- [文件導覽](../README.md)
- [架構與實作](../Architecture.md)
- [體重秤協定支援矩陣](../BluetoothProtocolSupport.md)
- [資料、同步與隱私](../DataAndPrivacy.md)
- [開發與驗證](../Development.md)
- [Agent 開發約定](../../AGENTS.md)

中文產品名為「觀我」，英文名及 Xcode 工程名為「ScaleMe」。規範標誌見 [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg)。文件中的第三方品牌名稱僅用於說明設備相容性或技術來源，不代表相關廠商背書。

## 授權條款

本專案整體原始碼發行採用 **[GNU GPL v3 或後續版本](../../LICENSE)**（`GPL-3.0-or-later`）。原創貢獻版權歸屬為 Copyright (C) 2026 bugwz；第三方部分保留其原始版權與授權，詳見[專案授權聲明](../../NOTICE)和[授權條款與第三方聲明](../../LICENSES/README.md)。
