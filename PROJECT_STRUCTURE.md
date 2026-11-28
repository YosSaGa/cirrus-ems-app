# แผนที่โครงสร้างโปรเจกต์ Cirrus EMS

อัปเดตล่าสุด 25 พฤศจิกายน 2026

เอกสารนี้ช่วยค้นหาตำแหน่งโค้ดสำหรับผู้พัฒนาและ AI agent อ่าน [README.md](README.md) เพื่อเข้าใจการทำงานและวิธีรัน อ่าน [TASK_STATUS.md](TASK_STATUS.md) เพื่อดูสถานะล่าสุด และอ่าน [AGENTS.md](AGENTS.md) สำหรับกติกาการแก้ไข ใช้ [DESIGN.md](DESIGN.md) เมื่อปรับ UI

โปรเจกต์เป็น Flutter app ฝั่งพนักงาน ใช้ EMS Backend ภายนอก โฟลเดอร์นี้ไม่มี source code ของ Backend หรือฐานข้อมูล ชื่อ package ของ Flutter คือ `cirrus_app` และ Android application ID คือ `com.cirrusgroup.ems`

## ภาพรวมการทำงาน

`lib/main.dart` โหลด `.env` และเปิด `SplashScreen` ซึ่งตรวจ session ผ่าน `AuthService` แล้วนำไปหน้า Login หรือ `MainShell` ภายใน shell มี Attendance, History, Pay & Leave และ Profile

Attendance ส่งรูปและ event ผ่าน `AttendanceService` พร้อมจัดการรายการค้าง History อ่าน attendance records และ scan events จากคนละ endpoint ส่วน Pay estimate อ่าน scan events และคำนวณในแอป Local leave เก็บแบบร่างไว้ในเครื่อง

## โฟลเดอร์ระดับบนสุด

| ตำแหน่ง | หน้าที่ |
| --- | --- |
| `lib/` | โค้ด Dart หลักของแอป |
| `test/` | unit tests, widget tests และ test support |
| `assets/icon/` | ภาพต้นทางสำหรับสร้าง Android launcher icon |
| `assets/fonts/` | Bebas Neue, IBM Plex Sans Thai (4 น้ำหนัก), Sarabun และ TH Sarabun PSK (Regular/Bold สำหรับแบบฟอร์มใบลาไทย PDF) |
| `android/` | Android runner, Gradle, manifest, activity และ resources |
| `ios/` | iOS runner, Xcode project, Info.plist และ assets |
| `web/` | Web entry HTML, manifest และ icons |
| `windows/`, `linux/`, `macos/` | runner และ build configuration ของแต่ละ desktop platform |
| `docs/superpowers/` | แผนและข้อกำหนดงานทดลองที่บันทึกไว้ในอดีต ใช้ README และ TASK_STATUS ตรวจสถานะปัจจุบันประกอบ เพราะสูตรอาจเปลี่ยนแล้ว |
| `sql/` | ไฟล์ SQL migration (`001_employee_payroll_items.sql`) และเอกสารสเปก API (`PAYROLL_API_SPEC.md`) สำหรับส่งให้ทีม Backend เปิดใช้งานระบบ Payroll & Deductions |
| `.agents/skills/` | คำแนะนำ skill ภายในโปรเจกต์ รวม Official `flutter/skills` และ `dart-lang/skills` สำหรับ AI agent (ไม่ถูกรวมใน APK) |
| `.tools/python/` | Python portable สำหรับเครื่องมือด้านการออกแบบ |
| `.tools/ems_local_server.js` | Local EMS API Bridge พอร์ต `3000` สำหรับเชื่อมฐานข้อมูล PostgreSQL `cirrus_02` ในเครื่องพัฒนา |
| `start_emulator_and_backend.bat` | สคริปต์ดับเบิลคลิกสำหรับเปิด Local EMS Bridge + Android Emulator (`Pixel_10_Pro_XL_API_35`) และเปิดแอป Cirrus EMS อัตโนมัติ |
| `.oil-ui/screenshots/` | ภาพสำหรับตรวจ UI และอ้างอิง บางภาพอาจมีข้อมูลผู้ใช้จริง |
| `build/`, `.dart_tool/` | ผล build และข้อมูลที่ Flutter/Dart สร้างขึ้น |

## ไฟล์ระดับบนสุด

