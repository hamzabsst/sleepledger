# Validation report

Prepared on 8 October 2026 in an Ubuntu workspace.

## Completed here

- Generated a dependency-free, single-target Xcode project and shared Run scheme.
- Parsed all 16 Swift files with tree-sitter-swift 0.7.4 / tree-sitter 0.26.0: **zero syntax errors**. This includes app/core, package manifest, unit test file and optional widget source. Parsing is not type checking.
- Structural validation checks PBX object IDs/references, app/core source membership, source existence, separate widget entry point, Info.plist, shared scheme references, absence of baseline Health entitlements, synthetic JSON/CSV fixtures, and local documentation links.
- Added 10 Swift unit tests for circular clock analysis, unknown-day/naps calculation, ID/overlap protection, quoted CSV/JSON round trips, Health grouping/stage totals, mixed-source rejection, schedule eligibility, confirmed-past wake suggestions, DST elapsed duration, and invalid data.
- Documented primary Apple sources for sleep phase reading, Health logging actions, URL exchange, Developer Mode and Personal Team limits. The exact sleep-writing fields remain an on-phone capability check.

## Verified cloud build

[GitHub Actions build #1](https://github.com/hamzabsst/sleepledger/actions/runs/37816137251) succeeded on 8 October 2026 for source commit `50588228007e69c4c6bb069b7ba74ecd1aa65c62`.

- Structural validation passed.
- `swift test --package-path Core`: **10 tests passed, 0 failures**.
- Xcode 16.4 / iPhoneOS 18.5 SDK compiled the **arm64 device Release app**, minimum deployment target iOS 17, with signing disabled: **BUILD SUCCEEDED**.
- IPA packaging and ZIP integrity check passed. The artifact contains `Payload/SleepLedger.app` with the device executable and Info.plist.
- Downloaded artifact ZIP SHA-256 matched GitHub’s digest: `8097bc52fad47c43cf9d5e39b62570f8b443157ab3db378cf6adb292af4af15c`.
- Extracted `SleepLedger-unsigned.ipa` SHA-256: `048c0ce0e5ffcadd74703dd4a0edf4d44c9b04fdeaf468b8ee8bd988a6cf64a5`.

The runner reported an Actions Node.js 20 deprecation warning for the v4 checkout/upload actions, which ran successfully under Node.js 24, and a macOS runner queue-capacity notice. Neither prevented the build. See [NO_MAC.md](NO_MAC.md) for local signing instructions.

## Still untested

- Simulator or iPhone launch, rendered UI/accessibility, signing and renewal.
- Shortcuts installation and execution; Health reading and writing.
- Notification delivery, locked-phone alarm behavior, Action Button, optional App Group signing/widget behavior and real Health duplicate handling.

No Swift/Xcode toolchain is installed on the local Ubuntu computer; the tests and compilation above ran on GitHub’s hosted Mac. Successful compilation does not establish working phone behavior.

The optional widget source is excluded from the baseline build; enable it only after the base app works and your team can provision its shared container.

## Reproduce structural checks

```sh
python3 Scripts/validate_project.py
```

Optional isolated syntax parser (not needed to build the app): install `tree-sitter==0.26.0` and `tree-sitter-swift==0.7.4` in a Python environment, then run `python3 Scripts/check_swift_syntax.py`.

## Complete on a Mac

```sh
cd Core
swift test
cd ..
xcodebuild -project SleepLedger.xcodeproj -scheme SleepLedger \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Then run the [phone checklist](TESTING.md), starting with Stage 1. Report any Xcode compiler errors verbatim so they can be corrected against the actual installed SDK. A clean syntax parse does not establish a successful iOS build.
