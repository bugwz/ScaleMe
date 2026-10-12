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