| ไฟล์ | หน้าที่ |
| --- | --- |
| `README.md` | ภาพรวม ความสามารถ API configuration และวิธีรัน |
| `TASK_STATUS.md` | งานที่ทำแล้ว งานค้าง ข้อจำกัด ผลตรวจ และประวัติ |
| `DESIGN.md` | แนวทางธีมและ UI |
| `AGENTS.md` | กติกาสำหรับผู้พัฒนาและ agent |
| `PROJECT_STRUCTURE.md` | แผนที่โฟลเดอร์และไฟล์ฉบับนี้ |
| `pubspec.yaml` | Flutter dependencies, assets, SDK constraint และ launcher icon configuration |
| `pubspec.lock` | เวอร์ชัน dependencies ที่ resolve แล้ว |
| `.env` | ค่า API base URL ที่โหลดโดย `main.dart` และประกาศเป็น asset ใน `pubspec.yaml` |
| `analysis_options.yaml` | กฎวิเคราะห์ Dart |
| `.gitignore`, `.metadata` | การละเว้นไฟล์ของ Git และ metadata ของ Flutter |
| `flutter_01.log`, `flutter_02.log` | log จากการรันที่ผ่านมา |
| `.flutter-plugins-dependencies` | ข้อมูล plugins ที่ Flutter สร้าง |

## หน้าจอใน `lib/screens/`

| ไฟล์ | หน้าที่ |
| --- | --- |
| `splash_screen.dart` | Animated Welcome Splash 3 จังหวะ (1.25 วิ, 60fps) พร้อมตรวจ/กู้ session แล้วเฟดไป Login หรือ MainShell |
| `login_screen.dart` | ฟอร์มเข้าสู่ระบบ (ปุ่มหมุน 700ms + เฟด 260ms), สถานะโหลด, ข้อผิดพลาด และ navigation เมื่อ login สำเร็จ |
| `main_shell.dart` | navigation หลัก 4 แท็บ ใช้ IndexedStack รักษา state พร้อมฟังทั้ง `ThemeService` และ `LanguageService` |
| `attendance_screen.dart` | สถานะลงเวลา, Pull-to-Refresh, ไทม์ไลน์ 4 ช่วง, ปุ่มเช็กอิน/เช็กเอาต์, โหมดช่าง (Role Technician/Admin), กล้องและพิกัดผ่าน services, pending retry และ pending checkout |
| `technician_jobs_screen.dart` | หน้ารายการ Job Code ทั้งหมด (ปักหมุดงานของตัวเองเด่นบนสุด + ค้นหา) และหน้า `TechnicianJobDetailScreen` ดูรายละเอียดงานเต็มพร้อมปุ่มเลือกเพื่อเช็คอิน |
| `technician_report_screen.dart` | หน้าบังคับเขียนและส่งรายงานการทำงาน (`operations.technician_reports`) หลัง Check Out เที่ยง/เย็น ก่อนเริ่มงานถัดไป |
| `technician_history_screen.dart` | หน้าประวัติงานที่ทำและรายงานช่างย้อนหลัง (เข้าผ่าน `Settings > Job & Report History` เฉพาะ Role `Technician` และ `Admin`) |
| `attendance_camera_screen.dart` | กล้องในแอป สลับกล้อง ถ่ายรูปและ preview |
| `history_screen.dart` | เลือกเดือน, Pull-to-Refresh, การ์ดชั่วโมง Deep Navy (ชู Hours Used for Pay เด่นด้านบน), Lazy `SliverList.builder` พร้อม precompute รายวัน และรายละเอียดรายวัน |
| `profile_screen.dart` | ข้อมูลพนักงานจาก API (Pull-to-Refresh, Shimmer skeleton, การ์ดรวม Account & Employment), ลิงก์ Settings, Switch Account (3 ล่าสุด) และ logout (ปุ่มหมุน 700ms + เฟด 260ms) |
| `saved_accounts_screen.dart` | หน้าดูบัญชีที่เคยสลับทั้งหมด (ค้นหา, ลบ, สลับบัญชี หรือเข้าสู่ระบบด้วยบัญชีใหม่) |
| `work_trial_screen.dart` | shell และสองแท็บของ Pay & Leave |
| `earnings_trial_tab.dart` | ประมาณค่าแรงจากสแกน (เรทต่อชั่วโมงตรง หรือ `เงินเดือน ÷ 30 ÷ 8`, fallback 300/8 ชม.) และการ์ดรายการหัก/ยอดสุทธิ (`_PayrollDeductionsCard`) |
| `pay_calculator_screen.dart` | หน้าเสริมจำลองคำนวณค่าแรงเอง (custom เงินเดือน/วันฐาน `30/26/22` และชั่วโมง/นาที ฝั่งเครื่องเท่านั้น) |
| `payroll_management_screen.dart` | หน้าจัดการอัตราค่าแรงรายชั่วโมงและรายการหัก (ค่าที่พัก, ประกันสังคม, ค่าประกันงาน, กำหนดเอง) เฉพาะสิทธิ์ HR Officer / Admin / Accountant / Owner |
| `leave_trial_tab.dart` | ฟอร์มและรายการลา (ส่งคำขอลาเข้า HR DB + แบบร่างในเครื่อง + PDF) |
| `leave_approval_screen.dart` | หน้าอนุมัติ/ไม่อนุมัติใบลาพนักงานสำหรับ HR/Admin/Manager/Owner |
| `leave_drafts_screen.dart` | หน้าแยกแสดงรายการแบบร่างใบลาทั้งหมดพร้อมกรองสถานะ All / Active / Cancelled |
| `settings_screen.dart` | เมนูตั้งค่าหลักของแอป (`Appearance`, `Language`, `Management` เฉพาะสิทธิ์ HR/Admin/Accountant, `About`) นำทางไปยังการตั้งค่าย่อย |
| `appearance_settings_screen.dart` | หน้าย่อย `Appearance` (รวม `App Theme` + `Pay Card Style`) และหน้า `PayCardStyleScreen` แสดงตัวอย่างบัตร `PayWalletCard` จริงพร้อมวงกลมเลือกสี 5 แบบ |
| `theme_settings_screen.dart` | หน้าย่อยเลือกธีมแอป (Default, Pure White, Obsidian Black) พร้อมตัวอย่างเฉดสี |
| `language_settings_screen.dart` | หน้าย่อยสลับภาษาแสดงผล (English / ภาษาไทย) พร้อมตัวอย่างข้อความและฟอนต์ IBM Plex Sans Thai |
| `device_check_screen.dart` | หน้าตรวจความพร้อมหน้างาน (เซิร์ฟเวอร์ EMS `/health`, สิทธิ์ GPS และกล้อง) พร้อมปุ่มขอสิทธิ์/เปิดตั้งค่าแอป |
| `help_faq_screen.dart` | หน้าคู่มือและคำถามที่พบบ่อย (Attendance, โหมดช่าง, รอบเงินเดือน/ใบลา, แก้ปัญหาเบื้องต้น) เข้าจาก Settings > About |
| `storage_cache_screen.dart` | หน้า Storage & Cache แบบกราฟวงแหวน (Telegram-style) แสดงสัดส่วนแคชแต่ละแหล่งและเลือกล้างแคชได้ |
| `welcome_screen.dart` | หน้า Welcome ที่มีอยู่ในโค้ด ตรวจ routes/callers ก่อนนำมาใช้ |

