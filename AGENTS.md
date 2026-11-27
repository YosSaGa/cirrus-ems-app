# กติกาการทำงานในโปรเจค

## ขอบเขตโปรเจค

Flutter app ฝั่งพนักงาน เชื่อมต่อ EMS Backend ภายนอก อ่านภาพรวมปัจจุบันจาก README.md ก่อนเริ่มงาน และอ่าน TASK_STATUS.md เพื่อทราบสถานะและข้อจำกัด

## เทคโนโลยี

- **Framework:** Flutter/Dart (SDK constraint `^3.13.7` ใน `pubspec.yaml`)
- **Flutter ที่ใช้จริง:** 3.50.0 / Dart 3.14.0 ที่ `C:\Users\yossa\OneDrive\เอกสาร\CostCal\.tools\flutter`
  - ใช้ผ่าน alias ชั่วคราว `subst F: "C:\Users\yossa\OneDrive\เอกสาร\CostCal\.tools\flutter"`
  - คำสั่งทดสอบ: `F:\bin\flutter.bat test <test_file>` หรือ `F:\bin\flutter.bat test test/a.dart test/b.dart`
  - คำสั่ง build (Debug): `F:\bin\flutter.bat build apk --debug -t lib/main.dart`
  - คำสั่ง build (Profile 60fps AOT): `F:\bin\flutter.bat build apk --profile -t lib/main.dart`
  - คำสั่ง build (Release ขนาดเล็กที่สุด): `F:\bin\flutter.bat build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols -t lib/main.dart`
  - คำสั่ง analyze: `F:\bin\flutter.bat analyze lib/screens/xxx.dart`
- **State/Storage:** SharedPreferences (ใบลา, session, retry queue, ธีม `ems.themeMode`, ภาษา `ems.language`)
- **HTTP:** `http` package, เลือก client ตาม platform ผ่าน `api_client_factory*.dart`
- **PDF และฟอนต์:** `pdf`, `printing`, **Bebas Neue** (หัวข้อ EN), **IBM Plex Sans Thai** 4 น้ำหนัก (โหมดภาษาไทย) และ **Sarabun** (สำหรับ Leave PDF) จาก `assets/fonts/`
- **UI Language:** รองรับ 3 ภาษา (**English** ค่าเริ่มต้น / **ภาษาไทย** / **Bahasa Melayu**) สลับได้แบบ real-time ผ่าน `Settings > Language` (`LanguageService` + `AppStrings`) โดยไม่กระทบ Backend/สูตรคำนวณ
- **Package name:** `com.cirrusgroup.ems` / Activity: `.MainActivity`

## โครงสร้างไฟล์

