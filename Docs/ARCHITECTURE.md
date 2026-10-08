# Architecture and data rules

## Layers

`SwiftUI views → MainActor LedgerStore → SwiftData ModelContext`

`Foundation SleepCore ← views/store → Shortcuts via URL or user-selected file`

The app uses only Apple frameworks. Core source is compiled directly into the app target; `Core/Package.swift` also builds it as an independent test library. No remote Swift package resolution is needed.

SwiftData persists three small entity types:

- `SessionEntity`: unique UUID and version-1 Codable payload containing start/end, original provenance, source, imported stage intervals, nap, optional 1–5 rating, tags, original timezone and edited flag.
- `StepsEntity`: unique timestamp/source key and a daily step-total payload. Multiple source totals on the same local calendar day are rejected during import, rather than added together.
- `WriteReceipt`: interval-specific request key, random callback token, and `pending`/`reportedComplete` state for Health transfers. These are device-local coordination metadata, not proof from Health.

Settings are a small versioned Codable object in local UserDefaults and are included in JSON backups. The SwiftData configuration explicitly disables CloudKit. The code never creates a HealthKit store or requests a Health entitlement.

Session payloads are stored as Data to keep the first schema small and make a versioned interchange format independent of SwiftData. A future schema update needs explicit payload/schema migration; never delete the database on a decoding error. Startup errors show a recovery screen and leave files intact.

## Tracking

Start writes a persistent session with `end = nil`; a second Start is idempotent. The elapsed display derives from start and current time and does not run a background timer. At most one active session exists. Stop records a user-reported wake time; Shortcut/alarm stops open an editor. Cancellation leaves the active session untouched.

A completed interval must be positive, no longer than 48 hours, and not in the future. Overlapping local sessions are rejected to prevent double counting. An open session reserves its interval through the future; resolve it before adding a new overlapping record. You can delete an accidental active session through History.

An accepted suggested wake time is labeled Estimated. Editing imported or estimated records retains that provenance and sets `edited`; imported samples never overwrite local records. If you change an imported record’s endpoints, you must explicitly acknowledge removal of its now-mismatched stage data. Editing tags/quality alone preserves stages.

## Analysis definitions

- **Manual / in-bed duration:** elapsed seconds between reported endpoints. Not measured sleep.
- **Detailed stage duration:** union of core/deep/REM intervals. Unspecified-asleep summaries are ignored for this total when detailed stages exist. Awake is excluded; in-bed summaries are excluded. If only unspecified-asleep intervals exist, use their union; if only in-bed intervals exist, use elapsed interval as an explicitly labeled proxy.
- **Wake date:** all duration attributed to the local calendar day containing the end timestamp. Naps count toward that day’s total. A long session spanning more than one day is still assigned to its wake date; it is not split across dates.
- **7/30-day window:** today and the preceding 6/29 calendar dates. Unknown dates are omitted, never counted as zero sleep.
- **Average:** mean of total duration on observed wake dates. The chart marks only observed dates, so missing nights are gaps.
- **Goal deficit (“sleep debt”):** sum of `max(goal - observed daily hours, 0)` over observed dates. Longer nights do not cancel deficits; missing dates contribute nothing. This is not a physiological model of sleep debt.
- **Main night:** longest non-nap session per wake date. This defines clock averages, schedule, variation, and best/worst-night comparisons. Unmarked daytime sleep is treated as a main night until you mark it as a nap.
- **Average bedtime/wake:** circular clock mean, so 23:50 and 00:10 average to midnight. Very dispersed times have no reliable circular mean.
- **Consistency:** circular RMS deviation from mean bedtime, in minutes, requiring two main nights. Smaller means more consistent timing; it is not a health score.
- **Schedule learning:** last 60 calendar days, main nights, excluding Estimated. Separate system-calendar weekday/weekend buckets, categorized by wake date. Minimum three nights per bucket. Imported records can participate; naps cannot.
- **Forgotten stop:** look for the earliest learned wake time after start, already in the past, 2–16 elapsed hours after start. The UI requires explicit confirmation. No automatic save or notification claims.
- **Weekly comparison:** current seven-day logged-date average versus the preceding seven dates; sample counts are displayed.
- **Tag insight:** difference in mean reported quality for tagged versus untagged non-nap sessions, requiring at least three in each group. Uses all available rated history. No causal claim, significance test or correction for confounding.
- **Steps comparison:** previous local calendar day’s selected-source daily total paired with the main session’s duration on the following wake date. The scatter plot is descriptive. It does not reproduce Health’s multi-device reconciliation.

