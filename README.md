# Cirrus EMS

แอปลงเวลาทำงานและติดตามงานภาคสนามสำหรับพนักงานและช่างของ Cirrus Group (Flutter / Dart) เชื่อมต่อกับ EMS Backend ภายนอก

อัปเดตล่าสุด: 28 พฤศจิกายน 2026

---

## ฟีเจอร์หลัก

- **Attendance:** ลงเวลาเข้า–ออกงานพร้อมถ่ายรูปและแนบพิกัด GPS, ไทม์ไลน์ 4 ช่วงเวลา, จัดการเวลาออกค้าง และส่งรายการค้างซ้ำอัตโนมัติ
- **Technician Mode:** สำหรับสิทธิ์ `Technician` / `Admin` — เลือก Job Code (ปักหมุดงานตัวเองพร้อมชื่อเรือและโปรเจกต์), จับเวลาทำงานจริง, พักเบรก/จบงาน และเขียนรายงานการทำงานแนบรูปสูงสุด 4 รูป (Auto-Save ร่างอัตโนมัติ)
- **History:** ดูประวัติสแกนและการมาทำงานรายเดือนพร้อมสรุปชั่วโมงที่ใช้คำนวณค่าแรง
- **Pay & Leave:** ประมาณการค่าแรงจากสแกน (`ฐานเงินเดือน ÷ 30 ÷ 8` หรือเรทต่อชม.), Pay Simulator, จัดการเรท/รายการหัก (เฉพาะ HR/Admin/Accountant), และแบบร่างใบลาในเครื่องพร้อมส่งออก PDF 2 ภาษา (TH/EN)
- **Profile & Switch Account:** แสดงข้อมูลพนักงาน, สลับบัญชีด่วน 3 บัญชีล่าสุด พร้อมหน้าดู/ค้นหาบัญชีทั้งหมด
- **Settings:** 3 ธีม (Default / Pure White / Obsidian Black), 3 ภาษา (EN / TH / MY), ขนาดตัวอักษร 4 ระดับ (ถึง XL), Device & Connection Check, Haptic Feedback / New Job Alerts และ Storage & Cache

---

การสลับบัญชีตรวจ token ของบัญชีปลายทางก่อนเปลี่ยน session และเก็บ token ไว้เมื่อเครือข่ายขัดข้อง ส่วนรายการลงเวลาที่ยังส่งไม่สำเร็จเก็บแยกตามผู้ใช้เพื่อกลับมาส่งอีกครั้งหลังเข้าสู่บัญชีเดิม

Local EMS Bridge ใน `.tools/ems_local_server.js` รับการเชื่อมต่อเฉพาะ localhost ใช้รหัสผ่านจากฐานข้อมูล และลงลายเซ็น token ด้วยกุญแจชั่วคราวของ process การรีสตาร์ต Bridge ทำให้ token ที่ Bridge ออกก่อนหน้าใช้ไม่ได้

## Tech Stack

- **Framework:** Flutter 3.50.0 / Dart 3.14.0 (`cirrus_app`, Android ID `com.cirrusgroup.ems`)
- **State & Storage:** `SharedPreferences`, local photo store (`path_provider`)
- **Networking:** `http` (พร้อม idempotency key สำหรับ upload และ attendance event)
- **Fonts & PDF:** `Bebas Neue` (EN), `IBM Plex Sans Thai` (TH), `Sarabun` / `TH Sarabun PSK` (Leave PDF)

---

## การตั้งค่า (`.env`)

ไฟล์ `.env` ที่ root ของโปรเจกต์ใช้กำหนด API Base URL (รวม `/api/v1/ems` โดยไม่ใส่ `/` ท้าย):

```dotenv
API_BASE_URL_ANDROID=https://api.cirrusmarine.site/api/v1/ems
API_BASE_URL_WEB=https://api.cirrusmarine.site/api/v1/ems
API_BASE_URL_IOS=https://api.cirrusmarine.site/api/v1/ems
```

---

## วิธีรันและทดสอบ

```powershell
# เตรียม alias Flutter (กรณี path มีภาษาไทย)
subst F: "C:\Users\yossa\OneDrive\เอกสาร\CostCal\.tools\flutter"

# ติดตั้ง dependencies และรันแอป
F:\bin\flutter.bat pub get
F:\bin\flutter.bat run -d <device-id>

# ตรวจโค้ดและรันเทสต์
F:\bin\flutter.bat analyze --no-fatal-infos lib/
F:\bin\flutter.bat test

# Build APK (Profile / Debug)
F:\bin\flutter.bat build apk --profile -t lib/main.dart
```

---

## เอกสารเพิ่มเติม

- [TASK_STATUS.md](TASK_STATUS.md) — สถานะงานล่าสุด, ข้อจำกัด และผลทดสอบ
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) — โครงสร้างโฟลเดอร์และหน้าที่ไฟล์ทั้งหมด
- [DESIGN.md](DESIGN.md) — แนวทาง UI และ Design Tokens
- [AGENTS.md](AGENTS.md) — กติกาและคำสั่งพัฒนาสำหรับทีมและ AI Agent
- [problem/BACKEND_INTEGRATION_REQUEST.md](problem/BACKEND_INTEGRATION_REQUEST.md) — สรุปจุดเชื่อมต่อ Backend โหมดช่างที่รออัปเดต