```
lib/
  main.dart                       # เริ่มแอป, โหลด .env, ThemeService + LanguageService
  l10n/
    app_strings.dart              # ข้อความ 2 ภาษา EN/TH และ formatter เฉพาะฝั่งแสดงผล
  screens/
    splash_screen.dart            # Animated Welcome Splash (1.25 วิ) + ตรวจ session
    login_screen.dart             # หน้าเข้าสู่ระบบ (700ms loading + 260ms fade)
    main_shell.dart               # IndexedStack 4 แท็บ + AppBottomNav / AppSideNav
    attendance_screen.dart        # หน้าลงเวลาหลัก (Pull-to-Refresh, timeline 4 ช่วง, โหมดช่าง Role Technician/Admin)
    technician_jobs_screen.dart   # หน้ารายการ Job Code ทั้งหมด (ปักหมุดงานตัวเองบนสุด) + หน้าดูรายละเอียดงานแยก
    technician_report_screen.dart # หน้าบังคับเขียนรายงานการทำงานหลัง Check Out เที่ยง/เย็น (operations.technician_reports)
    technician_history_screen.dart # หน้าประวัติงานและรายงานช่างย้อนหลัง (เข้าจาก Settings เฉพาะ Technician/Admin)
    attendance_camera_screen.dart # ถ่ายรูปสำหรับ attendance
    history_screen.dart           # ประวัติสแกนรายเดือน (SliverList, precompute, hero card)
    profile_screen.dart           # ข้อมูลพนักงาน + ลิงก์ Settings + Switch Account (3 ล่าสุด) + logout (700ms loading)
    saved_accounts_screen.dart    # หน้ารายการบัญชีที่เคยสลับทั้งหมด (ค้นหา/ลบ/สลับบัญชี)
    settings_screen.dart          # เมนูตั้งค่าหลัก (Appearance, Language, Management, About)
    appearance_settings_screen.dart # เมนู Appearance (App Theme + Pay Card Style 5 สีพร้อมรูปบัตรจริง)
    theme_settings_screen.dart    # เลือกธีม 3 แบบ (Default, White, Obsidian Black)
    language_settings_screen.dart # สลับภาษา English / ภาษาไทย แบบมินิมอล
    device_check_screen.dart      # ตรวจสถานะเซิร์ฟเวอร์ EMS, สิทธิ์ GPS และกล้องหน้างาน
    storage_cache_screen.dart     # หน้าดูกราฟวงแหวนแหล่งแคช (แบบ Telegram) และเลือกล้างแคช
    work_trial_screen.dart        # Earnings & Leave shell (2 แท็บ)
    earnings_trial_tab.dart       # Pay estimate (PayWalletCard 3D + เรทต่อชม./ฐานเงินเดือน + การ์ดรายการหัก)
    pay_calculator_screen.dart    # Pay Simulator คำนวณค่าแรงเองฝั่งเครื่อง
    payroll_management_screen.dart # จัดการเรทต่อชม. & รายการหัก (ค่าที่พัก/ประกันสังคม/ประกันงาน) เฉพาะ HR/Admin/Accountant
    leave_trial_tab.dart          # Local leave draft tab (แสดง 2 ใบล่าสุด + View all)
    leave_drafts_screen.dart      # หน้าแยกแบบร่างใบลาทั้งหมด (กรอง All/Active/Cancelled)
  widgets/
    app_bottom_nav.dart           # Bottom navigation แบบ floating bubble + Haptic
    ambient_panel.dart            # Decorative navy gradient painter (RepaintBoundary, centered mode)
    technician_attendance_section.dart # UI โหมดช่าง (badge, Job Code picker, active job card, today sessions)
    pay_wallet_card.dart          # การ์ดค่าแรง 3D flip + animated number roll
    shimmer_box.dart              # Shimmer skeleton loading (ShimmerBox / CardSkeleton)
    fade_slide_entry.dart         # Entry animation (FadeTransition + reduced motion)
    session_transition.dart       # Fade transition 260ms สำหรับ Login/Logout/Splash
  theme/
    app_theme.dart                # AppColors, AppRadius, AppTheme.forMode(mode, language)
  services/
    auth_service.dart             # login, session, SSO, logout, baseUrl, RBAC (canManagePayroll, isTechnician)
    technician_service.dart       # REST client โหมดช่าง (my-jobs / check-in / check-out ลง hr.work_sessions)
    work_timer_notification_service.dart # แจ้งเตือน Android Chronometer นับเวลาทำงานสดบน Status Bar (MethodChannel)
    payroll_service.dart          # REST client จัดการเรทต่อชม. และรายการหัก (hr.compensation / hr.employee_payroll_items)
    attendance_service.dart       # attendance events, upload, history, retry
    theme_service.dart            # จัดการธีม 3 แบบ + SharedPreferences
    language_service.dart         # จัดการภาษา EN/TH + SharedPreferences
    app_preferences_service.dart  # ตั้งค่าการสั่น (Haptics) และแจ้งเตือนงานใหม่ (SharedPreferences)
    leave_pdf_builder.dart        # สร้าง PDF จากใบลาทดลอง (Sarabun)
    file_download_service.dart    # ดาวน์โหลด PDF ลง Downloads (MediaStore)
    location_service.dart         # GPS one-shot
    local_photo_store.dart        # รูปบน disk สำหรับ retry (non-Web)
    api_client_factory*.dart      # platform HTTP client selection
  models/
    captured_photo.dart           # bytes + filename + mimeType
    payroll_calculator.dart       # สูตรคำนวณค่าแรง (เงินเดือน ÷ 30 ÷ 8, fallback 300/8 ชม.)
test/
  widget_test.dart                # smoke test
  ui_refresh_test.dart            # UI-layer tests (11 ข้อ)
  app_bottom_nav_test.dart        # bottom nav animation tests (5 ข้อ)
  settings_screen_test.dart       # Settings & Theme tests (5 ข้อ)
  language_settings_test.dart     # Language & IBM Plex Sans Thai tests (4 ข้อ)
  work_trial_screen_test.dart     # Pay & Leave tests (5 ข้อ)
  pay_calculator_screen_test.dart # สูตรฐานเงินเดือน & Pay Simulator tests (2 ข้อ)
  payroll_management_test.dart    # RBAC (HR/Admin/Accountant) + รายการหัก + PayrollManagementScreen tests (4 ข้อ)
  splash_screen_test.dart         # Splash session restoration tests (6 ข้อ)
  attendance_screen_*.dart        # attendance logic tests
  auth_service_test.dart          # auth unit tests
  leave_pdf_builder_test.dart     # PDF และข้อมูลเดิม
assets/
  icon/                           # ภาพต้นทางสำหรับ Android launcher icon
  fonts/                          # Bebas Neue, IBM Plex Sans Thai (4 น้ำหนัก), Sarabun + license
.env                              # API base URLs (อยู่ใน pubspec.yaml assets)
.tools/ems_local_server.js        # Local EMS API Bridge พอร์ต 3000 -> PostgreSQL cirrus_02
start_emulator_and_backend.bat    # สคริปต์เปิด Bridge + Emulator + แอปจาก Windows โดยตรง
.tools/python/python.exe          # Python portable สำหรับ ui-ux-pro-max skill
.oil-ui/screenshots/              # ภาพ screencap จาก emulator (reference)
```

