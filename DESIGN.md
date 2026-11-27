# Cirrus EMS interface

## Current theme — 24 November 2026

Use Bebas Neue for English (`AppLanguage.en`, default) with `IBMPlexSansThai` and `Sarabun` fallbacks. When the user switches to Thai (`AppLanguage.th`) via **Settings > Language**, switch the primary UI font family to **IBM Plex Sans Thai** (Regular 400, Medium 500, SemiBold 600, Bold 700) and tighten `letterSpacing` to `0.0` so Thai tone marks and vowels render cleanly. Keep `Sarabun` dedicated to Leave PDF generation. Keep user-entered text, backend values, and field semantics intact.

The floating circular Check In / Check Out hero spans ~48% of viewport width (172–202 logical pixels) inside a soft concentric halo ring directly on the canvas (not trapped inside a white rectangular box). Active states use a turquoise-to-teal gradient with luminous top rim and layered elevation; disabled states use a matte elevated surface disc with crisp hairline border and pill hint below. Mobile Attendance pairs a compact Deep Navy `AmbientPanel` clock hero (with Bangkok-timezone greeting, date, status chip, and large 34px live clock) above the floating circular action and a unified daily progress + activity card below.

Mobile navigation motion reference: [Deepak Rawat — Bottom Navigation Micro Interaction Concept](https://dribbble.com/shots/18876922-Bottom-Navigation-Micro-Interaction-Concept). Use a navy floating icon disc with turquoise glyph, an off-white curved notch moving on the same interpolated center, and a raised selected label. When pressed or transitioning between tabs, the active bubble sinks down into the notch depression (up to 22 px vertical sink, scale compacts to 0.72) and pops back up at the target destination with bounce easing. Tap-down provides immediate tactile sink feedback, and tapping the active item plays a bounce/sink animation. Duplicate icons are strictly eliminated: the origin icon remains hidden until the bubble sinks into the notch, and the destination icon remains in place until the bubble arrives and emerges. Translation settles over 360 ms ease-out; icon/label feedback uses synchronized transition phases. Reduced motion snaps directly. Retarget rapid taps from the current visual position, keep the destinations aligned with their displayed order, keyboard activation, selected semantics and screen-reader tap actions. Keep the full bubble within the navigation hit area and SafeArea.

Login pairs the Cirrus wordmark and a navy clock illustration with an off-white sign-in form. On phones the full-width brand panel extends under the status bar, and the rounded form follows in the same scroll view. Desktop uses a centered split panel. Use bold existing typography and reserve turquoise for the dial accents. The illustration is static and decorative. Keep floating field labels, inline validation, the password visibility control, and the existing entry motion, including reduced-motion support. After successful explicit sign-in or sign-out, fade in the destination over 180 ms on an opaque canvas. Skip the transition when the system requests reduced motion.

Pay estimate starts with the month selector and a navy panel for estimated base pay, verified hours counted, and bonus time. The fixed daily and hourly wage and refresh action sit below it, with empty and error messages visible in the page flow. Local leave uses the same inset navy header in its form card. Label both date controls and stack them as space tightens or text grows. The One day checkbox selects the start date as the end date; all leave durations count whole calendar days. Keep the draft history below the form. The Leave PDF Preview screen has two separate AppBar actions: **Download PDF** (saves directly to the device Downloads folder, shows a Snackbar with the saved path) and **Share PDF** (opens the system share sheet). Do not merge these into a single button.

Profile centers the employee identity in an AmbientPanel. The Account & Employment card presents employee code, phone and user ID in order. General provides the Settings entry, followed by Switch Account and Log Out.

Latest soft-reference refinement supersedes the prior editorial treatment: rounded navy hero panels with gradual turquoise light and blurred sculpted curves, floating white action cards, and a light capsule navigation with navy selected state. AmbientPanel is a native Flutter decorative painter shared by attendance and pay; artwork is excluded from semantics. No external images, 3D runtime or new dependency is required. Preserve data contrast and explicit pay-preview limitations. Avoid sharp grey shadow shelves and heavy repeated borders.

Reference refinement: use the user's editorial/bento UI collage for bold numerals, distinct task blocks and rounded surfaces, retaining the current product palette. Live attendance uses a large left-aligned clock, a small uppercase label and a circular turquoise action. Pay totals use a stronger numeric hierarchy; refresh is secondary. Desktop panels fit their content and scroll on short viewports. Existing logo, English copy, data sources and behavior remain the source of truth; no decorative or invented metrics are introduced.

This section supersedes the older visual tokens below. User palette: approximately 60% cool off-white, 30% deep navy, 10% turquoise accents; these are visual proportions, not exact pixel quotas.

1. Audience/task: employees recording attendance on phones, with a responsive desktop workspace.
2. Main action: clock and attendance action form one compact group; progress and activity remain secondary.
3. Baseline: retain four destinations and Cirrus assets; use a prominent circular attendance control.
4. Direction: a calm, contemporary daily work desk with decisive navy task areas and quiet light surfaces.
5. Typography/colors: Roboto, clear weight hierarchy; canvas #F3F6F7, surface #FAFCFC, navy #102D40, turquoise #32D5C0. Use Material icons and existing logo.
6. Feedback/states: retain native press/keyboard feedback, reduced-motion-aware navigation, loading, disabled, empty, error and success behavior. Action height grows with text scale.

Independent screenshot review requested a tighter desktop action group and smaller empty activity panel; both were adjusted. This pass changes presentation only. Salary/bonus preview behavior belongs to the separate feature documented in README.md.

---

## Themes & Appearance Modes

The app supports 3 distinct appearance modes configurable in the **Settings** screen (accessible via Profile > General > Settings), persisted across restarts via `SharedPreferences`:

1. **Cirrus Signature (Default):**
   - Palette balance: Canvas `#F3F6F7` (60%), Deep Navy `#102D40` (30%), Turquoise Teal `#32D5C0` (10%).
   - Off-white card surface `#FAFCFC`, muted labels `#536575`, card borders `#DFE8EC`.
   - Balanced, serene, corporate feel.

2. **Pure White (Clean Minimalist Light):**
   - Palette balance: Pure White Canvas `#FFFFFF`, Elevated Card Surfaces `#F8FAFC`, Crisp Slate Typography `#0F172A`, High-tech Sky Blue Accent `#0EA5E9`.
   - Subtle slate border `#E2E8F0`, muted labels `#64748B`.
   - Minimalist, bright, clean, high-contrast.

3. **Obsidian Black (OLED Night Mode):**
   - Palette balance: Pitch Black Canvas `#0B1118`, Slate Dark Surfaces `#151E28`, Crisp Off-White Text `#F1F5F9`, Glowing Neon Teal Accent `#2DD4BF`.
   - Subtle dark border `#223140`, muted labels `#94A3B8`.
   - High-contrast components: Role badge uses `#1E2D3D` capsule with `#F1F5F9` text and `#2DD4BF` icon; Avatar circle uses `#141D26` elevated surface with `#2DD4BF` monogram; Bottom nav bar uses `#151E28` surface with `#2DD4BF` active bubble on a seamless `#0B1118` canvas.
   - Deep contrast, battery saving on OLED screens, comfortable in low light.

Theme selection shows a compact `CHANGING THEME` progress cue in the AppBar for about 220 ms, then applies the palette and shows a short `THEME UPDATED` confirmation with a check icon. Keep the current tab state and avoid a full-screen loader.

---

## Design Tokens (lib/theme/app_theme.dart)

| Token | Value | Usage |
|---|---|---|
| `AppColors.primary` | `#F3F6F7` | Canvas / page background (60%) |
| `AppColors.surface` | `#FAFCFC` | Card / input surface |
| `AppColors.neutral` | `#102D40` | Deep navy text & panels (30%) |
| `AppColors.secondary` | `#32D5C0` | Teal accent, icons, badges (10%) |
| `AppColors.textSecondary` | `#536575` | Muted supporting labels |
| `AppColors.cardBorder` | `#DFE8EC` | Card outline |
| `AppRadius.pill` | `999` | Pill / capsule buttons & badges |
| `AppRadius.hero` | `28` | Large ambient panels |
| `AppRadius.surface` | `24` | Cards |
| `AppRadius.input` | `16` | Input fields & date buttons |

> **⚠️ Warning:** `AppColors.textPrimary` ไม่มีใน codebase — ใช้ `AppColors.neutral` หรือ `AppColors.neutral.withValues(alpha: 0.85)` แทนเสมอ

---

## Component Patterns (ใช้ซ้ำทุกหน้า)

### Pill Month/Period Selector
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.input),
    border: Border.all(color: AppColors.cardBorder),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: Offset(0, 2))],
  ),
  child: Row(children: [
    IconButton(icon: Icon(Icons.chevron_left)),
    Icon(Icons.calendar_today, color: AppColors.secondary),
    Text('November 2026', style: bold navy),
    IconButton(icon: Icon(Icons.chevron_right)),
  ]),
)
```

### Section Label
```dart
Text('SECTION NAME',
  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
    color: AppColors.neutral, letterSpacing: 0.6))
