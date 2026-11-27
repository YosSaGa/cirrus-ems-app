# Payroll and Leave Trial Implementation Plan

> Execute inline with executing-plans; the user requested implementation now.

**Goal:** App-only hourly earnings estimates and local leave drafts.
**Architecture:** Pure calculation model, user-scoped preference store, two focused tabs in a new screen, fourth navigation item.
**Tech Stack:** Existing Flutter, SharedPreferences, uuid, existing AttendanceService GET.
**Spec:** ../specs/2026-11-19-payroll-leave-trial-design.md

## Global constraints

- No backend modifications, new dependencies, approved payroll or real leave submission.
- Bangkok +07:00 cutoff default 17:00; editable rate and OT multiplier, initially 1.5.
- Financial amounts are satang; current month is provisional; incomplete scans must be visible.

## Review focus

Incomplete/overlapping scans; UTC versus Bangkok; nonfinite input; cross-user storage; draft leave mistaken for approved leave.

## Tasks

- [x] Write failing calculator tests, implement payroll_calculator.dart, run focused tests.
- [x] Write failing store tests, implement work_trial_store.dart with draft model, run tests.
- [x] Implement earnings_trial_tab.dart, leave_trial_tab.dart and work_trial_screen.dart; add shell/nav destination. Add widget tests for manual totals, read failure, drafts and narrow layout.
- [x] Run tests/analyze, fix relevant failures, Android debug build, refresh running app, inspect UI, update README and record results.

## Ledger

- No .git directory exists in this downloaded project; no worktree/commits possible.
- Ruling: configurable cutoff resolves the unconfirmed 17:00 rule without claiming an official payroll policy. Local leave drafts have no monetary effect.
- Review: fixed cross-workDate overlaps and strict timestamp parsing with observed RED→GREEN regression tests. User explicitly confirmed minute range 00–59; added 59/60 boundary cases.
- Replaced obsolete Flutter counter template test with actual four-destination navigation coverage. Full suite: 99 passed. Android x64 debug APK: built successfully. Analysis: no errors/warnings, existing Material deprecation notices and one existing null-aware style notice remain.
- Verified both earnings and leave screens visually on the authenticated Pixel 10 Pro XL emulator. No sample wage or leave record was saved to the user's account during visual checks. Web hot restart requested as well.
- Follow-up implemented: English interface for Pay & Leave; select THB 300/400/500 daily wage, derive read-only hourly rate using 8 hours, fixed read-only 1.5 OT multiplier. Legacy matching hourly settings restore the daily selection; unmatched settings require a new selection; custom legacy OT does not affect new estimates. Expanded dropdowns pass 320px layout tests. Full suite: 101 passed; analysis has no errors/warnings (35 informational notices). Hot-restarted Android and Web; visually verified the selector, automatic 37.50 hourly rate for THB 300/day and locked 1.5 OT on Pixel 10 Pro XL without saving a sample wage.
- Follow-up stale web client: the existing in-app browser tab still ran the old three-destination app even after the debug Chrome hot restart. Reloaded that exact tab and verified the four-destination English Pay & Leave UI. Translated the remaining attendance-service fallback messages; no hard-coded Thai text remains in lib Dart files. Affected regression tests: 39 passed. Server-supplied or user-entered text is preserved verbatim.
