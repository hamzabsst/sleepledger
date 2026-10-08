# Shortcuts bridge: capabilities, limits and recipes

The iPhone app has **no HealthKit entitlement**. Shortcuts is the only component that reads or writes Health. Build these recipes on the iPhone; Mac Shortcuts may show synced Health actions without supporting their full configuration.

## What is established, and what you must check

| Data/action | Supported route | Limit |
|---|---|---|
| Read basic sleep intervals | Find Health Samples, Type **Sleep** (may be labeled Sleep Analysis on some versions), Get Details → Start Date / End Date / Value | Requires existing Health records and permission. Manual tracking in this app does not automatically populate Health. |
| Read core/deep/REM | Apple explicitly added sleep-phase results to Find Health Samples in iOS 16.2 | Only when the Health store contains stages; some sources supply only in-bed/asleep intervals. |
| Write a basic interval | Log Health Sample with a supported Sleep category, start and end dates, **In Bed** value | The exact sleep value/date fields must be inspected on your iOS version. This project has not run them on a phone. Do not assume that every readable category is writable or that stage writing is supported. |
| Write manual physiological stages | Not used | We do not fabricate stages or send illustrative proportions to Health. |
| Read steps | Find Health Samples → Steps, one chosen source, daily sum | Raw totals are not necessarily Health’s reconciled multi-device total. |
| Update/delete a previously logged Health interval | No app-side route | Edit/delete it yourself in Health. The local edit does not propagate. |
| Read sample UUID or source reliably | Do not rely on it | Source details/filter availability differ by version/data type. If unavailable, explicitly identify and query a single known source; do not merge all sources. |
| Background/locked-phone operation | Not guaranteed | Health privacy, confirmation and Open URLs can require unlocking. |

