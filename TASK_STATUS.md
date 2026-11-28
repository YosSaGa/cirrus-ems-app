# สถานะงาน Cirrus EMS

อัปเดตล่าสุด: 28 พฤศจิกายน 2026 (แก้ความปลอดภัย Local Bridge และป้องกันข้อมูลค้างสูญหาย)

ภาพรวมและวิธีรันดู [README.md](README.md) — ไฟล์นี้เป็นแหล่งหลักสำหรับสถานะงาน แยกสิ่งที่มีในโค้ดออกจากสิ่งที่ตรวจบนระบบจริงแล้ว กติกาการทำงานและคำสั่งสำคัญดู [AGENTS.md](AGENTS.md) แนวทาง UI ดู [DESIGN.md](DESIGN.md)

---

## สภาพแวดล้อมปัจจุบัน

| รายการ | ค่า |
|---|---|
| Flutter | 3.50.0 / Dart 3.14.0 ที่ `C:\Users\yossa\OneDrive\เอกสาร\CostCal\.tools\flutter` |
| คำสั่ง flutter | `F:\bin\flutter.bat` (alias จาก `subst F: "C:\..\.tools\flutter"`) |
| Emulator | Pixel 10 Pro XL API 35, `emulator-5554`, 1344×2992px |
| ADB | `"$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"` |
| Package | `com.cirrusgroup.ems` / `.MainActivity` |
| Backend | `https://api.cirrusmarine.site/api/v1/ems` (Android / Web / iOS ผ่าน HTTPS โดยตรง) |
| APK ล่าสุด | `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (21.96 MB) / `app-armeabi-v7a-release.apk` (20.13 MB) / `app-x86_64-release.apk` (23.35 MB) (ลดจาก `app-profile.apk` 113.92 MB / `app-debug.apk` 163.82 MB) |
| Screenshots | `.oil-ui/screenshots/*.png` |

---

## ทำแล้ว

- [x] ตรวจและบันทึกภาพรวม Flutter app กับการเชื่อมต่อ EMS Backend ภายนอก
- [x] ตั้ง API สำหรับ Android, Web และ iOS ไปที่ `192.168.1.13:3000/api/v1/ems`
- [x] เตรียม Flutter และเปิด Android Emulator รุ่น Pixel 10 Pro XL API 35
- [x] ระบบเดิมมี login/session, ลงเวลาพร้อมรูปและพิกัด, retry รายการค้าง, pending checkout, history และ profile
- [x] เพิ่ม Pay & Leave แบบทดลองฝั่งแอป โดยไม่เพิ่ม API เขียนข้อมูลค่าแรงหรือใบลา
- [x] ปรับหน้าประมาณการเป็นค่าแรงทดลองคงที่ 300 บาทต่อ 8 ชั่วโมง อ่านสแกนจาก API เดิมอัตโนมัติ และคิดตามนาทีที่มีคู่สแกนครบก่อน 17:00
- [x] แสดงเวลา bonus หลัง 17:00 แยกจากยอดเงิน ยังไม่คิดมูลค่าโบนัส
- [x] ตรวจรูปแบบเวลา ชั่วโมง 00–23 นาที/วินาที 00–59 ไม่รับ `08:70`
- [x] ใบลาเป็นแบบร่างในเครื่อง แยกตามผู้ใช้ มีประเภทลา ช่วงวันที่แบบเต็มวัน เหตุผล และยกเลิกได้; เลือกวันเดียวเพื่อลา 1 วัน
- [x] เปิดดูตัวอย่างและดาวน์โหลดหรือแชร์ PDF จากใบลาที่บันทึกในเครื่องได้ รวมใบที่ยกเลิก โดยระบุสถานะใน PDF และรองรับข้อความภาษาไทย
- [x] PDF Preview มีปุ่มแยก: **Download PDF** (บันทึกลง Downloads folder โดยตรง ผ่าน MediaStore API บน Android ≥29) และ **Share PDF** (เปิด share sheet ของระบบ)
- [x] UI ภาษาอังกฤษ และปรับด้วย Oil UI: ธีม navy/teal, หน้า Attendance/Login, navigation, ฟอร์มและข้อความสถานะ ดู [DESIGN.md](DESIGN.md)
- [x] Settings screen เปิดใช้งานจริงจากหน้า Profile: แบ่งสัดส่วนเป็นเมนูการตั้งค่า (PREFERENCES, SYSTEM, ABOUT) แล้วเจาะลึกเข้าไปยังหน้ารายละเอียดย่อย `ThemeSettingsScreen` เลือกระหว่าง 3 ธีม (Default Cirrus, Pure White, Obsidian Black) พร้อมระบบ persist ลง SharedPreferences สลับสีทั้งแอปแบบ real-time
- [x] แก้หน้าเนื้อหาแท็บค้างสีเก่าเมื่อเปลี่ยนเป็น Obsidian Black: แต่ละแท็บรับ theme notifier แล้ว rebuild ด้วย key คงที่ จึงอัปเดตสีทันทีโดยรักษา State ของหน้าไว้
- [x] แสดง `CHANGING THEME` พร้อม progress indicator ใน AppBar ประมาณ 220ms ก่อนเปลี่ยน palette และแสดง `THEME UPDATED` พร้อมไอคอน check 2 วินาทีหลังบันทึกค่าลงเครื่อง โดยไม่ใช้ full-screen loader
- [x] แก้ไขปัญหา UI ธีม:
  1. แก้แถบมืด/ดำแปลกปลอมเหนือ Bottom Nav ในธีม Obsidian Black ด้วยการเปิด `extendBody: true` บน Scaffold และปรับ `bottomNavShadow` palette token แยกเฉพาะแต่ละธีม
  2. แก้ปัญหา Bottom Nav ไม่อัปเดตสีทันทีตอนเปลี่ยนธีม โดยครอบด้วย `ValueListenableBuilder<AppThemeMode>` เพื่อให้เปลี่ยนสีทันทีโดยไม่ต้องรอเลื่อนหน้าจอ
  3. ปรับปรุง Role Badge ในธีมดำให้มองเห็นชัดเจนด้วย `roleBadgeBackground`, `roleBadgeForeground`, `roleBadgeIcon` tokens
  4. ปรับลำดับหน้า Settings ให้เป็นเมนูหลักก่อนเข้าไปยังหน้าเลือกธีม (Settings -> App Theme)
- [x] จัดเอกสารหลักสองไฟล์และกติกาให้อัปเดตหลังเปลี่ยนแปลง
- [x] Bottom Navigation micro-interaction: bubble ยุบ/เด้ง/no-duplicate icon ตาม Dribbble Concept
- [x] ปรับ UI/UX ทันสมัยหน้า History, Profile, Pay estimate, Local leave — card-based, pill selectors, icon badges, section labels (ดูรายละเอียดในประวัติการเปลี่ยนแปลง)

- [x] เพิ่มระบบสลับภาษาแสดงผล **ไทย / อังกฤษ** ใน Settings (`Settings > Language`) พร้อมฟอนต์ **IBM Plex Sans Thai** (4 น้ำหนัก: Regular, Medium, SemiBold, Bold) บันทึกค่าลง `SharedPreferences` (`ems.language`) และอัปเดตทุกแท็บแบบ real-time โดยไม่กระทบ API, auth, ข้อมูลในเครื่อง หรือสูตรคำนวณใดๆ
- [x] ปรับประสิทธิภาพการเรนเดอร์ 60 FPS (`RepaintBoundary` บน `AmbientPanel`, `LiveClock`, `AppBottomNav`, `PayWalletCard`, เปลี่ยน `FadeSlideEntry` เป็น `FadeTransition`, เปลี่ยน `HistoryScreen` เป็น `CustomScrollView` + `SliverList.builder` + precompute รายวัน) พร้อม Pull-to-Refresh, Shimmer Skeleton และ Haptic Feedback
- [x] ยกระดับหน้า `SplashScreen` เป็น **Animated Welcome Splash ธีม Cirrus (1.25 วิ)** และเพิ่มจังหวะปุ่มหมุน `700ms` + เฟด `260ms` ตอนเข้าสู่ระบบ/ออกจากระบบ
- [x] ปรับสูตรประมาณการค่าแรงเป็น **`ฐานเงินเดือน ÷ 30 วัน ÷ 8 ชม.`** (fallback `300 บาท / 8 ชม.` เมื่อ `salary` เป็น null) และสร้างหน้าเสริม **Pay Simulator (`PayCalculatorScreen`)** สำหรับจำลองเงินเดือน/วันฐาน/ชั่วโมงทำงานฝั่งเครื่องโดยไม่ยุ่ง Backend
- [x] เพิ่มระบบ **จัดการค่าแรงรายชั่วโมงและรายการหัก (`PayrollManagementScreen`)** เชื่อมต่อ PostgreSQL `cirrus_02` ผ่าน Local EMS Bridge (`.tools/ems_local_server.js`) รองรับการตั้งค่าเรทต่อชั่วโมงตรง (`hr.compensation`) หรือฐานเงินเดือน (`core.employees.salary`) และเพิ่ม/แก้ไข/เปิด-ปิด/ลบรายการหักมาตรฐาน 3 ตัว (**ค่าที่พัก**, **ค่าประกันสังคม % พร้อมเพดาน**, **ค่าประกันงาน**) และรายการกำหนดเอง (`hr.payroll_components`, `hr.employee_payroll_items`) จำกัดสิทธิ์เฉพาะ **HR (`HR Officer`), `Admin`, `Accountant`, `Owner`** (และ permission `payroll.create/update/delete`) พร้อมแสดงการ์ด **รายการหักและยอดสุทธิโดยประมาณ** ในหน้า `EarningsTrialTab` โดยไม่กระทบหน้า `PayCalculatorScreen`
- [x] เพิ่มระบบ **แบบฟอร์ม PDF ใบลา 2 ภาษา (`LeavePdfLanguage.th / en`)** ใน `lib/services/leave_pdf_builder.dart` และปุ่มสลับ **`แบบฟอร์มไทย (TH)` / `English Form (EN)`** ในหน้า PDF Preview (`lib/screens/leave_trial_tab.dart`) โดยแบบฟอร์มไทยจัดโครงเอกสารทางการ (`แบบฟอร์มใบลา`, เขียนที่/วันที่ พ.ศ., เรื่อง, เติมอัตโนมัติ **`เรียน หัวหน้าฝ่ายทรัพยากรบุคคล`**, ข้าพเจ้า/ตำแหน่ง/แผนก, ช่องติ๊กประเภทลา + เนื่องจาก, ตั้งแต่วันที่–ถึงวันที่–รวมเวลา, ขอแสดงความนับถือ/ลงชื่อ, ความคิดเห็นผู้บังคับบัญชา + ลงชื่อ/วันที่) และแบบอังกฤษเติม `To (Approver): HR Manager` พร้อมแยกชื่อไฟล์ดาวน์โหลด/แชร์ `-th.pdf` / `-en.pdf`
- [x] เพิ่ม **โหมดช่าง (`Technician` & `Admin`)** เชื่อมต่อ PostgreSQL `cirrus_02` โดยไม่แก้ schema (`operations.work_orders`, `operations.scheduled_jobs`, `hr.work_assignments`, `hr.work_sessions`, `operations.technician_reports`):
  - เลือก Job Code จากหน้า `TechnicianJobsScreen` (ปักหมุดงานตัวเองบนสุด + red badge แจ้งเตือนงานค้าง)
  - ปรับ flow เป็น **Check-In → Break พัก (พร้อมตัวเลือก "จะจบงานเลยไหม?" / กลับมาทำงานต่อ) → Check-Out** โดยคงเงื่อนไข OT/Bonus หลัง 17:00 เดิม
  - บังคับเขียน **รายงานการทำงาน (`TechnicianReportScreen`)** หลังจบงาน พร้อม **แนบรูปภาพการทำงานสูงสุด 4 รูป** (ถ่ายผ่าน `AttendanceCameraScreen` อัปโหลดผ่าน `AttendanceService.uploadAttendancePhoto` และเก็บใน `operations.technician_reports.photos` jsonb) และช่องกรอก **ปัญหาที่พบระหว่างทำงาน (`findings`)**
  - ดูย้อนหลังได้ที่ `Settings > Job & Report History` (`TechnicianHistoryScreen`) แสดงจำนวนรูปและกรอบไฮไลต์ปัญหาที่พบ พร้อมสร้าง Flowchart สรุประบบที่ `docs/attendance_flow_preview.html`

---

- [ ] **ดึงอัตราค่าแรงจริงจาก Backend** แทนอัตราทดลองในแอป — ต้องรู้ endpoint และ schema ก่อน
- [ ] **นโยบายเงินเดือนจริง** สำหรับวันลา วันหยุด ขาดงาน วันทำงานไม่เต็ม และการปิดรอบรายเดือน
- [ ] **เกณฑ์และมูลค่า bonus** สำหรับเวลาหลัง 17:00 — ปัจจุบันแสดงเฉพาะระยะเวลา ไม่คิดเงิน
- [ ] **เชื่อมใบลากับ Backend** เพื่อส่งคำขอจริง อนุมัติ และตรวจสิทธิวันลา
- [ ] **คำนวณเงินจ่ายจริง** ภาษี ประกันสังคม รายการหัก และปิดรอบเงินเดือนอย่างเป็นทางการ
- [ ] **สร้างไฟล์ SQL Migration + คู่มือ API `/payroll/*` ส่งมอบทีม IT/Backend จริง** — เตรียมไฟล์ migration สร้างตาราง `hr.employee_payroll_items` + seed 3 รายการ (`ACCOMMODATION`, `SOCIAL_SECURITY`, `WORK_INSURANCE`) ลง `hr.payroll_components` และสเปก 6 endpoints (`/payroll/*`) สำหรับขึ้นเซิร์ฟเวอร์จริง
- [ ] **ระบบตรวจสอบเวอร์ชันและอัปเดต APK ในแอป (In-App Self-Update)** — เทียบเวอร์ชันจาก `version.json` แล้วดาวน์โหลด/ติดตั้ง APK ใหม่สำหรับแจกใช้ภายในองค์กร (ไม่ผ่าน Play Store) คู่กับเว็บดาวน์โหลด APK และ Keystore กลาง
- [ ] **ทดสอบ end-to-end** กล้อง/GPS + ส่ง attendance จริง + ใบลา กับ Backend จริง

---

## ข้อจำกัดและสิ่งที่ยังไม่ได้ตรวจ

- ค่าแรงเป็นประมาณการจากสูตร `ฐานเงินเดือน ÷ 30 วัน ÷ 8 ชม.` (หรือ fallback `300 บาท / 8 ชม.` เมื่อพนักงานยังไม่มีค่า `salary` ในฐานข้อมูล) คูณเฉพาะคู่สแกนครบก่อน 17:00 น. ไม่ใช่สลิปเงินเดือนอนุมัติ ใบลาไม่ถูกส่งหัวหน้าหรือหักจากค่าแรง
- ข้อมูลทดลองในเครื่อง (แบบร่างใบลา, ค่าจำลอง Pay Simulator) ไม่ซิงก์ข้ามอุปกรณ์ Backend และฐานข้อมูลไม่ได้อยู่ในโปรเจคนี้
- หาก Backend ปิดหรือเข้าไม่ถึง จะใช้งานส่วนที่ต้องเรียก API ไม่ได้
- Settings เปิดใช้งานจริงแล้วสำหรับหมวด **App Theme** (Default, Pure White, Obsidian Black) และ **Language** (English, ภาษาไทย) ส่วนการตั้งค่า Admin อื่นๆ ยังอยู่ในแผนพัฒนา
- การตรวจ UI ล่าสุดไม่ได้ส่ง attendance จริง ไม่ได้ทดสอบกล้อง/GPS และใบลาแบบ end-to-end กับ Backend จริง
- `AppColors.textPrimary` ไม่มีใน codebase — ถ้าเพิ่มไฟล์ใหม่ให้ใช้ `AppColors.neutral` หรือ `.withValues(alpha:)` แทน

---

## ผลตรวจล่าสุด

| รายการ                                       | ผลและขอบเขต                                                                                                                                                                         |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **แบบฟอร์ม PDF ใบลา 2 ภาษา TH/EN + `เรียน หัวหน้าฝ่ายทรัพยากรบุคคล` (25 พ.ย. 2026)** | ฟอร์มใบลาไทยทางการ (พ.ศ. + เติมอัตโนมัติ `เรียน หัวหน้าฝ่ายทรัพยากรบุคคล`) และฟอร์มอังกฤษ (`To: HR Manager`) พร้อมปุ่มสลับ `TH / EN` สดในหน้า Preview และแยกชื่อไฟล์ `-th.pdf`/`-en.pdf` — `flutter analyze` 0 error/warning; `leave_pdf_builder_test.dart` (5/5) + `work_trial_screen_test.dart` (5/5) ผ่านครบ 10/10 tests ✅; ติดตั้ง `app-profile.apk` บน `emulator-5554` สำเร็จ |
| **ระบบจัดการค่าแรงรายชั่วโมง + รายการหัก HR/Admin/Accountant (25 พ.ย. 2026)** | RBAC (`HR Officer`, `Admin`, `Accountant`, `Owner` / `payroll.*`) + CRUD ค่าที่พัก/ประกันสังคม/ค่าประกันงานและเรทต่อชั่วโมงลง PostgreSQL `cirrus_02` — `flutter analyze` 0 error/warning; `payroll_management_test.dart` (4/4), `work_trial_screen_test.dart`, `pay_calculator_screen_test.dart`, `settings_screen_test.dart`, `auth_service_test.dart` ผ่านครบ 33/33 tests ✅; ติดตั้ง `app-profile.apk` บน `emulator-5554` สำเร็จ |
| **สูตรฐานเงินเดือน + Pay Simulator (25 พ.ย. 2026)** | สูตร `เงินเดือน ÷ 30 ÷ 8` (fallback 300/8 ชม.) + หน้าเสริม `PayCalculatorScreen` (ปุ่มลัด `+8 ชม.` และ `เต็มเดือน = วันฐาน × 8 ชม.` ได้เงินเดือนเต็มเป๊ะ) — `flutter analyze` 0 error/warning; `pay_calculator_screen_test.dart`, `payroll_calculator_test.dart`, `work_trial_screen_test.dart`, `ui_refresh_test.dart` ผ่านครบ 29/29 tests ✅; ติดตั้ง `app-profile.apk` บน `emulator-5554` สำเร็จ |
| **Animated Welcome Splash + Login/Logout Pacing (24 พ.ย. 2026)** | `SplashScreen` 1.25 วิ 3 จังหวะ + ปุ่ม Login/Logout หมุน 700ms + เฟด 260ms — `splash_screen_test.dart`, `ui_refresh_test.dart`, `settings_screen_test.dart` ผ่านครบทุกข้อ ✅ |
| **60 FPS Optimization + UX Polish (24 พ.ย. 2026)** | `RepaintBoundary` 5 จุด, `SliverList.builder` + precompute รายวันใน History, `ShimmerCardSkeleton`, Pull-to-Refresh 4 หน้า, Haptic Feedback, Dark Mode contrast — 31/31 tests ผ่านครบ ✅ |
| **ระบบสลับภาษา ไทย/อังกฤษ + IBM Plex Sans Thai (24 พ.ย. 2026)** | `LanguageService` + `AppStrings` + `LanguageSettingsScreen` (มินิมอลชิดบน) + ฟอนต์ IBM Plex Sans Thai 4 น้ำหนัก — `language_settings_test.dart` และชุดหลักรวม 31/31 tests ผ่านครบ ✅ |
| **ระบบสลับธีม 3 แบบ (23 พ.ย. 2026)** | Settings เปิดใช้งานจริง: เลือก Default (Navy/Teal), White (Pure Minimalist), Black (Obsidian Dark) พร้อม real-time reactivity — 26 tests ผ่านทั้งหมด ✅ |
| **แก้เนื้อหาแท็บค้างสีใน Obsidian Black (23 พ.ย. 2026)** | Dart analyze `lib/screens/main_shell.dart`: ไม่มี warning/error มี SDK deprecation info 1 รายการ; debug APK build และติดตั้งสำเร็จ; ตรวจ Attendance และ History บน Pixel emulator แล้วเป็น dark surfaces ทั่วหน้า ไม่ส่ง attendance จริง; รอบนี้ไม่ได้รัน automated tests |
| **สถานะการเปลี่ยนธีม (23 พ.ย. 2026)** | `test/settings_screen_test.dart` ผ่าน 5 tests; ชุดเต็มผ่าน 125 tests และ skip 1; analyzer ไม่มี warning/error มี SDK deprecation info 3 รายการ; debug APK build, ติดตั้ง และเปิดบน Pixel สำเร็จ. Widget tests ยืนยัน `CHANGING THEME` ก่อนเปลี่ยนและ `THEME UPDATED` หลังเปลี่ยน; ภาพ emulator หลัง build ยังตรวจหน้าธีมไม่ได้เพราะแอปกลับหน้า login และบัญชีที่ให้มาถูกปฏิเสธว่า invalid username/password |
| ปรับ PDF ใบลาให้เป็นทางการ (Formal layout) | ปรับหัวเอกสาร REF:, เส้น bottom-border เวกเตอร์, แถบหัวข้อ navy accent, กรอบ reason, ช่องลายเซ็นทางการ — PDF tests ผ่าน 10 ข้อ ✅ |
| **Download PDF ลงเครื่อง (23 พ.ย. 2026)** | ปุ่ม Download PDF บันทึกไฟล์ไปยัง Downloads folder โดยตรง (Android ≥29 ใช้ MediaStore via MethodChannel, fallback ใช้ path_provider) แยกจากปุ่ม Share PDF — 23 tests ผ่านทั้งหมด ✅ |
| ปรับ UI/UX ทันสมัย History, Profile, Pay, Leave | card-based layout, pill selector, icon badges, section labels, teal ring avatar — ภาพยืนยัน refresh-earnings/history/profile/leave.png ✅ |
| ปรับ Bottom Navigation ยุบลงตอนกด & ตัดไอคอนซ้ำ | ฟองลอยยุบตัวลงในรอยเว้าขณะเคลื่อนที่และแตะกด (sink 22px, scale 0.72) เด้งขึ้นปลายทาง ไม่มีไอคอนซ้ำระหว่างสลับแท็บ |
| Flutter tests (UI modernize + Bottom Nav)    | `app_bottom_nav_test.dart` 5 ข้อ, `ui_refresh_test.dart` 5 ข้อ, `widget_test.dart` 1 ข้อ รวม 11 ข้อผ่านทั้งหมด |
| Dart analyzer ของไฟล์ที่แก้                  | ไม่มี error หรือ warning มี info deprecation ตาม SDK ปกติเท่านั้น |
| Emulator Pixel 10 Pro XL API 35              | Build APK สำเร็จ, ติดตั้งผ่าน ADB ยืนยันทุกแท็บผ่าน screencap — nav, history, profile, pay, leave ถูกต้อง |
| Flutter tests รอบปรับ UI ก่อนหน้า            | ผ่าน 21 ข้อ: attendance/retry, progress, navigation, pay/leave และ accessibility ที่เกี่ยวข้อง |
| ตรวจไฟล์ที่เกี่ยวข้องกับ Backend             | ไม่มีการแก้ไข API, services, models, auth หรือ storage ใดๆ คงพฤติกรรมเดิม 100% |
| **Entry Animations (รอบ 2 — 20 พ.ย. 2026)** | ทุกหน้าได้รับ FadeSlideEntry / flutter_animate, login_screen ได้ stagger delay ผ่าน Interval curve, tests 87 ข้อผ่านทั้งหมด ✅ |

## ประวัติการเปลี่ยนแปลง

### 28 พฤศจิกายน 2026 — ปิดช่องโหว่/บั๊ก Services + UI/Obsidian Contrast + รองรับฟิลด์ Dispatch ล่วงหน้า + QoL หน้างาน

- **Services & Models (`attendance_service.dart`, `payroll_service.dart`, `auth_service.dart`, `technician_service.dart`, `work_timer_notification_service.dart`, `theme_service.dart`, `payroll_calculator.dart`):**
  - **ปัญหา → วิธีแก้:** HTTP บางจุดไม่มี timeout เสี่ยงล็อกค้าง per-user → เพิ่ม `.timeout` (20s/15s/`uploadTimeout`); `TechnicianService` ดึงแบบไม่แบ่งหน้า + `_getHistoryFromNestApi` ไม่ resolve `teamMemberId` → เพิ่ม `_getPaginatedList` (`limit=200`, สูงสุด 5 หน้า), รองรับฟิลด์จาก `004_db_first_alignment.sql` (`jobCode`, `shiftDate`, `startTime`, `endTime`, `location`, `taskDescription`) ล่วงหน้า, และ resolve `/team-members` ในหน้าประวัติ; `switchToAccount` ทับข้อมูลใหม่ด้วย snapshot เก่า + token หมดอายุไม่ถูกล้าง → ใช้ snapshot ที่รีเฟรชแล้วและ prune token เกิน 5 วันอัตโนมัติ; `WorkTimerNotificationService` จำ `_lastKey` ก่อนเช็คสิทธิ์ผ่าน → ตั้ง `_lastKey` เฉพาะเมื่อ `showWorkTimer` คืน `true`; `ThemeService` แยก key Haptics จาก `AppPreferencesService` → รวมศูนย์ผ่าน `AppPreferencesService`; `PayrollAdjustmentItem.computeSatang` / `calculateScanPay` → ดัก `isFinite` และ normalize วันที่ขอบเขตรอบจ่าย
- **UI Bugs, Leaks, Obsidian Black Contrast & QoL (`attendance_screen.dart`, `technician_report_screen.dart`, `technician_jobs_screen.dart`, `technician_history_screen.dart`, `payroll_management_screen.dart`, `earnings_trial_tab.dart`, `leave_trial_tab.dart`, `attendance_camera_screen.dart`, `login_screen.dart`, `profile_screen.dart`, `saved_accounts_screen.dart`):**
  - **ปัญหา → วิธีแก้:** จบงานจาก Break ส่ง `jobStatusAtCheckout: null` และ `_technicianCheckOut` ขาด `vesselName` → สร้าง `completedSession` ครบถ้วน; ช่างสแกนตรงไม่ผ่านแล้วไม่มีปุ่ม Retry/Discard → เพิ่มการ์ด `technician-pending-attendance-card`; `PopScope` รายงานยอมให้กด Back ระหว่างส่ง → ล็อก `!_submitting`; `mounted` guard หลัง `await` ใน `attendance_screen.dart`, `dispose()` 4 controller ใน `payroll_management_screen.dart`, `try/catch` + Pull-to-Refresh เรท/รายการหักใน `earnings_trial_tab.dart`; `_metaRow` ล้นจอใน `technician_jobs_screen.dart` → ใช้ `Flexible`; แก้ contrast ธีม Obsidian Black (spinner, `CircleAvatar`, stepper icon)
  - **QoL ใหม่:** แตะซูมดูรูปเต็มจอ + ปุ่มลบใน `TechnicianReportScreen`, ปุ่ม `Details` บนการ์ด `YOUR JOB` ใน `TechnicianJobsScreen`, และปุ่ม `Reset filters` + แตะคัดลอก `Job Code` ใน `TechnicianHistoryScreen`
- **ผลตรวจ:** `flutter analyze --no-fatal-infos` ทั้ง 18 ไฟล์ที่แก้ → **0 error / 0 warning** (มีเฉพาะ SDK `deprecated_member_use` `info`), `flutter test` ทั้ง 7 ชุด (`auth_service_test`, `payroll_management_test`, `payroll_calculator_test`, `technician_attendance_test`, `work_trial_screen_test`, `settings_screen_test`, `ui_refresh_test`) → **ผ่านครบ 86/86 ข้อ**
- ตรวจ `README.md` แล้ว ภาพรวมโครงสร้างและ backend ยังตรงกัน

### 28 พฤศจิกายน 2026 — ลบค่า `localhost` / Local Bridge fallback ทั้งหมด ให้ต่อตรง Production API

- **สิ่งที่เปลี่ยน (`.env`, `lib/services/auth_service.dart`, `lib/services/payroll_service.dart`):**
  - ลบ `QUOTATIONS_URL=http://localhost:5000` ออกจาก `.env`
  - เพิ่ม `AuthService.defaultProductionBaseUrl` (`https://api.cirrusmarine.site/api/v1/ems`), ตัด trailing `/` ใน `resolveBaseUrl`, และเปลี่ยน `platformDefault` ของ Web/Android/iOS/Desktop จาก `localhost:3000` / `10.0.2.2:3000` เป็น Production URL ทั้งหมด
  - ลบ `_isLocalBridge` และสาขา `/payroll/my-config` ออกจาก `PayrollService.getMyPayrollConfig()` ให้เรียก `GET /compensation` ตรงฐานข้อมูลจริงเสมอ
- **ปัญหาที่พบ → วิธีแก้ไข:** เดิมโค้ดยังมี fallback URL ชี้ไป `localhost:3000` / `10.0.2.2:3000` และเช็ค `_isLocalBridge` ค้างไว้ (รวมถึง Desktop ที่ไม่อ่าน `.env`) → เปลี่ยน fallback ทั้งหมดเป็น `https://api.cirrusmarine.site/api/v1/ems` และอ่าน `.env` บน Desktop ด้วย
- **ผลตรวจ:** ค้นหา `localhost|127.0.0.1|10.0.2.2|:3000` ใน `lib/` และ `.env` พบ `0` รายการ, `flutter analyze --no-fatal-infos lib/services/auth_service.dart lib/services/payroll_service.dart` ผ่าน `0` warning/error, `flutter test test/auth_service_test.dart test/payroll_management_test.dart` ผ่านครบ `25/25` ข้อ
- ตรวจ `README.md` แล้ว ภาพรวมการเชื่อมต่อยังชี้ `https://api.cirrusmarine.site/api/v1/ems` ตรงกัน

### 28 พฤศจิกายน 2026 — ตรวจและแก้ความปลอดภัยกับการกู้คืนข้อมูล

- **Local Bridge:** ปัญหา token เดิมปลอมได้และมีรหัสผ่านทดสอบที่ใช้เข้าสู่บัญชีได้ แก้โดยลงลายเซ็น HMAC ด้วยกุญแจชั่วคราว ตรวจลายเซ็นก่อนอ่าน user ID ใช้รหัสผ่านจากฐานข้อมูลเท่านั้น และจำกัดการเชื่อมต่อที่ localhost การรีสตาร์ต Bridge ทำให้ token เดิมหมดอายุ
- **สลับบัญชี:** เดิมข้อผิดพลาดเครือข่ายทำให้ล้าง token บัญชีปลายทางและเปลี่ยน session ก่อนตรวจสำเร็จ แก้ให้ตรวจ token ก่อนสลับ เก็บ token เมื่อเครือข่ายหรือเซิร์ฟเวอร์ขัดข้อง และล้าง token เฉพาะเมื่อเซิร์ฟเวอร์ตอบ 401
- **รายการลงเวลาค้าง:** เดิมการล้าง session ลบรายการที่ยังส่งไม่สำเร็จ แก้ให้เก็บรายการแยกตามผู้ใช้ พร้อมปรับข้อความเตือนให้อธิบายการกลับมาเข้าสู่บัญชีเดิม
- **รายงานช่าง:** เดิมเมื่อ API ขอให้ยืนยันสถานะ ระบบส่ง completed อัตโนมัติ แก้ให้ใช้สถานะจาก work session และแจ้งให้รีเฟรชเมื่อสถานะไม่ชัดเจน
- **ตรวจแล้ว:** เทสต์ทั้งโปรเจกต์ผ่าน 170 ข้อ ข้าม 1 ข้อ ชุดเฉพาะไฟล์ที่เกี่ยวข้องผ่าน 81 ข้อ Analyzer ทั้งโปรเจกต์ไม่มี error/warning มี info 61 รายการ ซึ่งรวม lint ที่มีอยู่เดิม Analyzer 6 ไฟล์ที่แก้พบเฉพาะ SDK deprecation 3 รายการ ตรวจ syntax Bridge ด้วย `node --check` และตรวจ token ที่ถูกต้องกับ token ปลอมด้วย Node ผ่าน
- **ยังไม่ได้ทำ:** token ใน SharedPreferences ยังไม่ได้ย้ายไป secure storage รูปแนบรายงานยังไม่ได้เก็บเป็นร่างถาวร และยังไม่ได้ยืนยัน idempotency กับ Backend จริง ไม่ได้ทดสอบ end-to-end กับ Backend จริงรอบนี้
- ตรวจและอัปเดต README.md แล้ว ภาพรวมโครงสร้างไฟล์ไม่เปลี่ยน

### 26 พฤศจิกายน 2026 (รอบ 33) — ปรับ Flow โหมดช่างเป็น Check In / Break พัก (พร้อมถามจบงานเลยไหม) / Check Out + สร้างไฟล์ Flowchart HTML
- **Backend Bridge (`.tools/ems_local_server.js` — Zero DB Migration):**
  - เพิ่ม `POST /api/v1/ems/technician/break` (พักเบรก/พักเที่ยง: บันทึก `job_status_at_checkout = 'on_break'` ใน `hr.work_sessions` + ซิงก์ `lunch_out` ลง `hr.device_scans` โดยยังไม่ล็อกให้เขียนรายงานระหว่างพัก)
  - เพิ่ม `POST /api/v1/ems/technician/end-from-break` (กรณีช่างเลือก "จบงานเลย" ระหว่างพัก: ปิดสถานะงาน `in_progress/completed` แล้วเข้าสู่หน้าบังคับเขียนรายงาน)
  - อัปเดต `GET /api/v1/ems/technician/my-jobs` คืน `breakSession` และ `POST /technician/check-in` ปรับสถานะ `on_break → resumed` อัตโนมัติเมื่อกลับเข้าทำงานรอบบ่าย
- **Flutter UI เฉพาะโหมดช่าง (`lib/widgets/technician_attendance_section.dart`, `lib/screens/attendance_screen.dart`, `lib/services/technician_service.dart`):**
  - ระหว่างทำงานแสดงปุ่มหลัก **`CHECK OUT`** คู่กับปุ่ม **`พักเบรก / พักเที่ยง (Take a Break)`**
  - ระหว่างพัก (`ON BREAK`) แสดงปุ่มหลัก **`RESUME WORK / กลับเข้าทำงาน`** คู่กับการ์ดข้อความถาม **"กำลังพักอยู่ — วันนี้จะจบงานเลยไหม?"** พร้อมปุ่ม **`จบงานเลยและเขียนรายงาน`** (คงสูตรค่าแรง & OT/โบนัสหลัง 17:00 น. เดิม 100%)
- **Interactive Flowchart:** สร้าง `docs/attendance_flow_preview.html` แผนผัง Flowchart + ตัวจำลองกดเล่นได้จริง
- เพิ่ม widget test เคส `ON BREAK` ใน `test/technician_attendance_test.dart` พร้อมอัปเดต `README.md`

### 26 พฤศจิกายน 2026 (รอบ 32) — Optimize ความลื่นหน้า Splash → Attendance บนมือถือจริง (60/120fps)
- **Lazy Tab Hydration (`lib/screens/main_shell.dart`):** เปลี่ยน `MainShell` ให้สร้างเฉพาะแท็บแรก (`AttendanceScreen`) ตอนเปิดแอป และค่อยสร้างแท็บอื่น (`History`, `Pay & Leave`, `Profile`) เมื่อผู้ใช้กดเข้าครั้งแรก (พร้อมคง State ไว้ใน `IndexedStack` เหมือนเดิม) ลดภาระสร้าง widget tree + ยิง API พร้อมกัน 4 หน้าตอนเปลี่ยนจาก Splash → Attendance ลง ~75%
- **Zero `saveLayer` บน Splash (`lib/screens/splash_screen.dart`):** เปลี่ยน `Opacity` 3 จุดเป็น `FadeTransition` + `ScaleTransition` + `SlideTransition` และแยก `RepaintBoundary` ออกจาก `AnimatedBuilder` ลดการสร้าง offscreen GPU buffer ทุกเฟรม
- **Smooth Reveal Transition (`lib/widgets/session_transition.dart`):** เปลี่ยน `splashRevealTransition` จาก `ScaleTransition` (ที่ทำให้ต้อง re-rasterize ทั้งหน้า) เป็น GPU-composited `FadeTransition` + `SlideTransition` (`0.025 → 0`, `340ms`, `Curves.easeOutQuart`) พร้อม `RepaintBoundary`
- **Responsive Mobile Polish (`lib/widgets/app_bottom_nav.dart`, `lib/widgets/time_action_button.dart`):**
  - เพิ่มแผ่นไล่เฉดจางสีพื้นหลัง (`AppColors.primary` 0% → 88% → 100%) รองหลัง Floating Bottom Nav ให้เนื้อหาที่เลื่อนลงด้านล่างจางหายเนียนตาไม่โผล่ตัดครึ่งหลังปุ่ม (รองรับครบทั้ง 3 ธีม)
  - ปรับขนาดปุ่มวงกลม `TimeActionButton` ย่ออัตโนมัติ ~12% (`150–174dp`) บนมือถือที่ความสูงใช้งานต่ำกว่า `760dp` (เช่น มือถือที่มีแถบปุ่ม Android 3 ปุ่ม) เพื่อให้ไทม์ไลน์ 4 ช่วงด้านล่างมองเห็นชัดขึ้น
- ตรวจ `README.md` แล้ว (ภาพรวมยังตรง ไม่ต้องแก้เพิ่ม); ทดสอบบน `splash_screen_test.dart`, `ui_refresh_test.dart`, `settings_screen_test.dart`, `app_bottom_nav_test.dart` และติดตั้ง `app-profile.apk` ลงทั้งมือถือจริง `192.168.1.97:5555` และ `emulator-5554`

### 25 พฤศจิกายน 2026 (รอบ 31) — ปิดงานอัตโนมัติเมื่อเลือก `Completed` (ลดเลขแจ้งเตือนแดง) + หน้าประวัติงานและรายงานช่างใน Settings
- **ปิดงานอัตโนมัติ & ลดเลขจุดแดง (`.tools/ems_local_server.js`, `lib/widgets/technician_attendance_section.dart`):**
  - เมื่อช่างกด Check Out พร้อมเลือก **`Completed`** ระบบจะอัปเดต `operations.work_orders.status = 'completed'` (หรือ `operations.scheduled_jobs.status = 'completed'`) ใน `cirrus_02` และกรองงานที่ปิดแล้วออกจากคิวงานเปิด ทำให้ตัวเลขแจ้งเตือนสีแดง (`N YOURS`) ลดลงอัตโนมัติ (`2 → 1 → หายไป`)
- **ประวัติงานและรายงานช่าง (`lib/screens/technician_history_screen.dart`, `lib/screens/settings_screen.dart`, `lib/services/technician_service.dart`):**
  - เพิ่ม `GET /api/v1/ems/technician/history` (ช่างเห็นเฉพาะงานและรายงานของตัวเอง, `Admin` เห็นของทุกคนพร้อมชิปกรอง `All Technicians / My Jobs Only`)
  - เพิ่มเมนู **`Job & Report History / ประวัติงานและรายงานช่าง`** ใต้หมวด `TECHNICIAN` ในหน้า `Settings` แสดงเฉพาะ Role **`Technician` และ `Admin`** เท่านั้น
- เพิ่ม widget test ใน `test/technician_attendance_test.dart` พร้อมอัปเดต `PROJECT_STRUCTURE.md`, `README.md`, `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 30) — บังคับเขียนรายงานหลัง Check Out (เที่ยง & เย็น) ก่อนเริ่มงานถัดไป
- **Backend Bridge & Zero DB Migration (`.tools/ems_local_server.js`):** บันทึกรายงานลงตารางจริง `operations.technician_reports` (ผูก `work_session_id` กับ `hr.work_sessions` โดยตรง):
  - เพิ่ม `POST /api/v1/ems/technician/reports` (บันทึก `work_description`, `work_type`, `findings`, `recommendations`, `hours_worked`, `status = 'submitted'`, `report_kind = 'field'`)
  - อัปเดต `GET /api/v1/ems/technician/my-jobs` คืน `pendingReportSession` หากมี session ที่ checkout แล้วแต่ยังไม่ได้ส่งรายงาน
  - อัปเดต `POST /api/v1/ems/technician/check-in` ตรวจล็อกฝั่งเซิร์ฟเวอร์ (`409 PENDING_TECHNICIAN_REPORT`) ห้ามเช็คอินงานใหม่จนกว่าจะส่งรายงานงานก่อนหน้า
- **Flutter Screen & UI Gate (`lib/screens/technician_report_screen.dart`, `lib/services/technician_service.dart`, `lib/widgets/technician_attendance_section.dart`, `lib/screens/attendance_screen.dart`):**
  - ระบบคำนวณช่วงเวลา (`morning_in` / `lunch_out` / `afternoon_in` / `leave`) **อัตโนมัติตามเวลาจริงประเทศไทย** ทั้งฝั่งเซิร์ฟเวอร์และหน้าแอป (ก่อน 14:00 น. ล็อกเป็น `Lunch Break Out`, ตั้งแต่ 14:00 น. หรือรอบบ่ายล็อกเป็น `End of Day (Leave)`) ไม่ให้ช่างเลือกช่วงเวลาเองเพื่อป้องกันข้อมูลเพี้ยน
  - หลัง Check Out (ทั้ง **พักเที่ยง** และ **ออกงานเย็น**) เด้งเข้าหน้า `TechnicianReportScreen` อัตโนมัติทันที (เลือกประเภทงาน + บังคับกรอกรายละเอียดงานที่ทำ ≥ 5 ตัวอักษร + ปัญหาที่พบ/ข้อเสนอแนะ)
  - หากกดย้อนกลับโดยยังไม่ส่งรายงาน หน้า Attendance จะ **ล็อกการ์ดเลือก Job Code และปุ่ม Check In** พร้อมแสดงการ์ดเตือนสีเหลือง-ส้ม `WORK REPORT REQUIRED` และปุ่ม **`Write & Submit Report`** จนกว่าจะส่งรายงานเรียบร้อย
- **แก้ไขเพิ่มเติม & ยกระดับหน้ากล้อง (`lib/screens/attendance_camera_screen.dart`, `.tools/ems_local_server.js`):**
  - แก้ `UPDATE hr.work_sessions` ใน Bridge โดยไม่เขียนทับคอลัมน์ `duration_minutes` (เพราะเป็น Generated column ใน `cirrus_02`)
  - ปรับหน้าถ่ายรูป `AttendanceCameraScreen`: ใช้พื้นหลังเข้มคงที่ (`#0A141E`) รองรับครบ 3 ธีม, เพิ่มแถบหัวข้อ (`Attendance Photo` / `Review Photo`), กรอบพรีวิวมน `24px`, และแก้ปุ่ม **`Retake` / `ถ่ายใหม่`** (ตัวอักษรขาวชัด) คู่กับปุ่ม **`Use Photo` / `ใช้รูปนี้`** สี Turquoise เด่นชัด
- เพิ่ม widget test ตรวจ flow ล็อกงานและปลดล็อกหลังส่งรายงานใน `test/technician_attendance_test.dart` พร้อมอัปเดต `PROJECT_STRUCTURE.md`, `README.md`, `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 29) — หน้ารายการ Job Code ทั้งหมด + หน้าดูรายละเอียดงานแยก (ปักหมุดงานของตัวเองเด่นบนสุด)
- **Backend Bridge (`.tools/ems_local_server.js`):** อัปเดต `GET /api/v1/ems/technician/my-jobs` ให้คืน Job Code ทั้งหมดในระบบพร้อมฟิลด์ `isMine`, `assignedToName`, `priority`, `scheduleStart`, `scheduleEnd`, `description`, `location` โดยเรียงให้ `isMine = true` ขึ้นบนสุดเสมอ (ยังคงล็อกสิทธิ์ Check In เฉพาะงานของตัวเอง) และแก้ cast `device_user_code::text` + seed ตัวอย่าง Job ให้บัญชีช่างที่ Active ครบทุกคน
- **หน้าใหม่ (`lib/screens/technician_jobs_screen.dart`):**
  - `TechnicianJobsScreen`: แสดงรายการ Job Code ทั้งหมดพร้อมช่องค้นหา แยกหมวด **งานที่มอบหมายให้คุณ (`YOUR JOB`)** เป็นการ์ดฮีโร่สี Deep Navy (`AmbientPanel`) แตะแล้ว **เลือกเด้งกลับหน้า Attendance พร้อมเช็คอินทันที** (แตะซ้ำเพื่อยกเลิกได้ใน 1 แตะ) โดยแถบ `JOB CODE` ด้านบนปุ่ม Check In กระชับ 1 บรรทัด และแสดงรายละเอียดงานเต็ม (`TechnicianSelectedJobDetails`: ชื่องาน, `description`, กำหนดการ, สถานที่, ความสำคัญ) ไว้ในการ์ดล่างคู่กับไทม์ไลน์และ `Today's Activity` ส่วน **งานอื่นในระบบ (`OTHER JOBS`)** เป็นการ์ดสีขาวกระชับ แตะเข้าไปดูรายละเอียดใน `TechnicianJobDetailScreen` ได้
  - `TechnicianJobDetailScreen`: หน้าแยกแสดงรายละเอียดงานเต็ม (Job Code, สถานะ, รายละเอียดงาน `description`, ผู้รับผิดชอบ, กำหนดการ, สถานที่, ความสำคัญ) พร้อมปุ่ม **เลือกงานนี้เพื่อเช็คอิน** และปุ่ม **ยกเลิกการเลือกงานนี้ (`Unselect This Job`)** รวมถึงปุ่ม `×` ยกเลิกการเลือกเร็วบนการ์ดหน้า Attendance ซึ่งจะปิดปุ่ม Check In กลับทันทีจนกว่าจะเลือกงานใหม่ (ส่วนงานของคนอื่นแสดงเป็นดูอย่างเดียว)
- อัปเดต `lib/services/technician_service.dart`, `lib/widgets/technician_attendance_section.dart` (เพิ่มจุดแจ้งเตือนสีแดงพร้อมตัวเลขจำนวนงานของตัวเอง + ป้าย `N YOURS / N งานของคุณ` บนการ์ด JOB CODE เมื่อยังไม่ได้เลือกงาน และหายไปเองหลังเลือก/เช็คอิน), `lib/main.dart` (ปิดเอฟเฟกต์ Android 12+ overscroll stretch ด้วย `_NoStretchScrollBehavior` เพื่อไม่ให้การ์ดยืดเวลาดึงรีเฟรช), `test/technician_attendance_test.dart`, `PROJECT_STRUCTURE.md`, `README.md`, `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 28) — ระบบลงเวลาช่างตาม Job Code (เฉพาะ Role `Technician` และ `Admin`)
- **Role Gating (`lib/services/auth_service.dart`):** เพิ่ม `AuthService.hasTechnicianRole(roles)` และ `AuthService.isTechnician()` จำกัดโหมดลงเวลาช่างเฉพาะบัญชีที่มี Role `Technician` หรือ `Admin` เท่านั้น (Role อื่นยังใช้หน้า Attendance เดิม 100%)
- **Local EMS Bridge & Zero DB Migration (`.tools/ems_local_server.js`):** ใช้ตารางที่มีอยู่แล้วใน `cirrus_02` (`hr.work_assignments`, `operations.work_orders`, `operations.scheduled_jobs`, `hr.work_sessions`, `hr.device_scans`) โดยไม่ต้องสร้างตารางใหม่ เพิ่ม 3 endpoints ที่ตรวจสิทธิ์ Role `Technician` / `Admin` และกรองเฉพาะงานที่มอบหมายให้ผู้ใช้นั้น (`user_id = me`):
  - `GET /api/v1/ems/technician/my-jobs` (ดึงเฉพาะ Job Code ของตัวเอง + session วันนี้ + ช่วงที่ลงเวลาแล้ว)
  - `POST /api/v1/ems/technician/check-in` (ตรวจสิทธิ์ความเป็นเจ้าของ Job + เปิด `hr.work_sessions` พร้อม GPS/รูป + ซิงก์ `morning_in`/`afternoon_in` ลง `hr.device_scans`)
  - `POST /api/v1/ems/technician/check-out` (ปิด `hr.work_sessions` + คำนวณ `duration_minutes` + เก็บ GPS/รูป/สถานะงาน + ซิงก์ `lunch_out`/`leave` ลง `hr.device_scans`)
  - Seed ตัวอย่างงานที่มอบหมายให้บัญชีช่าง `Touch` (`JOB-2611-101`, `JOB-2611-102`) และบัญชี `Admin` (`JOB-2611-201`, `JOB-2611-202`) แยกของใครของมันสำหรับทดสอบ
- **Flutter Service & UI (`lib/services/technician_service.dart`, `lib/widgets/technician_attendance_section.dart`, `lib/screens/attendance_screen.dart`):**
  - แสดงป้าย badge **`TECHNICIAN / โหมดช่าง / JURUTEKNIK`** บนหัวการ์ด `AmbientPanel` ของหน้า Attendance เฉพาะบัญชีช่าง
  - การ์ดเลือก **MY JOB CODE** (แสดงเฉพาะงานของตัวเอง) → เลือก Job Code เพื่อปลดล็อกปุ่ม Check In (ถ่ายรูป + อัปโหลด + เก็บ GPS) → ช่วงเที่ยง/เย็นกด Check Out เลือกได้ทั้ง **พักเที่ยง (`lunch_out`)** หรือ **ออกงานเย็น (`leave`)** พร้อมสถานะงาน (`In Progress` / `Completed`) → บ่ายเข้างานต่อ Job เดิมหรือเปลี่ยน Job ได้ → แสดงประวัติ Job วันนี้และพิกัด GPS ในการ์ด Today's Activity
- **Tests & Docs:** เพิ่ม `test/technician_attendance_test.dart` (4 ข้อ ครอบคลุม Role gating, เลือก Job Code ของตัวเอง, และ Check Out พักเที่ยง/ออกงานเย็น) พร้อมอัปเดต `README.md`, `PROJECT_STRUCTURE.md` และ `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 27) — ขัดเกลาสัดส่วนตัวอักษร ไอคอน และแสงสมมาตรหน้า Profile
- เพิ่มโหมด `AmbientPanel(centered: true)` ใน `lib/widgets/ambient_panel.dart` (Deep Navy ไล่เฉดบน-ล่าง + แสง radial glow สี Turquoise และวงแหวนบางสมมาตรตรงกลางหลัง Avatar `J`) และเปิดใช้งานบนหน้า Profile (`lib/screens/profile_screen.dart`) เพื่อให้สายตาเห็นความสมดุลกึ่งกลางเป๊ะ โดยคงลายคลื่นด้านขวาเดิมไว้สำหรับหน้า Attendance/Login
- ปรับสัดส่วนข้อมูลใน `Account & Employment` (`lib/screens/profile_screen.dart`): ลดขนาด `Employee Code` และ `Phone` จาก `21pt → 16pt` และลด `User ID` จาก `15pt → 13pt` ให้สมดุลกับป้ายชื่อและขนาดตัวอักษรทั้งหน้า
- ครอบไอคอนหน้า `Settings` ในการ์ด `General` ด้วยกรอบสี่เหลี่ยมโค้งพื้น Teal อ่อนชุดเดียวกับ `Account & Employment`
- ปรับชื่อพนักงานบน `AmbientPanel` ให้รองรับชื่อยาว (`maxLines: 2`, `TextOverflow.ellipsis`) ขนาด `28pt` (EN) / `24pt` (TH) และกระชับระยะห่างแนวตั้ง (`padding` / `SizedBox`) ให้ปุ่ม `Log Out` หายใจโล่งขึ้นเหนือ Bottom Nav
- ตรวจ `README.md` แล้ว (ภาพรวมหน้า Profile ตรงกับโค้ดล่าสุดแล้ว ไม่ต้องแก้เพิ่ม); `flutter analyze` 0 error / 0 warning (เฉพาะ SDK deprecation info); `flutter test test/ui_refresh_test.dart test/settings_screen_test.dart` ผ่านครบ 17/17 ข้อ และติดตั้ง `app-profile.apk` ลง Emulator แล้ว

### 25 พฤศจิกายน 2026 (รอบ 26) — ปรับหน้า Profile

- สร้างและติดตั้ง Profile APK บน Pixel 10 Pro XL API 35 ตรวจหน้า Profile ธีม Cirrus Signature ภาษาอังกฤษจากภาพก่อนและหลังที่ `.oil-ui/screenshots/profile-before-hero.png` และ `.oil-ui/screenshots/profile-after-hero.png` ยืนยันการจัดกึ่งกลางและลำดับข้อมูลบนเครื่องจำลอง
- การ์ดแสดงตัวพนักงานใช้ `AmbientPanel` ร่วมกับ Attendance วางอักษรย่อ ชื่อ อีเมล และป้ายบทบาทกึ่งกลาง ชื่อขนาด 30 logical pixels อีเมลยังเลือกคัดลอกได้
- ส่วน Account & Employment เรียงรหัสพนักงาน เบอร์โทร และ User ID ตามลำดับ ข้อมูลสองแถวแรกใช้ขนาด 21 และ User ID ใช้ขนาด 15 ปุ่มคัดลอกมีพื้นที่แตะอย่างน้อย 48 × 48 logical pixels
- ตรวจและปรับ README.md และ DESIGN.md ตามหน้าจอที่แก้ ชุดทดสอบเต็มรอบสุดท้ายผ่าน 140 ข้อ ข้ามชุดจับภาพที่ต้องเปิดด้วยตัวแปรเฉพาะ 1 ข้อ Analyzer ของหน้า Profile พบเฉพาะ SDK deprecation 1 รายการ ผลตรวจทั้งโปรเจกต์ก่อนปรับการจัดกึ่งกลางพบ info 57 รายการ (SDK deprecation 51 และ lint ด้านรูปแบบ 6) ไม่มี warning หรือ error

### 25 พฤศจิกายน 2026 (รอบ 25) — เพิ่มปุ่ม `Switch Account` เหนือ Log Out + Micro-Animations 60fps
- **Switch Account 5 วัน (`lib/services/auth_service.dart`, `lib/screens/profile_screen.dart`, `lib/screens/login_screen.dart`):**
  - บันทึกรายชื่อบัญชีที่เคยเข้าใช้งานบนเครื่องสูงสุด 6 บัญชี (`ems.recentAccounts`, ไม่เก็บรหัสผ่าน): หากสลับกลับมาภายใน **5 วัน** (`switchSessionMaxAge`) สลับเข้า `MainShell` ได้ทันทีโดยไม่ต้องกรอกรหัสผ่านใหม่
  - หากบัญชีนั้นไม่ได้ใช้งานเกิน **5 วัน** (หรือเคยกด `Log Out`) จะพาไปหน้า `LoginScreen(lockedAccount: ...)` ซึ่ง **ซ่อนช่องกรอก Username** แล้วแสดงการ์ดระบุชัดเจนว่า **`กำลังใส่รหัสผ่านของบัญชี <ชื่อ> (<username>)`** ให้พิมพ์เฉพาะรหัสผ่าน (พร้อมปุ่ม `เปลี่ยนไปใช้บัญชีอื่น`)
- **Subtle 60fps Micro-Animations:**
  - `PayWalletCard`: เฟดสลับนุ่มๆ (`AnimatedSwitcher` 150ms) เมื่อแตะปุ่มรูปตา 👁️ ซ่อน/แสดงยอดเงิน
  - `TimeActionButton`: แอนิเมชันยุบตัวเบาๆ (`AnimatedScale` 0.965, 90ms) ตอนนิ้วกดปุ่ม Check In
  - `EarningsTrialTab`: แอนิเมชันสไลด์ + เฟด (`AnimatedSwitcher` 180ms) ตอนเปลี่ยนเดือน `<` / `>`

### 25 พฤศจิกายน 2026 (รอบ 24) — ชุดกัน Human Error + ยกระดับ QoL รอบแอป
- **กัน Human Error (`lib/screens/payroll_management_screen.dart` & `lib/screens/pay_calculator_screen.dart`):**
  - เพิ่ม Dialog ยืนยันก่อนลบรายการหักออกจากฐานข้อมูล, ล็อกเปอร์เซ็นต์ไม่เกิน `0–100%`, เตือนเมื่อเพิ่มรายการซ้ำ, แสดงข้อความ error ชัดใต้ช่องกรอก, เตือนเมื่อกดย้อนกลับทั้งที่ยังไม่ได้กด `Save rate`, และเตือนยืนยันเมื่อกรอกเรทต่อชั่วโมงสูงผิดปกติ (`> 5,000 บาท/ชม.`)
  - ล็อกช่อง `Minutes` ใน `PayCalculatorScreen` ให้อัตโนมัติไม่เกิน `59`
- **QoL & Performance รอบแอป:**
  - **Check In Pulse (`lib/widgets/time_action_button.dart`):** เปลี่ยนจาก `Opacity` เป็น alpha บน `Border.all` โดยตรง ตัด `saveLayer` ทิ้งเป็น 0 ลดโหลด GPU บน Emulator/มือถือ
  - **ซ่อน/แสดงยอดเงิน (`lib/widgets/pay_wallet_card.dart`):** เพิ่มปุ่มไอคอนรูปตา 👁️ บนการ์ดค่าแรง สลับแสดง `THB ••••••` ได้ทันที
  - **Payroll Management (`lib/screens/payroll_management_screen.dart`):** เพิ่มช่องค้นหาพนักงาน (`Search`) และการ์ด **Live Net Preview (240 ชม.)** แสดงยอดก่อนหัก/หักรวม/ยอดสุทธิสดๆ
  - **Local Leave (`lib/screens/leave_trial_tab.dart`):** เพิ่มปุ่มลัดเหตุผลการลา (`Quick Reason Chips`) 3 แบบ และป้ายเตือนเมื่อเลือกวันลาย้อนหลัง
  - **Profile & Attendance (`lib/screens/profile_screen.dart`, `lib/screens/attendance_screen.dart`):** เพิ่มปุ่มแตะคัดลอก (`Copy`) ข้างข้อมูลสำคัญพร้อม Toast แจ้งเตือน และเพิ่ม **Dialog ยืนยันก่อนออกจากระบบครบทั้ง 2 จุด** (ปุ่ม `Log Out` ใน Profile และเมนู `Sign out` มุมขวาบนหน้า Attendance พร้อมเตือนสีแดงพิเศษหากมีรายการลงเวลาค้างส่งอยู่)
  - **Appearance (`lib/screens/appearance_settings_screen.dart`, `lib/services/theme_service.dart`, `lib/main.dart`):** เพิ่มการปรับขนาดตัวอักษร (`Text Size`: เล็ก/ปกติ/ใหญ่) และสวิตช์เปิด-ปิด `Haptic Feedback`

### 25 พฤศจิกายน 2026 (รอบ 23) — Auto-Refresh History/Pay หลังลงเวลา + เพิ่มภาษาที่ 3 `Bahasa Melayu (MS)`
- **Auto-Refresh ไม่ต้องกดรีเฟรชเอง:** เพิ่ม `AttendanceService.attendanceUpdatedNotifier` ใน `lib/services/attendance_service.dart` ให้แจ้งเตือนทุกครั้งที่ส่ง Check-in / Check-out (หรือ Retry) สำเร็จ โดย `lib/screens/history_screen.dart` และ `lib/screens/earnings_trial_tab.dart` ฟัง notifier นี้เพื่อรีโหลดประวัติสแกนและยอดค่าแรงอัตโนมัติทันที
- **เพิ่มภาษาที่ 3 — มาเลเซีย (`Bahasa Melayu / MS`):** เพิ่ม `AppLanguage.ms` ใน `lib/services/language_service.dart`, พจนานุกรมคำแปล + รูปแบบวันที่/เดือน/เวลาภาษามาเลย์ครบทุกหน้าใน `lib/l10n/app_strings.dart`, และการ์ดตัวเลือก `MS · Bahasa Melayu` ใน `lib/screens/language_settings_screen.dart`
- อัปเดต `test/language_settings_test.dart`, `README.md` และ `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 22) — แก้ Check Constraint ตอนส่ง Check-in ใน Local EMS Bridge
- แก้ `.tools/ems_local_server.js`: เปลี่ยนค่า `INSERT INTO hr.device_scans` จาก `flag = 'normal', source = 'mobile_app'` เป็น `flag = NULL, source = 'app'` ให้ตรงกับ check constraints จริงของ `cirrus_02` (`chk_device_scans_flag` และ `chk_device_scans_source`) ทำให้กด Check-in พร้อมรูปและพิกัด GPS ผ่าน 100%

### 25 พฤศจิกายน 2026 (รอบ 21) — แก้จังหวะเปลี่ยนหน้าจาก Splash เข้าแอปให้สมูท (Seamless Cross-Fade + Scale)
- อัปเดต `lib/widgets/session_transition.dart`: เพิ่ม `splashRevealTransition` (420ms `FadeTransition` + `ScaleTransition 0.965 → 1.0`, `Curves.easeOutCubic`) โดยไม่วาง `ColoredBox` สีขาวทึบทับหน้า Splash สีกรมท่า ทำให้เปลี่ยนจาก Splash เข้า `MainShell` / `LoginScreen` ได้สมูทไร้รอยตัด
- อัปเดต `lib/screens/splash_screen.dart`: เริ่ม `_introController.forward()` หลังเฟรมแรกพร้อม (`addPostFrameCallback`) เพื่อให้แอนิเมชันเปิดแอปแสดงครบไม่โดนเฟรมเปิดเครื่องกลืน และเปลี่ยนมาใช้ `splashRevealTransition`

### 25 พฤศจิกายน 2026 (รอบ 20) — เมนู `Appearance` (App Theme + ปรับแต่งสีบัตร `PayWalletCard` 5 แบบ)
- อัปเดต `lib/services/theme_service.dart`: เพิ่ม `PayCardStyle` 5 เฉดสีพรีเมียม (`Cirrus Navy`, `Obsidian Gold`, `Emerald Slate`, `Midnight Indigo`, `Royal Burgundy`) พร้อม `payCardStyleNotifier`, `setPayCardStyle(...)` และ persist ลง `SharedPreferences` คีย์ `ems.payCardStyle`
- อัปเดต `lib/widgets/pay_wallet_card.dart`: ฟัง `ThemeService.payCardStyleNotifier` เพื่อสลับสีไล่เฉด, เงา และสีตัวเลขยอดเงินของบัตรค่าแรงแบบ real-time ด้วย `AnimatedContainer`
- สร้าง `lib/screens/appearance_settings_screen.dart` (`AppearanceSettingsScreen` + `PayCardStyleScreen`): จัดกลุ่ม **App Theme** และ **Pay Card Style** ไว้ใต้เมนู **Settings → Appearance (รูปลักษณ์)** โดยหน้า **Pay Card Style** แสดงรูปบัตร `PayWalletCard` จริงด้านบน (แตะพลิก 3D ได้) และแถววงกลมสี 5 แบบด้านล่าง แตะเปลี่ยนสีสดทันทีพร้อม Haptic Feedback
- อัปเดต `lib/screens/settings_screen.dart` และ `test/settings_screen_test.dart` (เพิ่มเคสทดสอบ `Appearance` + `PayCardStyleScreen`); อัปเดต `PROJECT_STRUCTURE.md`, `README.md`, `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 19) — แอนิเมชันคลื่นกระเพื่อมปุ่ม Check In (`TimeActionButton`)
- อัปเดต `lib/widgets/time_action_button.dart`: เพิ่มแอนิเมชันวงคลื่นสี Turquoise กระเพื่อมเบาๆ (`0.96 → 1.15`, รอบละ 2.2 วินาที) พร้อม halo breathing (`1.0 → 1.025`) เฉพาะตอนที่ช่วงเวลาเปิดให้ลงเวลา (`enabled && !loading`) ครอบด้วย `RepaintBoundary` เพื่อคงความลื่น 60fps และหยุดอัตโนมัติในโหมดลดการเคลื่อนไหว (Reduced Motion) หรือขณะรัน widget tests

### 25 พฤศจิกายน 2026 (รอบ 18) — แบบฟอร์ม PDF ใบลา 2 ภาษา (แบบฟอร์มไทยทางการ + English Form) พร้อมเติมอัตโนมัติ `เรียน หัวหน้าฝ่ายทรัพยากรบุคคล`
- อัปเดต `lib/services/leave_pdf_builder.dart`: เพิ่ม `LeavePdfLanguage { th, en }` และแยกเทมเพลต PDF 2 แบบ:
  - **แบบฟอร์มไทย (`LeavePdfLanguage.th`):** ใช้ฟอนต์ **TH Sarabun PSK** (`THSarabunPSK-Regular.ttf` / `Bold.ttf`) ขนาดมาตรฐานราชการไทย (หัวข้อ 21pt, เนื้อหา 16pt) จัดโครงตามแบบฟอร์มใบลาทางการไทย (หัวเรื่อง `แบบฟอร์มใบลา` + โลโก้ `CIRRUS GROUP` ใน `lib/assets/cirrus_group_logo.png`, เขียนที่ **`Cirrus Marine Co.,Ltd`** / วันที่ พ.ศ. ชิดแนวตรงกัน, `เรื่อง ขออนุญาตลาหยุดงาน`, เติมอัตโนมัติ **`เรียน หัวหน้าฝ่ายทรัพยากรบุคคล`**, จัดคอลัมน์ 2 แถวตรงกัน: `ข้าพเจ้า / ตำแหน่ง` และ `แผนก / รหัสพนักงาน`, ช่องติ๊กประเภทลา + `เนื่องจาก` แนวนอนเต็มบรรทัด, ตั้งแต่วันที่–ถึงวันที่–รวมเวลา กึ่งกลางเส้นประ, ขอแสดงความนับถือ/ลงชื่อ, ความคิดเห็นของฝ่ายทรัพยากรบุคคลเส้นประเต็มหน้ากระดาษ + ลงชื่อ/วันที่)
  - **แบบฟอร์มอังกฤษ (`LeavePdfLanguage.en`):** ปรับโครงเอกสารทางการแบบเดียวกับแบบฟอร์มไทย (A4, โลโก้ Cirrus + `LEAVE REQUEST FORM` ไม่มีป้าย Draft, `Location: Cirrus Marine Co.,Ltd`, `Date`, `Subject: Request for Leave of Absence`, `To: HR Manager`, แถวคู่ `Name / Position` และ `Department / Employee ID`, ช่องติ๊ก `Leave Type`, `Reason`, `From / To / Total`, `Sincerely yours`, `Human Resources Comments`, และ `Signature / Date`)
- อัปเดต `lib/screens/leave_trial_tab.dart`: ยกระดับ `_LeavePdfPreview` เป็น `StatefulWidget` เพิ่มแถบปุ่มสลับ **`แบบฟอร์มไทย (TH)` | `English Form (EN)`** ด้านบนหน้า Preview เพื่อดูตัวอย่างสลับภาษาสดๆ ล็อกขนาดกระดาษ A4, เพิ่มปุ่ม **Print PDF** (`Printing.layoutPdf`) คู่กับ **Download PDF** และ **Share PDF**, ตั้งชื่อไฟล์เป็น **`ใบลา_<รหัสพนักงาน>.pdf`** (และ `ใบลา_<รหัสพนักงาน>_EN.pdf` สำหรับภาษาอังกฤษ), ปรับข้อความใบลาซ้อนวันให้ตัด `Bad state:` ออก และตั้ง `SnackBar` หลังบันทึกใบลาให้ปิดเองใน 3 วินาที (`persist: false`)
- เพิ่ม unit tests ใน `test/leave_pdf_builder_test.dart` (รวม 5 tests ครอบคลุมทั้งแบบฟอร์มไทย/อังกฤษ, ข้อมูลว่าง, ยกเลิก และเหตุผลยาว 1,000 ตัวอักษร) พร้อมอัปเดต `TASK_STATUS.md`, `PROJECT_STRUCTURE.md` และ `README.md`

### 25 พฤศจิกายน 2026 (รอบ 17) — ระบบจัดการค่าแรงรายชั่วโมงและรายการหัก (ค่าที่พัก / ประกันสังคม / ค่าประกันงาน) + RBAC (HR / Admin / Accountant)
- **Local EMS Bridge & PostgreSQL (`cirrus_02`):** อัปเดต `.tools/ems_local_server.js` ให้สร้างตาราง `hr.employee_payroll_items` อัตโนมัติ, seed รายการมาตรฐาน 3 ตัวลง `hr.payroll_components` (`ACCOMMODATION`, `SOCIAL_SECURITY`, `WORK_INSURANCE`), และเพิ่ม API endpoints: `GET /payroll/my-config`, `GET/POST/DELETE /payroll/components`, `GET /payroll/employees`, `PATCH /payroll/employees/:id/rate`, `POST /payroll/employees/:id/items`, `PATCH/DELETE /payroll/items/:itemId` พร้อมตรวจสิทธิ์ RBAC (`Admin`, `HR Officer`, `Accountant`, `Owner` หรือ `payroll.create/update/delete`)
- **Models & Services:** เพิ่ม `PaySettings.fromHourlyRate`, `PayrollAdjustmentItem` (รองรับทั้งยอดบาทคงที่และ `%` พร้อม `maxCap`), `PayrollNetSummary` ใน `lib/models/payroll_calculator.dart`; เพิ่ม `getSavedRoles()`, `getSavedPermissions()`, `hasPayrollManageAccess()`, `canManagePayroll()` ใน `lib/services/auth_service.dart`; สร้าง `lib/services/payroll_service.dart`
- **UI & Screens:** สร้าง `lib/screens/payroll_management_screen.dart` สำหรับเพิ่ม/แก้/เปิด-ปิด/ลบเรทต่อชั่วโมงและรายการหักของพนักงานแต่ละคน พร้อมปุ่มลัด 3 รายการมาตรฐาน; วางเมนู **Payroll & Deductions** ไว้ใน `Profile > Settings > MANAGEMENT` (`lib/screens/settings_screen.dart`, แสดงเฉพาะผู้มีสิทธิ์); อัปเดต `lib/screens/earnings_trial_tab.dart` ให้รองรับเรทต่อชั่วโมงตรงและแสดงการ์ด `_PayrollDeductionsCard` (สรุปค่าแรงก่อนหัก - รายการหัก = ยอดสุทธิโดยประมาณ) โดยไม่วางการ์ดจัดการซ้ำในหน้า Pay Estimate และคงหน้า `PayCalculatorScreen` ไว้เหมือนเดิม
- **การตรวจ GPS:** ยืนยันว่าแอปมีระบบ GPS one-shot อยู่แล้ว (`lib/services/location_service.dart` via `geolocator`) และในฐานข้อมูล `cirrus_02` (`hr.device_scans`) มีข้อมูลพิกัดจริงจากแอปบันทึกอยู่แล้ว 14 รายการ
- **Tests & Docs:** เพิ่ม `test/payroll_management_test.dart` (4 tests ผ่านครบ), อัปเดต `TASK_STATUS.md`, `PROJECT_STRUCTURE.md`, `README.md` และ `AGENTS.md`

### 25 พฤศจิกายน 2026 (รอบ 16) — ปรับสูตรประมาณการค่าแรงตามฐานเงินเดือน (เงินเดือน ÷ 30 ÷ 8) + หน้าเสริม Pay Simulator
- อัปเดต `lib/models/payroll_calculator.dart`: เพิ่ม `PaySettings.fromMonthlySalary(...)` (`เงินเดือน ÷ 30 วัน ÷ 8 ชม.`) และ `PaySettings.forEmployeeSalary(...)` (ใช้ฐานเงินเดือนจริงจาก `/auth/me` เมื่อมีค่า > 0 และ fallback ไปใช้อัตราทดลอง `300 บาท / 8 ชม.` เมื่อเป็น `NULL` โดยไม่แก้ Backend/API)
- อัปเดต `lib/screens/earnings_trial_tab.dart`: แสดงอัตราค่าแรงจากฐานเงินเดือนจริง + สมการ 2 ขั้นใน **How this is calculated**, คืนปุ่ม **Refresh** ให้เต็มขนาด 40px และวางการ์ดเมนู **Pay Simulator / คำนวณค่าแรงเอง** (`Key('open-pay-calculator')`) ไว้ 1 แถวใต้การ์ด How this is calculated
- สร้างหน้าเสริม `lib/screens/pay_calculator_screen.dart` (`PayCalculatorScreen`): จำลองการคำนวณค่าแรงฝั่งแอป 100% ตามสูตรฐานเงินเดือนมาตรฐาน `8 ชม./วัน` (ปรับฐานเงินเดือน, วันฐาน `30 / 26 / 22` วัน และชั่วโมง/นาทีที่ทำจริง พร้อมปุ่มลัด `+8 ชม.`, `เต็มเดือน (วันฐาน × 8 ชม.)` ที่ได้เงินเดือนเต็มเป๊ะและ auto-sync ชั่วโมงเมื่อสลับวันฐานขณะอยู่โหมดเต็มเดือน, และปุ่ม `เดือนนี้`)
- ติดตั้ง Official Skills สำหรับ AI Agent (`flutter/skills` และ `dart-lang/skills`) ลงใน `.agents/skills/` เฉพาะโปรเจกต์นี้ (ไม่กระทบ `pubspec.yaml` หรือตัวแอป)
- เพิ่ม `test/pay_calculator_screen_test.dart` และอัปเดต `test/work_trial_screen_test.dart`; อัปเดต `PROJECT_STRUCTURE.md` (ตรวจ `README.md` แล้ว)

### 24 พฤศจิกายน 2026 (รอบ 15) — Animated Welcome Splash Screen ธีม Cirrus (1.25 วิ)
- ยกระดับ `lib/screens/splash_screen.dart` เป็นแอนิเมชันเปิดแอป 3 จังหวะ (1.25 วินาที, 60fps ผ่าน `AnimationController` + `RepaintBoundary`): พื้นหลัง Deep Navy radial glow, โลโก้ Cirrus เด้งพร้อมวงแหวนแสง Turquoise แผ่ระลอก, ชื่อแบรนด์ + เส้นเน้น Turquoise ขยายจากกลาง + คำโปรย 2 ภาษา และแถบโหลด `LinearProgressIndicator` ก่อนเฟดเข้าหน้า `MainShell` หรือ `LoginScreen`
- กำหนด `minDisplayDuration: Duration(milliseconds: 1250)` ใน `lib/main.dart` (คงค่าเริ่มต้น `Duration.zero` ใน `SplashScreen` เพื่อให้ `test/splash_screen_test.dart` ผ่านครบโดยไม่ต้องแก้ test และข้ามหน่วงอัตโนมัติในโหมด reduced motion)
- ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน

### 24 พฤศจิกายน 2026 (รอบ 14) — ยกระดับ UX/UI, Layout, Micro-interactions และ Lazy 60 FPS
- สร้าง `lib/widgets/shimmer_box.dart` (`ShimmerBox` / `ShimmerCardSkeleton`) สำหรับแสดง skeleton loading แทนวงกลมหมุนในหน้า History และ Profile (รองรับ reduced motion)
- เพิ่ม **Pull-to-Refresh (`RefreshIndicator`)** ในหน้า `Attendance`, `History`, `Pay estimate` และ `Profile`
- เพิ่ม **Haptic Feedback** ตอนสลับแท็บ (`AppBottomNav`), พลิกการ์ดค่าแรง 3D (`PayWalletCard`), กดลงเวลา (`TimeActionButton`) และเลือกธีม/ภาษา (`ThemeSettingsScreen`, `LanguageSettingsScreen`) พร้อม **Animated Number Roll** บนยอดประมาณการค่าแรง
- ยกระดับ `lib/screens/history_screen.dart`: เปลี่ยนเป็น `CustomScrollView` + `SliverList.builder` (lazy rendering), precompute ข้อมูลต่อวัน (`_DailyScanSummary`) ครั้งเดียวตอนโหลดสแกน, ย่อปุ่ม `Recalculate` เป็น pill กะทัดรัด และย่อแถบ empty summary ให้กระชับ
- ยกระดับ `lib/screens/profile_screen.dart`: รวม Phone + User ID + Employee Code เป็นการ์ดเดียว (`Account & Employment`) ให้เห็นปุ่ม `Settings` และ `Log Out` ชัดขึ้น และแสดงทั้งธีมและภาษาใน subtitle ของ `Settings`
- แก้ contrast ในโหมดมืด (`Obsidian Black`) ของ TabBar ใน `WorkTrialScreen` และ filter pills ใน `LeaveDraftsScreen` ให้ใช้ `AppColors.onNeutral` แทน `Colors.white`
- ปรับลำดับความเด่นการ์ด `_WorkingHoursCard` ใน `lib/screens/history_screen.dart`: ดัน **`Hours Used for Pay`** (`ชั่วโมงที่ใช้คำนวณค่าแรง`) ขึ้นด้านบนด้วยฟอนต์ใหญ่เด่น 38px สี Turquoise และลดขนาด **`Total Working Hours`** (`ชั่วโมงทำงานรวม`) ลงมาเป็นฟอนต์รอง 20px ด้านล่าง พร้อมล็อกแนวคอลัมน์ไอคอน (46px) ให้ตรงกันทั้งสองแถว
- ปรับหน้า `lib/screens/language_settings_screen.dart` ให้มินิมอลชิดบนใต้ AppBar เหลือเฉพาะป้าย `EN`/`TH` + ชื่อภาษา (`English` / `ภาษาไทย`) + ป้าย `ACTIVE` (ตัดชื่อฟอนต์และกล่องตัวอย่างออก)
- เพิ่มจังหวะ loading นุ่มนวลในปุ่ม (`Signing in…` / `กำลังเข้าสู่ระบบ…` และ `Signing out…` / `กำลังออกจากระบบ…`) ขั้นต่ำ 700ms + เฟด 260ms + Haptic Feedback ก่อนเปลี่ยนหน้า Login ↔ MainShell ใน `lib/screens/login_screen.dart`, `lib/screens/profile_screen.dart`, `lib/widgets/primary_cta_button.dart` และ `lib/widgets/session_transition.dart` (ข้ามการหน่วงอัตโนมัติเมื่อเปิด reduced motion)
- ผลตรวจ: `flutter analyze` 12 ไฟล์ 0 error/warning, `flutter test` 6 ไฟล์รวม 31 tests ผ่านครบ ✅, Build `--profile` APK (AOT) และติดตั้งลง `emulator-5554` สำเร็จ; อัปเดต `PROJECT_STRUCTURE.md` (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 13) — Optimize ประสิทธิภาพการเรนเดอร์ 60 FPS (ไม่กระทบดีไซน์และ Backend)
- `lib/widgets/ambient_panel.dart`: ครอบ `RepaintBoundary` รอบพื้นหลัง gradient + `_SculptedBackdrop` (`MaskFilter.blur`) และส่งสีธีมเข้า painter เพื่อ cache texture บน GPU ครั้งเดียว
- `lib/widgets/live_clock.dart`: ครอบ `RepaintBoundary` รอบนาฬิกาที่อัปเดตทุก 1 วินาที เพื่อไม่ให้ดึง `AmbientPanel` ด้านหลัง repaint ตาม
- `lib/widgets/fade_slide_entry.dart`: เปลี่ยนจาก `Opacity` เป็น `FadeTransition` และคืน `widget.child` ตรงๆ ทันทีเมื่อแอนิเมชันจบ (`v >= 1.0`) ลด offscreen `saveLayer` บนทุกการ์ด
- `lib/widgets/app_bottom_nav.dart` และ `lib/widgets/pay_wallet_card.dart`: ครอบ `RepaintBoundary` แยก layer แอนิเมชัน bubble/notch และแอนิเมชันพลิกการ์ด 3D ออกจากหน้าจอหลัก
- `lib/screens/history_screen.dart`: memoize ผลจัดกลุ่มสแกนรายวัน (`_groupedScans`) ใน `_loadScans` แทนการ sort/group ใหม่ทุกครั้งที่ `build()`
- ผลตรวจ: `flutter analyze` 6 ไฟล์ 0 error/warning, `flutter test` 6 ไฟล์รวม 31 tests ผ่านครบ ✅, Build `--profile` APK (AOT) และติดตั้งลง `emulator-5554` สำเร็จ (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 12) — เพิ่มระบบสลับภาษา ไทย/อังกฤษ ใน Settings พร้อมฟอนต์ IBM Plex Sans Thai
- ดาวน์โหลดและติดตั้งฟอนต์ **IBM Plex Sans Thai** (Regular 400, Medium 500, SemiBold 600, Bold 700 + OFL license) ใน `assets/fonts/` และประกาศใน `pubspec.yaml` (คง `BebasNeue` สำหรับภาษาอังกฤษและคง `Sarabun` สำหรับ Leave PDF เดิม)
- สร้าง `lib/services/language_service.dart` (`AppLanguage.en` / `AppLanguage.th`, default เป็น `en`, persist ใน `SharedPreferences` คีย์ `ems.language`) และ `lib/l10n/app_strings.dart` (`AppStrings` แปลเฉพาะข้อความแสดงผล ไม่แตะค่าที่เก็บหรือส่ง Backend)
- สร้าง `lib/screens/language_settings_screen.dart` และเชื่อมต่อเข้ากับเมนู **Language** ใน `lib/screens/settings_screen.dart` (รูปแบบเดียวกับ `ThemeSettingsScreen` พร้อมแถบสถานะ `UPDATING` / `UPDATED` ใน AppBar)
- เชื่อม `LanguageService.languageNotifier` เข้ากับ `lib/main.dart`, `lib/theme/app_theme.dart` (สลับ `fontFamily` เป็น `IBMPlexSansThai` และปรับ `letterSpacing` เป็น 0 เมื่อใช้ภาษาไทย), `lib/screens/main_shell.dart`, `lib/widgets/app_bottom_nav.dart`, `lib/widgets/app_side_nav.dart` และแปลข้อความแสดงผลครบทุกหน้าหลัก (`Attendance`, `History`, `Earnings & Leave`, `PayWalletCard`, `Local Leave`, `All Leave Drafts`, `Profile`, `Settings`, `App Theme`, `Login`)
- เพิ่ม `test/language_settings_test.dart` (4 tests) — ผลตรวจ: `flutter analyze` 0 error / 0 warning (มีเฉพาะ SDK deprecation `info`), `flutter test` 6 ไฟล์รวม 31 tests ผ่านครบ ✅, Build Debug APK และติดตั้งลง `emulator-5554` สำเร็จ
- เก็บรายละเอียดภาษาไทยเพิ่ม: เปลี่ยนช่วง `leave` บนไทม์ไลน์เป็น **`เลิกงาน`**, เว้นวรรคคำทักทาย **`คุณ <ชื่อ>`**, ปรับวันเริ่มงานหลังการ์ด Pay เป็น **`06 ต.ค. 2026`** และปรับหน่วยชั่วโมงฝั่งแสดงผลใน History / Pay estimate เป็น **`ชม. น.`** (ไม่แตะสูตรคำนวณ); ตรวจ `flutter analyze` 0 error/warning, `flutter test` 20/20 ผ่าน, ติดตั้ง APK ลง `emulator-5554` แล้ว
- อัปเดต `README.md`, `DESIGN.md` และ `PROJECT_STRUCTURE.md`

### 24 พฤศจิกายน 2026 (รอบ 11) — แสดงแบบร่างใบลาล่าสุด 2 ใบใน Local leave + หน้าแยก All Leave Drafts
- สร้างหน้าแยก `lib/screens/leave_drafts_screen.dart` (`LeaveDraftsScreen`) แสดงแบบร่างใบลาทั้งหมดพร้อมตัวกรอง **`All` / `Active` / `Cancelled`** และรองรับเปิดดู PDF / ยกเลิกใบลาได้โดยตรง
- สร้างการ์ดแบบร่างแบบกระชับ `LeaveDraftCard` จับปุ่ม `View PDF` (ซ้าย) และ `Cancel draft` (ขวา) ให้อยู่แถวเดียวกัน ลดความสูงของการ์ดลงเกือบครึ่ง
- ปรับ `lib/screens/leave_trial_tab.dart` ให้แสดงเฉพาะ **2 ใบล่าสุด** ใต้ฟอร์ม พร้อมปุ่ม `View all (N)` เปิดไปหน้า `LeaveDraftsScreen` และรีเฟรชรายการอัตโนมัติเมื่อกดย้อนกลับ
- เพิ่ม widget test ใน `test/work_trial_screen_test.dart`; อัปเดต `DESIGN.md` และ `PROJECT_STRUCTURE.md` (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 10) — ปรับหน้า History (Deep Navy Hero Card, ตัดชั่วโมงซ้ำ, แสดงเวลาไทย +07:00)
- เปลี่ยนการ์ดสรุปชั่วโมงบนสุด (`_WorkingHoursCard`) ใน `lib/screens/history_screen.dart` เป็น Deep Navy `AmbientPanel` (ตัวเลข `Total Working Hours` สีขาว, `Hours Used for Pay` สี Turquoise) ให้เข้าชุดกับหน้า Attendance และ Pay Wallet Card
- เปลี่ยนป้ายมุมขวาบนในการ์ดรายวัน (`_DailyScanRow`) จากตัวเลขชั่วโมงที่ซ้ำกับคอลัมน์ `WORKING HOURS` เป็นป้ายจำนวนสแกน (`2 scans` / `4 scans`) พร้อมไอคอน fingerprint
- ปรับ `_formatDeviceLocalTime` ให้แสดงเวลาไทย Bangkok `+07:00` เพื่อให้เวลาสแกนตรงกับเวลาทำงานจริงแม้เครื่องจำลองตั้ง timezone เป็น UTC
- ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน; อัปเดต `DESIGN.md`

### 24 พฤศจิกายน 2026 (รอบ 9) — เพิ่มเส้นสีความคืบหน้า (Progress Track) บนไทม์ไลน์ 4 ช่วงหน้า Attendance
- เปลี่ยนเส้นเชื่อมไทม์ไลน์ 4 ช่วงใน `lib/screens/attendance_screen.dart` จากเส้นเทา 1px เป็นแถบ progress หนา 3px ที่เปลี่ยนสีตามสถานะจริง (`AppColors.success` สำหรับช่วงที่บันทึกแล้ว, `AppColors.secondary` สำหรับเส้นที่นำเข้าสู่ช่วงที่เปิดอยู่, muted navy สำหรับช่วงที่ผ่านแล้ว และ `AppColors.cardBorder` สำหรับช่วงที่ยังไม่ถึง) พร้อมเพิ่มขอบและ glow อ่อนที่จุดปัจจุบัน
- ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน

### 24 พฤศจิกายน 2026 (รอบ 8) — แสดง Base Salary + ข้อมูลการจ้างงาน (ชุดที่ 2) บนหลังการ์ด PayWalletCard
- ปรับหลังการ์ด `PayWalletCard` แสดง 4 ช่องจริงจาก `cirrus_02`: **`BASE SALARY`** (`core.employees.salary` หรือ `NOT SET`), **`DEPARTMENT`**, **`EMPLOYMENT`**, และ **`START DATE`** (`06 OCT 2026`) โดยยังไม่เปลี่ยนสูตรคำนวณทดลอง 300 บาท/8 ชม. ด้านหน้าบัตร
- เพิ่ม `e.salary` ใน response ของ `.tools/ems_local_server.js` (`/auth/login`, `/auth/me`) และให้ `earnings_trial_tab.dart` ดึง `AuthService.fetchMe()` แบบ silent หาก cache ยังไม่มีฟิลด์ `salary`
- อัปเดต `test/work_trial_screen_test.dart` และ `DESIGN.md` (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 7) — ปรับหน้า Attendance (Deep Navy Clock Hero + ปุ่มวงกลมลอยมีมิติ) และรีเซ็ตหน้าบัตร Pay เมื่อสลับแท็บ
- ปรับ `lib/widgets/time_action_button.dart`: ปลดปล่อยปุ่มวงกลม Check In ออกจากการ์ดสี่เหลี่ยมขาว ย่อสัดส่วนเป็น 172–202px พร้อมวงแหวนรัศมีซ้อน 2 ชั้น (concentric halo ring), ไล่เฉดสี Turquoise/Teal และเงา 3 มิติ พร้อม pill hint ด้านล่าง
- ปรับ `lib/screens/attendance_screen.dart`: เพิ่มการ์ดนาฬิกา Deep Navy (`AmbientPanel`) ด้านบนรวม Greeting (แก้เป็นเวลาไทย `UTC+7`), วันที่, ชิปสถานะรอบ และนาฬิกา Live Clock ขนาดใหญ่ (34px); รวมไทม์ไลน์ 4 ช่วงกับ Today's Activity ไว้ในการ์ดเดียว
- เพิ่ม `PayWalletCard.resetAllToFront()` ใน `lib/widgets/pay_wallet_card.dart` และเรียกจาก `MainShell._selectTab` กับ `WorkTrialScreen._onTabChanged` เพื่อให้การ์ดเงินเดือนพลิกกลับมาด้านหน้าอัตโนมัติทุกครั้งที่สลับแท็บไปหน้าอื่นแล้วกลับมา
- เพิ่ม widget test ตรวจการรีเซ็ตหน้าบัตรใน `test/work_trial_screen_test.dart`; อัปเดต `DESIGN.md` (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 6) — แยกข้อมูลหลังการ์ด PayWalletCard ไม่ให้ซ้ำกับช่องชั่วโมงด้านล่าง
- เปลี่ยนเนื้อหาหลังการ์ด `PayWalletCard` เป็น **Employee & Monthly Scan Status**: แสดง `DEPARTMENT`, `EMPLOYMENT`, `COUNTED DAYS` (`estimate.workDays`), `NEEDS REVIEW` (`estimate.issueDates.length`) และเกณฑ์ `CUTOFF 17:00 ICT · COMPLETE PAIRS ONLY` แทนการแสดงชั่วโมงและสมการซ้ำกับด้านล่าง
- ส่ง `department`, `employmentType`, `employmentStatus` จาก `AuthService.getSavedUser()` เข้า `PayWalletCard` ใน `earnings_trial_tab.dart`
- อัปเดต `test/work_trial_screen_test.dart` และ `DESIGN.md` (ตรวจ `README.md` แล้วภาพรวมไม่เปลี่ยน)

### 24 พฤศจิกายน 2026 (รอบ 5) — เพิ่มระยะเผื่อด้านล่างของหน้าแท็บไม่ให้ Bottom Nav บังเนื้อหาเมื่อเลื่อนสุด
- สาเหตุ: หลังเปิด `extendBody: true` บน `MainShell`, `appTabBottomPadding()` คืนค่าคงที่ 112px โดยไม่รวม system gesture inset (`MediaQuery.paddingOf(context).bottom`) ทำให้เมื่อเปิด `How this is calculated` แล้วเลื่อนลงสุด ปุ่ม `Scans need review` ยังโดนฟองลอยของ Bottom Nav บังขอบล่าง
- แก้ `appTabBottomPadding(context)` ใน `lib/theme/app_theme.dart` ให้บวก `MediaQuery.paddingOf(context).bottom + 24` เพื่อให้เลื่อนพ้นฟองลอยของ Bottom Nav ได้ครบทุกแท็บ

### 24 พฤศจิกายน 2026 (รอบ 4) — จัดวาง Verified hours & Bonus time เป็น 2-Column Metric Tiles และย่อแถว Wage/Refresh
- เปลี่ยนกล่องแสดง `Verified hours counted` และ `Bonus time after 17:00` ใต้ `PayWalletCard` เป็นการ์ด 2 คอลัมน์เคียงกัน (`_PayMetricTile`) พร้อมไอคอนวงกลมสี teal และตัวเลขใหญ่ขนาด 22px เต็มความกว้างรับกับการ์ดด้านบน
- จัดปุ่ม `Refresh` (pill outlined button) มาอยู่แถวเดียวชิดขวาคู่กับ `Fixed daily wage estimate` ลดความสูงของการ์ดให้เห็น `How this is calculated` ชัดเจนขึ้น
- อัปเดต `test/work_trial_screen_test.dart` และ `test/ui_refresh_test.dart` ให้ตรวจค่าจาก `verified-hours-tile` และ `bonus-time-tile`; ตรวจ `README.md` (ภาพรวมไม่เปลี่ยน) และอัปเดต `DESIGN.md`

### 24 พฤศจิกายน 2026 (รอบ 3) — ตัดปุ่ม Hide balance / Flip card และเลขบัตรจุดไขปลาออกจาก Pay Wallet Card
- นำปุ่ม `Hide balance` และ `Flip card` ใต้การ์ดออกทั้งหมด (ยังคงแตะที่ตัวการ์ดเพื่อพลิกหน้า-หลัง 3D ได้ตามปกติ)
- นำบรรทัดเลขบัตรจุด `•••• •••• •••• XXXX` ออก และย้ายรหัสพนักงานจริง (`EMP CODE`) ไปแสดงตรงๆ คู่กับชื่อพนักงานและช่วงเดือนแทน ไม่มีข้อมูลตกแต่งแบบเลขบัตรเครดิต
- อัปเดต widget test ใน `test/work_trial_screen_test.dart`, `README.md`, `DESIGN.md` และ `PROJECT_STRUCTURE.md`

### 24 พฤศจิกายน 2026 (รอบ 2) — ปรับหน้า Pay estimate เป็น Wallet Card พลิกหน้า-หลัง 3D
- สร้างวิดเจ็ตใหม่ `lib/widgets/pay_wallet_card.dart` แปลงแนวคิด Wallet Card ให้เข้ากับธีม Cirrus ทั้ง 3 โหมด (Default Navy/Teal, Pure White, Obsidian Black) พร้อม EMV chip, ไอคอน contactless, แสงเงาสะท้อนตามเคอร์เซอร์, เลขรหัสพนักงานแบบซ่อน (`•••• •••• •••• XXXX`), ชื่อผู้ถือบัตร, ช่วงเดือน และปุ่ม **Hide balance / Show balance**
- เพิ่มแอนิเมชันพลิกการ์ด 3D 180° (`AnimationController` + `Matrix4` perspective `rotateY`) แตะการ์ดหรือปุ่ม **Flip card** เพื่อพลิกดูสรุปหลังการ์ด (Verified hours, Bonus after 17:00 และสมการย่อ) พร้อมรองรับโหมดลดแอนิเมชันของระบบ
- ผสานเข้ากับ `lib/screens/earnings_trial_tab.dart` โดยคงสูตรคำนวณ 300 บาท/8 ชม., ข้อมูล API, `How this is calculated`, และปุ่ม Refresh estimate เดิม 100% (ไม่แตะ `lib/services/` หรือ `lib/models/`)
- เพิ่ม widget test สำหรับ Hide/Show balance และการพลิกหน้า-หลังใน `test/work_trial_screen_test.dart`
- ผลตรวจ: `flutter analyze` 0 error / 0 warning (มีเฉพาะ SDK deprecation `info` 3 รายการ); `flutter test test/work_trial_screen_test.dart test/ui_refresh_test.dart test/widget_test.dart` ผ่านครบ 16 ข้อ ✅
- ตรวจและอัปเดต `README.md`, `DESIGN.md` และ `PROJECT_STRUCTURE.md` เรียบร้อยแล้ว

### 24 พฤศจิกายน 2026 — เชื่อมฐานข้อมูล `cirrus_02` ผ่าน Local EMS Bridge และเปิดแอปบน Emulator
- ตรวจสอบฐานข้อมูล PostgreSQL `cirrus_02` (`localhost:5432`) และไฟล์ `schema_dump_42with_data.sql`: ยืนยัน 11 บัญชีใน `core.user_accounts` ผูกครบกับ `core.employees` และ `core.user_profiles` พร้อมพบจุดต่างรหัสเครื่องสแกน (`device_user_code`) 5 บัญชี (`Sales2026`, `cirrusmarinestore@gmail.com`, `Meow`, `Touch`, `Nii`)
- ตั้ง Local EMS Bridge บนพอร์ต `3000` (`/api/v1/ems`) เชื่อมตรงกับ PostgreSQL `cirrus_02` รองรับ `/auth/login`, `/auth/me`, `/auth/logout`, `/app-attendance/status`, `/app-attendance/my-scans`, `/app-attendance/events`, `/storage/uploads` และ `/attendance` โดยยังคงไม่ดึงหรือเปลี่ยนสูตรเงินเดือนตามเงื่อนไขผู้ใช้
- ปรับ `.env` ให้ Android ใช้ `http://10.0.2.2:3000/api/v1/ems` และ Web/iOS ใช้ `http://localhost:3000/api/v1/ems` ไม่แตะโค้ดใน `lib/`
- ปิด Emulator ที่ค้างและบูต `Pixel_10_Pro_XL_API_35` ใหม่ด้วย `-no-snapshot-load`, build Debug APK, ติดตั้งและเปิดแอปถึงหน้า Sign In สำเร็จ (`.oil-ui/screenshots/emu_app2.png`)
- ผลทดสอบ: `test/auth_service_test.dart` และ `test/widget_test.dart` ผ่าน 18 ข้อ; ทดสอบ API จริงผ่าน `/health`, `/auth/login` (`admin`), `/app-attendance/status` และ `/app-attendance/my-scans` (43 รายการเดือน พ.ย. 2026)
- เพิ่มไฟล์ `start_emulator_and_backend.bat` และ `.tools/ems_local_server.js` สำหรับดับเบิลคลิกเปิด Local EMS Bridge + Android Emulator และเปิดแอป Cirrus EMS อัตโนมัติจากหน้าจอ Windows ของผู้ใช้
- ตรวจและอัปเดต `README.md` และ `PROJECT_STRUCTURE.md` ให้ตรงกับค่า `.env` และไฟล์ใหม่ล่าสุด

### 23 พฤศจิกายน 2026 (รอบ 7) — แสดงสถานะกำลังเปลี่ยนธีม
- แสดง `CHANGING THEME` พร้อม progress indicator ใน AppBar ราว 220ms ก่อนอัปเดต palette; หลัง `ThemeService` บันทึกค่าจะเปลี่ยนเป็น `THEME UPDATED` พร้อม check icon 2 วินาที
- เพิ่ม widget assertions สำหรับทั้งสองสถานะ; ตรวจแบบ RED ก่อนแก้ (ขาด `CHANGING THEME`) แล้ว GREEN หลังแก้
- `flutter test test/settings_screen_test.dart`: ผ่าน 5 tests; `flutter test`: ผ่าน 125 tests, skip 1
- `flutter analyze lib/main.dart lib/screens/theme_settings_screen.dart test/settings_screen_test.dart`: ไม่มี warning/error; มี SDK deprecation info 3 รายการ
- `flutter build apk --debug -t lib/main.dart`: สำเร็จ; ติดตั้ง APK และเปิดแอปบน `emulator-5554` สำเร็จ
- Build แจ้งเตือนล่วงหน้าเรื่อง Flutter support สำหรับ Gradle 9.3.1, AGP 9.1.1 และ Kotlin 2.4.10; build ปัจจุบันยังสำเร็จ
- ตรวจจอหลังติดตั้งพบหน้า Sign In; การเข้าสู่ระบบด้วยบัญชีทดสอบที่ผู้ใช้ให้มาถูกปฏิเสธว่า invalid จึงยืนยัน visual state ใหม่บนหน้า App Theme หลัง build ไม่ได้; widget test ยืนยันลำดับสถานะแล้ว
- คืนค่า preference ธีมบน emulator จาก Pure White กลับเป็น Cirrus Signature โดยแก้เฉพาะ `flutter.ems.themeMode`; เปิดแอปค้างไว้ที่หน้า Sign In
- ตรวจ README.md และปรับคำอธิบายพฤติกรรม; อัปเดต DESIGN.md; ไม่แก้ API, Backend, auth, storage หรือสูตรคำนวณ

### 23 พฤศจิกายน 2026 (รอบ 6) — เปลี่ยนธีมทันทีพร้อมข้อความยืนยัน
- ปิด MaterialApp theme interpolation เพื่อให้สีใหม่มีผลทันที ไม่ทำให้ผู้ใช้เห็นเหมือนกำลังรอโหลด
- หลังเลือกธีมใหม่แสดง `THEME UPDATED` พร้อมไอคอน check ที่ AppBar 2 วินาที; แตะธีมที่เลือกอยู่แล้วจะไม่แสดงข้อความซ้ำ
- เปลี่ยนสีทันทีและบันทึก SharedPreferences ต่อแบบ asynchronous โดยไม่บล็อก UI; ไม่มี spinner เต็มหน้า
- อัปเดต README.md และ DESIGN.md ให้บันทึกพฤติกรรม feedback; ไม่เปลี่ยน palette, Backend/API/auth/storage
- ผล analyzer/build/Emulator จะเพิ่มหลังตรวจรอบนี้; automated tests ไม่ได้รันในรอบนี้

### 23 พฤศจิกายน 2026 (รอบ 5) — แก้เนื้อหาแท็บค้างสีเดิมในธีม Obsidian Black
- สาเหตุ: MainShell เก็บ widget ของแท็บเดิมไว้ ทำให้หน้า Attendance/History ที่อ่าน `AppColors` ตอน build ไม่วาดสีใหม่ แม้ Bottom Navigation จะตอบสนองต่อ theme notifier แล้ว
- ครอบแต่ละแท็บด้วย `ListenableBuilder` ที่ฟัง `ThemeService.themeModeNotifier` และคืน screen widget ที่ใช้ key คงที่ จึง rebuild สีโดยเก็บ State และข้อมูลของแท็บไว้
- Dart analyze `lib/screens/main_shell.dart` ผ่าน ไม่มี warning/error; มี deprecation info จาก SDK 1 รายการ; สร้าง debug APK และติดตั้งบน `emulator-5554` โดยเก็บข้อมูลแอปเดิม
- ตรวจด้วยตาบน Pixel emulator หลังเลือก Obsidian Black: หน้า Attendance และ History เปลี่ยนพื้นหลัง/การ์ดเป็นสีดำเข้มทั่วหน้าเหมือน navigation; ไม่ส่ง attendance จริง; automated tests ไม่ได้รันในรอบนี้
- ตรวจ README.md และอัปเดตคำอธิบายการเปลี่ยนธีม; ตรวจ DESIGN.md แล้ว ไม่ต้องเปลี่ยนเพราะไม่มีการแก้ palette หรือแนวทางออกแบบ; ไม่เปลี่ยน Backend/API/auth/storage

### 23 พฤศจิกายน 2026 — ตรวจเอกสารสถานะล่าสุด
- อ่าน README.md, TASK_STATUS.md, DESIGN.md, PROJECT_STRUCTURE.md และ AGENTS.md แล้วเทียบคำอธิบายกับ Settings, ThemeSettingsScreen และ FileDownloadService ในโค้ด
- แก้ README.md ที่ยังระบุว่า Settings เป็น placeholder ให้ตรงกับ Settings และการเลือกธีมที่ทำแล้ว; ระบุให้ชัดว่า PDF Preview แยก Download ลงเครื่องกับ Share sheet
- งานล่าสุดที่บันทึกแล้ว: Settings มี 3 ธีม, PDF มีปุ่ม Download/Share แยก, Local leave นับเต็มวันและ PDF ไม่มี Last leave
- ไม่ได้เปลี่ยนโค้ดแอปในรอบตรวจเอกสารนี้; สถานะผลตรวจเดิมคงตามขอบเขตในหัวข้อผลตรวจล่าสุด

### 23 พฤศจิกายน 2026 (รอบ 4) — ระบบเลือกธีมแอป (Default, White, Black) & Settings Screen

- **เปิดใช้งานหน้า Settings จริง:** จากหน้า Profile ในหมวด General กด Settings เข้าสู่ `SettingsScreen` (แทน stub เดิม)
- **ระบบเลือกธีม 3 รูปแบบ (`AppThemeMode`):**
  1. **Default (Cirrus Signature):** Navy 30% / Off-white 60% / Teal Accent 10%
  2. **Pure White:** ขาวบริสุทธิ์ `#FFFFFF`, การ์ด `#F8FAFC`, ตัวอักษรสี Slate Dark `#0F172A`, Accent สีฟ้า Sky Blue `#0EA5E9`
  3. **Obsidian Black (OLED Dark):** ดำสนิท `#0B1118`, การ์ด Slate Dark `#151E28`, ตัวอักษรขาวนวล `#F1F5F9`, Accent สีนีออนเทอร์ควอยซ์ `#2DD4BF`
- **ไฟล์ใหม่:**
  - `lib/services/theme_service.dart`: จัดการ `themeModeNotifier` (`ValueNotifier`), บันทึก/โหลด `SharedPreferences` ผ่านคีย์ `'ems.themeMode'`
  - `lib/screens/settings_screen.dart`: หน้าการตั้งค่า มี visual cards สำหรับแต่ละธีม พร้อม radio check indicator, active badge และ color swatch preview
  - `test/settings_screen_test.dart`: ทดสอบการสลับธีม, การจำค่า, การเรนเดอร์ในหน้า Settings และการเปิดจาก Profile
- **ปรับปรุง `lib/theme/app_theme.dart`:**
  - สร้าง `AppThemePalette` กำหนดชุดสีเฉพาะสำหรับ 3 ธีม
  - ให้ `AppColors` เชื่อมโยงกับ Active Palette ของธีมที่เลือกแบบ reactive
  - สร้าง `AppTheme.forMode(AppThemeMode)` ปรับแต่ง ThemeData ตามความสว่างและชุดสี
- **ผลตรวจ:**
  - `flutter analyze` ผ่าน 0 errors, 0 warnings (มีเฉพาะ `info` deprecation ตาม SDK ปกติ) ✅
  - `flutter test` (6 test suites) ผ่านครบทั้งหมด 42 ข้อ (รวม tests ธีมและ contrast) ✅
  - ตรวจสอบบน Emulator Pixel 10 Pro XL API 35: สลับธีมไปมา ตอบสนองทันที ไม่มีกรอบสีค้าง และตัวหนังสือโรลอ่านชัดเจน

- **แก้ไขข้อผิดพลาดหลังตรวจการใช้งานจริง (Theme Switch & Black Mode Contrast & Settings Submenu):**
  - **ปัญหา 1 — เมนูด้านล่างและพื้นหลังค้างสีเดิมจนกว่าจะเลื่อน:** เกิดจาก `MainShell` และ `AppBottomNav` ไม่ได้รับรู้การสลับธีม ทำให้ `Scaffold.backgroundColor` ค้างสีเดิม และ `_NavigationSurface` มี `shouldRepaint` ตรวจเฉพาะการเปลี่ยนตำแหน่ง `center` เท่านั้น
    - **วิธีแก้:**
      1. ห่อ `MainShell.build` และ `AppBottomNav.build` ด้วย `ValueListenableBuilder<AppThemeMode>` เพื่อให้ rebuild ทันทีที่สลับธีม
      2. ส่ง `surfaceColor` และ `shadowColor` เข้า `_NavigationSurface` CustomPainter และเพิ่มเงื่อนไขตรวจใน `shouldRepaint`
  - **ปัญหา 2 — ป้าย Role และ Avatar ในธีม Obsidian Black อ่านไม่ชัด:** เกิดจากใช้ `AppColors.neutral` เป็นพื้นหลัง ซึ่งใน Black theme คือสีขาวนวล `#F1F5F9` ทำให้ตัวหนังสือสีขาวกลืนกับพื้นหลัง
    - **วิธีแก้:**
      1. เพิ่ม Semantic Tokens ใน `AppThemePalette`: `roleBadgeBackground`, `roleBadgeForeground`, `roleBadgeIcon`, `avatarBackground`, `avatarForeground`, `sideNavBackground`, `splashBackground`
      2. ใน Obsidian Black: ป้าย Role ใช้แคปซูลเข้ม `#1E2D3D` กับตัวหนังสือขาวนวล `#F1F5F9` และไอคอนนีออนเทอร์ควอยซ์ `#2DD4BF` คอนทราสต์สูงและอ่านชัดเจน 100%
      3. วงกลม Avatar ใน Black mode ใช้พื้นหลังมืด `#141D26` พร้อมตัวอักษรนีออนเทอร์ควอยซ์ `#2DD4BF` เข้ากับธีม OLED
      4. ปรับ `_LoginBackdrop` ใน `login_screen.dart` และ background ใน `splash_screen.dart` ให้ใช้สีพื้นหลังเข้มตาม Palette
      5. เพิ่ม 2 Widget Tests ใน `test/settings_screen_test.dart` ตรวจสอบความถูกต้องของการเปลี่ยนสี BottomNav แบบ Realtime และ Contrast ของ Role Badge
  - **ปัญหา 3 — โครงสร้างหน้า Settings ต้องการให้มีเมนูย่อยเลือกธีม (ไม่ใช่เข้า Settings แล้วเป็นการ์ดเลือกธีมทันที):**
    - **วิธีแก้:**
      1. ปรับ `SettingsScreen` (`lib/screens/settings_screen.dart`) ให้เป็นหน้าเมนูการตั้งค่าแบบกลุ่ม (Preferences, System, About) โดยมีรายการ **App Theme** แสดงธีมปัจจุบันและไอคอน `palette`
      2. แยกระบบเลือกธีมเป็นการ์ด 3 รูปแบบไปไว้ในหน้ารายละเอียดย่อย `ThemeSettingsScreen` (`lib/screens/theme_settings_screen.dart`) เพื่อให้ผู้ใช้กดเข้าไปเลือกธีมได้เป็นสัดส่วน
  - **ปัญหา 4 — แถบสีดำและขอบนูนผิดปกติเหนือเมนูด้านล่างในธีมสีดำ:**
    - **วิธีแก้:**
      1. เพิ่ม `extendBody: true` ใน `Scaffold` ของ `MainShell` และตั้ง `bottomNavigationBarTheme: transparent` ป้องกันไม่ให้ Scaffold แทรกแถบ shelf สี่เหลี่ยมสีทึบตัดกับพื้นหลังด้านบน
      2. ปรับจูนรัศมีความโค้งและระยะ `halfNotch` ใน `_NavigationSurface` CustomPainter ให้เป็น `(size.width / 8 - 4).clamp(24.0, 32.0)` ทำให้ขอบโค้งมุมบนขวาและซ้ายของแถบเมนูโค้งมนเรียบเนียน ไม่เกิดติ่งหรือรอยหยักดำข้างฟองลอย
      3. ปรับโทเค็น `bottomNavShadow` ในธีมมืดให้ใช้เงาสีดำแบบซอฟต์ (`0x66000000`) แทนเงาสว่าง

### 23 พฤศจิกายน 2026 (รอบ 3) — PDF Download ลงเครื่องแทน Share Sheet

- **เปลี่ยนพฤติกรรมปุ่ม PDF Preview:** แทนปุ่ม "Download or share PDF" เดิมด้วย 2 ปุ่มแยก:
  - **Download PDF** (`Icons.download_outlined`) — บันทึกไฟล์ลง Downloads folder โดยตรง แสดง Snackbar บอก path
  - **Share PDF** (`Icons.share_outlined`) — เปิด share sheet ของระบบ (พฤติกรรมเดิม)
- **ไฟล์ใหม่ `lib/services/file_download_service.dart`:** `FileDownloadService.downloadFile()` จัดการตามแพลตฟอร์ม:
  - Android ≥29: MediaStore API ผ่าน MethodChannel `com.cirrusgroup.ems/downloader` → บันทึกไป `Downloads/`
  - Android <29 fallback: `path_provider` `getExternalStorageDirectories(type: StorageDirectory.downloads)`
  - Desktop: `getDownloadsDirectory()`
  - Web: fallback `Printing.sharePdf()`
  - มี `debugDownloadOverride` สำหรับ tests
- **แก้ `android/app/src/main/kotlin/com/cirrusgroup/ems/MainActivity.kt`:** เพิ่ม MethodChannel `com.cirrusgroup.ems/downloader` → method `saveToDownloads` ใช้ MediaStore ContentValues (API≥29) และ FileOutputStream fallback (<29)
- **แก้ `test/work_trial_screen_test.dart`:** อัปเดต test `'local leave draft stays local'` ให้ใช้ `FileDownloadService.debugDownloadOverride` และตรวจ tooltip `'Download PDF'`/`'Share PDF'` แทน tooltip เดิม
- **ผลตรวจ:**
  - `flutter analyze` → `info` deprecation จาก SDK 2 รายการ ไม่มี warning/error ✅
  - `flutter test` (5 ไฟล์) → **23 tests ผ่านทั้งหมด** ✅
  - Build Debug APK สำเร็จ ✅
  - ติดตั้งบน Emulator Pixel 10 Pro XL API 35 สำเร็จ แอปเปิดได้ ✅ (session หมด → แสดงหน้า Login ปกติ)
  - Screenshot: `.oil-ui/screenshots/pdf-leave-tab.png`
- ไม่มีการแก้ไข API, auth, storage, eligibility หรือสูตรคำนวณใดๆ

### 23 พฤศจิกายน 2026 (รอบ 2) — ปรับรูปแบบ PDF ใบลาให้ดูเป็นทางการยิ่งขึ้น (Formal layout)
- ปรับการจัดวาง PDF ใบลาให้มีโครงสร้างแบบฟอร์มทางการขององค์กร (โดยยังคงเนื้อหาเดิมและรองรับภาษาไทย Sarabun):
  - **หัวเอกสารทางการ:** ระบุชื่อองค์กร "CIRRUS EMS", หัวเรื่อง "LEAVE REQUEST FORM", ป้ายสถานะแบบร่าง/ยกเลิก, และเพิ่มเลขที่เอกสาร "REF: LEV-..." พร้อมระบุวันเวลาที่สร้างตามเวลาประเทศไทย
  - **เส้นกรอกข้อความเรียบหรู:** เปลี่ยนช่องกรอกเว้นว่าง `To (Approver)` และ `Department` จากการใช้ตัวอักษรขีดเส้นใต้ `_____` เป็นเส้นเวกเตอร์ bottom border ที่คมชัด สะอาดตา
  - **แถบหัวข้อส่วน (Section Headers):** เพิ่มแถบขอบซ้าย Deep Navy หนา 3px พร้อมพื้นหลังสีนวล `#F0F4F7` สไตล์แบบฟอร์มเอกสารทางการ
  - **กรอบกล่องข้อความเหตุผล (Reason):** ล้อมกรอบช่อง Reason ด้วยเส้นขอบบาง 0.7px พร้อมพื้นหลัง `#FAFCFC` และ padding 7px เพื่อให้อ่านง่ายและเป็นสัดส่วน
  - **ช่องลงนามทางการ (Signature Block):** ปรับการจัดวางช่องลงนามทั้ง Employee และ Manager ให้จัดกึ่งกลาง มีเส้นลงลายมือชื่อ, ช่องวงเล็บสำหรับชื่อตัวบรรจง, หัวข้อตำแหน่งตัวหนา, และเส้นกรอกวันที่ `Date: ....... / ....... / ...........` ตามแบบฟอร์มมาตรฐาน
- ผลทดสอบ:
  - `leave_pdf_builder_test.dart`, `work_trial_store_test.dart`, `work_trial_screen_test.dart` ผ่านครบทั้ง 10 ข้อ ✅
  - `flutter analyze lib/services/leave_pdf_builder.dart` ผ่าน 0 issues (ไม่มี warning หรือ error)
  - ส่งออกตัวอย่าง `build/leave-pdf-preview.pdf` ตรวจสอบความถูกต้องสมบูรณ์แล้ว
  - ตรวจและอัปเดต README.md กับ DESIGN.md ให้ตรงกับรูปแบบล่าสุด

### 23 พฤศจิกายน 2026 — ใบลาเต็มวันและตัดช่อง Last leave ใน PDF
- เปลี่ยนตัวเลือก Half day เป็น One day (single date); เมื่อเลือก ระบบกำหนดวันสิ้นสุดให้ตรงกับวันเริ่ม และนับเป็น 1 วันเต็ม
- เลิกเก็บ halfDay สำหรับร่างใหม่ และอ่านร่างเก่าที่มี halfDay เป็นวันเต็มตามช่วงวันที่ โดยยังเก็บข้อมูลเดิมอื่นครบ
- เอาแถว Last leave ออกจาก PDF และให้ Duration แสดงจำนวนวันเต็ม
- ชุดทดสอบ store และ PDF ผ่าน 7 ข้อ; analyzer พบเฉพาะ info deprecation ของ `package:flutter/material.dart` จาก SDK ใน `leave_trial_tab.dart` ไม่มี warning/error จากโค้ด
- Build Debug APK สำเร็จและติดตั้งบน Pixel 10 Pro XL แล้ว ตรวจภาพ `.oil-ui/screenshots/leave-after.png`: เลือก One day ไว้ และร่างเดิมที่เคยเป็นครึ่งวันแสดงเป็น 1 DAY
- ตรวจและอัปเดต README.md กับ DESIGN.md แล้ว; ไม่มีการเปลี่ยน Backend API หรือโครงสร้างไฟล์สำคัญ

### 21 พฤศจิกายน 2026 — สลับตำแหน่งเมนู Profile

- เปลี่ยนลำดับเมนูเป็น Attendance, History, Pay & Leave, Profile ทั้งเมนูล่างและแถบด้านข้าง พร้อมสลับหน้าปลายทางให้ตรงกัน
- ตรวจเมนูบน emulator หลังติดตั้ง Android debug APK; widget tests ตรวจว่าปุ่มใหม่เปิดหน้าที่ตรงกัน
- ทดสอบทั้งชุดแบบทีละชุดผ่าน 119 ข้อ ข้าม 1 ข้อ; analyzer ไม่มี error/warning มี info 44 รายการ รอบขนานก่อนหน้าทดสอบลงเวลาบางข้อไม่ผ่าน แต่รันชุดนั้นแยกผ่านทั้งหมด
- ตรวจและอัปเดต README, DESIGN, PROJECT_STRUCTURE และ AGENTS ให้ตำแหน่งเมนูและพิกัดตรงกัน; ไม่เปลี่ยน backend หรือสูตร


### 21 พฤศจิกายน 2026 — ปรับรูปแบบ PDF ใบลา

- ปรับแบบฟอร์มตามแนว HumanSoft: ผู้รับ ข้อมูลพนักงาน ช่องเลือกประเภทลา ช่วงวัน เหตุผล ช่องกรอกแผนก/ลาครั้งก่อน และลายเซ็น คงภาษาอังกฤษและรองรับข้อมูลภาษาไทย
- ตามคำขอภายหลัง ตัดส่วน For manual review ออก คง Draft – not approved และสถานะ Cancelled; ข้อมูลที่ไม่ทราบเว้นให้กรอกเอง ไม่ส่งใบลาไป Backend
- ตรวจ PDF จำลองรวมข้อความไทยยาวและเหตุผล 1,000 ตัวอักษร; tests ผ่าน 119 ข้อ ข้าม 1 ข้อ; analyzer ไม่มี error/warning มี info 44 รายการ; สร้างและติดตั้ง Android debug APK สำเร็จ
- ตรวจและอัปเดต README และ DESIGN; ยังไม่ได้ตรวจการแสดง PDF ใบลาจริงใน emulator หลังปรับ


### 21 พฤศจิกายน 2026 — กลับด้านบนเมื่อเปลี่ยนแท็บและขยายการ์ด History

- เมื่อสลับแท็บหลักให้หน้าที่ออกกลับไปด้านบน โดยรักษา state เดิม รวมถึงเปลี่ยนแท็บ Pay / Leave; ไม่สร้างหน้าซ้ำหรือเปลี่ยนการเรียก backend
- ขยายระยะภายในการ์ด วันที่และค่าชั่วโมง เน้นปุ่ม View all และคงรายการล่าสุด 4 วันกับรายละเอียดเดิม
- เพิ่ม widget test เลื่อน History แล้วสลับแท็บกลับ; tests ผ่าน 119 ข้อ ข้าม 1 ข้อ; analyzer ไม่มี error/warning มี info 44 รายการ
- Build ติดตั้งและเปิด Android debug APK สำเร็จ ตรวจหน้าประวัติบน emulator; ตรวจและอัปเดต README และ DESIGN


### 21 พฤศจิกายน 2026 — ประวัติ 4 วันล่าสุดและดูทั้งหมด

- หน้า History แสดง 4 วันล่าสุดของเดือนที่เลือก พร้อม View all สำหรับขยายรายการทั้งหมดและ Show less สำหรับย่อ เมื่อเปลี่ยนเดือนกลับไปแสดง 4 วันแรก
- ขยายวันที่และตัวเลขในการ์ด เพิ่มขนาดป้ายและอนุญาตให้ตัดบรรทัด คงรายละเอียดเมื่อกดรายการ ข้อมูล Backend และสูตรเดิม
- เพิ่ม widget test สำหรับดูทั้งหมด ย่อ และเปลี่ยนเดือน; tests ผ่าน 118 ข้อ ข้าม 1 ข้อ; analyzer ไม่มี error/warning มี info 44 รายการ
- Build ติดตั้งและตรวจ History บน Android emulator แล้ว กด View all พบรายการเพิ่มเติม; ตรวจและอัปเดต README และ DESIGN


### 21 พฤศจิกายน 2026 — เพิ่มระยะฟอนต์ทั่วแอป

- เพิ่มระยะตัวอักษรในชุดรูปแบบข้อความกลางและจุดที่กำหนดระยะศูนย์ในหน้า History, Pay, Profile และ Login โดยคงฟอนต์ Bebas Neue และ fallback เดิม
- ตรวจและปรับ README และ DESIGN; analyzer ไม่มี error/warning มี info deprecation 43 รายการ; tests ผ่าน 117 ข้อ ข้าม 1 ข้อ
- Build และติดตั้ง Android debug APK สำเร็จ ตรวจหน้า History และ Pay estimate บน emulator โดยไม่แก้ backend หรือสูตรคำนวณ


### 21 พฤศจิกายน 2026 — จัดตำแหน่งปุ่ม Check In

- ปรับระยะระหว่างไอคอนกับข้อความและชดเชยตำแหน่งข้อความเล็กน้อยให้ดูสมดุลในวงกลม คงไอคอนและพฤติกรรมลงเวลาเดิม
- ตรวจ README แล้ว ไม่มีการเปลี่ยนภาพรวม; analyzer ไม่มี error/warning มี info 43 รายการ; tests ผ่าน 117 ข้อ ข้าม 1 ข้อ
- Build ติดตั้งและเปิด Android debug APK สำเร็จ ตรวจปุ่มในสถานะปิดรอบบน emulator โดยไม่ส่งลงเวลาจริง


### 21 พฤศจิกายน 2026 — ดูใบลา PDF และปรับระยะฟอนต์

- เปลี่ยนปุ่มใบลาเป็น View PDF เปิดหน้าตัวอย่างพร้อมไอคอนดาวน์โหลด/แชร์ บน Android ใช้เมนูแชร์ของระบบเพื่อเลือกบันทึกหรือเปิดไฟล์ ใบลายังคงอยู่ในเครื่อง
- ปรับระยะตัวอักษร Employee Attendance และจุดที่ใช้ระยะติดลบในธีมและหน้าต่าง ๆ ให้ฟอนต์ Bebas Neue อ่านง่ายขึ้น
- ตรวจ README และอัปเดตคำอธิบาย ตรวจ analyzer ไม่มี error/warning มี info deprecation 43 รายการ; Flutter tests ผ่าน 117 ข้อ ข้าม 1 ข้อ
- Build และติดตั้ง Android debug APK สำเร็จ เปิดแอปบน emulator แล้ว; ตรวจหน้าหลักหลังติดตั้ง แต่ยังไม่ได้ตรวจหน้าตัวอย่าง PDF บนเครื่องจริงหรือ emulator หลังแก้
- Emulator จำลอง 1344 × 2992 ที่ 480 dpi ภาพบนหน้าต่างที่ย่ออาจดูไม่คม ยังไม่ได้ยืนยันคุณภาพบนอุปกรณ์จริง; ไม่เปลี่ยน backend หรือสูตรคำนวณ


### 21 พฤศจิกายน 2026 — PDF ใบลาและฟอนต์ Bebas Neue

- เพิ่ม PDF ใบลาจากแบบร่างในเครื่อง พร้อมโลโก้ ข้อมูลโปรไฟล์ที่เก็บไว้ วันที่สร้าง รายละเอียดลา และช่องลายเซ็น แสดง Draft – not approved และระบุ Cancelled เมื่อใบลาถูกยกเลิก ข้อมูลโปรไฟล์ที่ไม่มีแสดง Not provided
- เพิ่ม Download PDF หลังบันทึกและในการ์ดทุกรายการ Android/iOS เปิดตัวเลือกแชร์ ส่วน Web ใช้กลไกดาวน์โหลดของ printing สร้าง PDF ใหม่เมื่อกด
- ตั้ง Bebas Neue ทั้งแอป พร้อม Sarabun fallback สำหรับภาษาไทย PDF ใช้ Sarabun เพื่อให้อ่านข้อความผู้ใช้ได้ ปุ่ม CHECK IN / CHECK OUT เป็นตัวพิมพ์ใหญ่ ไฟล์ฟอนต์และใบอนุญาตอยู่ใน assets/fonts
- ทดสอบชุดเต็ม 118 ข้อผ่าน Analyzer ไม่มี warning หรือ error มี SDK deprecation ระดับ info 43 รายการ Build Android และ Web สำเร็จ ติดตั้ง Android และตรวจว่ากด Download PDF จากใบลาเดิมเปิดหน้าต่างแชร์บน Pixel ได้
- ตรวจ PDF ตัวอย่างด้วยข้อมูลจำลอง รวมภาษาไทย ครึ่งวัน ใบที่ยกเลิก และเหตุผลยาว ใบลาเก่าอ่านได้ Web ยังไม่ได้ตรวจการดาวน์โหลดผ่านเบราว์เซอร์จริง และ iOS ยังไม่ได้ build หรือทดสอบบนเครื่องจริง
- ตรวจและอัปเดต README.md, DESIGN.md, PROJECT_STRUCTURE.md และ AGENTS.md ใบลายังเก็บในเครื่องและไม่ส่งอนุมัติ


### 21 พฤศจิกายน 2026 — เพิ่มแผนที่โครงสร้างโปรเจกต์

- เพิ่ม PROJECT_STRUCTURE.md อธิบายโฟลเดอร์ ไฟล์ Dart, widgets, services, tests และจุดเริ่มต้นการทำงานสำหรับ AI agent
- ตรวจ README.md และเพิ่มลิงก์ไปยังเอกสารใหม่ แก้เส้นทางไฟล์กล้องและ .env ใน AGENTS.md ให้ตรงกับโครงสร้าง และกำหนดให้อัปเดตแผนที่เมื่อโครงสร้างเปลี่ยน
- ตรวจชื่อไฟล์และลิงก์ภายในจาก filesystem งานนี้เปลี่ยนเอกสาร ไม่มีการรัน Flutter tests

### 21 พฤศจิกายน 2026 — แยกป้ายชั่วโมงใน History

- การ์ด History แสดง Total Working Hours และ Hours Used for Pay เป็นคนละส่วน พร้อมข้อความเรื่องเวลาอ้างอิงและคู่สแกนครบก่อน 17:00 เวลาไทย ตัวเลขอ้างอิงการคำนวณเดิม
- เทสต์ชุดเต็มแบบรันทีละไฟล์ผ่าน 115 ข้อ หลังรอบแรกแบบขนานพบเทสต์ Attendance retry ล้ม 2 ข้อ Analyzer ไม่มี error หรือ warning และสร้าง Debug APK สำเร็จ
- ติดตั้ง APK บน Pixel สำเร็จหลังเปิด emulator ใหม่ แอปเปิดที่ Sign In การ์ดที่มีข้อมูลตรวจด้วย widget test โดยเปรียบเทียบชั่วโมงใน History กับ Pay estimate ทั้งเดือนปัจจุบันและเดือนก่อน
- ตรวจและอัปเดต README.md กับ DESIGN.md

### 20 พฤศจิกายน 2026 — แสดงชั่วโมงที่ใช้คิดค่าแรงใน History

- การ์ด History แสดงยอดชั่วโมงรวมและ Verified hours counted พร้อมคำอธิบายเรื่องเวลาอ้างอิง ทั้ง History และ Pay estimate ใช้ตัวคำนวณและค่า PaySettings.trial ร่วมกันสำหรับยอดที่ใช้คิดค่าแรง
- เทสต์เปรียบเทียบทั้งสองหน้าด้วยสแกนชุดเดียวกันผ่านทั้งเดือนปัจจุบันและเดือนก่อน ชุดเต็มก่อนเพิ่มการยืนยันในเทสต์ผ่าน 115 ข้อ เทสต์ UI รอบล่าสุดผ่าน 9 ข้อ Analyzer ไม่มี warning หรือ error มี SDK deprecation ระดับ info 43 รายการ
- สร้างและติดตั้ง APK แล้ว หลังผู้ใช้เข้าสู่ระบบ ตรวจบน Pixel พบ Verified hours counted เท่ากันทั้งสองหน้าและเปิดหน้า History ค้างไว้
- ตรวจและอัปเดต README.md และ DESIGN.md


### 20 พฤศจิกายน 2026 — แสดงชั่วโมงสะสมใน History

- ย้ายยอดชั่วโมงจากสรุปการเข้างานมาไว้ในการ์ดใต้ตัวเลือกเดือน ใช้สแกนและสูตรเดิมของ History การ์ดแสดงยอดได้แม้สรุปการเข้างานว่าง ใช้ชื่อ Working Hours This Month ในเดือนปัจจุบัน และ Total Working Hours ในเดือนก่อน
- คำนวณยอดตอนอ่านสแกนสำเร็จและแสดงสถานะโหลด ว่าง หรือโหลดไม่สำเร็จตามผลของสแกน
- Flutter tests ผ่าน 115 ข้อ รวมการเลือกเดือนและแสดงยอดเมื่อมีสแกนแต่ไม่มี attendance records Analyzer ไม่มี error หรือ warning มี SDK deprecation ระดับ info 43 รายการ สร้างและติดตั้ง APK เปิดการ์ดบน Pixel และบันทึกภาพก่อนและหลัง
- ตรวจและอัปเดต README.md, DESIGN.md และ AGENTS.md


### 20 พฤศจิกายน 2026 — คิดค่าแรงตามชั่วโมงที่ยืนยันได้

- ใช้อัตราทดลองคงที่ 300 บาทต่อ 8 ชั่วโมง หรือ 37.50 บาทต่อชั่วโมง ยอดของเดือนคือค่าแรงจากนาทีที่ยืนยันได้ก่อน 17:00 ส่วนเวลาหลัง 17:00 แสดงแยกเป็นโบนัสเวลา
- อ่านสแกนจาก API เดียวกับ History และนับเฉพาะคู่ครบ ชม. ที่ใช้คิดค่าแรงอาจต่างจาก Working Hours บน History ในวันที่ใช้เวลาอ้างอิง หน้า Pay estimate แสดงอัตรา ชั่วโมง ยอด และวันที่ควรตรวจ
- เทสต์ด้วยสแกนจำลอง 6 ชั่วโมง 30 นาที ได้ 243.75 บาท พร้อมโบนัสเวลา 1 ชั่วโมงและแสดงวันสแกนไม่ครบ รันชุดเต็มผ่าน 114 ข้อ Analyzer ไม่มี error หรือ warning มี SDK deprecation ระดับ info 43 รายการ
- สร้าง Debug APK ติดตั้งและตรวจหน้า Pay estimate บน Pixel บันทึกภาพก่อนและหลัง อัปเดต README.md, DESIGN.md และ AGENTS.md ตามสูตรปัจจุบัน


### 20 พฤศจิกายน 2026 — ย่อรายละเอียดสูตรเงินเดือน

- แสดงสมการกับยอดประมาณการแบบย่อในหน้าเดิม วันต้องตรวจแสดงจำนวนก่อนและแตะดูรายการได้ เวลาโบนัสอยู่ในสรุปหลัก
- ป๊อปอัปเป็นแนวคิดสำหรับพิจารณาถ้ารายละเอียดเพิ่มขึ้น หน้าในรุ่นนี้ยังใช้แผงเปิดในหน้า
- Flutter tests ผ่าน 114 ข้อ รวมเปิดแผงสูตรและเปิดรายการวันที่แยกกัน Analyzer ไม่มี error หรือ warning ติดตั้งบน Pixel และตรวจว่าพบสมการขณะรายละเอียดสแกนยังพับอยู่
- ตรวจและอัปเดต README.md กับ DESIGN.md


### 20 พฤศจิกายน 2026 — จัดรายละเอียดสูตรเงินเดือน

- ส่วน How this is calculated แสดงฐานเงินเดือนจำลอง วันตามตาราง และวันที่นับได้ทีละบรรทัด พร้อมยอดประมาณการ แยกเวลาโบนัสและวันที่ควรตรวจสแกนออกเป็นกล่อง
- ใช้ผลคำนวณจากตัวประมาณเดิมและใช้จำนวนวันตามตารางจากค่าของโมเดล เทสต์เปิดรายละเอียดด้วยสแกนจำลองแบบครบและไม่ครบ และตรวจว่ายอดตรงกับหน้าสรุป
- Flutter tests ผ่าน 114 ข้อ Analyzer ไม่มี error หรือ warning มี SDK deprecation ระดับ info 43 รายการ สร้างและติดตั้ง APK บน Pixel แล้วตรวจภาพก่อนและหลังปรับ โดยเปิดการ์ดสูตรใหม่ทิ้งไว้
- ตรวจและอัปเดต README.md กับ DESIGN.md


### 20 พฤศจิกายน 2026 — แอนิเมชัน Login และ Logout

- เฟดเข้าหน้าปลายทาง 180 ms เมื่อ Login สำเร็จ หรือเมื่อออกจากระบบผ่าน Attendance และ Profile พื้นทึบบังหน้าก่อนหน้าและข้ามเฟดตามการตั้งค่าลดการเคลื่อนไหวของระบบ
- ทดสอบ Flutter ชุดเต็มผ่าน 114 ข้อ และทดสอบเฉพาะ UI ผ่าน 8 ข้อหลังเพิ่มการตรวจทางออกผ่าน Profile ใช้ API และบัญชีจำลองในการทดสอบ รวมถึงตรวจว่ากดย้อนกลับไปหน้าพนักงานไม่ได้หลัง Logout
- Analyzer ไม่มี warning หรือ error มี SDK deprecation ระดับ info 43 รายการ สร้างและเปิด Debug APK บน Pixel สำเร็จ การทดสอบ Login และ Logout ใช้บัญชีจำลอง ส่วน Pixel เปิดด้วยเซสชันเดิม
- ตรวจและอัปเดต README.md กับ DESIGN.md ให้ตรงกับการเปลี่ยนหน้า


### 20 พฤศจิกายน 2026 — เพิ่มหน้าปัด Cirrus บนหน้า Login

- มือถือใช้แผง deep navy เต็มความกว้าง ตามด้วยฟอร์มสีขาวนวลในพื้นที่เลื่อนเดียวกัน เดสก์ท็อปจัดแบรนด์และฟอร์มเคียงกัน หน้าปัดเป็นภาพตกแต่งแบบคงที่วาดด้วย Flutter
- เพิ่มคำสั่ง Next และ Done บนคีย์บอร์ดสำหรับช่องชื่อผู้ใช้และรหัสผ่าน คงการตรวจฟอร์มและการส่งข้อมูลไปยัง AuthService
- ตรวจภาพ Flutter บนมือถือ 390 × 844 และเดสก์ท็อป 1280 × 720 ภาพรีวิวรอบแรกอ่านเป็นเรดาร์จึงเพิ่มเข็มและจุดกลางหน้าปัด
- Flutter tests ผ่าน 112 ข้อ Analyzer มี SDK deprecation ระดับ info 42 รายการ ไม่มี error หรือ warning Build และติดตั้ง Debug APK พร้อมเปิดแอปบน Pixel 10 Pro XL สำเร็จ เซสชันเดิมยังพาเข้าหน้าหลัก จึงตรวจหน้าตา Login จากภาพ Flutter และไม่ได้ส่งรหัสผ่านจริง
- ตรวจและอัปเดต README.md กับ DESIGN.md


### 20 พฤศจิกายน 2026 — ปรับหน้า Pay estimate และ Local leave

- Pay estimate จัดตัวเลือกเดือนและยอดประมาณการไว้ในการ์ดเดียว แสดงฐานเงินเดือนจำลองข้างล่าง พร้อมสถานะเมื่อไม่มีสแกนหรือโหลดไม่สำเร็จ สูตรยังใช้ฐานเดิมและแสดงเวลาโบนัสแยกจากยอดเงิน
- Local leave รวมคำอธิบายกับฟอร์ม เพิ่มป้าย Start date และ End date ที่จัดซ้อนเมื่อพื้นที่จำกัด แสดงข้อผิดพลาดในฟอร์มและรายการแบบร่างด้านล่าง การเก็บแบบร่างยังอยู่ในเครื่อง
- Flutter tests ผ่าน 112 ข้อรวมการอ่านสแกน การบันทึกแบบร่างใน SharedPreferences จำลอง และการเรนเดอร์ภาพ Analyzer ไม่มี error หรือ warning มี SDK deprecation ระดับ info 42 รายการ
- Build และติดตั้ง Debug APK บน Pixel 10 Pro XL สำเร็จ ตรวจภาพทั้งสองแท็บจาก emulator แล้วโดยไม่ได้บันทึกใบลาบนอุปกรณ์
- ตรวจและอัปเดต README.md กับ DESIGN.md ให้ตรงกับ layout ใหม่


### 20 พฤศจิกายน 2026 — จัดหน้า Login ใหม่

- รวมโลโก้และแผงแบรนด์ navy/turquoise กับฟอร์มไว้ในกรอบเดียวเพื่อลดช่องว่างกลางหน้า มือถือวางซ้อนกัน เดสก์ท็อปวางเคียงกัน และเลื่อนได้เมื่อคีย์บอร์ดกินพื้นที่
- ปรับหัวข้อและป้ายช่องกรอกให้ชัด พร้อมคงปุ่มแสดงรหัสผ่าน ข้อความตรวจสอบ และการส่งค่าไปยัง AuthService เดิม
- Flutter tests ผ่าน 112 ข้อรวมการเรนเดอร์ภาพและกรณีจอแนวนอนที่ขยายตัวอักษร 2 เท่าและเปิดคีย์บอร์ด Analyzer ไม่มี error/warning มี SDK deprecation ระดับ info 42 รายการ
- Build และติดตั้ง Debug APK สำเร็จ เปิดหน้า Login บน Pixel 10 Pro XL แล้วและตรวจภาพ `.oil-ui/screenshots/login-after-refresh.png` รอบนี้ยังไม่ได้ทดสอบล็อกอินด้วยบัญชีจริง ส่วนเดสก์ท็อปตรวจจากภาพที่ Flutter เรนเดอร์
- ตรวจและอัปเดต README.md กับ DESIGN.md ให้ตรงกับหน้าใหม่


### 20 พฤศจิกายน 2026 (รอบ 2) — เพิ่ม Entry Animations ทั่วแอป

- **ขอบเขต:** UI-only ไม่แตะ services, models, auth, storage, eligibility หรือสูตรคำนวณใดๆ
- **Widget ใหม่ `lib/widgets/fade_slide_entry.dart`:** Ticker-safe animation ด้วย `AnimationController` + `Interval` curve สำหรับ stagger delay — ไม่ใช้ `Future.delayed` จึงไม่มี pending timer ใน tests
- **`lib/screens/login_screen.dart`:** Brand panel (slide from top/left), "Sign in" heading, username field, password field, Sign In button — stagger delay 80/150/210/280ms ผ่าน `FadeSlideEntry`
- **`lib/screens/history_screen.dart`:** MonthSelector, metric cards และ DailyScanList rows ด้วย `FadeSlideEntry`
- **`lib/screens/profile_screen.dart`:** Avatar card, section groups (Personal/Employment/General), logout button ด้วย `FadeSlideEntry`
- **`lib/screens/earnings_trial_tab.dart`:** Month selector, salary card และ AmbientPanel ด้วย `FadeSlideEntry`
- **`lib/screens/leave_trial_tab.dart`:** Form card และ draft cards ด้วย `FadeSlideEntry`
- **`lib/screens/attendance_screen.dart`:** `_mobileLayout` sections และ `_windowStepItem` ด้วย `flutter_animate` (safe — ไม่มี navigation tests ที่ติดขัด)
- **ผลตรวจ:**
  - `flutter analyze` ไฟล์ที่แก้: 2 `info` เท่านั้น (SDK deprecated_member_use ที่มีอยู่เดิม) ไม่มี warning/error
  - `flutter test` ทั้ง 10 ไฟล์ test: **87 ข้อผ่านทั้งหมด ✅** (0 failures, 0 skipped)
  - Build Debug APK สำเร็จ, ติดตั้งบน Emulator Pixel 10 Pro XL API 35
  - Screenshot: `.oil-ui/screenshots/login_anim.png`
- **เทคนิคสำคัญที่ค้นพบ:** `Future.delayed` ใน widget `initState` ทำให้ Flutter test framework ร้องว่า "A Timer is still pending" หลัง widget disposed — แก้โดยใช้ `AnimationController` + `Interval(delayRatio, 1.0)` curve แทน ไม่มี timer ค้างเลย
- **ตรวจ README.md:** ภาพรวม/โครงสร้าง/วิธีรันไม่เปลี่ยน

### 20 พฤศจิกายน 2026 — เน้นช่วงลงเวลาและผลสแกนล่าสุด

- หน้า Attendance แยกไทล์ช่วงลงเวลาจาก Today’s Activity เน้นช่วงปัจจุบันด้วย turquoise และใช้เครื่องหมายถูกกับช่วงที่บันทึกแล้ว
- การ์ดกิจกรรมบนมือถือเน้นเวลาสแกนล่าสุดและแสดงเหตุผลของรายการที่ไม่นับในกล่องเตือน ใช้ข้อมูลและเงื่อนไขเดิม
- แก้ชั้น Material ของ Settings และช่องครึ่งวันใน Leave หลังชุดทดสอบเต็มพบว่าพื้นการ์ดบังเอฟเฟกต์ตอนกด
- ทดสอบผ่านทั้งชุด 111 ข้อ รวมการจับภาพด้วยข้อมูลจำลอง ตรวจภาพสถานะ Afternoon In และรายการที่ไม่นับแล้ว
- Flutter analyzer ไม่มี warning หรือ error และยืนยันหน้า Attendance บน Pixel 10 Pro XL หลังติดตั้ง APK ใหม่
- ตรวจและอัปเดต README.md กับ DESIGN.md

### 20 พฤศจิกายน 2026 — ปรับ UI/UX ทันสมัยหน้า History, Profile, Pay estimate และ Local leave

- **ขอบเขต:** ปรับ UI/UX ทุกหน้านอกหน้า Attendance และ Login ให้ทันสมัยและคงธีม navy/teal 60/30/10 เดิม ไม่แก้ API, auth, storage, eligibility หรือสูตรคำนวณใดๆ
- **History Screen (`lib/screens/history_screen.dart`):**
  - `_MonthSelector`: pill container + calendar icon + ปุ่มก่อน/หลังชัดเจน
  - `_MetricCard`: white surface card พร้อม border/shadow, uppercase label, icon badge (แทน flat card สี)
  - `_DailyScanList`: card-per-row แยกด้วย gap (ไม่ใช้ Divider)
  - `_DailyScanRow`: calendar icon + bold date, working-hours pill badge, metric row บน navy panel พร้อม divider
  - `_MetricMini`: centered column พร้อม icon, uppercase label, bold value; `isHighlight` parameter
- **Profile Screen (`lib/screens/profile_screen.dart`):**
  - `_sectionLabel`: bold navy 14px uppercase
  - `_groupCard`: surface card พร้อม border/shadow (แทน Material)
  - `_profileField`: teal icon badge, uppercase label (11px), bold value (15px)
  - Avatar card: white surface พร้อม teal ring + glow shadow, navy bg avatar อักษรย่อ teal
  - Role badge: navy pill + teal icon + white bold text
  - Log Out: red `OutlinedButton.icon` pill shape (แทน navy FilledButton)
- **Work Trial Screen (`lib/screens/work_trial_screen.dart`):**
  - TabBar แบบ pill container + `BoxDecoration` indicator (navy selected, surface unselected)
- **Earnings Trial Tab (`lib/screens/earnings_trial_tab.dart`):**
  - Month selector: pill + calendar icon (เข้าชุดกับ History)
  - Salary card: white surface + UPPERCASE label + icon badge + bold large numeral + navy pill subtitle
  - Refresh button: `OutlinedButton.icon` pill shape + surface bg
- **Leave Trial Tab (`lib/screens/leave_trial_tab.dart`):**
  - Form ครอบใน white surface card (border/shadow)
  - Date buttons: 2 ปุ่มข้างกัน (แทนเรียงซ้อน)
  - Save button: navy FilledButton pill + white loading spinner
  - Draft cards: individual card + teal icon + status pill badge + navy bg reason + red cancel button
- **ผลตรวจและหลักฐาน:**
  - `flutter test test/app_bottom_nav_test.dart test/ui_refresh_test.dart test/widget_test.dart` ผ่านทั้งหมด 11 ข้อ (5+5+1)
  - Dart analyzer ไฟล์ที่แก้ไม่มี error หรือ warning มีเฉพาะ SDK-level info deprecation
  - Build Debug APK สำเร็จ, ติดตั้งบน Emulator Pixel 10 Pro XL API 35
  - ตรวจภาพจริงผ่าน screencap: `.oil-ui/screenshots/refresh-earnings.png`, `refresh-history.png`, `refresh-profile.png`, `refresh-leave.png` ✅
  - ตรวจ README.md แล้ว ภาพรวมและโครงสร้างระบบหลักไม่เปลี่ยนแปลง

### 20 พฤศจิกายน 2026 — ปรับ Bottom Navigation ยุบลงตอนกดและตัดการแสดงไอคอนซ้ำตาม Dribbble Concept

- **ปัญหาเดิม:** ขณะเปลี่ยนแท็บ ฟองลอยสลับไอคอนเป็นปลายทางทันทีขณะยังอยู่ตำแหน่งเดิม ทำให้เกิดไอคอนของแท็บปลายทางซ้อนกับแท็บต้นทาง (ไอคอนซ้ำกัน) และฟองลอยเคลื่อนที่ลอยผ่านกลางอากาศโดยไม่ยุบตัวลงตามการออกแบบใน Dribbble
- **การแก้ไข:**
  - แปลง `AppBottomNav` เป็น `StatefulWidget` เพื่อควบคุม micro-interaction ได้แม่นยำ
  - **ยุบลงตอนกด (Sink down on tap/move):** ขณะเปลี่ยนแท็บ ฟองลอยจะยุบตัวลงไปในรอยเว้า (แกน Y เลื่อนลงลึก 22px และ scale ยุบลงเหลือ 0.72) เคลื่อนที่ไปตามรอยเว้าอย่างนุ่มนวล และเมื่อถึงปลายทางจะเด้งลอยขึ้นมา (pop up) ด้วย bounce easing
  - **การแตะสัมผัส (Tactile feedback):** เมื่อแตะกด (`onTapDown`) ฟองลอยจะตอบสนองด้วยการยุบตัวลง 6px ทันที และเมื่อแตะแท็บเดิมที่เลือกอยู่แล้วจะเล่นแอนิเมชัน bounce ยุบลง 10px แล้วดีดกลับ
  - **ตัดไอคอนซ้ำ (Strict no-duplication):** ซิงค์การแสดงผลของไอคอนในแถบนำทาง — ไอคอนปลายทางจะคงอยู่จนกว่าฟองลอยจะเคลื่อนมาถึงและเริ่มลอยขึ้น ส่วนไอคอนต้นทางจะซ่อนไว้จนกว่าฟองลอยจะยุบตัวลงและออกจากตำแหน่งเดิม จึงไม่มีจังหวะที่ไอคอน 2 ตัวปรากฏซ้อนกัน และนำ duplicate icon widget ออกจาก widget tree เมื่อไม่ได้ถูกเลือก
- **การทดสอบและการแสดงผลจริง:**
  - เพิ่มการทดสอบใน `test/app_bottom_nav_test.dart` ครอบคลุมการยุบตัวของฟองลอย, การเด้งกลับเมื่อแตะแท็บเดิม, และการไม่ปรากฏไอคอนซ้ำซ้อนในทรี ทั้งหมด 5 ข้อผ่าน 100%
  - รัน `ui_refresh_test.dart` ผ่าน 6 ข้อ และ `widget_test.dart` ผ่าน 1 ข้อ
  - ตรวจสอบ Dart analyzer บน `lib/widgets/app_bottom_nav.dart` ไม่มี error หรือ warning
  - Build Debug APK สำเร็จ และติดตั้งลงในเครื่อง Emulator Pixel 10 Pro XL API 35 ผ่าน ADB
  - ทดสอบสลับแท็บจริงผ่าน ADB input tap และจับภาพหน้าจอ `.oil-ui/screenshots/nav-attendance.png`, `nav-profile.png`, `nav-history.png` ยืนยันการแสดงผลและ micro-interaction ถูกต้อง สวยงามตรงตามสเปก
  - ตรวจสอบ `README.md` แล้ว ภาพรวมและโครงสร้างระบบหลักของแอปไม่เปลี่ยนแปลง

### 20 พฤศจิกายน 2026 — ติดตั้งชุด Skills (Superpowers, UI-UX Pro Max, Caveman, Brainstorming, Oil-UI)

- ติดตั้ง Skills ลงใน `~/.gemini/skills/` (Global) และ `.agents/skills/` (Workspace):
  - **Superpowers suite:** `using-superpowers`, `diagnosing-superpowers`, `writing-plans`, `executing-plans`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`
  - **Brainstorming:** ทักษะสำรวจความต้องการ วางแนวคิด และออกแบบระบบก่อนลงมือพัฒนา
  - **UI-UX Pro Max:** คลังข้อมูลและคำแนะนำการออกแบบ UI/UX, Design Systems, Palettes และ Accessibility
  - **Oil-UI:** เครื่องมือและกระบวนการปรับแต่งหน้าตาแอป/เว็บตามมาตรฐาน DESIGN.md
  - **Caveman suite:** โหมดสื่อสารกระชับ ลด token พร้อมชุดเครื่องมือ `caveman-*`
- อัปเดต [AGENTS.md](AGENTS.md) กำหนดการเรียกใช้งานทักษะใหม่ตามบริบทของงาน
- ตรวจสอบ [README.md](README.md) แล้ว ภาพรวมและโครงสร้างระบบหลักของแอปไม่เปลี่ยนแปลง

### 20 พฤศจิกายน 2026 — แก้ไข UI หน้าแรก (Attendance) ไม่ให้ทับซ้อนและจัดระเบียบตามธีม 60/30/10

- **ปัญหาเดิม:** การ์ด Check In ใช้ `Transform.translate(offset: Offset(0, -12))` ซ้อนทับขอบล่างของ AmbientPanel จนตัดขาดตอน, ปุ่ม `TimeActionButton` ฟิกความกว้าง 320px ทำให้ล้นหรือจัดกึ่งกลางไม่กลมกลืน, และการจัดตำแหน่ง Greeting/Chip บนพื้นหลังมืดทำให้คอนทราสต์ลดลง
- **การแก้ไข:**
  - จัด Greeting (`Good morning, Jirawat`), วันที่ และ Status Chip (`Morning In`) ไว้บนพื้นผ้าใบสว่างด้านบน ให้คอนทราสต์ตัวอักษรและสีชิปคมชัดตามหลัก WCAG AA
  - ปรับ `_mobileClockPanel` (AmbientPanel) เน้นแสดงนาฬิกา Live Clock ชัดเจน ขนาดมุมโค้งมนสมส่วน ไม่มี negative offset
  - ปรับ `_mobileActionCard` แยกอิสระเป็นการ์ดขาวมนสวยงาม ไม่ซ้อนทับกรอบนาฬิกา
  - ปรับ `TimeActionButton` ให้ขยายเต็มการ์ดแบบ fluid `ConstrainedBox` และปรับ padding ให้พอดีกับหน้าจอมือถือ
  - สัดส่วนธีม 60/30/10: พื้นหลัง 60% ขาวนวลอมเทา, การ์ดนาฬิกา 30% Deep Navy, และปุ่ม/แอกเซนต์ 10% Turquoise
- **ผลทดสอบและการแสดงผล:**
  - รัน `flutter test test/ui_refresh_test.dart` ผ่านครบทั้ง 5 ข้อ (ทดสอบ `TODAY'S ACTIVITY` ไม่ตกขอบจอ, คอนทราสต์สี, คีย์บอร์ด)
  - รัน `attendance_screen_checkin_test.dart` และ `attendance_screen_progress_test.dart` รวม 16 ข้อผ่านทั้งหมด
  - Rebuild Debug APK สำเร็จ, ติดตั้งลงเครื่อง Emulator (Pixel 10 Pro XL API 35) ผ่าน `adb install -r`
  - ยืนยันการแสดงผลผ่าน framebuffer จริงของ Emulator ที่เวลา 10:57:04 (`attendance-screen-v2.png`) หน้าจอแสดงผลถูกต้อง ไม่มีองค์ประกอบทับซ้อน
  - ตรวจสอบ `README.md` แล้ว เนื้อหาภาพรวมยังคงถูกต้องสอดคล้องกับงาน

### 20 พฤศจิกายน 2026 — แก้ปุ่ม Check In ดูเหมือนหาย

- ตรวจ emulator จริง: ปุ่มไม่ได้ถูกถอด แต่แสดง Morning In เป็นสีเทาและไม่มีเหตุผลบนปุ่ม เพราะ latestCountedEvent ตรงกับช่วงปัจจุบัน ทำให้ผู้ใช้หา Check In ไม่พบ
- คืนชื่อการกระทำ Check In/Check Out แสดงชื่อช่วงเป็น hint; สถานะลงเวลาแล้วใช้เครื่องหมายถูก ข้อความ Already recorded และขอบ/ตัวอักษรชัดเจน ยังคงป้องกันส่งซ้ำ
- ขั้นตอนกล้อง/upload/submit/retry และ progress/UI เดิมผ่าน 15 ข้อ เพิ่ม regression test ให้ปุ่มลงเวลาแล้วต้องปรากฏและกดไม่ส่ง POST
- ตรวจและอัปเดต README.md; ไม่แก้ Backend/eligibility หรือข้อมูลการลงเวลา
- Regression/UI รอบเพิ่มผ่าน 5 ข้อ; analyzer ไม่มี error/warning มี info 4 ข้อ สร้างและติดตั้ง APK ใหม่แล้ว ตรวจ emulator จริงเห็น Check In พร้อม Morning In • Already recorded และเครื่องหมายถูก

### 20 พฤศจิกายน 2026 — Bottom Navigation micro interaction

- ดู GIF จริงจากลิงก์ Dribbble ที่ผู้ใช้ส่ง แล้วปรับเมนูล่างเป็นวงกลมลอยและรอยเว้าที่เคลื่อนพร้อมกัน พร้อมยกข้อความเมนูที่เลือก
- ใช้ native Flutter animation/custom painter ไม่เพิ่ม dependency; คงสี่ปลายทางและ desktop rail เดิม รองรับ keyboard, selected semantics และ reduced motion
- ทดสอบตำแหน่งระหว่างแอนิเมชัน การเปลี่ยนเป้าระหว่างทาง reduced motion และ callback indices พร้อม capture/navigation/accessibility เดิม รวม 8 ข้อผ่าน
- ตรวจ README.md/DESIGN.md และภาพ `.oil-ui/screenshots/nav-*.png` แล้ว
- Analyzer ไม่มี error/warning มี Material deprecation info 2 ข้อ; build/install APK ใหม่สำเร็จ และตรวจ emulator จริงจาก Attendance ไป Profile เห็นวงกลมย้ายมาหยุดตรง Profile แล้ว

### 20 พฤศจิกายน 2026 — แก้ emulator แสดง Profile รุ่นเก่า

- ผู้ใช้พบว่าแอพที่เปิดจริงยังแสดง CONTACT/ACCOUNT/SETTINGS แม้โค้ดเปลี่ยนแล้ว การยืนยัน hot restart รอบก่อนจึงไม่เพียงพอ
- Build APK ใหม่ ติดตั้งด้วย `adb install -r` โดยเก็บข้อมูลเดิม หยุด process เก่าและเปิดแอพใหม่
- ตรวจผ่านหน้าต่าง emulator จริงถึง Profile ของบัญชีที่ล็อกอินแล้ว ยืนยัน avatar สี mint และหัวข้อ Personal information / Employment / General ตรงกับโค้ดล่าสุด
- ตรวจ README.md แล้ว ภาพรวมและวิธีใช้งานไม่เปลี่ยน รอบนี้ไม่แก้โค้ดหรือ Backend

### 20 พฤศจิกายน 2026 — Profile ตามภาพอ้างอิง

- จัด avatar อักษรย่อ/ชื่อ/อีเมล/บทบาทแบบกึ่งกลาง แบ่งข้อมูลจริงเป็น Personal information, Employment และ General
- แถวข้อมูลใช้ icon tile และ label/value แบบซ้อน เลือกคัดลอกค่าได้ ไม่ตัดชื่อหรืออีเมลด้วย ellipsis
- คง fetchMe, refresh, error/retry, Settings placeholder และ logout เดิม ไม่เพิ่มเมนูแก้ไขหรือระบบบัญชีที่ยังไม่มี
- ตรวจ README.md/DESIGN.md และภาพ `.oil-ui/screenshots/profile-profile-mobile.png`; capture/navigation tests ผ่าน 2 ข้อ analyzer ไม่มี error/warning มี deprecation info 1 ข้อ
- Independent screenshot review: ลดระยะส่วนหัวและนำอีเมลซ้ำในรายการออก โดยเก็บอีเมลที่เลือกคัดลอกได้ใต้ชื่อ; capture รอบแก้ผ่านและตรวจภาพแล้ว

### 20 พฤศจิกายน 2026 — Soft layered UI ตามภาพอ้างอิงใหม่

- เพิ่ม AmbientPanel วาดพื้นหลังโค้งไล่แสงด้วย Flutter ใช้ร่วมใน Login, Attendance และ Pay; การตกแต่งถูกซ่อนจาก accessibility semantics
- ปรับการ์ดลงเวลาให้ซ้อนบน hero และเมนูล่างเป็นแคปซูลสีอ่อน เลือกเมนูด้วย navy/turquoise
- ตรวจภาพอิสระและปรับเงาที่หนักกับลายโค้งที่แข็งให้เบาลง คงข้อความจริงและพฤติกรรมเดิม
- ตรวจและอัปเดต README.md/DESIGN.md; ไม่เพิ่ม dependencies ไม่แก้ API/storage/สูตรเงินเดือน
- ก่อนเก็บรายละเอียดตาม review: screenshot/accessibility/pay-leave/navigation tests ผ่าน 9 ข้อ; analyzer ไม่มี error/warning มี info 6 ข้อ
- หลังเก็บรายละเอียดเงาและการ์ดซ้อน: screenshot/accessibility tests ผ่าน 5 ข้อ ตรวจภาพล่าสุดแล้ว
- Android debug build/install สำเร็จและเปิดแอพบน emulator แล้ว; analyzer รอบสุดท้ายไม่มี error/warning มี info 6 ข้อ

### 20 พฤศจิกายน 2026 — ปรับตามภาพอ้างอิง editorial/bento

- เพิ่มน้ำหนักตัวเลขเวลาและยอดเงิน จัด clock panel ใหม่ ปุ่มลงเวลา turquoise พร้อมข้อความ navy ลดกรอบซ้อนและเพิ่มมุมโค้งร่วมกัน
- ปรับ desktop panel ให้สูงตามเนื้อหาและเลื่อนหน้าจอสั้นได้ เปลี่ยน Refresh estimate เป็นปุ่มรองตาม independent visual review
- ตรวจ README.md และ DESIGN.md ให้ตรงกับงาน เปลี่ยนเฉพาะ presentation ไม่แก้สูตร/API/storage
- ภาพหลักฐานอยู่ `.oil-ui/screenshots/reference-*.png` ใช้ข้อมูลจำลองในการตรวจภาพ
- ทดสอบรอบแรก 13 ข้อผ่าน; หลังแก้ตาม review ทดสอบ capture/accessibility/pay-leave 8 ข้อผ่าน และ analyzer ไฟล์ที่แก้ไม่มี error/warning มี info 5 ข้อ
- Android debug build/install รอบสุดท้ายสำเร็จ และเริ่ม Flutter app บน emulator แล้ว

### 20 พฤศจิกายน 2026 — ปรับธีม 60/30/10 และตรวจ emulator

- ใช้ oil-ui และ ui-ux-pro-max ปรับขาวนวลอมเทา/navy/turquoise จาก shared tokens ลดกรอบการ์ด และเปลี่ยนปุ่มลงเวลาเป็นทรงสี่เหลี่ยมมน
- ปรับเมนูล่างและย่อ desktop panel ตาม independent screenshot review โดยคง API และสูตรเดิม
- ติดตั้ง Python 3.13.7 แบบ portable จาก python.org ที่ `.tools/python` และรันเครื่องมือค้นคำแนะนำของ ui-ux-pro-max ได้
- ตรวจ README.md และ DESIGN.md ให้ตรงกับธีมใหม่ ผลทดสอบรอบแรกผ่าน 13 ข้อ (รวม screenshot capture); analyzer ไฟล์ UI ไม่มี error/warning มี info 5 ข้อ
- Emulator ตอบ ADB และ boot สำเร็จ แต่แอพอยู่สถานะ stopped/background และ Flutter debug session เก่าหลุด จึงเปิดแอพและรัน debug ใหม่
- หลังปรับ desktop/ขนาดปุ่มรอบสุดท้าย screenshot capture และ accessibility tests ผ่าน 5 ข้อ; analyzer ไม่มี error/warning มี info 5 ข้อ; Android debug build และติดตั้งสำเร็จ
- หน้าระบบ NotificationShade ของ emulator ไม่ตอบสนองต่อการย้อนกลับ/ปัด จึง reboot Android โดยไม่ล้างข้อมูลแอพ
- หลัง reboot ยืนยันหน้า Sign in ธีมใหม่แสดงผล และช่อง Username รับ focus/เปิด keyboard ได้แล้ว ผู้ใช้ต้องเข้าสู่ระบบเพื่อทดสอบหน้าข้อมูลจริงต่อ

### 20 พฤศจิกายน 2026 — ทดลองสูตรเงินเดือนรายเดือน

- เปลี่ยนหน้า Pay estimate เป็นเงินเดือนจำลอง 13,000 บาท อ่านสแกนอัตโนมัติ คำนวณรายวันจาก 26 วัน และแสดงเวลาโบนัสหลัง 17:00 โดยไม่ตีราคาโบนัส
- อ้างอิงสูตรหาอัตรารายวันจากบทความ HumanSoft; 26 วันเป็นสมมติฐานของโปรเจค
- ตรวจ README.md และแก้ความสามารถที่เปลี่ยน; ไม่เปลี่ยน Backend หรือข้อมูลใบลา
- ทดสอบสูตรและหน้าจอที่เกี่ยวข้อง 18 ข้อผ่าน; analyzer ไฟล์ที่แก้ไม่มี error/warning

### 20 พฤศจิกายน 2026 — จัดเอกสารถาวร

- ใช้ README.md สำหรับภาพรวม และ TASK_STATUS.md สำหรับงานทำแล้ว/ยังไม่ทำ แก้ข้อมูลจำนวนแท็บและผลตรวจที่ล้าสมัยใน README
- เพิ่ม AGENTS.md เพื่อกำหนดให้อ่านและอัปเดตเอกสารหลักหลังการเปลี่ยนแปลงทุกครั้ง
- สรุปสถานะตั้งต้นจากโค้ดและบทสนทนา โดยแยกแผนเงินเดือนรายเดือน/bonus ออกจากฟีเจอร์ทดลองปัจจุบัน

### 20 พฤศจิกายน 2026 — ปรับ UI ด้วย Oil UI

- ปรับ shared theme, navigation, attendance action, Login และฟอร์ม Pay & Leave
- ปรับ keyboard activation, การตัดข้อความ และสถานะ disabled พร้อม focused tests ผ่าน 21 ข้อ
- คงบริการ API, models, environment, dependencies และสูตรคำนวณเดิ

### งานก่อนจัดทำบันทึกนี้

- ตรวจโปรเจค เตรียม Flutter/emulator ตั้ง IP ของ API และเพิ่มฟีเจอร์ทดลองค่าแรง/ใบลา ตามรายการทำแล้วด้านบน
- บันทึกย้อนหลังเป็นภาพรวม เนื่องจากไม่มีประวัติ version control ใน workspace นี้ที่ใช้ยืนยันวันที่ของแต่ละรายการ

### 20 พฤศจิกายน 2026 — ปุ่มลงเวลาวงกลมและไทม์ไลน์

- ทำแล้ว: ปรับปุ่ม Check In / Check Out เป็นวงกลม ลดขนาดแผงนาฬิกาบนมือถือ และเชื่อมสี่ช่วงเป็นไทม์ไลน์แสดง Recorded, Open, Passed และ Pending ทั้งมือถือและ desktop
- เวลาเปิดรอบถัดไปยังรอข้อมูลจาก Backend ตรวจฟิลด์สถานะพนักงานบน Pixel พบ currentWindowCode และ serverTime แต่ไม่มีเวลาเปิดรอบถัดไป แอปแสดงชื่อช่วงถัดไปเมื่อระบุได้ พร้อม Opening time unavailable
- ตรวจแล้ว: Flutter tests ผ่านทั้ง 111 ข้อรวมภาพจำลองและกรณีปิดส่งซ้ำ Analyzer รายงาน info 42 รายการ ไม่มี warning หรือ error ติดตั้ง debug APK แบบเก็บข้อมูลเดิมและตรวจพบ Check In กับ Opening time unavailable บน Pixel โดยไม่ได้ส่งรายการลงเวลาจริง
- ตรวจและปรับ README.md กับ DESIGN.md ให้ตรงกับหน้าใหม่

### 20 พฤศจิกายน 2026 — ขยายปุ่มหลักหน้า Attendance

- ขยายวงกลมจาก 156 เป็น 261 logical pixels บนจอกว้าง 390 เพิ่มขอบ deep navy ไอคอนและตัวอักษร ย่อนาฬิกาบนมือถือให้เหลือบรรทัดเดียวเมื่อพื้นที่พอ
- Flutter tests ผ่าน 111 ข้อ ตรวจภาพสถานะเปิดจากข้อมูลจำลองบนจอ 390 × 844 แล้ว ติดตั้ง APK และเปิดแอปบน Pixel emulator โดยเก็บข้อมูลเดิม
- ตรวจและอัปเดต README.md และ DESIGN.md ข้อจำกัดเรื่องเวลาเปิดรอบและการทดสอบลงเวลาจริงยังเหมือนเดิม

### 28 พฤศจิกายน 2026 — ปลดล็อกสแกนลงเวลาในแอปสำหรับโหมดช่างเมื่อยังไม่มี Job Code

- **ทำแล้ว:**
  - **ปลดล็อกปุ่มวงกลมหลักในโหมดช่าง (`lib/screens/attendance_screen.dart`, `lib/widgets/technician_attendance_section.dart`):**
    - สิ่งที่ทำ: ส่งสถานะช่วงเวลาลงเวลาที่เปิดอยู่ (`Morning In`, `Lunch Out`, `Afternoon In`, `Leave`) และ callback `_checkIn(windowCode)` เข้า `TechnicianJobActionZone` เพื่อเปิดให้กดสแกนลงเวลาผ่านแอปได้โดยตรง (`Scan · <Window>`) เมื่อยังไม่ได้เลือก Job Code
    - ปัญหาที่พบ → วิธีแก้ไข: เดิมปุ่ม `CHECK IN` โหมดช่างล็อกบังคับให้เลือก Job Code ก่อนเสมอ ทำให้วันที่ยังไม่มีงานเข้า (`NO JOBS AVAILABLE TODAY`) ช่างกดสแกนเข้างานผ่านแอปไม่ได้ทั้งที่ช่วง `MORNING IN` เปิดอยู่ → เพิ่มเงื่อนไขปลดล็อกปุ่มเมื่อช่วงเวลาลงเวลาเปิดอยู่และยังไม่เคยสแกนช่วงนั้น (ปรับ `_pendingLookup == null || absent` และใช้ `openAttendanceWindowKind == 'in'` เพื่อให้ `lunch_out` แสดงเป็น `Check Out` ตรงตามช่วงเวลา; เพิ่มเทสต์ใน `test/technician_attendance_test.dart`)
  - **ซิงก์สถานะสแกนลงเวลาแบบเรียลไทม์อัตโนมัติ (`lib/screens/attendance_screen.dart`):**
    - สิ่งที่ทำ: เพิ่ม `_ensureAttendancePolling()` และ `_pollAttendanceStatusSilently()` ดึง `/app-attendance/status` และ `/my-scans` เงียบๆ ทุก 15 วินาทีขณะเปิดแอปอยู่หน้าหลัก และรีเฟรชทันทีเมื่อสลับกลับเข้าแอป (`AppLifecycleState.resumed`) ทั้งบัญชี Office และ Technician พร้อมหยุด timer เมื่อพับแอป (`paused`/`detached`)
    - ปัญหาที่พบ → วิธีแก้ไข: เดิมระบบ poll อัตโนมัติเฉพาะรายการ Job Code ของช่าง ทำให้เวลาพนักงานไปสแกนที่เครื่องสแกนนิ้วแล้วกลับมาดูแอป สถานะปุ่มและไทม์ไลน์ไม่อัปเดตจนกว่าจะกด Refresh เอง → เพิ่ม foreground polling แยกเฉพาะสถานะสแกนและปิดอัตโนมัติใน Widget Test (`_isWidgetTest`) เพื่อไม่ให้ค้าง timer ในชุดทดสอบ
  - **สร้างเอกสาร Spec จัดระเบียบรายงานช่างสำหรับฝั่งเว็บ (`docs/REPORT_FORMAT_SPEC.md`):**
    - สิ่งที่ทำ: สรุป Marker หัวข้อใน `workDescription` (`[ปัญหาที่พบ / Issues]`, `[งานค้างต่อ / Recommendations]`, `[ส่งรายงานช้า / Late Report: +N min]`), ตัวอย่าง JSON จริง, และโค้ด TypeScript Parser พร้อมแนวทางแสดงผลแยกกล่องสีบนเว็บ
    - ปัญหาที่พบ → วิธีแก้ไข: ฝั่งเว็บรับข้อความรวมก้อนเดียวจาก `workDescription` จึงดูกลืนกัน → ทำไฟล์ Spec ส่งทีมเว็บแยกแสดงผลฝั่ง Frontend โดยไม่กระทบ Backend/Database เลย 100%
  - **ปรับรอบตัดเงินเดือนหน้า Pay Estimate เป็นตัดวันที่ 25 · เงินเข้าวันที่ 5 (`lib/models/payroll_calculator.dart`, `lib/screens/earnings_trial_tab.dart`):**
    - สิ่งที่ทำ: เพิ่ม `PayrollCycle` (`26 เดือนก่อน → 25 เดือนนี้`, `payday` วันที่ 5 เดือนถัดไป) พร้อมแถบ `payroll-cycle-banner` แสดงช่วงวันตัดรอบ, วันเงินเข้า, และตัวนับถอยหลัง โดยยังคงหน้า `History` เป็นเดือนปฏิทินตามเดิม
    - ปัญหาที่พบ → วิธีแก้ไข: (1) เดิมคำนวณวันที่ `1–สิ้นเดือน` ไม่ตรงรอบบริษัท และ (2) AI Subagent (`Payroll Cycle Auditor`) ตรวจพบเทสต์เก่าที่ใช้ `วันที่ 2 ของเดือนปฏิทิน` ตกนอกรอบเมื่อรันหลังวันที่ 25 รวมถึง `daysUntilPayday` ข้าม DST → ปรับใช้ `PayrollCycle.forDate(...)`, `DateTime.utc` ในการนับวัน, `AppStrings.monthShort` กันข้อความล้น และเพิ่ม unit tests (`test/payroll_calculator_test.dart`, `test/work_trial_screen_test.dart`, `test/pay_calculator_screen_test.dart`)
  - **สแกนและอุดช่องโหว่ + Human Error 7 จุด โดยไม่กระทบ UI/UX และ Backend (AI Subagents: Security & UX Auditors):**
    - สิ่งที่ทำ: (1) ล้าง `_cachedTeamMemberId` และ `lastDashboardData` ทั้งใน `AuthService._clearLocalSession()`, `switchToAccount()`, และ `AttendanceScreen._logout()` พร้อมยกเลิก Work Timer Notification; (2) ส่ง `authenticated: true` ให้ `POST /auth/logout` และเพิ่ม `.timeout(authRequestTimeout)` ใน `AuthService._request`; (3) ล้างคีย์ให้ครบใน `switchToAccount()` rollback เมื่อ `prev* == null`; (4) เพิ่ม `try/catch` ปิด `switching-account-dialog` ใน `ProfileScreen` ไม่ให้ค้าง; (5) ป้องกัน `TypeError`/`FormatException` ใน `AttendanceService` (`Map<String, dynamic>.from` และ `MediaType.parse` fallback); (6) เพิ่มตัวกันกดซ้ำ (`saving` ใน `PayrollManagementScreen._openItemDialog`, `_submitting` หลัง dialog ใน `TechnicianReportScreen._submit`); (7) หยุด `_techPollTimer` เมื่อแอปพับเข้า background
    - ปัญหาที่พบ → วิธีแก้ไข: เดิมสลับบัญชี/ออกจากระบบอาจเหลือ cache ช่างคนเก่า, dialog สลับบัญชีอาจค้างถ้า throw error, และกดบันทึกซ้ำเร็วๆ ในฟอร์มค่าแรง/รายงานอาจยิงซ้อน → อุดทุกจุดฝั่ง client โดยไม่แตะ UI/UX, Storage format, หรือ Backend API
  - **ขัดเกลา `AppBottomNav` ให้สมูทและมีมิติขึ้น (`lib/widgets/app_bottom_nav.dart`):**
    - สิ่งที่ทำ: ปรับจังหวะเลื่อนเป็น `380ms Curves.easeOutQuart`, เพิ่ม `AnimatedSwitcher` (`easeOutBack` + `FadeTransition`) ให้ไอคอนในฟองลอย, ไล่สี label ด้วย `Color.lerp`, เพิ่มขอบบางๆ (`cardBorder`) รอบ `_NavigationSurface` และเงาสองชั้น + ขอบ Teal จางๆ บนฟองลอย
    - ปัญหาที่พบ → วิธีแก้ไข: เดิมสีข้อความใต้ฟองตัดเปลี่ยนทันทีที่ `progress > 0.5` และตัวแถบไม่มีเส้นขอบแยกจากพื้นหลังในธีมสว่าง → ใช้ `Color.lerp` ไล่สีและเพิ่ม hairline stroke บน path รอยเว้าโดยคงทุก key และรองรับ reduced motion เต็มรูปแบบ
  - **เพิ่มการ์ด `ASSIGNED CREW` + ย่อรายชื่อทีม + สี Priority ตรงกับเว็บ (`lib/screens/technician_jobs_screen.dart`):**
    - สิ่งที่ทำ: เพิ่มการ์ด `ASSIGNED CREW (N)` (`Key('job-assigned-crew-card')`) แสดงชิปทีมช่างพร้อมอักษรย่อและไฮไลต์ป้าย `YOU / คุณ` ในหน้า `TechnicianJobDetailScreen`, ย่อรายชื่อบนการ์ดเป็น `A, B +N` เมื่อมี 3+ คน, และปรับสี `_priorityPill` (`urgent` แดง, `high` ส้ม, `medium` ฟ้า) ให้ตรงกับ `SYSTEM_OVERVIEW.md`
    - ปัญหาที่พบ → วิธีแก้ไข: เดิม `assignedToName` แสดงเป็นข้อความยาวบรรทัดเดียวทำให้ล้นเมื่อมีช่างหลายคนและไม่เน้นตัวผู้ใช้ → แยกเป็น `_parseCrewNames` + `_formatCompactCrew` และเพิ่มเทสต์ใน `test/technician_attendance_test.dart`
  - **อัปเดตป้ายเวอร์ชันใน Settings เป็น Beta (`lib/screens/settings_screen.dart`):**
    - สิ่งที่ทำ: เปลี่ยนข้อความแสดงเวอร์ชันใน `About` จาก `1.0.0 (Build 2026.11)` เป็น `1.0.0-beta (Build 2026.11)` (EN/TH/MS)
    - ปัญหาที่พบ → วิธีแก้ไข: แอปยังอยู่ในช่วงทดสอบภาคสนาม จึงติดป้าย `-beta` ให้ผู้ใช้และทีมเห็นชัดเจน
  - **เพิ่มหน้า `Help & Guide` / คู่มือ & คำถามที่พบบ่อย (`lib/screens/help_faq_screen.dart`, `lib/screens/settings_screen.dart`):**
    - สิ่งที่ทำ: สร้าง `HelpFaqScreen` แบบ Accordion แตะกาง/ยุบได้ 5 คำถามสำคัญสำหรับผู้ใช้จริง (สแกนแอปกับเครื่องนิ้ว, ขั้นตอนช่าง, ส่งรายงานก่อน 07:00 น., รอบเงินเดือน 26–25/เงินเข้าวันที่ 5 & ใบลา PDF, แก้ปัญหาเบื้องต้นกล้อง/GPS) รองรับ EN/TH/MS และทั้ง 3 ธีม เชื่อมเข้าจาก `Settings > ABOUT` พร้อมอัปเดต `PROJECT_STRUCTURE.md` และเพิ่มเทสต์ใน `test/settings_screen_test.dart`
    - ปัญหาที่พบ → วิธีแก้ไข: ช่วงปล่อย Beta พนักงานและช่างมักถามซ้ำเรื่องเครื่องสแกนนิ้ว, เวลาส่งรายงาน 07:00 น. และรอบตัดเงินเดือน → คัดเฉพาะ 5 ข้อสำคัญและย่อคำตอบให้กระชับ 1–2 ประโยคพร้อมพับเริ่มต้นเพื่อให้อ่านง่ายในหน้าเดียวโดยไม่ต้องแก้ Backend
  - **กรองงานที่ส่งรายงานจบแล้วออกจาก Notification งานใหม่ (`lib/screens/attendance_screen.dart`):**
    - สิ่งที่ทำ: เพิ่มเงื่อนไข `j.isSelectableForCheckIn` ใน `_pollTechnicianJobsSilently()` ตอนคำนวณ `newJobs`
    - ปัญหาที่พบ → วิธีแก้ไข: เดิม `newJobs` เช็กแค่ `!prevIds.contains(j.id)` ทำให้เมื่อ Backend ส่งงานเก่าที่ช่างคนนั้นส่งรายงานจบแล้วกลับมาในลิสต์ แอปเด้งแจ้งเตือน `New Job` หลอกทั้งที่หน้าจอขึ้น `NO JOBS AVAILABLE TODAY` → กรองด้วย `isSelectableForCheckIn` ให้แจ้งเตือนเฉพาะงานที่ทำได้จริง
- **ตรวจแล้ว:**
  - `F:\bin\flutter.bat analyze --no-fatal-infos`: 0 error, 0 warning (มีเฉพาะ SDK `material.dart` deprecation info)
  - `F:\bin\flutter.bat test test\settings_screen_test.dart`: ผ่านครบทุกข้อ (รวม `HelpFaqScreen`)
  - Build split release APK: `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk` และติดตั้งลงเครื่องทดสอบ

### 27 พฤศจิกายน 2026 — จับคู่ teamMemberId + แยก Error 502 จากไม่มีงาน + ตรวจเทสต์ทั้งโปรเจกต์

- **ทำแล้ว:**
  - เพิ่มการดึง `GET /team-members` และ `_resolveTeamMemberFromList(...)` ใน `lib/services/technician_service.dart` เพื่อจับคู่ `core.users.id ↔ hr.team_members.id` (และชื่อช่าง) ให้การจัดหมวด `YOUR JOB` และ `teamMemberId` ที่ส่งเข้า `POST /work-sessions` แม่นยำตลอด
  - ปรับ `_getMyJobsFromNestApi` ให้โยน `TechnicianApiException` ทันทีเมื่อ `GET /work-orders` ตอบกลับ non-2xx (เช่น `502 Bad Gateway`) แทนการคืนลิสต์ว่าง และเพิ่มสถานะ **แตะเพื่อลองใหม่ (`onRetry: _loadInitial`)** ใน `TechnicianJobActionZone` (`lib/widgets/technician_attendance_section.dart`, `lib/screens/attendance_screen.dart`) เพื่อแยกชัดระหว่าง *"ยังไม่มีงานวันนี้"* กับ *"โหลดงานไม่สำเร็จจากเซิร์ฟเวอร์"*
  - เคลียร์ `use_null_aware_elements` lint ใน `lib/services/technician_service.dart` (8 จุด) และ `lib/services/attendance_service.dart` (5 จุด) จนทั้ง `lib/` เหลือ 0 non-`material.dart` issues
  - เปลี่ยนชื่อแอปใน `android/app/src/main/AndroidManifest.xml` เป็น `Cirrus EMS` และเพิ่มตัวกรองสถานะ (`All` / `Completed` / `In Progress`) + ปุ่ม `Retry` ใน `lib/screens/technician_history_screen.dart`
  - เพิ่มฟีเจอร์ในหน้า `Settings > SYSTEM`: **Device & Connection Check** (`lib/screens/device_check_screen.dart` ตรวจเซิร์ฟเวอร์ EMS `/health` แบบไม่โชว์ URL ดิบ, จัดชิดบนพร้อมเวลา `Last checked`, ตรวจสิทธิ์ GPS และกล้อง), สวิตช์ **Haptic Feedback** และ **New Job Alerts** (`lib/services/app_preferences_service.dart` + เชื่อมใน `lib/screens/attendance_screen.dart`), และหน้า **Storage & Cache** แบบกราฟวงแหวน Telegram-style (`lib/screens/storage_cache_screen.dart` แยกสัดส่วน Image Memory / Temp Camera Photos / PDF & Documents / Other Temp พร้อม Dialog ยืนยันก่อนล้างแคชโดยไม่หลุด session) พร้อมอัปเดต `AGENTS.md` และ `PROJECT_STRUCTURE.md`
  - ปรับระบบ **Switch Account** (`lib/services/auth_service.dart`, `lib/screens/profile_screen.dart`): หน้า Quick Sheet แสดงเฉพาะ **3 บัญชีล่าสุดที่สลับ** (พร้อมเลื่อนบัญชีที่สลับสำเร็จขึ้นอันดับ 1 อัตโนมัติ, เก็บประวัติได้สูงสุด 30 บัญชี) และเพิ่มหน้าแยก **All Switched Accounts** (`lib/screens/saved_accounts_screen.dart`) สำหรับค้นหา ลบ และสลับบัญชีทั้งหมดที่เคยเข้าใช้งาน
  - ปรับสัดส่วนฟอนต์ภาษาไทย (`IBMPlexSansThai`) ใน `lib/theme/app_theme.dart` และ `0.93` optical scale ใน `lib/main.dart` ให้สมสัดส่วนและไม่ตัดสระ/วรรณยุกต์ทั้งแอป
  - เพิ่มตัวช่วยสำหรับช่างหน้างาน: เพิ่มตัวเลือกขนาดตัวอักษร **`XL / ใหญ่มาก` (`1.24x`)** ใน `lib/services/theme_service.dart` + `lib/screens/appearance_settings_screen.dart` และระบบ **Auto-Save ร่างรายงานอัตโนมัติ** (`ems.reportDraft.<id>`, กู้คืน + ปุ่มล้าง + ลบอัตโนมัติเมื่อส่งสำเร็จ) ใน `lib/screens/technician_report_screen.dart` พร้อมเพิ่มเทสต์ใน `test/technician_attendance_test.dart`
  - ยืนยัน `Check-In` และ `Check-Out` จริงบน `api.cirrusmarine.site` สำเร็จแล้ว (`WO-000017`), ปรับ `_closeSessionViaNestApi` ให้ยิง `POST /work-sessions/:id/check-out` + `POST /work-sessions/:id/confirm-job-status` และ `POST /work-sessions/:id/break` ก่อน, ปรับ **`Take a Break`** ให้กดยืนยัน + GPS โดยไม่ต้องถ่ายรูป, และตัดฟิลด์ `findings` / `recommendations` ระดับบนออกจาก `POST /technician-reports` พร้อม auto-confirm job status อัตโนมัติก่อนส่งรายงาน
  - เพิ่ม **Dialog แจ้งเตือนกลางหน้าจอตอนเปิดแอป** (`pending-report-startup-dialog`) เมื่อช่างมีรายงานการทำงานที่ค้างส่ง กด **ตกลง (`OK`)** แล้วเด้งเข้าหน้า `TechnicianReportScreen` ของงานที่ค้างไว้ทันที (`lib/screens/attendance_screen.dart`)
  - ยืนยันการส่งรายงานการทำงานจริงบน `api.cirrusmarine.site` (`WO-000017`) สำเร็จแล้วหลังปรับ `confirm-job-status` retry ใน `lib/services/technician_service.dart`
  - ปรับหน้า `TechnicianHistoryScreen` (`lib/screens/technician_history_screen.dart`) ให้ **ซ่อนรายละเอียดรายงาน** (`workDescription`, `findings`, `recommendations`) เป็นค่าเริ่มต้นและแตะที่การ์ดเพื่อกาง/ย่อ (`Details` / `Hide`) พร้อมย่อ UUID ของเลขรายงานเป็น `#XXXXXXXX` เพื่อความกระชับ (อัปเดตเทสต์ใน `test/technician_attendance_test.dart`)
  - เสริมระบบป้องกัน **Human Error & System Error** ครบชุด: (1) `PopScope` เตือนก่อนกด Back หากแนบรูปถ่ายไว้ใน `TechnicianReportScreen`, (2) Dialog ยืนยันก่อนกด `Clear` ร่างรายงาน, (3) Dialog ยืนยันก่อนกด `Submit Work Report` พร้อมเตือนหากยังไม่มีรูปแนบ, (4) แจ้งเตือนก่อน Log Out / Switch Account ใน `ProfileScreen` เมื่อช่างยัง `ON SITE` หรือมีรายงานค้างส่ง (`TechnicianService.lastDashboardData`), (5) จำ `storageKey` ของรูปที่อัปโหลดแล้วใน `TechnicianReportScreen` เพื่อกันอัปโหลดซ้ำตอน Retry, (6) แจ้งเตือนแบบไม่บล็อกงานเมื่อจับพิกัด GPS ไม่ได้ (`LocationService` คืนค่า `null`), และ (7) แปลง error เครือข่าย/timeout/5xx เป็นภาษาที่อ่านเข้าใจง่ายผ่าน `AppStrings.friendlyError` (`lib/l10n/app_strings.dart`, `attendance_screen.dart`, `technician_report_screen.dart`, `technician_history_screen.dart`)
  - ปรับหน้า `ALL JOB CODES` (`lib/screens/technician_jobs_screen.dart`, `lib/services/technician_service.dart`, `lib/widgets/technician_attendance_section.dart`) แยกสถานะงานแบบ 3 กรณี: (1) ซ่อนงานที่ Backend ปิดแล้ว (`completed`/`closed`/`cancelled`), (2) ย้ายงานที่ช่างส่งรายงานเสร็จแล้ว (`Completed`) แต่เว็บยัง `OPEN` ไปอยู่หมวดล่าง **`SUBMITTED · AWAITING CLOSE`** พร้อมป้ายเขียว `REPORT SUBMITTED ✓` และล็อกไม่ให้กด Check-In ซ้ำ, (3) งานที่ส่งรายงานแบบ `In Progress` ยังอยู่ด้านบนเพื่อทำต่อได้ (เพิ่มเทสต์ใน `test/technician_attendance_test.dart`)
  - ปรับปุ่มโหมดช่างใน `TechnicianJobActionZone` (`lib/widgets/technician_attendance_section.dart`, `lib/screens/attendance_screen.dart`): หากช่างสแกนเข้างานวันนี้แล้ว (เช่น สแกนจากเครื่องสแกนนิ้ว) ปุ่มจะเปลี่ยนจาก **`Check In / เช็คอิน`** เป็น **`Start Job / เริ่มงาน`** อัตโนมัติ (เพิ่มเทสต์ใน `test/technician_attendance_test.dart`)
  - อัปเดตเทสต์กล้องเก่าที่ยังคาดหวังข้อความ `'Confirm'` ให้ตรงกับปุ่ม `'Use Photo'` ใน `test/attendance_camera_switching_test.dart` และ `test/attendance_screen_checkin_test.dart` และเพิ่มเทสต์ใน `test/settings_screen_test.dart` (Haptics, Clear Cache, DeviceCheckScreen)
  - **ลดขนาดแอปบนมือถือ (App Size Optimization) โดยคงคุณภาพ UI/ฟีเจอร์เดิม 100%:**
    - ตัด dependency ที่ไม่ได้ใช้งาน (`cupertino_icons`, `flutter_animate`) และ asset ที่ไม่ได้อ้างอิง (`lib/assets/Cirrus_app_logo.png`) ออกจาก `pubspec.yaml`
    - เปิด R8 code shrinking (`isMinifyEnabled = true`), resource shrinking (`isShrinkResources = true`), `localeFilters += listOf("en", "th", "ms")` และ `packaging.jniLibs.useLegacyPackaging = false` ใน `android/app/build.gradle.kts` พร้อม `android/app/proguard-rules.pro` (fallback ไปใช้ debug keystore เมื่อไม่มี `android/key.properties` สำหรับ build release ทดสอบในเครื่อง)
    - Build แบบ `--release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols` พร้อม `--tree-shake-icons` (ลด `MaterialIcons-Regular.otf` จาก 1,645,184 bytes เหลือ 22,192 bytes, ลดลง 98.7%)
  - **แจ้งเตือนไปสแกนเข้างาน + ล็อกหน้ารายงานการทำงานแบบเข้มงวด:**
    - แก้ `_hasScannedAttendanceToday` ใน `lib/screens/attendance_screen.dart` ให้ตรวจ `workDate`/`scannedAt` ของวันนี้จริง (ไม่ดึงสแกนค้างจากวันก่อนมาขึ้นปุ่ม `Start Job`), เพิ่มข้อความเตือนสแกนเข้างานใน SnackBar เมื่อมี Job Code ใหม่เข้า และเพิ่มแบนเนอร์ `technician-scan-reminder-banner` ใน `lib/widgets/technician_attendance_section.dart` แสดงตลอดเมื่อวันนี้ยังไม่ได้สแกนเข้างาน (ทั้งกรณีมี Job Code และยังไม่มี Job Code) พร้อมแปลข้อความ error `MORNING_IN` ใน `lib/l10n/app_strings.dart`
    - ล็อกหน้ารายงานการทำงานแบบเข้มงวด: `PopScope(canPop: false)` บน `pending-report-startup-dialog`, ซ่อนปุ่ม Back บน AppBar และบล็อก `PopScope` (`report-locked-snackbar`) ใน `lib/screens/technician_report_screen.dart` จนกว่าจะส่งรายงานสำเร็จ, เปิดผ่าน `rootNavigator: true` พร้อม `_reportScreenOpen` กัน background poll ซ้อน และเพิ่ม `WidgetsBindingObserver` flush ร่างรายงานทันทีเมื่อแอปเข้า `inactive`/`paused` (รองรับกรณีปัดแอปทิ้ง)
  - **แจ้งเตือนจับเวลาทำงานสดบนแถบ Status Bar / Notification ของ Android (`Chronometer`):**
    - เพิ่ม `MethodChannel('com.cirrusgroup.ems/work_timer')` ใน `android/app/src/main/kotlin/com/cirrusgroup/ems/MainActivity.kt` และสิทธิ์ `POST_NOTIFICATIONS` ใน `android/app/src/main/AndroidManifest.xml` (ขอสิทธิ์อัตโนมัติบน Android 13+) แสดง notification แบบ `setUsesChronometer(true)` + `setOngoing(true)` นับเวลาต่อเนื่องตาม `checkInAt` ของ `activeSession` แม้พับแอป
    - สร้าง `lib/services/work_timer_notification_service.dart` และเชื่อมใน `lib/screens/attendance_screen.dart` (แสดงเมื่อมี `activeSession`, ยกเลิกเมื่อ `Break` / `Check Out`) และ `lib/screens/profile_screen.dart` (ยกเลิกเมื่อ Log Out)
  - **ชุดไฟล์ SQL Migration & API Spec สำหรับทีม Backend (`sql/`):**
    - สร้าง `sql/001_employee_payroll_items.sql` (idempotent migration สร้างตาราง `hr.employee_payroll_items` + index + seed component มาตรฐาน 3 ตัวใน `hr.payroll_components`)
    - สร้าง `sql/PAYROLL_API_SPEC.md` (สเปก 6 endpoints และ RBAC สำหรับเชื่อมเมนู `Payroll & Deductions`)
  - **ปรับ UI หน้า Local Leave (`lib/screens/leave_trial_tab.dart`, `lib/screens/leave_drafts_screen.dart`):** ลบปุ่ม `View all drafts` ซ้ำซ้อนด้านล่างออก คงไว้เฉพาะลิงก์ `View all (N) >` ด้านบนหัวข้อ `YOUR LEAVE DRAFTS`, ซ่อนปุ่ม `Cancel draft` พร้อมแสดงป้าย `Passed / ผ่านวันที่ลาแล้ว` สำหรับใบลาที่ผ่านวันที่ลาไปแล้ว, แยกการ์ดหัวข้อ `AmbientPanel` ออกจากฟอร์ม `Card` ไม่ให้ซ้อนขอบ, เปลี่ยน `One day` เป็น `Switch.adaptive` พร้อมซ่อนช่อง `End date` เมื่อเลือกวันเดียว, จัดชิปเหตุผลให้อยู่แถวเดียวเลื่อนแนวนอนได้ และปรับปุ่ม `View PDF` เป็น `OutlinedButton.icon` ทรง pill
  - **QoL ใช้งานจริง (`lib/screens/technician_report_screen.dart`, `lib/screens/main_shell.dart`, `lib/screens/profile_screen.dart`):** แสดงความคืบหน้าการอัปโหลดรูปทีละรูป (`กำลังอัปโหลดรูป 1/4...`) บนปุ่มส่งรายงาน, เพิ่ม `PopScope` กันเผลอปัดขอบจอกลับในหน้าหลัก (`กดย้อนกลับอีกครั้งเพื่อออกจากแอป` ภายใน 2 วินาที), และแสดง Dialog โหลดแจ้งชื่อบัญชีระหว่างสลับบัญชี (`ท่านกำลังสลับไปใช้บัญชี ...`)
  - **สรุปสถิติการเข้างานรายเดือนบนหน้า History (`lib/screens/history_screen.dart`):** เพิ่มการ์ด Insights 2×2 (`Work days`, `Late`, `Early leave`, `Overtime`) ใต้การ์ดชั่วโมงทำงาน พร้อมแตะกรองวันที่มีสาย/ออกก่อน/OT, ปุ่มลัด `This month / เดือนนี้` ใต้ตัวเลือกเดือน, และป้ายสรุปบนการ์ดรายวัน (`Late` / `Early leave (HH:mm)` / `OT`)
  - **ดึงฐานเงินเดือนจาก `GET /compensation` (`lib/services/payroll_service.dart`, `lib/screens/earnings_trial_tab.dart`):** ให้ `PayrollService.getMyPayrollConfig()` ข้าม `GET /payroll/my-config` บนเซิร์ฟเวอร์จริง (เรียกเฉพาะ Local Bridge) เพื่อไม่ให้ไปชน route `@Get('payroll/:id')` จนเกิด error `invalid input syntax for type uuid: "my-config"` และยิง `GET /compensation` ตรงแทน (เพิ่มเทสต์ใน `test/payroll_management_test.dart`)
  - **ข้อมูลเรือและอุปกรณ์ในหน้า Job Details (`lib/services/technician_service.dart`, `lib/screens/technician_jobs_screen.dart`):** ดึงรายละเอียดเรือ (`/vessels`) และอุปกรณ์ (`/assets`) มาแสดงเป็นการ์ด `VESSEL & EQUIPMENT` ใน `TechnicianJobDetailScreen` (ประเภทเรือ, รุ่น, ทะเบียน/IMO, ชื่ออุปกรณ์, รุ่น, Serial No.) พร้อมเพิ่มเทสต์ใน `test/technician_attendance_test.dart`
  - **แจ้งเตือน Job Code ใหม่แบบ Heads-Up + สั่น (`MainActivity.kt`, `AndroidManifest.xml`, `work_timer_notification_service.dart`, `attendance_screen.dart`):** เพิ่มช่อง Notification `cirrus_new_jobs` (`IMPORTANCE_HIGH` + `VIBRATE`) เด้งเตือนพร้อมสั่นแม้อยู่นอกแอป/พับแอป/ล็อกจอ (แตะเปิดเข้าหน้างานได้ทันที)
  - **กำหนดส่งรายงานก่อน 07:00 น. วันถัดไป + นับนาทีสาย (`technician_service.dart`, `technician_report_screen.dart`, `attendance_screen.dart`):** เพิ่ม `reportDeadlineLocal`, `reportLateMinutes()`, `reportRemainingTime()` บน `TechnicianWorkSession`, แสดงแบนเนอร์เตือนเวลาที่เหลือหรือจำนวนนาทีที่เกิน 07:00 น. บนหน้ารายงานและ Dialog เปิดแอป และแนบ `[ส่งรายงานช้า / Late Report: +N min]` ใน `workDescription` เมื่อเกินกำหนด (เพิ่ม unit/widget tests ใน `test/technician_attendance_test.dart`)
  - **ล้าง Job Code ที่ส่งรายงานเสร็จแล้วออกจากหน้า Attendance อัตโนมัติ + หน้าต่างยินดีเมื่อจบงาน (`lib/screens/attendance_screen.dart`):**
    - ใน `_loadInitial()`, `_pollTechnicianJobsSilently()` และ `_openTechnicianReport()` ให้เคลียร์ `_selectedTechJob` ทันทีเมื่องานนั้นมี `isSelectableForCheckIn == false` เพื่อไม่ให้งานที่ `Completed` ค้างอยู่บนปุ่ม `START JOB`
    - เพิ่ม AlertDialog แสดงความยินดี (`Key('job-completed-dialog')`, `Job Completed!` / `ยินดีด้วย! จบงานเรียบร้อยแล้ว`) พร้อม Haptic Feedback และปุ่ม `เยี่ยมเลย / Great!` (`Key('job-completed-ok-button')`) เมื่อช่างกดจบงานแบบ `completed` และส่งรายงานการทำงานสำเร็จ (เพิ่มเทสต์ใน `test/technician_attendance_test.dart`)
  - **เพิ่มกติกาการบันทึกเอกสาร `.md` (`AGENTS.md`):** ปรับกติกาใน `AGENTS.md` ให้บันทึกอัปเดตระบุทั้ง **สิ่งที่ทำ/สิ่งที่เปลี่ยน** คู่กับ **ปัญหาที่พบและวิธีแก้ไข** ในความยาวระดับปานกลาง กระชับ ตรงประเด็น ไม่เวิ้นเว่อ (แก้ปัญหาการจดแค่รายการที่ทำแล้วไม่เห็นสาเหตุและวิธีแก้ย้อนหลัง)
  - **เพิ่ม UI/UX Micro-Animations 6 จุด (Zero New Packages + 60fps Safe):**
    - สิ่งที่ทำ: (1) เพิ่ม `_LivePulseDot` ข้างป้าย `ON SITE` และ `AnimatedSize`/`AnimatedSwitcher` สลับการ์ดสถานะใน `lib/widgets/technician_attendance_section.dart`; (2) แยก `JobCompletedDialog` (`lib/widgets/job_completed_dialog.dart`) พร้อม `_ConfettiBurstPainter` (1.2 วินาทีจบในตัว) และไอคอน `elasticOut`; (3) เพิ่ม `AnimatedSwitcher` ชื่อเดือน + `TweenAnimationBuilder<int>` นับชั่วโมงและ Insights 2×2 ใน `lib/screens/history_screen.dart`; (4) เพิ่ม `AnimatedRotation` ลูกศรกางรายละเอียดใน `lib/screens/technician_history_screen.dart`; (5) เพิ่ม pop-in รูปถ่าย + แถบความคืบหน้าการอัปโหลดบนปุ่มส่งรายงานใน `lib/screens/technician_report_screen.dart`; (6) เปิด `themeAnimationDuration: 260ms` ใน `lib/main.dart`
    - ปัญหาที่พบ → วิธีแก้ไข: แอนิเมชันวนซ้ำอาจทำให้ `tester.pumpAndSettle()` ค้าง และอาจกินแบตถ้าไม่แยก layer → ป้องกันใน `_LivePulseDot` ด้วยการปิด loop เมื่ออยู่ใน Widget Test หรือเปิด Reduced Motion พร้อมครอบ `RepaintBoundary` และให้ confetti ใน `JobCompletedDialog` เล่น `forward()` รอบเดียวแล้วหยุด
  - **ซ่อนงานที่ส่งรายงานจบแล้วออกจากหน้า `ALL JOB CODES` และการ์ดเลือกงานหน้า Attendance (`lib/screens/technician_jobs_screen.dart`, `lib/widgets/technician_attendance_section.dart`):**
    - สิ่งที่ทำ: กรอง `isSubmittedAwaitingClose` ออกจากทั้ง `myJobs` และ `otherJobs` พร้อมลบหมวด `SUBMITTED · AWAITING CLOSE` ใน `TechnicianJobsScreen` และปรับ `TechnicianJobActionZone` (`_jobSelectorCard`) ให้คำนวณ `openJobs` (เฉพาะงานที่ยังไม่ส่งรายงานจบและยังไม่ปิด) แทน `jobs.length`
    - ปัญหาที่พบ → วิธีแก้ไข: งานที่ช่างส่งรายงานจบแล้ว (`WO-000018`, `WO-000019`) แต่เว็บยังไม่ปิดใบงานยังทำให้ปุ่มเลือกงานขึ้น `Tap to view all Job Codes (2)` และโชว์ค้างในหน้ารายการงาน → กรอง `openJobs` ทั้งสองจุดให้เหลือเฉพาะงานที่ยังทำได้จริง เมื่อไม่มีงานค้างจะแสดง `No jobs available today` (อัปเดตเทสต์ใน `test/technician_attendance_test.dart`)
- **ตรวจแล้ว:**
  - `F:\bin\flutter.bat analyze --no-fatal-infos`: 0 error, 0 warning (มีเฉพาะ SDK `material.dart` deprecation info)
  - `F:\bin\flutter.bat test test\technician_attendance_test.dart test\settings_screen_test.dart test\ui_refresh_test.dart`: ผ่านครบ **40/40** ข้อ
  - Build split release APK: `app-arm64-v8a-release.apk` **22.0 MB**, `app-armeabi-v7a-release.apk` **20.2 MB**, `app-x86_64-release.apk` **23.4 MB**
  - ติดตั้ง `app-x86_64-release.apk` และเปิดแอปบน `emulator-5554` สำเร็จ
- **ตรวจ `README.md`:** ตรวจแล้วไม่มีผลกระทบต่อภาพรวม (`อัปเดตล่าสุด: 27 พฤศจิกายน 2026` ตรงแล้ว)

### 26 พฤศจิกายน 2026 — โหมดช่าง Check-In / Break พัก / Check-Out + แนบรูปและปัญหาที่พบในหน้ารายงานการทำงาน

- **ทำแล้ว (โหมดช่าง & รายงานการทำงาน):**
  - ปรับ flow โหมดช่าง (`Technician` & `Admin`) เป็น **Check-In → Break พัก (พร้อมปุ่ม "จะจบงานเลยไหม?" / กลับมาทำงานต่อ) → Check-Out** และเพิ่ม endpoint `/technician/break` + `/technician/end-from-break` ใน `.tools/ems_local_server.js` โดยคงสูตร OT/Bonus หลัง 17:00 น. ตามเดิม
  - อัปเกรดหน้า `TechnicianReportScreen` (`lib/screens/technician_report_screen.dart`): เพิ่มการ์ด **รูปภาพการทำงาน (`WORK PHOTOS`)** กดถ่ายรูปผ่าน `AttendanceCameraScreen` แนบได้สูงสุด 4 รูปพร้อม thumbnail ลบออกได้ และอัปโหลดผ่าน `AttendanceService.uploadAttendancePhoto(...)` ส่ง array ไปเก็บใน `operations.technician_reports.photos` (jsonb) โดยไม่แก้ schema DB
  - ปรับการ์ด **ปัญหาที่พบระหว่างทำงาน (`PROBLEMS / ISSUES ENCOUNTERED`, `Key('report-findings-field')`)** ให้ชัดเจนขึ้น พร้อมแสดงจำนวนรูป (`photoCount`) และกรอบไฮไลต์ปัญหาที่พบในหน้า `TechnicianHistoryScreen` (`lib/screens/technician_history_screen.dart`)
  - เพิ่ม **ตัวนับเวลาทำงานแบบเรียลไทม์ (`_TechnicianWorkTimer`, `HH:MM:SS`)** ครอบด้วย `RepaintBoundary` ในการ์ด `ON SITE` หลังช่างกด Check In (`lib/widgets/technician_attendance_section.dart`)
  - สลับ `.env` ไปใช้ **`https://api.cirrusmarine.site/api/v1/ems`** และเพิ่ม **NestJS Direct Endpoint Adapter** ใน `lib/services/technician_service.dart` ให้ fallback อัตโนมัติเมื่อเจอ `404` จาก `/technician/*` ไปเรียก `/work-orders`, `/work-assignments`, `/work-sessions`, `/technician-reports` โดยตรง (รองรับทั้ง `camelCase` และ `snake_case`)
  - เพิ่ม **Real-time Job Watcher** ใน `lib/screens/attendance_screen.dart` (silent poll ทุก 15 วินาที + รีเฟรชทันทีเมื่อสลับกลับเข้าแอป) เมื่อพบ Job Code ใหม่จะสั่นแจ้งเตือน (`HapticFeedback.heavyImpact`), เด้งแถบแจ้งเตือน `มี Job Code ใหม่เข้า: ...`, และอัปเดตรายการ + red badge อัตโนมัติทันที
  - แก้การจับคู่ช่างกับงานบน `api.cirrusmarine.site`: ตรวจ JSON จริงผ่าน log ชั่วคราว (ลบออกแล้ว) พบว่า `GET /work-orders` ส่งช่างมาใน **`technicians: [{id, name}]`** และ `GET /work-assignments` คืน 0 รายการ จึงเพิ่ม `_parseTechnicians()` อ่าน array นี้ (จับคู่ด้วย `core.users.id` + fallback username/ชื่อ เช่น `Bom V.2`), แสดงชื่อช่างทุกคนในช่อง Assigned Technician และดึง `GET /work-orders/:id` เพิ่มตอนเปิดหน้ารายละเอียดงาน
  - เพิ่มการดึงข้อมูล **ชื่อเรือ (`vesselName`) และโปรเจกต์ (`projectName`)** จาก `/projects`, `/vessels`, `/assets` บน `api.cirrusmarine.site` มาแสดงใน 3 จุด (หน้า All Job Codes ทั้ง `YOUR JOB` และ `OTHER JOBS`, หน้า Job Details แถว `Vessel`/`Project`, และหน้า Attendance ทั้งการ์ดรายละเอียดงานที่เลือกและสถานะ `ON SITE`) พร้อมป้ายชื่อเรือสี Turquoise ทึบแบบกะทัดรัด กล่องรายละเอียดสรุปบนการ์ด และ **Dialog ยืนยันก่อนเลือก Job Code (`confirm-job-selection-dialog`, มีปุ่ม `×` และ `No / Yes` คู่กัน)** เพื่อป้องกัน human error ก่อนเด้งกลับหน้า Check In
  - แก้ `uploadRequestId` ในการอัปโหลดรูปทั้งหมดของโหมดช่าง (`Check In`, `Break`, `Resume`, `Check Out`, และรูปรายงานการทำงาน) ให้ส่งเป็น **UUID v4 (`const Uuid().v4()`)** ตรงตาม validation ของ `POST /storage/uploads` บน `api.cirrusmarine.site`
  - ปรับ payload ของ `POST /work-sessions` (`_checkInViaNestApi`) ใน `lib/services/technician_service.dart` ให้ตรงกับ NestJS DTO (`workOrderId`, `teamMemberId`, `createdBy`, `notes` รวมพิกัด GPS), สั่งลงเวลาเข้างาน (`POST /app-attendance/events`) **ก่อน** สร้าง work session, และรองรับ `teamMemberId` ตอนดึง sessions/history (ใช้โหมดเชื่อม API จริง 100% บน `https://api.cirrusmarine.site/api/v1/ems` โดยไม่เก็บ session/report ปลอมในเครื่อง)
  - ปรับการส่งรายงานการทำงาน (`POST /technician-reports`) ใน `lib/services/technician_service.dart` ให้จัดรวมข้อความ (`[ปัญหาที่พบ / Issues]` และ `[งานค้างต่อ / Recommendations]`) ต่อท้ายใน `workDescription` อย่างเป็นระเบียบควบคู่กับฟิลด์ `findings`, `recommendations` และ `photos` หลังช่างกดจบงาน (Check-Out) และตัดฟิลด์ `projectId` ออกจาก payload หลังทดสอบจริงบน `api.cirrusmarine.site` พบว่า DTO ไม่อนุญาต (`property projectId should not exist`) — ตรวจ `README.md` แล้วไม่มีผลกระทบต่อภาพรวม
  - อัปเดต `start_emulator_and_backend.bat` ให้เช็กสถานะ `https://api.cirrusmarine.site/api/v1/ems/health` โดยตรงแทน Local Node Bridge, สร้างไฟล์ log ยิง API จริงที่ `problem/backend_api_error.log`, และอัปเดต `problem/BACKEND_INTEGRATION_REQUEST.md` (เพิ่ม log จริงและผลเทสต์ DTO ของ `POST /technician-reports` ที่ผ่านแล้ว — ตรวจ `README.md` แล้วไม่มีผลกระทบต่อภาพรวม)
  - เพิ่มและนำเมนูชั่วคราว **`Test Work Report Form`** ใน `Settings > TECHNICIAN` (`lib/screens/settings_screen.dart`) ออกเรียบร้อยแล้ว หลังใช้ทดสอบยืนยันบน `api.cirrusmarine.site` ว่า DTO ของ `POST /technician-reports` ผ่าน validation ครบถ้วน (ตรวจ `README.md` แล้วไม่มีผลกระทบต่อภาพรวม)
  - สร้างเอกสารส่งทีมเว็บ/Backend ที่ `docs/TECHNICIAN_API_GUIDE.md`
  - สร้างแผนผังระบบแบบมินิมอล 1 หน้าจอไว้ที่ `docs/attendance_flow_preview.html`
- **ตรวจแล้ว:**
  - `node --check .tools/ems_local_server.js` ผ่าน และรีสตาร์ท Local EMS Bridge บนพอร์ต 3000 แล้ว
  - `F:\bin\flutter.bat analyze lib/screens/technician_report_screen.dart lib/screens/technician_history_screen.dart lib/services/technician_service.dart test/technician_attendance_test.dart`: 0 error, 0 warning (มีเฉพาะ SDK `material.dart` deprecation info 3 รายการ)
  - `F:\bin\flutter.bat test test/technician_attendance_test.dart`: ผ่านครบ 7/7 ข้อ (รวมตรวจปุ่มแนบรูปการทำงาน, ช่องกรอกปัญหาที่พบ, และการแสดงจำนวนรูป/ปัญหาที่พบในหน้าประวัติรายงาน)
  - ตรวจและอัปเดต `README.md` ให้ตรงกับฟีเจอร์ล่าสุดแล้ว
