---
name: dev
description: Apply ScaleMe's repository development conventions when implementing, fixing, or reviewing its SwiftUI features, Bluetooth protocols, storage, localization, or resources. Use for development work in this project, especially edits or builds that touch String Catalogs; not for unrelated projects.
---

# ScaleMe development conventions

This skill and its references are the canonical development rules for ScaleMe. Paths in rules and commands are relative to the repository root unless explicitly linked. Root AGENTS.md is the loading entry point; keep rules here instead of duplicating them in tool-specific instructions.

## Required references

Read the relevant references before inspecting or changing the corresponding implementation. Their constraints are mandatory for that work:

- For UI, shared components, icons, assets, or launch animation: [design.md](references/design.md).
- For Bluetooth discovery, decoding, rules, protocol IDs, or compatibility claims: [bluetooth.md](references/bluetooth.md).
- For user-facing text, language handling, String Catalog edits, or builds that may rewrite catalogs: [localization.md](references/localization.md). This includes the one-entry-per-line format for Localizable.xcstrings and every application catalog.
- Before choosing or running validation: [verification.md](references/verification.md). Run the smallest meaningful checks for the actual change and report results.

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

## Data, health, and privacy

- This repository is public. Apply the following disclosure rules to documentation, code comments, fixtures, screenshots, generated artifacts, and proposed commit/PR/release text; a user's diagnostic upload authorizes investigation, not publication of its contents.
- Do not copy personal measurements, profile attributes, capture dates/times, local paths, account names, device UUIDs/MAC addresses/serial numbers, credentials, or a user's specific device/firmware/hardware combination into repository content. Describe general protocol behavior and validation coverage without linking it to an individual device or measurement session. Public model names and protocol identifiers may remain when needed to define compatibility, without personal ownership or capture context.
- Derive public fixtures from synthetic measurements, dates, device identifiers, and credentials. Preserve the relevant framing, state transitions, and validation conditions, recalculate dependent lengths/checksums, and label synthetic examples. Keep original diagnostic files outside the repository and inspect the final diff for identifying details before handoff.
- Default to local-first storage. Do not add accounts, analytics, advertising identifiers, or cloud upload without an explicit requirement.
- Request Bluetooth or HealthKit permissions only at the moment their feature is used, with accurate Chinese usage descriptions.
- Do not display an enabled control for an integration that is not functional. Label unfinished integrations clearly or omit them.
- Do not fabricate body-composition values received from hardware. Derived metrics must be visibly treated as estimates and based on documented profile inputs.
- Preserve units internally in SI (`kg`, `cm`, ohms) and convert only for display.
- Avoid logging health measurements, profile attributes, Bluetooth binding keys, or other sensitive values.
- Persist app configuration and measurement data as separate versioned JSON files under the app-owned `ScaleMe/` directory. Keep both eligible for normal device backup and protect them with iOS Complete File Protection; do not add app-managed encryption that depends on a nonmigrating device-only key. Device binding and authentication secrets still belong in Keychain and must never be written beside the data files.
- UI that presents body fat, visceral fat, basal metabolism, or similar metrics must retain an appropriate non-medical disclaimer.

## Swift implementation rules

- Keep UI state on the main actor. Make concurrency boundaries explicit around delegate callbacks and persistent state.
- Avoid force unwraps and unchecked indexing for Bluetooth data.
- Validate payload length before every read and reject impossible values rather than silently saving them.
- Use descriptive domain names such as `weightKG`, `impedanceOhm`, and `bodyFatPercent`; never encode units ambiguously.
- Use SF Symbols and native accessibility semantics. Important status must not be conveyed by color alone.
- Avoid one-off styling when a reusable design-system component or token is appropriate.

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
- When the user asks to release a version, create a release tag, publish a GitHub Release, or update its description, use the project skill at `.agents/skills/release/SKILL.md`. Its separate commit, tag, and remote-publication confirmations are mandatory.
