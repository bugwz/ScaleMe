# ScaleMe Agent Development Guide

This is the canonical development guide for every coding agent working in this repository, including Codex, Claude Code, GitHub Copilot, Cursor, and other agentic tools. Read it before inspecting or changing implementation files. Tool-specific instruction files must point here instead of duplicating these rules.

## Product identity

- Chinese product name: **观我**.
- English product name and Xcode project name: **ScaleMe**.
- Product purpose: a privacy-conscious native iOS app for Bluetooth weight and body-composition scales, personal records, and long-term trend analysis.
- Product wording: “观察身体变化，看见自己的健康轨迹。”
- Do not imply medical diagnosis, treatment, or clinical accuracy. Consumer bioelectrical-impedance results are estimates for trend reference only.

## Current development phase: rapid iteration

This project is pre-release and in rapid development. Optimize for a clean current implementation, not compatibility with unfinished historical versions.

- Do **not** preserve backward compatibility with earlier development-only code, internal APIs, local schemas, `UserDefaults` keys, mock data, file names, view structures, or parser interfaces.
- When a design changes, replace the old implementation and remove obsolete code in the same change.
- Do not add deprecated wrappers, forwarding types, dual read/write paths, legacy adapters, migration shims, fallback branches, compatibility aliases, or feature flags merely to keep an earlier development build working.
- Do not leave commented-out alternatives, temporary copies, `V1`/`V2` duplicates, or “remove later” code.
- Development data may be reset when its schema changes. Prefer a new clean storage key or clearing invalid development data over writing migrations.
- Rename files and symbols directly and update all references; do not retain aliases for old names.
- An exception requires an explicit user request or a clearly identified released/public data contract. If that happens, document the compatibility boundary and add focused tests.

## Platform and project structure

- Native iOS app using Swift and SwiftUI.
- Minimum deployment target: iOS 17.
- Use Apple frameworks first: SwiftUI, Charts, CoreBluetooth, Foundation, and HealthKit when its capability is actually configured.
- Keep responsibilities separated:
  - `ScaleMe/App`: application entry, root navigation, launch flow, and app-wide observable state.
  - `ScaleMe/Core/Localization`: supported languages and semantic application text keys.
  - `ScaleMe/Domain`: framework-independent models, calculations, simulation data, and trend analysis.
  - `ScaleMe/Infrastructure`: Bluetooth, persistence, HealthKit, and diagnostics implementations.
  - `ScaleMe/Features`: feature-first SwiftUI screens grouped by user-facing area.
  - `ScaleMe/Shared`: reusable SwiftUI components, input bridges, and design-system tokens.
  - `ScaleMe/Resources`: asset catalogs, String Catalogs, entitlements, and other bundled resources.
  - `Design/Logo/logo.svg`: canonical vector logo.
  - `Tests/Smoke`: deterministic smoke executables mirroring the production responsibility they verify.
  - `Tools`: development utilities grouped by purpose.
- The Xcode project uses a file-system-synchronized root group. Keep the on-disk hierarchy intentional because Xcode mirrors it directly; do not add hand-maintained PBX file references for ordinary files under `ScaleMe/`.
- Avoid new third-party dependencies unless they provide clear value that Apple frameworks cannot reasonably cover.
- Prefer small, testable types and pure parsing functions. Keep CoreBluetooth delegate orchestration separate from byte decoding.

## Bluetooth scale compatibility

- Implement standards before brand heuristics:
  - Bluetooth SIG Weight Scale Service `0x181D`, Weight Measurement `0x2A9D`.
  - Bluetooth SIG Body Composition Service `0x181B`, Body Composition Measurement `0x2A9C`.
- Xiaomi legacy scale support may parse the publicly documented `0x181B` advertising payload for weight, stability, timestamp, and impedance.
- Treat standard GATT characteristic data and Xiaomi advertising data as separate protocol paths even when they share the `0x181B` UUID.
- Each proprietary brand or protocol family must have an isolated parser/adapter. Do not accumulate device-name conditionals in the central manager.
- Never mark a brand or model “supported” based only on discovery, name matching, or an online snippet. Require captured payload fixtures and preferably real-device/firmware validation.
- Show unverified devices as discoverable or pending validation. Do not claim universal compatibility.
- Newer encrypted or bound devices, including protocol variants that require vendor keys, must not be presented as supported until authorization and key handling are implemented securely.
- Validate byte order, flags, units, stability, plausible ranges, and malformed packet behavior. Add a fixture for every newly supported payload shape.

### Communication protocol IDs

- Treat a communication-rule ID as a stable machine identifier, not as a display name, version label, repository path, or source-attribution field. Keep author, upstream project, and source URL in the rule metadata and detail view.
- Built-in rules must use `protocol.builtin.<slug>`.
  - `<slug>` must contain 1 to 16 lowercase ASCII letters, digits, or hyphens; it must begin with a letter or digit.
  - `<slug>` is a single component: do not put another `.` inside it.
  - Keep it concise and protocol- or model-oriented, for example `sig-weight`, `xiaomi-181d`, or `eufy-p2`.
  - Do not include source markers such as `ble`, `ble-scale-sync`, `open`, `openscale`, or `upstream`.
  - Never resolve a collision with an arbitrary numeric suffix such as `-2`. First determine whether the records implement the same wire protocol: if they do, merge them into one built-in rule and retain every upstream source link in its metadata. If they do not, assign each a distinct semantic slug based on a real protocol difference such as model family, transport, service, or session type.