Apple sources: [sleep-phase reading](https://support.apple.com/en-za/101583), [iOS 17 Health Sample enhancements](https://support.apple.com/en-au/111098), [Log Health Sample action](https://support.apple.com/en-az/guide/shortcuts/apdaf74d75a5/ios), [run-shortcut URL parameters](https://support.apple.com/en-au/guide/shortcuts/apd624386f42/ios). Health distinguishes in-bed intervals and asleep/stage intervals; overlapping summaries should not be summed. [Sleep category semantics](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis).

Apple’s public guide does not enumerate every current sleep-writing picker combination. The check below is mandatory for this recipe, not a claim that the action has been tested here. If your installed action cannot represent a bounded In Bed sleep interval, stop configuring the write recipe and use CSV/JSON/manual Health entry. All manual tracking remains available.

## 0. Check the actions without writing test data

1. Shortcuts → `+` → add **Find Health Samples**. Set Type to **Sleep**. Choose a range containing a night already visible in Health. Use **Start Date in the last 3 days**, sort Start Date ascending, Limit off.
2. Run it with **Quick Look** to inspect output. Approve the requested read access in Shortcuts/Health. If empty, check dates, phone unlock state, existing data and permissions. A healthy person without Watch/tracker records may have no stages; that is expected.
3. Add **Repeat with Each** sample; inside it add **Get Details of Health Sample** for **Value**, **Start Date**, **End Date**, and **Source**, followed by Text and Quick Look. Note the *actual* Value strings on your phone. They may be localized; do not infer them from screenshots online.
4. Remove the debug loop after noting the labels. Select one source (your Watch or your chosen tracker) in the Find filter if offered. If Source is blank/unavailable, use a known single-source dataset and the source fallback described below. If you cannot isolate a source safely, export/review one source manually rather than guessing.
5. Separately add **Log Health Sample**, inspect its Type picker for **Sleep** / **Sleep Analysis**, its category/value choices, and expandable start/end fields. **Do not run this action while testing its UI.** Confirm it can express an In Bed category with your requested Start and End dates.
6. If the fields are missing, do not substitute a quantity/minutes value or select a random category. Use local exports and Health → Sleep → Add Data if available. Update iOS and recheck later if desired.

Permissions belong to Shortcuts. If access was denied, inspect Health → profile → Apps/Apps and Services → Shortcuts (names vary) and the Shortcut’s Privacy settings. The app cannot request or repair Health permission itself. No records may mean no permission or no matching data; it does not establish either by itself.

## 1. Start SleepLedger

1. Shortcuts → `+`; name it **Start SleepLedger**.
2. Add **URL**: `sleepledger://start`.
3. Add **Open URLs**, with that URL as input.
4. Run with the app installed and signed. It opens the app and starts one local session. Running it again leaves the active session unchanged.

## 2. Stop SleepLedger

1. Create **Stop SleepLedger**.
2. Add **URL**: `sleepledger://stop`.
3. Add **Open URLs**.
4. Run it while tracking. Review the wake time and tap Save. Cancellation keeps the session active. A repeat run with no active session changes nothing.

For quick access, open the Shortcut details/menu → **Add to Home Screen**. Or add the Apple **Shortcuts widget** and select a folder containing these two Shortcuts. On supported iPhones use Settings → Action Button → Shortcut → choose the appropriate Shortcut. This is quick access, not guaranteed execution while the phone is locked.

## 3. Read Health sleep into the app (CSV, recommended)

Name: **SleepLedger Read Health**. Start with a 3-day range; after it works, expand to 7 or 30 days. Import whole nights and review query-boundary nights.

### Build the query

1. Add **Find Health Samples** → Type **Sleep**; Start Date **is in the last 3 days**; sort **Start Date**, oldest first; Limit **off**.
2. Add Source filter for **one source** if available. Do not query all Watch + iPhone + third-party sleep records and sum them.
3. Add **Text** containing only `kind,start,end,source,value`. Add **Set Variable** → name **Rows** → this Text.
4. Add **Repeat with Each** over the **Health Samples** from step 1 (explicitly select that magic variable, not the Text header).

### Inside Repeat

5. **Get Details of Health Sample** → Start Date from **Repeat Item**. **Format Date** that result with custom `yyyy-MM-dd'T'HH:mm:ssXXX`. Set variable **StartISO**. The timezone suffix is required.
6. Repeat for End Date → **EndISO** using the same format.
7. Get Details → Value from **Repeat Item** → variable **RawStage**.
8. Add a **Dictionary** mapping the exact Value labels you observed in check 0 to the canonical strings:

   | Observed meaning (use your actual label as key) | Dictionary value |
   |---|---|
   | In Bed | `inBed` |
   | Asleep / Asleep Unspecified | `asleep` |
   | Awake | `awake` |
   | Core / Asleep Core | `core` |
   | Deep / Asleep Deep | `deep` |
   | REM / Asleep REM | `rem` |

   Add **Get Dictionary Value** with key **RawStage** and this dictionary → **Stage**. If Stage has no value, Show Alert including RawStage and **Stop This Shortcut**. Do not map an unknown stage to asleep. Do not assume numeric HealthKit enum values are what Shortcuts returns.
9. Get Details → Source from Repeat Item → **SourceText**. If the action returns no source, use a Text action with the name of the one source you have independently isolated, e.g. `My Watch`. This is a user-supplied label, not a recovered source identifier. If you have several indistinguishable sources, stop and isolate/export them manually.
10. Escape SourceText for CSV: **Replace Text**, find `"`, replace with `""`, regular expression **off** → **EscapedSource**.
11. Add **Text** with the following line. Replace each bracketed placeholder by its magic variable; retain the literal quotation marks:

    ```text
    "sleep","[StartISO]","[EndISO]","[EscapedSource]","[Stage]"
    ```

12. **Add to Variable** → **Rows**, using that Text line. End Repeat.

### After Repeat: file route

13. **Combine Text** → **Rows**, separator **New Lines**.
14. **Set Name** → `SleepLedger-health.csv`.
15. **Save File**, Ask Where to Save **on**, choose a location in Files. Use the app → Settings → Choose JSON or CSV file → select it.
16. The app shows a preview. Check source, first/last night, duration, stage labels, any overlap warning. Tap Import. Naps are not automatically identified: mark them in History afterward.
17. Run and import the same file again. Added sessions should be zero; duplicates should be reported.

### Smaller-batch URL route (optional alternative to steps 14–15)

14. **URL Encode** the Combined Text (encode exactly once) → **EncodedPayload**.
15. Text: `sleepledger://import?payload=[EncodedPayload]` using the magic variable.
16. **URL** using that Text → **Open URLs**. Review the import in the app.

Use files for large histories. The app limits decoded URL payloads to 300 KB, and iOS/Shortcuts may impose a smaller practical limit. Do not send local sleep data to a web URL/encoding website. No clipboard access happens silently; for a clipboard fallback, Copy to Clipboard in Shortcuts, then tap the app’s Paste button and Preview.

### Import behavior to expect

- Identical raw intervals are collapsed. Nearby stage samples from one source group into a session (gap ≤90 min).
- In-bed/asleep summaries can overlap detailed stages. Main duration prefers core/deep/REM union when present; the detail view labels summary totals separately.
- Awake-only data does not become a sleep session. In-bed-only data remains an interval proxy.
- Contradictory overlapping detailed stages or mixed sources reject the batch with a reason. Split the file or choose a source; do not add all durations together.
- Local manual data always wins by preservation: overlapping imported sessions are skipped, not merged into it. To import stages for an already-manual night, export a backup, inspect the Health copy, then explicitly remove the local conflicting record and import. Ratings/tags must then be transferred manually.
- Later Health changes do not automatically update local imports. To replace one intentionally, export a backup and remove the old local copy first.

## 4. Write a manual interval to Health

Name must be exactly **SleepLedger Write Health**, because the app calls it by name. The app passes JSON text in **Shortcut Input**:

```json
{"id":"a-session-uuid","start":"2026-10-06T23:00:00Z","end":"2026-10-07T07:00:00Z","value":"inBed","token":"a-request-uuid"}
```

The intended record is **In Bed**, not measured asleep time. Do not change it to Deep/REM or automatically log illustrative stage estimates.

1. Complete check 0 first. If your sleep logging fields cannot express this interval, use the fallback and do not run the write recipe.
2. Add **Get Dictionary from Input** using **Shortcut Input**. Explicitly set this dictionary as the input for every following Get Dictionary Value action.
3. Extract keys `id`, `start`, `end`, `value`, `token` into separate named variables. If any is missing, or `value` is not `inBed`, Show Alert and **Stop This Shortcut**.
4. Convert `start` and `end` separately with **Get Dates from Input** (or the Date action’s specified-date field if your version accepts the ISO string). Set **StartDate** and **EndDate**. Require one date from each and EndDate after StartDate. Reject future dates and intervals longer than 48 hours, matching the app’s policy.
5. **Find Health Samples** → Type Sleep, Start Date within the last 3 days **relative to StartDate** by first computing StartDate minus 2 days and EndDate plus 1 day using Adjust Date. Use an explicit **Start Date is between QueryStart and QueryEnd**, not “today.” Limit off. This range catches typical ≤48h overlapping intervals; check unusually long Health intervals manually.
6. Initialize Number `0` → variable **HasOverlap**; Repeat with Each returned sample. Get its Start Date and End Date. With nested **If** actions test `SampleStart < EndDate` and `SampleEnd > StartDate`. Set HasOverlap to `1` if both are true. This intentionally blocks any overlapping sleep sample from any source, including stages, rather than duplicating Watch data with another manual interval.
7. After Repeat, If HasOverlap is `1`, Show Alert: “Health already has overlapping sleep data. Inspect it before adding another interval.” Then **Stop This Shortcut**. Leave the app’s receipt pending. The user can retain the existing Health record; no automatic replacement occurs.
8. **Show Alert** with title “Add In Bed interval to Apple Health?” and message containing the formatted StartDate and EndDate. **Show Cancel Button on**. Continue only after the user confirms.
9. **Log Health Sample** → supported Sleep/Sleep Analysis type → **In Bed** value → Start Date **StartDate**, End Date **EndDate**. Expand the action options. If the UI has an ambiguous duration/unit field instead of category + endpoints, stop and use the fallback; do not log a quantity as sleep.
10. Only after Log Health Sample completes successfully, add Text: `sleepledger://health-written?token=[token]`. Insert the token magic variable; it is an ASCII UUID. **URL** → **Open URLs**.
11. In the app, open a completed **Manual** session → Send interval to Health. Confirm the Shortcut prompt. Check Health → Sleep → Show All Data for the correct **In Bed** record and bounds. The app can only report the Shortcut’s completion callback, not independently inspect Health.

If permission is denied, the user cancels, the Shortcut name is wrong, or it stops mid-run, the receipt remains pending. Check Health first. Only if there is no matching record, use History → session → **I checked Health: no matching record** to clear the pending receipt, then retry. Never put the callback in an unconditional error/finally branch.

An interrupted Shortcut may have written successfully before the callback. That is why both the pending receipt and Health overlap check exist. A second instance of this app/Shortcut can still race; do not run parallel writes. A restore does not include receipts; the Health-side overlap check remains the safeguard.

Local edits/deletions do not update/delete Health. If a previously exported interval is wrong, correct its Health record manually before exporting the local correction. Apple Health contains the original record under **Shortcuts**, not SleepLedger’s bundle identifier.

## 5. Optional stopped-alarm automation

1. Create **SleepLedger Alarm Wake**: URL `sleepledger://suggest-stop` → Open URLs.
2. Shortcuts → Automation → `+` → **Alarm** → **Is Stopped**. Select your wake-up alarm, not every timer/alarm. If a specific wake-up option is available, use it.
3. Choose **Run Immediately** if offered. Add **Run Shortcut** → SleepLedger Alarm Wake. On older versions use the available confirmation setting.
4. On a test morning, stop the alarm and unlock if requested. The app opens a proposed wake time with an **Estimated** label. Adjust/cancel/save explicitly. No active session means nothing changes.
5. Snoozing/stopping an alarm does not establish you actually woke. Do not automatically write Health or finalize sleep from the trigger.

Alternative: use the Sleep → Waking Up trigger if your version exposes it and it matches your routine. It still opens review.

## 6. Optional daily steps import

Name: **SleepLedger Read Steps**. Use a **completed day**, initially yesterday.

1. Current Date → Adjust Date minus 1 day → Get Start of Day (or a Date calculation that yields local midnight) → **DayStart**. Adjust DayStart plus 1 calendar day → **DayEnd**.
2. Find Health Samples → **Steps** → Start Date between DayStart and DayEnd, source **one chosen iPhone/Watch source**, Limit off. Samples exactly at DayEnd belong to the next day: in the loop require `SampleStart < DayEnd`. Only include intervals fully inside this day, or inspect boundary-crossing samples separately.
3. Repeat with Each sample: Get Details → Start Date / End Date / Value. Retain only `SampleStart >= DayStart`, `SampleStart < DayEnd`, and `SampleEnd <= DayEnd`; accumulate each retained Value in a **StepValues** variable. Values must be counts, not durations or distances.
4. Calculate Statistics → **Sum** of StepValues; Round Number to ones → **TotalSteps**. If the query has no samples, show “No steps found” and stop; do not create a zero total because permissions/data may be absent.
5. Format DayStart and DayEnd with `yyyy-MM-dd'T'HH:mm:ssXXX`. Use the CSV quote-escaping rule for the chosen source label.
6. Text with two lines:

   ```text
   kind,start,end,source,value
   "steps","[DayStartISO]","[DayEndISO]","[EscapedSource]","[TotalSteps]"
   ```

7. Set Name → `SleepLedger-steps.csv` → Save File. Import via the app’s file picker. In Trends enable Compare imported daily steps.
8. Repeat for other days with a Repeat loop if desired. Existing local dates are skipped rather than updated; delete/replace through a future dedicated step editor if needed, or restore a curated backup into a fresh install after exporting. This version does not provide a step-day editor.

A raw sum from several devices can double-count. This recipe deliberately chooses one source and omits day-boundary-crossing samples; it may differ from Health’s reconciled daily number. If source isolation is not available, enter a verified Health daily total in the provided JSON example instead of pretending to reproduce Health’s total.

## CSV / JSON fallback

- App Settings → Prepare sessions CSV / Prepare full JSON backup → Share → Save to Files.
- App Settings → Choose JSON or CSV file, or Paste → Preview pasted data → review → Import.
- `Examples/health-samples.csv` demonstrates canonical stage mapping. `Examples/backup.json` includes full fields and a daily step total.
- For manual Health entry: Health → Browse/Search → Sleep → Add Data, if available, choose In Bed and enter your reported bounds. No app callback is expected.

The project does not include a signed `.shortcut` download or an iCloud sharing link. These are reproducible on-device action recipes; the actual installed fields, permissions and real Health writes remain your on-phone verification steps.
