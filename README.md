# SleepLedger

A personal, local-first iPhone sleep journal. SwiftUI + SwiftData, iOS 17+, no HealthKit, server, paid account, or package dependencies. Apple Health is accessed only by user-created Shortcuts.

**Build status:** [GitHub Actions build #1](https://github.com/hamzabsst/sleepledger/actions/runs/37816137251) passed on 8 October 2026: 10 core tests passed and the unsigned arm64 iPhone Release app compiled with Xcode 16.4 / iPhoneOS 18.5 SDK (iOS 17 minimum). The unsigned IPA is available in that run’s artifacts. Local signing, installation and iPhone behavior remain untested. See [validation](Docs/VALIDATION.md).

## Short plan and stages

| Stage | Screens / behavior | Included |
|---|---|---|
| 1: MVP | Tonight: start/stop and persisted active interval. History: add, edit, delete, nap, quality and tags. Settings: goal and CSV backup. | Source implemented |
| 2: Analysis | Weekday/weekend schedule, confirm forgotten stops, 7/30-day charts, clock averages, variation, goal deficit, weekly summary, tag comparisons. | Source implemented |
| 3: Shortcuts | Start/stop links, Health CSV/JSON import preview, stage records, guarded Health export, alarm recipe, optional daily step comparison. | App source implemented; Shortcuts must be built/tested on your iPhone |
| 4: Extras | Full JSON backup/restore, reminder, appearance; optional last-night WidgetKit extension. | Backup/reminder/theme implemented. Widget source supplied separately, not enabled in baseline project |

Test stage 1 on your phone before enabling stage 3. The optional widget requires a working shared App Group provisioned by your team; it is never a prerequisite for the app or quick tracking. The Shortcuts widget is the baseline quick-access option.

## File structure

```text
SleepLedger/
  .github/workflows/build-ios.yml Hosted Mac: test/build unsigned device IPA
  SleepLedger.xcodeproj/          Open directly in Xcode
  App/
    SleepLedgerApp.swift         Startup + URL/file intake
    Models.swift                 SwiftData entities
    LedgerStore.swift            Mutations, transactions, receipts, reminders
    RootView.swift               Tabs + shared components
    TonightView.swift            Timer + forgotten-stop suggestion
    HistoryView.swift            History, detail, stages, Health export
    SessionEditor.swift          Add/edit/confirm wake time
    TrendsView.swift             Charts, summary, schedules, steps
    SettingsView.swift           Goal, appearance, transfer, reminder
    WidgetPublisher.swift        Dormant optional snapshot publisher
    Info.plist                   URL/document declarations; no Health entitlement
  Core/
    Package.swift                Independently testable Foundation library
    Sources/SleepCore/
      Types.swift                DTOs + validation + ISO dates
      Analysis.swift             Date windows, circular clocks, interval unions
      Transfer.swift             CSV/JSON + Health grouping + duplicate protection
    Tests/SleepCoreTests/         Swift unit tests
  OptionalWidget/                 Optional extension, not in main target
  Scripts/                       Project generation + structural validation
  Examples/                      Synthetic CSV/JSON fixtures
  Docs/
    INSTALL.md                   Direct Xcode free-account setup
    NO_MAC.md                    Cloud build + Ubuntu sideloading
    SHORTCUTS.md                  Read/write recipes + limits
    ARCHITECTURE.md               Rules, calculations, data contract
    WIDGET.md                     Optional widget setup
    TESTING.md                    Phone test checklist
    VALIDATION.md                 What was actually checked here
```

## Install on your iPhone

**No Mac?** Use the included [GitHub Actions + Ubuntu/iloader guide](Docs/NO_MAC.md). The workflow builds an unsigned IPA on a hosted Mac, then you sign/install locally with a free Apple Account. The first cloud build passed. The steps below are the alternative for direct Xcode installation.

1. Copy the entire `SleepLedger` folder to a **Mac**. Use Xcode that supports your phone’s installed iOS version (minimum Xcode 15 for iOS 17, newer devices/OS usually require newer Xcode).
2. Open `SleepLedger.xcodeproj`. Xcode → Settings → Accounts → add your free Apple Account.
3. Select the **SleepLedger target** → Signing & Capabilities → Automatically manage signing → your **Personal Team**. Change `me.hamzabsst.SleepLedger` to a unique identifier, for example `me.yourname.SleepLedger`.
4. Connect and unlock your iPhone, trust the Mac, and select the phone as the run destination.
5. Pair the phone with Xcode, then enable Settings → Privacy & Security → Developer Mode; restart and confirm. Select Product → Run (⌘R). If iOS asks you to trust the developer, use Settings → General → VPN & Device Management.
6. Test Start → close/reopen → Stop → edit quality. Then create the two simple Shortcuts in [SHORTCUTS.md](Docs/SHORTCUTS.md).

**Free signing expires seven days after issuance.** Rebuild with the same bundle ID/team, installing over the existing app, to renew it. Export a JSON backup first. Do not delete the app to renew signing: deletion removes local data. Apple currently documents 3 installed apps per device, 3 registered devices and 10 App IDs for Personal Teams. [Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

A native SwiftUI iOS build needs Xcode on macOS, which can run on GitHub's hosted Mac. Ubuntu can then sign/install the unsigned IPA through iloader; see the no-Mac guide above. Direct Xcode installation on a borrowed Mac is another option. No purchase of an Apple Developer membership is needed for this baseline target. [On-device development](https://developer.apple.com/support/compare-memberships/), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

Full troubleshooting: [INSTALL.md](Docs/INSTALL.md).

## Run checks on the Mac

```sh
cd SleepLedger/Core
swift test
cd ..
xcodebuild -project SleepLedger.xcodeproj -scheme SleepLedger \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Run the app in an iPhone simulator for UI checks; use your real iPhone for Shortcuts/Health, signing, Action Button, reminders and optional widget. A build is not proof that the Health recipes work on your iOS version.

## Honest limits

- A manually tracked interval is reported time, not sensed sleep. Imported in-bed-only records also represent elapsed time in bed. Detailed imported stages use the union of actual sleep-classified intervals for duration.
- No personal stage inference is possible from two timestamps. The optional fixed 55% core / 20% deep / 25% REM display is an **illustration**, not a validated estimate. It is disabled by default, never stored, and never written to Health.
- Health imports are additive snapshots, not live synchronization. Existing records, including manually edited imports, are never overwritten. A richer later import that overlaps a local session is skipped; deliberately replace the local copy only after exporting a backup.
- Health samples can overlap and come from several devices/apps. Import one selected source at a time. Detailed stage conflicts are rejected. The importer groups gaps of at most 90 minutes, so review split nights/naps before accepting.
- Health writing depends on your phone’s Shortcuts sleep action fields. Apple confirms phase reading and generic Health logging; exact picker options require the on-device check in the guide. If your version cannot log a bounded Sleep/In Bed interval, use the app’s CSV/JSON exports and Health’s manual Add Data screen.
- The app has no background sleep detection. A stopped-alarm automation opens a confirmation; an alarm stopping is not proof of waking.
- The baseline target uses no capabilities requiring a Health entitlement. Optional widget signing is a separate on-device capability check, with the Shortcuts widget as the usable fallback.
