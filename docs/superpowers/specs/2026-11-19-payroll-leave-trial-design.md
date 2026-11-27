# Payroll and leave trial

User requested immediate implementation of an app-only trial. No backend changes or new write endpoints.

## Approach

Add a fourth main destination, Pay & Leave, with earnings and leave tabs. All interface labels, errors and helper text for this feature are English. Reuse the app theme, SharedPreferences, UUID and the existing GET my-scans API. A backend payroll/approval workflow is outside this trial; a separate mock server would duplicate existing infrastructure.

## Earnings

Calendar-month periods, Bangkok business time. Users choose daily THB wage 300, 400 or 500. Derive the read-only hourly rate using an eight-hour workday (37.50, 50.00 or 62.50); OT multiplier is read-only and fixed at 1.5. OT start remains editable, initially 17:00. Require a selection if a legacy saved hourly rate does not match an offered daily wage; do not use legacy custom OT multipliers for new calculations. Earnings = regular minutes × rate / 60 + OT minutes × rate × multiplier / 60. Store money in satang, round each monthly component to the nearest satang. Show current/future months as provisional; elapsed months as period-ended estimates, never approved payroll. Do not freeze or write official monthly totals.

Support manual-hour trials and explicitly requested read-only scan import. Pair morning_in/lunch_out and afternoon_in/leave within workDate, exclude incomplete/invalid pairs with a visible warning, merge overlapping intervals before splitting at the chosen Bangkok cutoff, never infer missing scans or count breaks. Ignore uncounted scans. Use earliest input/latest output for duplicate counted window codes, matching History's direction rules. Require timestamp zones, validate dates and positive intervals no longer than 24 hours. Filter by workDate, including overnight work attributed to its workDate.

## Leave

Local drafts only: sick, personal, annual, unpaid; date range, full/half day, reason. Half-day is a single date. Reject overlapping active drafts. Permit cancellation, retaining the record. Never imply submission/approval, quota, paid entitlement or payroll deduction. No file attachments in this trial.

## Persistence and isolation

Persist rate/OT preferences and leave drafts under the authenticated user's ID; reject use without a saved user ID. No shared global HR records, no credentials in new storage. Preserve malformed data and surface an error instead of overwriting it. Show and disable conflicting actions while saving; validate finite numeric inputs and date ranges.

## Proof

Review ruling: exclude both workDates when overnight intervals overlap across dates, rather than choosing a pay policy arbitrarily. Reject overflowing timestamp date/clock fields instead of allowing Dart's date normalization. Boundary tests cover 00–59 minutes/seconds and 00–23 hours.

Calculation tests: cutoff, breaks, duplicate/overlap, incomplete/malformed/uncounted scans, Bangkok timezone, month attribution, rounding, invalid numbers. Storage tests: per-user isolation, restart retention, validation, cancellation, overlap/corrupt storage. Widget tests: navigation, manual calculation, local leave submission and validation, API failure handling. Run focused tests, existing suite, analyze and Android debug build; inspect UI without entering credentials.