## Services และข้อมูล

| ไฟล์ | หน้าที่ |
| --- | --- |
| `lib/services/auth_service.dart` | เลือก base URL, HTTP auth, login/logout, session, Web SSO และตรวจสิทธิ์ RBAC (`canManagePayroll`, `isTechnician`) |
| `lib/services/secure_token_store.dart` | เข้ารหัสและจัดเก็บ JWT + Switch-Account tokens ด้วย `flutter_secure_storage` (Android Keystore / iOS Keychain) พร้อม auto-migrate จาก `SharedPreferences` |
| `lib/services/technician_service.dart` | REST client โหมดช่าง (`GET /technician/my-jobs`, `POST /technician/check-in`, `POST /technician/check-out`) เฉพาะ Role `Technician` |
| `lib/services/work_timer_notification_service.dart` | แสดง/ยกเลิก Android Chronometer notification นับเวลาทำงานสดบนแถบแจ้งเตือนระหว่างช่างอยู่ในสถานะ `ON SITE` (ผ่าน `MethodChannel`) |
| `lib/services/payroll_service.dart` | REST client สำหรับดึง/อัปเดตอัตราค่าแรงรายชั่วโมง (`hr.compensation`) และเพิ่ม/แก้ไข/ลบรายการหัก (`hr.employee_payroll_items`) |
| `lib/services/leave_service.dart` | REST client สำหรับส่งคำขอลา ดึงรายการ และอนุมัติ/ปฏิเสธใบลา (`GET/POST /leave`, `approve`, `reject`) |
| `lib/services/attendance_service.dart` | API สถานะ สแกน ประวัติ อัปโหลดรูป ส่ง event และจัดการ pending request รวม request ID สำหรับ retry |
| `lib/services/location_service.dart` | ขอพิกัดปัจจุบันตามสิทธิ์อุปกรณ์ |
| `lib/services/local_photo_store.dart` | เก็บ อ่าน และลบรูปใน app documents สำหรับ retry บนแพลตฟอร์มที่รองรับ |
| `lib/services/leave_pdf_builder.dart` | สร้าง PDF ใบลา 2 ภาษา (`LeavePdfLanguage.th` แบบฟอร์มใบลาไทยทางการ เติมอัตโนมัติ `เรียน หัวหน้า HR` และ `LeavePdfLanguage.en` แบบฟอร์มอังกฤษ `To: HR Manager`) พร้อมฝังฟอนต์ Sarabun และโลโก้ |
| `lib/services/file_download_service.dart` | บันทึกไฟล์ลง Downloads folder โดยตรง: MediaStore API (Android ≥29 ผ่าน MethodChannel), path_provider fallback, Desktop และ Web; มี `debugDownloadOverride` สำหรับ tests |
| `lib/services/theme_service.dart` | จัดการสถานะธีมแอป (Default, White, Black) พร้อมบันทึกและโหลดค่าจาก SharedPreferences |
| `lib/services/language_service.dart` | จัดการภาษาที่แสดงผล (`en` / `th`) พร้อมบันทึกและโหลดค่าจาก SharedPreferences (`ems.language`) |
| `lib/services/app_preferences_service.dart` | จัดการตั้งค่าการสั่น (Haptics) และแจ้งเตือน Job Code ใหม่ลง SharedPreferences |
| `lib/l10n/app_strings.dart` | ศูนย์รวมข้อความแสดงผล 2 ภาษา (EN/TH) สำหรับทุกหน้าและฟอร์แมตวันที่/เดือน/ประเภทใบลา |
| `lib/services/work_trial_store.dart` | โมเดลและ SharedPreferences สำหรับ leave drafts และการตั้งค่ารุ่นทดลอง แยกตาม user ID |
| `lib/services/api_client_factory.dart` | เลือก HTTP client ตามแพลตฟอร์มผ่าน conditional import |
| `lib/services/api_client_factory_stub.dart` | HTTP client สำหรับแพลตฟอร์มที่ใช้ implementation ทั่วไป |
| `lib/services/api_client_factory_web.dart` | Web HTTP client สำหรับการส่ง credentials |
| `lib/models/captured_photo.dart` | ข้อมูลรูปที่ถ่าย เช่น bytes, filename และ MIME type |
| `lib/models/payroll_calculator.dart` | จับคู่สแกน, สูตรค่าแรงจากฐานเงินเดือน (`เงินเดือน ÷ 30 ÷ 8`, fallback 300/8 ชม.), แยกนาทีทำงานและโบนัสหลัง cutoff และตรวจข้อมูล |
| `lib/theme/app_theme.dart` | สี ระยะห่าง รัศมี breakpoint และ Material theme |
| `lib/assets/` | โลโก้ Cirrus (`Cirrus_app_logo.svg` / `.png`) และโลโก้แนวนอน `cirrus_group_logo.png` สำหรับหัวกระดาษ PDF ใบลา |