- Imported local or remote rules must use `protocol.custom.<slug>` and must never claim the `protocol.builtin.` namespace.
  - `<slug>` must contain 1 to 64 ASCII characters, begin with an ASCII letter or digit, and otherwise use only letters, digits, `.`, `_`, or `-`, matching `CommunicationRuleCodec` validation.
  - Choose a stable, concise, globally distinguishable slug. Do not encode a URL, version number, author name, or upstream repository name into it.
- Built-in display names must also be unique. A repeated brand or adapter name is not sufficient evidence that two wire protocols are identical; compare services, characteristics, framing, encryption, and session behavior before merging. When protocols cannot be merged, use concise English names that expose the meaningful distinction instead of repository names or numeric disambiguators.
- Keep every complete ID unique. When an ID changes during rapid development, update catalog mappings and deterministic smoke fixtures in the same change; do not add legacy aliases or compatibility shims.

## Data, health, and privacy

- Default to local-first storage. Do not add accounts, analytics, advertising identifiers, or cloud upload without an explicit requirement.
- Request Bluetooth or HealthKit permissions only at the moment their feature is used, with accurate Chinese usage descriptions.
- Do not display an enabled control for an integration that is not functional. Label unfinished integrations clearly or omit them.
- Do not fabricate body-composition values received from hardware. Derived metrics must be visibly treated as estimates and based on documented profile inputs.
- Preserve units internally in SI (`kg`, `cm`, ohms) and convert only for display.
- Avoid logging health measurements, profile attributes, Bluetooth binding keys, or other sensitive values.
- Persist app configuration and measurement data as separate versioned JSON files under the app-owned `ScaleMe/` directory. Keep both eligible for normal device backup and protect them with iOS Complete File Protection; do not add app-managed encryption that depends on a nonmigrating device-only key. Device binding and authentication secrets still belong in Keychain and must never be written beside the data files.
- UI that presents body fat, visceral fat, basal metabolism, or similar metrics must retain an appropriate non-medical disclaimer.

## Visual language

- The interface should feel fresh, calm, clean, and health-oriented—not like a dense medical dashboard or a high-contrast sports console.
- Do not rely on stock iOS system chrome (default `List`/`Form` styling, system edit-mode reorder handles, default navigation bar/list backgrounds, unstyled `Toggle`/`Picker` rows, etc.) for user-facing screens. Compose new UI from this project's own components (`SoftCard`, `SettingsPanel`, `pageBackground()`, custom rows built from `ScrollView`/`VStack`) and the shared palette below, matching the existing screens' look. Reserve system controls for cases with no reasonable custom equivalent (e.g. `DatePicker`, keyboard, share sheet).
- Selection dropdowns must use the shared anchored-overlay pattern in `ScaleMe/Shared/DesignSystem/DesignSystem.swift` (`AppDropdownField`, `AppDropdownAnchorPreferenceKey`, and `AppDropdownMenuLayer`) so their appearance, positioning, dismissal, and animation remain consistent. Extend the shared component when a new selection mode is needed instead of building a screen-local dropdown.
- Dropdown options must be presented as an overlay anchored to the field. Do not conditionally insert an options `VStack`, `List`, or other expanded content into the surrounding card or scroll layout, because opening a dropdown must not resize the panel, move adjacent content, or change the page's scroll position.
- Preserve the shared dropdown transition and field-chevron animation. The menu must choose above or below the anchor based on available space, remain inside horizontal screen bounds, scroll when its content is taller than the available area, and dismiss when the user taps outside it.
- Single-choice menus should dismiss after selection. Multi-choice menus should remain open while options are toggled, show every selected option with the shared selected styling and accessibility trait, and dismiss through the field or outside-tap layer. Only one dropdown may be expanded on a screen at a time.
- While a dropdown overlay is visible, hide the obscured underlying page from accessibility and expose the menu as a modal container. If no options are available, keep the field collapsed and disabled, visually communicate the disabled state, and show a localized explanation near the field rather than presenting an empty menu.
- Use the centralized palette in `ScaleMe/Shared/DesignSystem/DesignSystem.swift`; do not scatter new literal brand colors through views.
- Core palette:
  - Ink `#12332E`
  - Secondary text `#5C7873`
  - Canvas `#F6FCFA`
  - Mint `#14AD8C`
  - Pale mint `#E6FAF2`
  - Leaf `#BDE8A3`
  - Sky `#6DC2E6`
  - Muted lavender `#94A8E0`
  - Apricot and rose are limited semantic accents.
