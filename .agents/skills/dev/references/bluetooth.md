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
