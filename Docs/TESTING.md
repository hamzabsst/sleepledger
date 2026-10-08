# What to test on your phone

Run these stages in order. Use synthetic data before recording real nights. The supplied examples are deliberately dated synthetic records, not your personal sleep history.

## Stage 1: tracking and persistence

- [ ] Install with Personal Team and launch disconnected from the Mac.
- [ ] Start sleep. Start again: only one active session remains.
- [ ] Background and force-close the app; reopen: original start time persists and elapsed interval is correct.
- [ ] Stop sleep: one Manual record appears. Stopping with no active session makes no change.
- [ ] Add a forgotten previous-night session; adjust dates across midnight; save quality 1–5 and tags.
- [ ] Mark a separate short session as a nap; verify it shows Nap in History.
- [ ] Attempt end-before-start, future time and an overlapping session: save is disabled or an error appears; existing data is preserved.
- [ ] Edit a completed session; delete another after confirmation; cancel deletion once.
- [ ] Export full JSON to Files; import it again: all existing sessions are skipped as duplicates.
- [ ] Export sessions CSV; import it again: tags, ratings, provenance, nap and stage fields survive and duplicates are skipped.
- [ ] Switch system/light/dark and larger text sizes; check editing, charts and labels on your screen.

## Stage 2: estimation and analysis

- [ ] Import `Examples/backup.json`; inspect its synthetic dates and provenance before accepting. Choose a chart window containing those dates or edit only a test copy into the current window.
- [ ] Add three recent non-nap weekday sessions with consistent endpoints; weekday schedule appears. Weekend schedule still needs its own three nights.
- [ ] Use two bedtimes around midnight (23:50 and 00:10): clock mean is near midnight, variation is about 10 min, not 12 hours.
- [ ] Leave a test session active after its learned wake time has passed. Review the wake suggestion; Cancel leaves it active; Save keeps Estimated provenance.
- [ ] Confirm estimated sessions do not teach the future schedule. Naps do not teach the schedule either.
- [ ] Verify 7/30-day windows, logged-date counts, goal line, bedtime/wake scatter plots, highest/lowest quality and longest/shortest nights.
- [ ] Leave a day unlogged: it remains unknown and is not included as a zero-hour night.
- [ ] Add three rated nights with one tag and three without it: a descriptive quality difference appears, without a causal claim.
- [ ] For a no-stage record, enable the illustrative-stage toggle: its limitation label is visible; a backup still contains no fabricated stages.

## Stage 3: Shortcuts / Health

- [ ] Perform the read-only capability check in SHORTCUTS.md; note actual Value/source labels and logging fields.
- [ ] Start/Stop Shortcuts open the installed app. Stop requests review; cancellation leaves the session active.
- [ ] Add those Shortcuts to the Home Screen or Shortcuts widget; test Action Button if your phone has one.
- [ ] Build the read recipe for ONE source. Read a small date range with real sleep data and import the CSV; inspect stage totals in History against Health.
- [ ] Import the same batch twice: second import adds zero duplicate sessions.
- [ ] Try `Examples/overlap-health.csv` after `Examples/backup.json`: the conflicting night is skipped and the manual record remains unchanged.
- [ ] Try `Examples/invalid-mixed-sources.csv`: rejected before any insert.
- [ ] Import the synthetic stage file; detailed sleep duration excludes awake and ignores overlapping In Bed/asleep summaries.
- [ ] Change imported record quality/tags only: stages remain. Change its endpoints: explicit removal acknowledgement is required.
- [ ] If bounded sleep writing is available, build the guarded writer. Choose a real manual interval you intentionally want to add, check no Health overlap, then confirm its In Bed category and exact bounds in Health.
- [ ] Try sending the same interval twice: the app receipt blocks the repeat. The writer’s Health overlap guard also blocks a second copy after receipt clearing/restore.
- [ ] Cancel/interrupt a writer. It remains pending; check Health before clearing the receipt. Do not assume an interruption means no write occurred.
- [ ] Deny Health permission once: no local manual data is lost. Repair permission and retry the actual read test.
- [ ] Alarm-stopped automation opens Estimated review; it does not finalize or log Health silently. Test while locked, and document whether your phone requires unlocking.
- [ ] Import one prior-day step total; the following wake-date night appears in the scatter plot. Reimport skips the day.

## Stage 4: reminder, backup and optional widget

- [ ] Enable reminder for a few minutes ahead, Save, grant permission, background the app and wait. Check Focus settings if silent.
- [ ] Change the reminder time and Save: only the new time is pending. Disable it and Save: it is removed.
- [ ] Test notification denial: the app reports it and disables the reminder setting.
- [ ] Export a JSON backup containing stages, steps, settings and an active session. To test a full restore, use a separate simulator installation, or a fresh phone installation only after verifying the backup is saved outside the app. The restored session may remain active until resolved.
- [ ] Reinstall over the same bundle ID/team to renew free signing; verify the journal survives. Do not delete it for routine renewal.
- [ ] If optional App Groups provisioning works, configure the widget using WIDGET.md. Confirm source/date label, delayed refresh, deletion refresh and app opening on tap. If it cannot sign, keep the baseline and Shortcuts widget.

A simulator can verify the app UI and storage but does not replace on-phone tests for Health permissions/data, signing expiry, alarm behavior, Action Button, notification delivery and widget refresh.