## Widgets ใช้ร่วมกันใน `lib/widgets/`

| ไฟล์ | หน้าที่ |
| --- | --- |
| `app_bottom_nav.dart` | แถบนำทางมือถือและ animation ของแท็บ |
| `app_quick_drawer.dart` | เมนูลัด (Drawer `☰`) แสดงฟีเจอร์นอก Bottom Nav ตาม Role ผู้ใช้ |
| `app_side_nav.dart` | แถบนำทาง desktop |
| `success_feedback_overlay.dart` | แอนิเมชัน + เสียงแจ้งเตือนเมื่อส่งคำขอ/อนุมัติ/บันทึกสลิปสำเร็จ |
| `app_logo.dart` | แสดงโลโก้ Cirrus จาก SVG |
| `ambient_panel.dart` | พื้นหลังตกแต่ง navy/turquoise |
| `pay_wallet_card.dart` | การ์ดประมาณการค่าแรงสไตล์ Wallet Card พร้อม EMV chip, รหัสพนักงานจริง และแอนิเมชันแตะพลิก 3D |
| `live_clock.dart` | นาฬิกาเวลา Bangkok สำหรับแสดงผล |
| `time_action_button.dart` | ปุ่มวงกลมลงเวลา |
| `job_completed_dialog.dart` | หน้าต่างแสดงความยินดีพร้อม confetti burst และไอคอนเด้งเมื่อจบงานแบบ `completed` |
| `primary_cta_button.dart`, `primary_action_button.dart` | ปุ่มหลักและปุ่มรองที่ใช้ร่วมกัน |
| `status_banner.dart`, `status_chip.dart`, `empty_note.dart` | แสดงสถานะ ข้อผิดพลาด และข้อมูลว่าง |
| `detail_row.dart` | แถวข้อมูลรายละเอียด |
| `fade_slide_entry.dart` | animation เข้าแสดง widget พร้อมรองรับ reduced motion |
| `shimmer_box.dart` | skeleton loading แบบ shimmer สำหรับการ์ดและแถวข้อมูล พร้อมรองรับ reduced motion |
| `session_transition.dart` | transition สำหรับการเข้าสู่ระบบและออกจากระบบ |