Durations use actual elapsed seconds, including daylight-saving transitions. Charts/schedule use the current device timezone; each session retains its capture timezone ID for auditing/export. Travel can change the displayed wake-date grouping. A future travel-aware analysis can group per-record timezone explicitly.

## Health import

The raw Health CSV format has exactly:

```csv
kind,start,end,source,value
sleep,2026-10-06T23:00:00+01:00,2026-10-07T07:00:00+01:00,My Watch,asleep
steps,2026-10-06T00:00:00+01:00,2026-10-07T00:00:00+01:00,My iPhone,8200
```

Sleep values: `inBed`, `awake`, `asleep`, `core`, `deep`, `rem`. Source is selected in Shortcuts; mixing sleep sources in one batch is rejected. Exact raw rows are deduplicated. Intervals within 90 minutes are grouped, clipped to sleep endpoints (or in-bed endpoints if no sleep classification exists), and labeled Imported. Awake-only groups do not become sleep sessions. Naps are not inferred: mark them after import. Records with overlapping contradictory detailed stages are rejected as an entire invalid batch.

Different nights can accidentally group if they have unusually small gaps or bridging in-bed samples. Split the CSV into one-night files if needed. Samples crossing the queried date boundary can be incomplete; query a margin around the target nights and verify first/last imported nights.

Importer safety is intentionally conservative: same UUID, external ID/source, or exact endpoints → duplicate; any interval overlap → conflict. Both are skipped. Local records are never modified. The preview shows existing conflicts; final import also checks conflicts within the batch. It is an additive restore, not a destructive replacement.

## Interchange

Full JSON uses `version`, `sessions`, `steps`, optional `settings`. Dates use ISO 8601 with explicit timezone. Exports normalize to UTC at whole-second precision. IDs/source/provenance are preserved. See `Examples/backup.json`.

Canonical session CSV preserves all session fields, including escaped JSON columns for tags and stages, and round-trips through the app. It does not include steps/settings. Exact column order is required; use the supplied header. CSV parser supports quoted commas, doubled quotes and embedded newlines. Opening untrusted CSV in a spreadsheet may interpret formula-like tag/source strings; use the JSON backup for archival.

Input limits: UTF-8, 8 MB files, 300 KB URL payload, at most 10,000 sessions and 10,000 step days, 3,000 stage intervals per session. Invalid version/data rejects the full batch before any insert. JSON backups preserve provenance as supplied by the user; labels are not cryptographic evidence of origin.

## Health write coordination

Only completed Manual records without stages can be sent, as **In Bed**. Before invoking `shortcuts://run-shortcut`, the app saves a pending receipt with a unique token. The Shortcut must inspect existing Health samples, ask the user, log once, then call `sleepledger://health-written?token=...`. That callback changes only the matching receipt. Cancellation/error leaves it pending; checking Health is necessary before retrying. Completed intervals cannot be resent through the same receipt.

The Shortcut must not use a generic success callback as evidence that a sample was written. No automatic deletion or update of Health samples is attempted. The guide requires an overlap check; edits to a previously exported record do not edit Health. Manually reconcile old Health intervals before exporting a changed interval.

Receipts are omitted from backups because they are local transfer state. After reinstall/restore, the Shortcut’s Health-side duplicate/overlap check remains essential. Custom URL schemes are a local convenience and can be invoked by other apps; imports always require review. Callback tokens are random but not a signed attestation from Health.

## Privacy and failure behavior

No network code or telemetry. App sandbox/OS data protection apply; the app does not add a separate encryption key/password. OS/device backups may include app data according to the user’s backup settings. Exports are user-initiated plaintext documents protected by the OS while local; sharing them moves that copy outside the sandbox.

Save failures show an error and roll back unsaved SwiftData changes. Storage-open errors do not reset the journal. The optional widget reads only a small summary snapshot, not the database. Live widget refresh timing is controlled by iOS.
