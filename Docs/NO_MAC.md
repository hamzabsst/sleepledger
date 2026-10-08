# Run on your iPhone from Ubuntu, without owning a Mac

You need a macOS/Xcode environment to **compile** this SwiftUI app, but you do not need to own or borrow a Mac. The practical route is:

**GitHub-hosted Mac builds unsigned IPA → download to Ubuntu → iloader signs and installs using your free Apple Account.**

GitHub provides standard macOS runners; public-repository standard runner use is free. Private repositories use your account's included minutes and may incur charges after that allowance. [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

iloader is a third-party sideloading tool whose official project supports Linux and importing arbitrary IPA files. [Official iloader repository](https://github.com/nab138/iloader), [Linux prerequisites](https://docs.sidestore.io/docs/installation/prerequisites).

No Apple credentials or signing certificate go into GitHub. You sign in yourself in iloader on your computer. The compiled IPA is not installable until locally signed.

**Status:** [build #1](https://github.com/hamzabsst/sleepledger/actions/runs/37816137251) passed on 8 October 2026 at source commit `50588228007e69c4c6bb069b7ba74ecd1aa65c62`. All 10 core tests passed; Xcode 16.4 / iPhoneOS 18.5 SDK compiled the arm64 iPhone Release app and packaged the unsigned IPA. GitHub artifacts expire after seven days; run the workflow again if needed. Phone signing and installation remain untested.

## 1. Put the project in a GitHub repository

1. Extract the updated `SleepLedger-source.zip` on Ubuntu.
2. Create a GitHub repository. Choose public only if you want the source public and unlimited standard runner usage; otherwise choose private and check your Actions allowance/budget.
3. Put the **contents of the SleepLedger folder at the repository root**. The root must contain:

   ```text
   .github/workflows/build-ios.yml
   SleepLedger.xcodeproj/
   App/
   Core/
   Scripts/
   Examples/
   Docs/
   README.md
   ```

   Do not nest these inside another `SleepLedger/` folder. `.github` is hidden on Linux; Ctrl+H reveals it in Files. Merely uploading the ZIP will not activate the workflow: GitHub needs its extracted files.
4. Use your normal Git workflow to commit/push the project, or GitHub's file uploader. Ensure `.github/workflows/build-ios.yml` is actually present on the default branch. Keep real sleep exports and Apple credentials out of the repository; the supplied Examples are synthetic.

## 2. Run the cloud build

1. In the repository, open **Actions**.
2. If prompted, enable Actions for this repository.
3. Select **Build iPhone IPA** → **Run workflow** → choose the default branch → Run.
4. Wait for the run. It validates the project, runs the Foundation unit tests, compiles a **device** app using Xcode with signing disabled, and packages `Payload/SleepLedger.app` as an IPA.
5. Open the completed run → **Artifacts** → download **SleepLedger-unsigned**.
6. Extract the downloaded artifact ZIP on Ubuntu. The file you need is **SleepLedger-unsigned.ipa**, not the outer ZIP and not `SleepLedger-source.zip`.
7. If the run fails, open the failed step or download **SleepLedger-build-logs** and inspect/share the first real compiler/test error. A failed run has no usable IPA. Do not switch to a simulator build: simulator binaries cannot run on the phone.

The workflow is manual-only and does not publish a release or use Apple credentials. It builds the baseline app without the optional WidgetKit extension or HealthKit entitlement. No App Store or TestFlight is involved.

## 3. Install iloader on Ubuntu

1. Download iloader **only** from [its official releases](https://github.com/nab138/iloader/releases) or the official site linked by its repository.
2. Select the Linux **DEB** matching your computer. `uname -m` shows `x86_64` on Intel/AMD (choose amd64) or `aarch64` (choose arm64/aarch64). Use the actual release asset name; names may change.
3. Install `usbmuxd` if it is not already available. On Ubuntu, from your own terminal:

   ```sh
   sudo apt update
   sudo apt install usbmuxd
   ```

4. Install the downloaded DEB through Ubuntu's software installer, or `sudo apt install ./actual-downloaded-filename.deb` from its directory. Enter passwords yourself. Alternatively use the official AppImage, following the project's Linux instructions.
5. Launch iloader. Connect your unlocked iPhone with a data-capable USB cable. Tap **Trust This Computer** and enter your phone passcode yourself.

## 4. Sign and install SleepLedger

1. In iloader, select your connected iPhone and sign in with your free Apple Account. Complete Apple verification yourself. Do not send your password/2FA code to this chat, and do not put it in GitHub secrets for this workflow.
2. Choose iloader's **Import IPA** action and select **SleepLedger-unsigned.ipa**. Exact menu wording can change; the project's supported feature is importing any IPA.
3. Let iloader sign and install it. This creates/uses free development provisioning; the project has no paid Health capability to request.
4. On the phone, if prompted, use **Settings → General → VPN & Device Management → Developer App → your Apple Account → Trust**.
5. Enable **Settings → Privacy & Security → Developer Mode** if required. Restart and confirm. It may appear after development-app installation/pairing. [Apple Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
6. Open SleepLedger. Test Start → background/reopen → Stop before using real overnight data. Then create the Start/Stop and Health Shortcuts from [SHORTCUTS.md](SHORTCUTS.md).

Third-party sideloading can fail when Apple changes authentication/provisioning behavior or a tool has not caught up with your iOS version. Use the official project's current troubleshooting/error information; this guide is not evidence that your specific device/account has successfully installed it.

## 5. Keep it working

Free development provisioning expires after seven days. Before expiry, reconnect the phone and re-sign/reinstall the same IPA with iloader. You do **not** need a new cloud build each week unless the source changes. Keep the same Apple Account and app bundle identity so the install updates the existing app. Export JSON backups; do not delete the app for routine renewal. [Apple's free-account limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

Optional later: install SideStore through iloader and follow [SideStore's installation guide](https://docs.sidestore.io/docs/installation/install) for on-phone refresh setup. SideStore has its own pairing/network prerequisites; it is not needed for the initial direct IPA install. The simplest starting point is iloader over USB once a week.

This route keeps SwiftUI + SwiftData, your local journal and Shortcuts-only Health access. It does not require rewriting the app as a website or purchasing an Apple Developer membership.
