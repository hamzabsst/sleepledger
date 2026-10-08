# Optional last-night home-screen widget

The baseline project deliberately contains **one app target with no App Group entitlement**. Start/stop quick access already works through Apple’s Shortcuts widget and Action Button. This separate WidgetKit source is a later stage; it has not been compiled/signed on this workspace.

A live data widget must access a small summary outside the app’s private container. Apple’s supported approach is a shared App Group. Account provisioning availability must be checked in Xcode for your actual Personal Team; this project does not promise that every free team can provision it. Do not pay just to run the baseline app. [Supported capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios), [App Group setup](https://developer.apple.com/documentation/xcode/configuring-app-groups).

## Enable only after the MVP works

1. Back up the project folder and export your journal JSON.
2. In Xcode: File → New → Target → **Widget Extension** → product name **SleepLedgerWidget**. Uncheck Include Configuration Intent (use a static widget). Do not include a Live Activity. Deployment target iOS 17+.
3. Let Xcode embed the extension in SleepLedger. Choose your Personal Team for both targets and a unique extension bundle ID under the app ID, such as `me.yourname.SleepLedger.widget`.
4. Remove the generated widget Swift files from the extension target. Add `OptionalWidget/SleepLedgerWidget.swift` to the **widget extension only**. It already contains the extension’s `@main`; do not compile it into the app target.
5. Keep `App/WidgetPublisher.swift` in the **app target only**. Do not add app/model/core source files to the widget target.
6. For both targets, Signing & Capabilities → `+ Capability` → **App Groups** → create/select one unique group, for example `group.me.yourname.SleepLedger`. Both targets must select the exact same group.
7. In `App/Info.plist`, add a String key **SleepLedgerAppGroup** with that group ID.
8. In the widget target’s Info settings add the same String key and value. Keep the normal Xcode-generated `NSExtension` → `NSExtensionPointIdentifier = com.apple.widgetkit-extension` entry.
9. Build for your actual iPhone. If Xcode cannot provision App Groups with this Personal Team, undo steps 2–8 or restore the baseline project. Continue using the Shortcuts widget. Do not add HealthKit to solve widget signing.
10. Run the main app once after configuration; it publishes a small `last-night.json` snapshot into the shared container. Add the SleepLedger widget from the iPhone widget gallery. Save/edit/delete a session and confirm it eventually refreshes.

The summary shows the **most recent completed non-nap night**, its wake date and provenance, so an old night is not mislabeled as yesterday. The widget does not write the database, run a timer, request Health access or detect sleep. iOS controls refresh timing. Tapping opens the app. The view is marked privacy-sensitive so the OS can redact it on relevant surfaces.

The shared cache is protected until first unlock. No cache is created at all unless the group ID is configured and its container exists. Rebuilding the main app without the widget does not migrate/change its SwiftData database.

Do not rerun `Scripts/generate_project.py` after manually configuring the extension: the generator intentionally restores the one-target baseline. Save your Xcode project configuration separately.