```

### Surface Card (เนื้อหาทั่วไป)
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.surface),
    border: Border.all(color: AppColors.cardBorder),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, 2))],
  ),
)
```

### Icon Badge (teal circle + icon)
```dart
Container(
  width: 36, height: 36,
  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), shape: BoxShape.circle),
  child: Icon(icon, color: AppColors.secondary, size: 18),
)
```

### Pill Badge (status / label)
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.neutral, borderRadius: BorderRadius.circular(AppRadius.pill)),
  child: Text('LABEL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
)
```

### Pill Button (Primary — navy)
```dart
FilledButton.icon(
  style: FilledButton.styleFrom(
    backgroundColor: AppColors.neutral,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  ),
)
```

### Pill Button (Secondary — outlined)
```dart
OutlinedButton.icon(
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.neutral,
    backgroundColor: AppColors.surface,
    side: BorderSide(color: AppColors.cardBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
  ),
)
```

---

## Per-Screen Design Spec

### Bottom Navigation (`lib/widgets/app_bottom_nav.dart`)
- StatefulWidget + SingleTickerProviderStateMixin
- Floating navy bubble (disc) อยู่เหนือรอยเว้า (notch)
- **Transition:** bubble ยุบลง Y +22px, scale → 0.72, เคลื่อนไปปลายทาง, เด้งขึ้น (bounce easing, 360ms settle)
- **Tap-down:** ยุบลง 6px ทันที (tactile)
- **Tap active tab:** bounce animation (sink 10px → ดีดกลับ)
- **Icon dedup:** origin icon ซ่อนเมื่อ bubble ออก; destination icon ซ่อนจนถึงเป้า — ไม่มีจังหวะที่ icon 2 ตัวปรากฏพร้อมกัน
- **Reduced motion:** snap ทันที ไม่เล่น animation
- 4 destinations: Attendance, History, Pay & Leave, Profile

### History Screen (`lib/screens/history_screen.dart`)
- Show a full-width Deep Navy `AmbientPanel` scan-hours hero card below the month selector (matching Attendance and Pay). Use Total Working Hours This Month (white bold numeral) for the current month and Total Working Hours for past months. When data is available, show Hours Used for Pay (turquoise bold numeral) below a translucent divider. Display scan times in Bangkok time (`UTC+7`).
- **_MonthSelector:** Pill container + `calendar_today` icon + ซ้าย/ขวา chevron
- **_MetricCard:** Surface card, uppercase label (12px, letterSpacing 0.6), icon badge (teal circle), bold value, border+shadow
- **_DailyScanList:** ไม่ใช้ Divider — card-per-row แยกด้วย `SizedBox(height: 10)` gap
- **_DailyScanRow:** calendar icon + bold date, scan-count pill badge (`N scans`), chevron → เปิด bottom sheet detail (working hours shown once in the 3-column metric bar below)
- **_MetricMini:** centered column, icon (teal badge), uppercase label (10px), bold value; `isHighlight: true` → teal color
- Bottom sheet detail: แสดง scan event list พร้อม check-in/check-out times

### Profile Screen (`lib/screens/profile_screen.dart`)
- **Avatar card:** Deep navy AmbientPanel, centered avatar with a theme-accent ring and a soft glow `BoxShadow`
- **Name:** 30 logical pixels, bold white, centered and allowed to wrap
- **Email:** 15 logical pixels, translucent white, selectable
- **Role badge:** Navy pill + teal icon (verified_user) + white bold text
- **Section label:** `_sectionLabel()` = bold 14px navy uppercase
- **Group card:** `_groupCard()` = surface card พร้อม border+shadow (ไม่ใช้ Material widget)
- **Field row:** A 40 × 40 icon tile precedes the label and selectable value. Employee code and phone use 21 logical pixels in bold. User ID follows at 15 in a muted color. Each populated row has a copy target of at least 48 × 48 logical pixels.
- **Log Out button:** Red `OutlinedButton.icon` pill shape, `Icons.logout`, `Colors.red.shade600`

### Work Trial Screen (`lib/screens/work_trial_screen.dart`)
- Background: `AppColors.primary`
- **Tab switcher:** pill-shaped `Container` พร้อม `BoxDecoration`; selected = navy bg white text, unselected = surface bg navy text
- ไม่ใช้ `TabBar` widget มาตรฐาน

### Earnings Trial Tab (`lib/screens/earnings_trial_tab.dart` & `lib/widgets/pay_wallet_card.dart`)

- The month selector and interactive **PayWalletCard** share one card. The wallet card uses Cirrus's active theme palette (`ambientGradientStart` → `secondary`), painted EMV chip, contactless glyph, pointer-tracking specular sheen, employee holder name, real employee code (`EMP CODE`, without masked card dots), animated number roll (`TweenAnimationBuilder`, 240 ms), and period short label.
- Tapping anywhere on the card plays a 520 ms 3D `rotateY` perspective flip (with `HapticFeedback.lightImpact()`) to reveal the back details (magnetic stripe `CIRRUS EMS · PAY CARD DETAILS`, employee `BASE SALARY`, `DEPARTMENT`, `EMPLOYMENT`, and `START DATE` localized to Thai months when `AppLanguage.th` is active). Switching main tabs or Pay/Leave tabs resets the card to its front face.
- Below the wallet card, display **Verified hours counted** and **Bonus time after 17:00** as two equal-width metric tiles (`_PayMetricTile`) with teal circular icon badges and bold 22px tabular numerals (`h m` in EN / `ชม. น.` in TH), followed by the rate summary (`Salary-based hourly rate` from `baseSalary ÷ 30 ÷ 8` or fallback `Fixed daily wage estimate` `300/8h`) and a full-size 40px pill **Refresh** button.
- Keep the transparent calculation in an inline expandable card (`How this is calculated`), followed by a dedicated single-row **Pay Simulator** action card (`PayCalculatorScreen`) with a teal `tune_rounded` icon badge.

### Pay Simulator Screen (`lib/screens/pay_calculator_screen.dart`)

- Dedicated client-side sandbox screen pushed from `EarningsTrialTab` (never writes to backend or alters payroll).
- Top **Deep Navy `AmbientPanel`** live result card displays the simulated estimate (38px Turquoise tabular numerals), **Hourly rate**, and **Daily rate (8h)**, updating instantaneously as inputs change.
- Single focused salary-formula flow (no redundant daily-wage tab): **Monthly salary (THB)** input + **Base days per month** chips (`30 / 26 / 22` days, locked to the Thai labor-law standard `8h/day` divisor) + **Working time to simulate** (`Hours` & `Minutes` inputs with quick chips **`+8h (1 day)`**, dynamic **`Full month (baseDays × 8h)`** yielding the exact monthly salary, and **`This month`** pre-filled from verified scans).

### Animated Welcome Splash & Session Pacing (`lib/screens/splash_screen.dart`, `lib/widgets/session_transition.dart`)

- **Welcome Splash (1.25 s, 60fps):** Deep Navy radial-glow backdrop, spring-popped `AppLogo` inside a luminous Turquoise ring with expanding ripple wave, staggered `Cirrus EMS` wordmark + expanding Turquoise accent bar + bilingual tagline, and sleek `LinearProgressIndicator` before smoothly fading (`260 ms`) into `MainShell` or `LoginScreen`. Defaults to `minDisplayDuration: Duration.zero` for deterministic widget tests and respects `disableAnimations`.
- **Login / Logout Pacing:** Explicit sign-in and sign-out trigger `HapticFeedback.lightImpact()`, display an inline button spinner with status copy (`Signing in…` / `กำลังเข้าสู่ระบบ…`, `Signing out…` / `กำลังออกจากระบบ…`) for a minimum of **700 ms** on success, then reveal the destination over a **260 ms** fade (`0.0 → 1.0`).

### History Hero Hierarchy & 60 FPS Rendering (`lib/screens/history_screen.dart`, `lib/widgets/shimmer_box.dart`)

- **`_WorkingHoursCard` (`AmbientPanel`):** Elevates **Hours Used for Pay** to the primary top slot (38px bold Turquoise numerals + 46×46px teal icon badge) and places **Total Working Hours** below as a calm secondary metric (20px soft-white numerals + centered 36px icon inside a matching 46px column so both text columns align on the exact same vertical axis).
- **Performance & Feel:** `CustomScrollView` + lazy `SliverList.builder`, precomputed `_DailyScanSummary` per fetch, compact pill **Recalculate** button, slim inline empty summary banner, `RefreshIndicator` across all 4 main screens, `ShimmerCardSkeleton` loading placeholders, `RepaintBoundary` isolation around blurred/animated surfaces (`AmbientPanel`, `LiveClock`, `AppBottomNav`, `PayWalletCard`), and `FadeTransition` in `FadeSlideEntry`.
- **Dark Mode (`Obsidian Black`) Contrast:** Selected pill controls (`WorkTrialScreen` TabBar, `LeaveDraftsScreen` filter pills, `PayCalculatorScreen` chips) always use `AppColors.onNeutral` foreground over `AppColors.neutral` fill rather than hardcoded `Colors.white`.
- **Language Settings (`lib/screens/language_settings_screen.dart`):** Top-aligned minimalist 1-row cards showing radio indicator, `EN`/`TH` badge, native language name (`English` / `ภาษาไทย`), and `ACTIVE` badge.

### Leave Trial Tab (`lib/screens/leave_trial_tab.dart`)

- Nest the navy heading and local draft explanation inside the off-white form card.
- Show Start date and End date on separate labeled buttons. Stack the buttons when there is insufficient width.
- Follow the form with up to **2 most recent** compact draft cards (`LeaveDraftCard`, placing `View PDF` and `Cancel draft` on one horizontal row) or the local drafts empty state, plus a **View all (N)** button opening the dedicated `LeaveDraftsScreen` with **All / Active / Cancelled** status filter pills. Provide `View PDF` after saving and on each draft card, including cancelled drafts. PDF export uses Sarabun for Thai, Cirrus logo and draft/cancelled status.

---

## Oil UI refinement — 20 November 2026

Audience: employees checking attendance on a phone, with a responsive desktop companion.
Main action: record attendance when the backend permits it; show today's recorded state nearby.
Keep the familiar four destinations, Cirrus logo, navy and teal identity. Retain English interface copy.
Direction: a compact daily work desk, using a light canvas, a single navy time/action panel and quiet content surfaces. No decorative hero imagery, invented statistics or promotional copy.
Typography: existing platform sans-serif, tabular clock digits, clear 14–16 px body text, 12–13 px supporting labels. Use the existing Material icon family.
Feedback: native Material press/focus feedback, restrained selection transitions, existing loading/error/success/disabled states. Do not introduce data-dependent animations or extra requests.

## Tokens and layout

- Keep navy #0F3347 and teal #2DD4BF; navy text on teal actions, never low-contrast white-on-teal labels.
- Light blue-gray canvas, white inputs and surfaces, muted slate supporting text. Use semantic container foreground colors for status labels.
- Use the existing 4 px spacing scale. Inputs/actions have 12 px corners, main surfaces 20 px corners; reserve circular geometry for the attendance action and stepper.
- Navigation uses a white surface, visible labels, a soft selected fill and selected semantics. Minimum interactive targets remain 48 px.
- Mobile: a compact greeting, time/action panel, progress and activity in normal document flow. No spaceBetween stretching that hides today's activity below a mostly empty hero.
- Desktop: two readable columns; do not stretch forms beyond their existing max widths. Preserve keyboard scrolling and short-height layouts.
- Error text must wrap rather than being truncated. Long names and account values must remain readable.

## Protected behavior

No changes to services, models, API URLs, permissions, auth, eligibility, duplicate-request protection, photo/GPS workflow, calculation formulas or stored data. The monthly-salary/bonus discussion is not implemented by this UI task. All displayed dates, status labels, history and amounts keep their existing sources.

## Verification

- Focused Flutter suite: 21 tests passed, covering attendance submission/retry, progress, navigation, pay/leave and UI accessibility.
- All 13 protected services, models, environment and dependency files match their pre-refinement SHA256 hashes.
- Independent screenshot review identified a missing mobile disabled-state explanation and tight profile spacing; both were corrected and recaptured.
- Confirmed refreshed Attendance and Pay & Leave on the Pixel emulator. No real attendance or pay/leave records were submitted during review.
- UI modernization pass (20 Nov 2026): 11 tests passed across bottom nav, ui_refresh and widget suites. Emulator screenshots captured for all 5 screens: attendance, history, profile, pay estimate, local leave.

### Typography and leave PDF preview (21 November 2026)

Bebas Neue headings use open letter spacing for readability; the login brand title also has more line spacing. Leave drafts open an in-app PDF preview with an accessible download/share icon.

Typography: use positive letter spacing on the shared Bebas Neue text styles and avoid cramped custom heading styles. Verify narrow screens and text scaling.

History shows up to four recent daily scan cards by default, with larger metric text and a View all / Show less control for the selected month. Keep daily details accessible from each card.

On switching navigation tabs, reset vertical scroll to the top while retaining screen state. History cards use roomier padding and larger time values, with an emphasized View all action.

Leave PDF follows a concise request form: employee information, selected leave type, dates and reason, plus employee and manager signature lines. Keep the draft and cancellation state visible; leave unavailable details blank.

Leave PDF formal styling (23 November 2026):
- Form Header: includes CIRRUS EMS brand mark, document reference (`REF: LEV-...`), and generation date/time in Bangkok timezone.
- Form Fill Lines: replaces typewriter underscore strings with crisp vector bottom border lines for manual fill areas (To Approver, Department).
- Section Titles: styled with a solid 3px Deep Navy left accent bar over a soft `#F0F4F7` background.
- Reason: framed in an enclosed, padded light container to clearly separate user-provided narrative from metadata.
- Signatures: formal centered layout with signature rule, printed name placeholder `(                    )`, role title, and dot-leader date line.
