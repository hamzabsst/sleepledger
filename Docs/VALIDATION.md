# Validation report

Prepared on 8 October 2026 in an Ubuntu workspace.

## Completed here

- Generated a dependency-free, single-target Xcode project and shared Run scheme.
- Parsed all 16 Swift files with tree-sitter-swift 0.7.4 / tree-sitter 0.26.0: **zero syntax errors**. This includes app/core, package manifest, unit test file and optional widget source. Parsing is not type checking.
- Structural validation checks PBX object IDs/references, app/core source membership, source existence, separate widget entry point, Info.plist, shared scheme references, absence of baseline Health entitlements, synthetic JSON/CSV fixtures, and local documentation links.
- Added 10 Swift unit tests for circular clock analysis, unknown-day/naps calculation, ID/overlap protection, quoted CSV/JSON round trips, Health grouping/stage totals, mixed-source rejection, schedule eligibility, confirmed-past wake suggestions, DST elapsed duration, and invalid data.
- Documented primary Apple sources for sleep phase reading, Health logging actions, URL exchange, Developer Mode and Personal Team limits. The exact sleep-writing fields remain an on-phone capability check.

## No-Mac workflow added

A manual GitHub Actions workflow now runs core tests, compiles the device app unsigned, and packages an IPA for local iloader signing on Linux. YAML and embedded shell syntax were checked locally. The workflow has not been uploaded or executed; no compiled IPA is available yet. See [NO_MAC.md](NO_MAC.md).

## Not run here

No Swift toolchain or Xcode/iOS SDK is installed on this Linux machine. Therefore:

- `swift test` has **not run**.
- iOS source/API type checking and `xcodebuild` have **not run**.
- Simulator or iPhone launch, rendered UI/accessibility, signing and renewal have **not been tested**.
- No Shortcuts have been installed or run. No Health data has been read or written.
- Notification delivery, locked-phone alarm behavior, Action Button, optional App Group signing/widget behavior and real Health duplicate handling remain unverified.

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
