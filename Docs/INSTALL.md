# Free Apple Account installation

This page covers direct Xcode installation. If you have no Mac, use [GitHub Actions + Ubuntu/iloader](NO_MAC.md) instead; a hosted Mac compiles the app and Linux handles local signing/installation.

## What you need

- An iPhone running iOS 17 or later. SwiftData is the reason for the iOS 17 minimum.
- A Mac with Xcode and a matching iPhoneOS SDK. Use the latest stable Xcode compatible with the phone’s OS and your macOS version. No command-line dependency manager is needed.
- Your free Apple Account, a USB cable for initial pairing, and Internet access on the Mac for Apple’s signing service.

This workspace is Linux. Native iOS compilation needs Xcode on macOS, locally or in the cloud. Xcode signing is one route; third-party iloader supports local signing/installation on Linux. The no-Mac guide explains that alternative.

## Exact steps

1. Transfer the **whole folder**, including `App`, `Core`, `SleepLedger.xcodeproj`, and `Docs`, to the Mac. Do not copy just the `.xcodeproj` file.
2. Install Xcode from Apple/Mac App Store. Launch it, accept its license and install the iOS platform support it requests.
3. Double-click `SleepLedger.xcodeproj`. The generated project is already checked in as files; you do not need to run the Python generator.
4. Xcode → Settings → Accounts → `+` → Apple Account. Sign in yourself. Select your Personal Team.
5. In the project navigator, click the project, select TARGETS → **SleepLedger** → Signing & Capabilities. Check **Automatically manage signing**, choose your Personal Team.
6. Replace the Bundle Identifier with a unique reverse-domain string, such as `me.hamza.sleepjournal.personal`. Use the same identifier for all later reinstalls.
7. Leave the baseline capabilities empty. Do not add HealthKit, CloudKit, iCloud, push notifications, or App Groups to get the base app running. Local notifications need runtime permission, not a push capability.
8. Plug in and unlock the iPhone. Tap Trust This Computer and enter the passcode yourself. In Xcode select the phone from the run-destination menu. If needed, use Window → Devices and Simulators, or newer Xcode’s Device Hub, to finish pairing.
9. Enable **Settings → Privacy & Security → Developer Mode** on the iPhone. It may only appear after pairing starts. Restart, then confirm Turn On/Enable and enter the passcode. [Apple instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
10. In Xcode select scheme **SleepLedger**, destination **your iPhone**, and press **⌘R**. Let Xcode create the free signing certificate/profile.
11. If iOS shows an Untrusted Developer message, open Settings → General → VPN & Device Management, select your developer identity, and trust it. This screen may be absent if no trust step is required.
12. Open the app. Start a session, return to the Home Screen, reopen it, and confirm that the interval is still running. Stop it and add quality/tags in History.
13. Disconnect the cable. The app runs locally while its provisioning profile remains valid. Tracking does not need the Mac or a network connection.

## Every seven days

Personal Team profiles expire seven days from issuance. Connect the iPhone, select the same target, bundle ID and Personal Team, and press ⌘R again. Installing over the existing app normally preserves its data container. Keep a JSON backup because signing/account changes or deleting the app can invalidate that assumption.

Do not delete the app as the first troubleshooting step. If it has already expired and cannot launch, try the same-ID reinstall first, then export a backup. Apple documents the signing lifetime and free limits in [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Common problems

| Problem | Action |
|---|---|
| Signing requires a development team | Select the **target**, not just the project, and choose Personal Team. |
| Bundle identifier is unavailable | Change it to a unique identifier; do not keep changing it after you start storing real nights. |
| Failed to create provisioning profile | Confirm Apple Account sign-in and Internet access; remove accidentally added capabilities; inspect Xcode’s actual error. |
| Too many apps/devices/App IDs | Free account limits apply. Remove another development app if appropriate or wait for registrations to expire. A widget may use an additional App ID. |
| Developer Mode is missing | Pair the phone with Xcode first; check Privacy & Security afterward. |
| Device support / OS version mismatch | Update Xcode/macOS as needed to support your phone’s OS. Raising the deployment target alone does not add SDK support. |
| No such module SwiftData | Use Xcode 15+ with an iOS 17+ SDK. |
| App stops opening after a week | Renew signing with ⌘R over the same app. |
| Shortcut cannot open app | Confirm the app launches directly and signing has not expired. Use the exact `sleepledger://` URLs from the guide. |
| Health actions have no records | Unlock phone, check Shortcuts Health permissions, confirm source/date filters and existing Health sleep records. |
| Optional widget fails signing | Remove the optional target from the app’s build/embed dependencies, or use the original baseline project. Use the Shortcuts widget. No paid account is required to keep manual tracking working. |

## If the project file is accidentally removed

From a Mac terminal with Python 3 installed:

```sh
cd SleepLedger
python3 Scripts/generate_project.py
open SleepLedger.xcodeproj
```

Regeneration resets project signing customization and target membership to the baseline. Do not run it after manually configuring the optional widget unless you intend to discard that project configuration.