## การทดสอบใน `test/`

| ไฟล์ | หน้าที่ |
| --- | --- |
| `auth_service_test.dart`, `splash_screen_test.dart` | auth, session และเส้นทางเริ่มแอป |
| `attendance_service_test.dart` | API และการจัดการ pending attendance/retry |
| `attendance_screen_checkin_test.dart`, `attendance_screen_progress_test.dart` | ขั้นตอนเช็กอินและสถานะช่วงเวลาบนหน้าจอ |
| `attendance_camera_screen_test.dart`, `attendance_camera_switching_test.dart` | กล้องและการสลับกล้อง |
| `local_photo_store_test.dart` | การเก็บรูปสำหรับ retry |
| `payroll_calculator_test.dart` | การคำนวณจากสแกนและกรณีข้อมูลผิดหรือทับซ้อน |
| `leave_pdf_builder_test.dart` | ตรวจสร้าง PDF, ข้อมูลเก่า, ข้อความไทยและเหตุผลยาว |
| `work_trial_store_test.dart`, `work_trial_screen_test.dart`, `pay_calculator_screen_test.dart` | storage, สูตรเงินเดือน, หน้าทดลอง Pay & Leave และหน้า Pay Simulator |
| `ui_refresh_test.dart`, `app_bottom_nav_test.dart`, `widget_test.dart` | UI, accessibility และ navigation |
| `settings_screen_test.dart`, `language_settings_test.dart` | ทดสอบ Settings, ระบบสลับธีม 3 แบบ และระบบสลับภาษา ไทย/อังกฤษ พร้อมฟอนต์ IBM Plex Sans Thai |
| `oil_ui_capture_test.dart` | จับภาพ Flutter โดยใช้ข้อมูลจำลองเมื่อกำหนด `OIL_UI_CAPTURE` |
| `support/fake_camera_platform.dart`, `support/preview_fonts.dart` | กล้องจำลองและฟอนต์สำหรับทดสอบ/จับภาพ |

## จุดที่ควรตรวจเมื่อแก้ฟีเจอร์

- **ลงเวลาและ retry** ตรวจทั้ง `attendance_screen.dart`, `attendance_service.dart`, `local_photo_store.dart` และ tests ที่เกี่ยวข้อง เพราะ request ID และรูปค้างสัมพันธ์กัน
- **History และ Pay estimate** ใช้สแกนจาก API เดียวกัน แต่กติกาชั่วโมงต่างกัน History อาจใช้เวลาอ้างอิงเมื่อสแกนขาด ส่วนค่าแรงนับคู่สแกนครบก่อน 17:00 โดยแสดงเวลาโบนัสแยก
- **Local leave** เป็นแบบร่างใน SharedPreferences ของผู้ใช้ ไม่มีการส่งคำขออนุมัติ
- **iOS/Web/Desktop** มีโฟลเดอร์ runner อยู่แล้ว ตรวจสถานะการทดสอบจริงใน TASK_STATUS ก่อนสรุปว่าฟีเจอร์ทำงานครบ
- **เอกสาร** หลังเปลี่ยนโครงสร้างหรือหน้าที่ไฟล์ ให้อัปเดตเอกสารนี้พร้อม README, TASK_STATUS และ AGENTS ตามกติกาโปรเจกต์