- Favor mist-white surfaces, generous spacing, restrained gradients, soft corners, subtle mint shadows, and strong readable text contrast.
- Reference screenshots define useful information hierarchy, not pixel-perfect appearance. Do not clone another product's branding or layout.
- The canonical logo is `Design/Logo/logo.svg`: a full-bleed fresh mint-to-sky scale face with exactly four compact light sensing points, no center symbol, and no outer white margin or nested app-icon silhouette. A clearly visible translucent white perimeter stroke is inset inside the scale face; let iOS apply the final app-icon corner mask.
- `Design/Logo/readme-logo.svg` is the dedicated transparent, tightly cropped README mark. Do not add an outer canvas or safe-area padding to it.
- Keep these generated application resources synchronized with the canonical logo:
  - `ScaleMe/Resources/Assets.xcassets/AppLogo.imageset/AppLogo.svg` for in-app vector rendering.
  - `ScaleMe/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` for the iOS app icon.
  - `Design/Logo/logo-preview.png` for documentation preview.
- Follow Apple asset naming conventions: PascalCase asset catalog names (`AppIcon`, `AppLogo`, `AccentColor`) and concise, role-based file names. Do not add version suffixes to active production assets.
- Regenerate the opaque iOS icon with `Tools/AssetGeneration/GenerateAppIcon.swift` after updating `logo-preview.png`; do not use lossy conversion or commit an app icon with an alpha channel.
- The custom SwiftUI launch animation lives in `ScaleMe/App/Launch/AnimatedLaunchView.swift`. Keep it visually aligned with the four-point logo, honor Reduce Motion, block interaction only while visible, and transition cleanly into the real root view. Do not use launch animation time to delay required initialization.

## Swift implementation rules

- Keep UI state on the main actor. Make concurrency boundaries explicit around delegate callbacks and persistent state.
- Avoid force unwraps and unchecked indexing for Bluetooth data.
- Validate payload length before every read and reject impossible values rather than silently saving them.
- Use descriptive domain names such as `weightKG`, `impedanceOhm`, and `bodyFatPercent`; never encode units ambiguously.
- Simplified Chinese is the source language. Put localizable user-facing text in `ScaleMe/Resources/Localization/Localizable.xcstrings`; use SwiftUI localizable APIs for view literals and semantic `AppText` keys for text selected by the in-app language setting. Do not reintroduce per-language Swift switches or scattered `.lproj/Localizable.strings` files.
- Use SF Symbols and native accessibility semantics. Important status must not be conveyed by color alone.
- Avoid one-off styling when a reusable design-system component or token is appropriate.

## Verification

After relevant changes, run the smallest meaningful checks and report the result.

Build without signing:

```sh
xcodebuild -project ScaleMe.xcodeproj \
  -scheme ScaleMe \
  -sdk iphoneos \
  -configuration Debug \
  -derivedDataPath .build/AgentCheck \
  CODE_SIGNING_ALLOWED=NO build
```

Protocol smoke test:

```sh
swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Bluetooth/ParserSmoke.swift \
  -o /tmp/scaleme-parser-smoke
/tmp/scaleme-parser-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Bluetooth/CommunicationRuleSmoke.swift \
  -o /tmp/scaleme-rule-smoke
/tmp/scaleme-rule-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Localization/LocalizationSmoke.swift \
  -o /tmp/scaleme-localization-smoke
/tmp/scaleme-localization-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  ScaleMe/Domain/Models/SimulationData.swift \
  Tests/Smoke/Domain/SimulationDataSmoke.swift \
  -o /tmp/scaleme-simulation-smoke
/tmp/scaleme-simulation-smoke
```

- Bluetooth discovery and measurement require a physical iPhone and real scale; simulator success is not hardware validation.
- Add deterministic tests for parser and calculation changes.
- Run `git diff --check` before handoff.
- Do not treat host CoreSimulator service failures as source-code failures; still perform an iPhoneOS compile check when possible.

## Documentation and compatibility claims

- Update `README.md` when setup steps, supported protocols, project structure, or user-visible capabilities change.
- Cite Bluetooth SIG specifications for standard services and link primary or original technical sources for proprietary protocol research.
- Clearly separate “implemented,” “works with fixture,” “verified on hardware,” and “planned.”
- Brand names describe compatibility only and do not imply endorsement.

## Agent working agreement

- Inspect the repository and current working tree before editing. Preserve unrelated user changes.
- Prefer completing an authorized implementation and its verification over returning only a plan.
- Use web research for current or uncertain protocol details; prefer official specifications and original repositories.
- Keep changes focused. Remove superseded code created by the same change.
- Never commit, push, publish, change developer signing, or contact external services unless the user explicitly requests it.
- Never use destructive Git commands to discard local changes.
- If real hardware, credentials, signing capabilities, or a material product decision is required, complete all safe local work first and then state the exact remaining blocker.
- When the user asks to create a Git commit or prepare commit information, use the project skill at `.agents/skills/commit/SKILL.md`. The skill's explicit confirmation step is mandatory.