## Theme Tokens (lib/theme/app_theme.dart)

```dart
AppColors.primary       = Color(0xFFF3F6F7)   // canvas/background (60%)
AppColors.surface       = Color(0xFFFAFCFC)   // card surface
AppColors.neutral       = Color(0xFF102D40)   // deep navy (30%)
AppColors.secondary     = Color(0xFF32D5C0)   // teal accent (10%)
AppColors.textSecondary = Color(0xFF536575)   // muted label
AppColors.cardBorder    = Color(0xFFDFE8EC)   // card outline
// ⚠️ AppColors.textPrimary ไม่มี — ใช้ AppColors.neutral หรือ AppColors.neutral.withValues(alpha: 0.85)

AppRadius.pill    = 999.0  // pill/capsule shape
AppRadius.hero    = 28.0   // large panels
AppRadius.surface = 24.0   // cards
AppRadius.input   = 16.0   // input fields
```

## Emulator & ADB

- **Device:** Pixel 10 Pro XL API 35 (emulator-5554), 1344×2992px, 8GB RAM, host GPU
- **ADB path:** `"$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"`
- **Launch app:** `adb -s emulator-5554 shell am start -n com.cirrusgroup.ems/.MainActivity`
- **Install:** `adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk`
- **Screenshot:** `adb -s emulator-5554 shell screencap -p /sdcard/name.png && adb pull /sdcard/name.png .oil-ui/screenshots/name.png`
- **Bottom Nav tap coords (y≈2800):**
  - Attendance: x≈168, History: x≈504, Pay & Leave: x≈840, Profile: x≈1176
- **Tab tap coords ใน Work Trial Screen (y≈350):**
  - Pay estimate: x≈190, Local leave: x≈850

## เอกสารหลักและการอัปเดต

- `README.md`: โปรเจคเกี่ยวกับอะไร ความสามารถ โครงสร้าง การเชื่อมต่อ และวิธีรัน
- `TASK_STATUS.md`: งานทำแล้ว งานยังไม่ทำ ข้อจำกัด ผลตรวจ และประวัติการเปลี่ยนแปลง
- `DESIGN.md`: รายละเอียดแนวทาง UI อ้างอิงเมื่อแก้หน้าตาแอป
- `PROJECT_STRUCTURE.md`: แผนที่โฟลเดอร์และหน้าที่ไฟล์สำหรับผู้พัฒนาและ AI agent

หลังมีการเปลี่ยนแปลงทุกครั้ง ก่อนส่งคำตอบปิดงาน:

1. อัปเดต TASK_STATUS.md ให้ตรงกับงานจริง ระบุสิ่งที่เปลี่ยน ผลตรวจ ข้อจำกัด และเพิ่มบันทึกวันที่ โดยเก็บประวัติเดิมไว้
2. ตรวจ README.md และอัปเดตวันที่ล่าสุด หากความสามารถ โครงสร้าง configuration หรือวิธีรันเปลี่ยน ให้แก้เนื้อหาที่เกี่ยวข้องด้วย หากไม่มีผลต่อภาพรวม ระบุในบันทึกงานว่าได้ตรวจ README แล้ว
3. แยกงานที่ทำแล้ว งานยังไม่ทำ และแนวคิดที่ยังไม่อนุมัติอย่างชัดเจน อ้างผลทดสอบที่รันจริง ระบุขอบเขตของผลตรวจเดิมเมื่อใช้ย้อนหลัง
4. เมื่อโครงสร้าง เทคโนโลยี คำสั่ง หรือกติกาพัฒนาเปลี่ยน ให้อัปเดต AGENTS.md ในงานเดียวกัน
5. เมื่อเพิ่ม ย้าย หรือลบไฟล์สำคัญ หรือเปลี่ยนหน้าที่ของไฟล์ ให้อัปเดต PROJECT_STRUCTURE.md ในงานเดียวกัน

## Skill ที่เกี่ยวข้อง

| งาน | Skill |
|---|---|
| ปรับ UI/UX | `oil-ui` + `ui-ux-pro-max` (อ่าน DESIGN.md ประกอบ) |
| วางแผนฟีเจอร์ใหม่ | `brainstorming` + `using-superpowers` |
| debug ปัญหา | `systematic-debugging` |
| implement ฟีเจอร์ | `test-driven-development` + `executing-plans` |
| ก่อน claim งานเสร็จ | `verification-before-completion` |
| สื่อสารกระชับ | `caveman` |
| ดูแลเอกสาร | skill ด้านเอกสารที่มีใน session |

## ข้อจำกัดที่ต้องรักษา

- งาน UI **ห้ามแตะ** API, auth, storage, eligibility และสูตรคำนวณ เว้นแต่ผู้ใช้ขอเปลี่ยนพฤติกรรมนั้นโดยตรง
- หน้าประมาณการค่าแรงใช้สูตร **`ฐานเงินเดือน ÷ 30 วัน ÷ 8 ชม.`** (fallback `300 บาท / 8 ชม.` เมื่อพนักงานยังไม่มีค่า `salary`) คิดจากคู่สแกนครบก่อน 17:00 น. และแสดงเวลา bonus แยกจากยอดเงิน
- ใบลายังเป็นฟีเจอร์ทดลอง บันทึกในเครื่องเท่านั้น ไม่ส่ง Backend; หน้า Pay Simulator คำนวณฝั่งเครื่องเท่านั้นไม่เขียนลง DB
- `AppColors.textPrimary` **ไม่มี** — ใช้ `AppColors.neutral` หรือ `.withValues(alpha:)` แทน; ปุ่ม pill พื้นสี `AppColors.neutral` ให้ใช้ข้อความ `AppColors.onNeutral` เสมอ (เพื่อให้อ่านชัดในโหมด Obsidian Black)
- การอัปเดตเอกสาร `.md` ทุกครั้งต้องเขียนให้ **ละเอียดและตรงกับโค้ดจริงครบทุกไฟล์ที่เกี่ยวข้อง** (`TASK_STATUS.md`, `README.md`, `DESIGN.md`, `PROJECT_STRUCTURE.md`, `AGENTS.md`)
- Analyzer ยอมรับได้เฉพาะ `info` deprecation จาก SDK — ห้ามมี `warning` หรือ `error`
- Tests ต้องผ่านก่อน mark งานว่าเสร็จ

## ลำดับการทำ UI Task ใหม่

1. อ่าน README.md + TASK_STATUS.md + DESIGN.md
2. อ่าน skill `oil-ui` SKILL.md และ `ui-ux-pro-max` SKILL.md
3. ถ่ายภาพ before จาก emulator ก่อนแก้
4. แก้โค้ด (ห้ามแตะ services/models)
5. รัน `flutter analyze` ตรวจไม่มี error/warning
6. รัน `flutter test` ตรวจผ่านครบ
7. Build APK + install + ถ่ายภาพ after จาก emulator
8. อัปเดต TASK_STATUS.md, ตรวจ README.md, อัปเดต DESIGN.md ถ้าธีมเปลี่ยน
